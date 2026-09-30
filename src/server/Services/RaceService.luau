--!strict
-- Racing: a race starts at each zone's start pad when players stand on it. Bots fill small lineups.
-- The server tracks checkpoints; a finish only counts if every checkpoint was passed in order and
-- no stretch was covered faster than the racer could possibly move.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local Teleport = require(script.Parent.Teleport)
local TutorialService = require(script.Parent.TutorialService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Zones = require(ReplicatedStorage.Config.Zones)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Economy = require(ReplicatedStorage.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local AnimalModel = require(ReplicatedStorage.Shared.AnimalModel)

local RACE = Economy.Race
local MAX_RACERS = 8
local MAX_SPEED_FACTOR = 3 -- anti-cheat: nobody can cover a stretch faster than this x their speed
local DEFAULT_JUMP = 50
local BOT_NAMES = { "Zippy", "Dash", "Bolt", "Flash", "Turbo", "Sprout", "Blaze", "Comet", "Pip", "Nibbles" }
local TUTORIAL_BOT_PACE = { 0.93, 0.8, 0.74 } -- first race: the player should finish 1st or 2nd

type Racer = {
	Player: Player?,
	Character: Model?,
	Humanoid: Humanoid?,
	Bot: Model?,
	Name: string,
	Lateral: number,
	Distance: number,
	NextCheckpoint: number,
	CheckpointTimes: { number },
	Finished: boolean,
	FinishTime: number,
	Left: boolean,
	Disqualified: boolean,
	Speed: number,
	Abilities: { [string]: number },
	BoostUntil: number,
	BoostMult: number,
	SlowUntil: number,
	ShieldUsed: boolean,
	LogHits: { [Instance]: boolean },
	Race: Race,
}

type Race = {
	Zone: string,
	Racers: { Racer },
	StartTime: number, -- 0 until "Go"
}

local rng = Random.new()
local racerByPlayer: { [Player]: Racer } = {}
local abilityReadyAt: { [Player]: number } = {}

local RaceService = {}

local function inSection(sections: { Zones.Section }?, d: number): boolean
	for _, section in sections or ({} :: { Zones.Section }) do
		if d >= section.From and d <= section.To then
			return true
		end
	end
	return false
end

local function speedMultiplier(racer: Racer, d: number, now: number): number
	local zoneId = racer.Race.Zone
	local track = Zones[zoneId].Track
	local mult = 1
	if track then
		if inSection(track.Water, d) then
			mult *= racer.Abilities.WaterSpeed or RACE.WaterMultiplier
		end
		if inSection(track.Sand, d) and not racer.Abilities.SandWalker then
			mult *= RACE.SandMultiplier
		end
	end
	if zoneId == "Forest" and racer.Abilities.ForestRunner then
		mult *= racer.Abilities.ForestRunner
	end
	if now < racer.BoostUntil then
		mult *= racer.BoostMult
	end
	if now < racer.SlowUntil then
		mult *= RACE.LogSlowMultiplier
	end
	return mult
end

local function newRacer(race: Race, name: string, speed: number): Racer
	return {
		Name = name,
		Lateral = 0,
		Distance = 0,
		NextCheckpoint = 1,
		CheckpointTimes = {},
		Finished = false,
		FinishTime = math.huge,
		Left = false,
		Disqualified = false,
		Speed = speed,
		Abilities = {},
		BoostUntil = 0,
		BoostMult = 1,
		SlowUntil = 0,
		ShieldUsed = false,
		LogHits = {},
		Race = race,
	}
end

local function rankBefore(a: Racer, b: Racer): boolean
	if a.Finished ~= b.Finished then
		return a.Finished
	end
	if a.Finished then
		return a.FinishTime < b.FinishTime
	end
	return a.Distance > b.Distance
end

local function placeOf(race: Race, racer: Racer): number
	local place = 1
	for _, other in race.Racers do
		if other ~= racer and rankBefore(other, racer) then
			place += 1
		end
	end
	return place
end

local function fireRacers(race: Race, kind: string, payload: { [string]: any }?)
	for _, racer in race.Racers do
		if racer.Player and not racer.Left then
			Net.Fire("RaceEvent", racer.Player, kind, payload or {})
		end
	end
end

local function resetHumanoid(humanoid: Humanoid?)
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = RACE.BaseWalkSpeed
		humanoid.JumpPower = DEFAULT_JUMP
	end
end

local function playersOnPad(zoneId: string): { Player }
	local center = Layout.StartPad(zoneId)
	local size = Layout.StartPadSize
	local result = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") ~= zoneId or racerByPlayer[player] then
			continue
		end
		local character = player.Character
		local root = character and character.PrimaryPart
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			if math.abs(offset.X) <= size.X / 2 + 1 and math.abs(offset.Z) <= size.Z / 2 + 1 and offset.Y > -2 and offset.Y < 10 then
				table.insert(result, player)
			end
		end
	end
	return result
end

local function broadcastLobby(zoneId: string, payload: { [string]: any })
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") == zoneId and not racerByPlayer[player] then
			Net.Fire("RaceEvent", player, "Lobby", payload)
		end
	end
end

local function makeBot(race: Race, speed: number): Racer
	local zone = Zones[race.Zone]
	-- Bots ride the zone's common-to-rare animals.
	local choices = {}
	if zone.Egg then
		for i, entry in Eggs[zone.Egg].Odds do
			if i <= 3 then
				table.insert(choices, entry.Animal)
			end
		end
	end
	local animalId = if #choices > 0 then choices[rng:NextInteger(1, #choices)] else "Rabbit"
	local name = BOT_NAMES[rng:NextInteger(1, #BOT_NAMES)]
	local model = AnimalModel.Build(animalId)
	model.Name = "Bot_" .. name
	model:ScaleTo(1.7)
	local tagPart = model:FindFirstChild("Head") :: BasePart?
	if tagPart then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(6, 1.5)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
		gui.MaxDistance = 120
		gui.Parent = tagPart
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Text = `🤖 {name}`
		text.Parent = gui
	end
	local zoneModel = WorldBuilder.ZoneModel(race.Zone)
	model.Parent = if zoneModel then zoneModel:FindFirstChild("Racers") else workspace
	local racer = newRacer(race, name, speed)
	racer.Bot = model
	return racer
end

local function updateBot(racer: Racer, origin: Vector3, length: number, elapsed: number, dt: number, now: number)
	local bot = racer.Bot
	if not bot or racer.Finished then
		return
	end
	local wobble = 1 + math.sin(elapsed * 0.7 + racer.Lateral) * 0.04
	racer.Distance += racer.Speed * speedMultiplier(racer, racer.Distance, now) * wobble * dt
	if racer.Distance >= length then
		racer.Distance = length
		racer.Finished = true
		racer.FinishTime = elapsed
	end
	local hop = math.abs(math.sin(elapsed * 9 + racer.Lateral)) * 1.2
	local position = origin + Vector3.new(racer.Distance, hop + 0.2, racer.Lateral)
	bot:PivotTo(CFrame.lookAt(position, position + Vector3.xAxis))
end

local function updateHuman(racer: Racer, origin: Vector3, elapsed: number, now: number)
	if racer.Finished or racer.Left then
		return
	end
	local player = racer.Player :: Player
	local character = player.Character
	local humanoid = racer.Humanoid
	local root = character and character.PrimaryPart
	if player.Parent ~= Players or character ~= racer.Character or not root or not humanoid or humanoid.Health <= 0 then
		racer.Left = true
		return
	end

	local zone = Zones[racer.Race.Zone]
	local track = zone.Track :: any
	local rel = root.Position - origin
	racer.Distance = rel.X

	local checkpointDistance = track.Length * racer.NextCheckpoint / track.Checkpoints
	if rel.X >= checkpointDistance and math.abs(rel.Z) <= track.Width / 2 + 6 then
		local previous = racer.CheckpointTimes[#racer.CheckpointTimes] or 0
		local stretch = track.Length / track.Checkpoints
		if elapsed - previous < stretch / (racer.Speed * MAX_SPEED_FACTOR) then
			racer.Disqualified = true
			racer.Left = true
			resetHumanoid(humanoid)
			Net.Notify(player, "Race not counted: you moved too fast!", "Error")
			return
		end
		table.insert(racer.CheckpointTimes, elapsed)
		racer.NextCheckpoint += 1
		if racer.NextCheckpoint > track.Checkpoints then
			racer.Finished = true
			racer.FinishTime = elapsed
			racer.Distance = track.Length
			resetHumanoid(humanoid)
			Net.Fire("RaceEvent", player, "Finished", { Place = placeOf(racer.Race, racer), Time = elapsed })
			return
		end
		Net.Fire("RaceEvent", player, "Checkpoint", { Index = racer.NextCheckpoint - 1, Total = track.Checkpoints })
	end

	local target = racer.Speed * speedMultiplier(racer, rel.X, now)
	if math.abs(humanoid.WalkSpeed - target) > 0.05 then
		humanoid.WalkSpeed = target
	end
end

local function finishRace(race: Race)
	local zone = Zones[race.Zone]
	local order = table.clone(race.Racers)
	table.sort(order, rankBefore)

	local standings = {}
	for place, racer in order do
		standings[place] = {
			Name = racer.Name,
			IsBot = racer.Bot ~= nil,
			Finished = racer.Finished,
			Time = if racer.Finished then racer.FinishTime else nil,
		}
	end

	for place, racer in order do
		local player = racer.Player
		if not player then
			continue
		end
		racerByPlayer[player] = nil
		player:SetAttribute("Racing", nil)
		resetHumanoid(racer.Humanoid)
		local data = DataService.Get(player)
		if racer.Disqualified or not data or player.Parent ~= Players then
			continue
		end
		-- Everyone who took part earns something; standing still at the start earns nothing.
		local earned = 0
		if racer.Finished or #racer.CheckpointTimes > 0 then
			local share = Economy.PlacePayout[math.min(place, #Economy.PlacePayout)]
			earned = math.floor(zone.Purse * share * (1 + (racer.Abilities.CoinBonus or 0)))
		end
		data.Races += 1
		if place == 1 and racer.Finished then
			data.RacesWon += 1
		end
		if earned > 0 then
			DataService.AddCoins(player, earned, "Race")
		end
		DataService.Changed(player)
		TutorialService.OnRaceFinished(player)
		Net.Fire("RaceEvent", player, "Results", {
			Place = place,
			Coins = earned,
			Finished = racer.Finished,
			Standings = standings,
		})
	end

	-- Clean up bots, then bring racers back to the start area.
	local origin = Layout.ZoneOrigins[race.Zone]
	task.delay(3, function()
		for _, racer in race.Racers do
			if racer.Bot then
				racer.Bot:Destroy()
			end
		end
	end)
	task.delay(5, function()
		for _, racer in race.Racers do
			local player = racer.Player
			if player and player.Parent == Players and not racerByPlayer[player] and player:GetAttribute("Zone") == race.Zone then
				local root = player.Character and player.Character.PrimaryPart
				if root and root.Position.X > origin.X then
					Teleport.To(player, Layout.ZoneSpawn(race.Zone), race.Zone, Vector3.xAxis)
				end
			end
		end
	end)
end

local function runRace(zoneId: string, players: { Player })
	local zone = Zones[zoneId]
	local track = zone.Track :: any
	local origin = Layout.ZoneOrigins[zoneId]
	local race: Race = { Zone = zoneId, Racers = {}, StartTime = 0 }

	local tutorial = false
	local totalSpeed = 0
	for _, player in players do
		if #race.Racers >= MAX_RACERS then
			break
		end
		local data = DataService.Get(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not data or not humanoid then
			continue
		end
		local pets = PetMath.EquippedPets(data.Pets, data.Equipped)
		local racer = newRacer(race, player.DisplayName, PetMath.RaceSpeed(pets))
		racer.Player = player
		racer.Character = character
		racer.Humanoid = humanoid
		racer.Abilities = PetMath.Abilities(pets)
		table.insert(race.Racers, racer)
		racerByPlayer[player] = racer
		player:SetAttribute("Racing", true)
		totalSpeed += racer.Speed
		if TutorialService.IsFirstRace(player) then
			tutorial = true
		end
	end
	local humanCount = #race.Racers
	if humanCount == 0 then
		return
	end

	local averageSpeed = totalSpeed / humanCount
	local botCount = if humanCount < 3 then math.max(0, RACE.MinLineup - humanCount) else 0
	for i = 1, botCount do
		local pace = if tutorial then TUTORIAL_BOT_PACE[i] or 0.7 else rng:NextNumber(0.8, 1.05)
		table.insert(race.Racers, makeBot(race, averageSpeed * pace))
	end

	-- Line everyone up across the start line.
	local count = #race.Racers
	for i, racer in race.Racers do
		racer.Lateral = -track.Width / 2 + track.Width * i / (count + 1)
		local position = origin + Vector3.new(-4, 0, racer.Lateral)
		if racer.Player then
			local humanoid = racer.Humanoid :: Humanoid
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			task.spawn(Teleport.To, racer.Player, position + Vector3.new(0, 3, 0), zoneId, Vector3.xAxis)
		elseif racer.Bot then
			racer.Distance = -4
			racer.Bot:PivotTo(CFrame.lookAt(position, position + Vector3.xAxis))
		end
	end

	for seconds = RACE.CountdownSeconds, 1, -1 do
		fireRacers(race, "Countdown", { Seconds = seconds })
		task.wait(1)
	end

	race.StartTime = os.clock()
	for _, racer in race.Racers do
		if racer.Humanoid then
			racer.Humanoid.WalkSpeed = racer.Speed
			racer.Humanoid.JumpPower = DEFAULT_JUMP
		end
	end
	fireRacers(race, "Go", { Length = track.Length })

	local lastHumanCheck, lastStandings = 0, 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local elapsed = now - race.StartTime
		for _, racer in race.Racers do
			if racer.Bot then
				updateBot(racer, origin, track.Length, elapsed, dt, now)
			end
		end
		if now - lastHumanCheck >= 0.1 then
			lastHumanCheck = now
			for _, racer in race.Racers do
				if racer.Player then
					updateHuman(racer, origin, elapsed, now)
				end
			end
		end
		if now - lastStandings >= 0.5 then
			lastStandings = now
			for _, racer in race.Racers do
				if racer.Player and not racer.Left and not racer.Finished then
					Net.Fire("RaceEvent", racer.Player, "Standings", {
						Place = placeOf(race, racer),
						Total = count,
						Elapsed = elapsed,
						Progress = math.clamp(racer.Distance / track.Length, 0, 1),
					})
				end
			end
		end
	end)

	local lastLobby = 0
	while true do
		task.wait(0.25)
		local elapsed = os.clock() - race.StartTime
		local anyoneRacing = false
		for _, racer in race.Racers do
			if racer.Player and not racer.Finished and not racer.Left then
				anyoneRacing = true
				break
			end
		end
		if not anyoneRacing or elapsed >= RACE.MaxRaceSeconds then
			break
		end
		if os.clock() - lastLobby >= 1 then
			lastLobby = os.clock()
			broadcastLobby(zoneId, { Zone = zoneId, Running = true })
		end
	end
	connection:Disconnect()
	finishRace(race)
end

local function zoneLoop(zoneId: string)
	while true do
		local countdown = RACE.IntermissionSeconds
		local lineup: { Player }
		while true do
			local onPad = playersOnPad(zoneId)
			if #onPad == 0 then
				countdown = RACE.IntermissionSeconds
			else
				for _, player in onPad do
					if TutorialService.IsFirstRace(player) then
						countdown = math.min(countdown, RACE.TutorialIntermissionSeconds)
					end
				end
			end
			broadcastLobby(zoneId, { Zone = zoneId, Seconds = if #onPad > 0 then countdown else nil, OnPad = #onPad })
			if #onPad > 0 and countdown <= 0 then
				lineup = onPad
				break
			end
			task.wait(1)
			if #onPad > 0 then
				countdown -= 1
			end
		end
		local ok, err = pcall(function()
			runRace(zoneId, lineup)
		end)
		if not ok then
			warn(`[RaceService] race in {zoneId} failed: {err}`)
			for player, racer in racerByPlayer do
				if racer.Race.Zone == zoneId then
					racerByPlayer[player] = nil
					player:SetAttribute("Racing", nil)
					resetHumanoid(racer.Humanoid)
				end
			end
		end
	end
end

local function useAbility(player: Player): Net.Result
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return { Ok = false }
	end
	local now = os.clock()
	local readyAt = abilityReadyAt[player] or 0
	if now < readyAt then
		return { Ok = false, Cooldown = readyAt - now }
	end
	local racer = racerByPlayer[player]
	if racer and racer.Race.StartTime == 0 then
		return { Ok = false, Message = "Wait for GO!" }
	end

	local abilities = PetMath.Abilities(PetMath.EquippedPets(data.Pets, data.Equipped))
	local used = {}
	if abilities.SpeedBurst then
		table.insert(used, "SpeedBurst")
		if racer then
			racer.BoostUntil = now + 3
			racer.BoostMult = abilities.SpeedBurst
		else
			humanoid.WalkSpeed = RACE.BaseWalkSpeed * abilities.SpeedBurst
			task.delay(3, function()
				if not racerByPlayer[player] and humanoid.Parent then
					humanoid.WalkSpeed = RACE.BaseWalkSpeed
				end
			end)
		end
	end
	if abilities.HighJump then
		table.insert(used, "HighJump")
		humanoid.JumpPower = abilities.HighJump
		task.delay(4, function()
			local current = racerByPlayer[player]
			if humanoid.Parent and (not current or current.Race.StartTime > 0) then
				humanoid.JumpPower = DEFAULT_JUMP
			end
		end)
	end
	if abilities.Leap then
		table.insert(used, "Leap")
		Net.Fire("AbilityFx", player, "Leap", abilities.Leap)
	end
	if #used == 0 then
		return { Ok = false, Message = "Equip a Rabbit, Cat or Frog to use this button!" }
	end
	abilityReadyAt[player] = now + RACE.AbilityCooldown
	return { Ok = true, Used = used, Cooldown = RACE.AbilityCooldown }
end

function RaceService.IsRacing(player: Player): boolean
	return racerByPlayer[player] ~= nil
end

function RaceService.Init()
	Net.OnInvoke("UseAbility", 2, useAbility)
end

function RaceService.Start()
	-- Logs slow racers down unless they jump over them (or have a Bear or a Turtle's shield).
	for _, log in CollectionService:GetTagged("Log") do
		local logPart = log :: BasePart
		logPart.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			local racer = player and racerByPlayer[player]
			if not player or not racer or racer.Finished or racer.Race.StartTime == 0 or racer.LogHits[log] then
				return
			end
			racer.LogHits[log] = true
			if racer.Abilities.Tough then
				return
			end
			if racer.Abilities.Shield and not racer.ShieldUsed then
				racer.ShieldUsed = true
				Net.Fire("RaceEvent", player, "Shield", {})
				return
			end
			racer.SlowUntil = os.clock() + RACE.LogSlowSeconds
			Net.Fire("RaceEvent", player, "Bonk", {})
		end)
	end

	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = DEFAULT_JUMP
			humanoid.WalkSpeed = RACE.BaseWalkSpeed
		end
	end
	local function onPlayer(player: Player)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local racer = racerByPlayer[player]
		if racer then
			racer.Left = true
		end
		racerByPlayer[player] = nil
		abilityReadyAt[player] = nil
	end)

	for zoneId in Layout.ZoneOrigins do
		task.spawn(zoneLoop, zoneId)
	end
end

return RaceService
