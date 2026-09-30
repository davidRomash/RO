--!strict
-- Builds the whole map from basic parts when the server starts: Plaza, portals, egg stands,
-- bases, zones and tracks. Positions come from Shared/Layout so the client can point at them.
-- Everything here is placeholder art: swap parts for real models later without touching game logic.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Util = require(ReplicatedStorage.Shared.Util)
local Zones = require(ReplicatedStorage.Config.Zones)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Animals = require(ReplicatedStorage.Config.Animals)

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

local WorldBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

-- A vertical cylinder (Roblox cylinders point along X, so rotate them upright).
local function column(parent: Instance, name: string, radius: number, height: number, base: Vector3, color: Color3, material: Enum.Material?): Part
	local cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), cframe, color, Enum.PartType.Cylinder, material)
end

local function label(parent: Instance, text: string, textColor: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = FONT
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = textColor or WHITE
	l.TextStrokeTransparency = 0.2
	l.Parent = parent
	return l
end

local function billboard(adornee: BasePart, name: string, text: string, size: Vector2, offsetY: number, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 150
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee
	local l = label(gui, text)
	l.Name = "Text"
	return gui
end

local function prompt(parent: BasePart, action: string, object: string, tag: string, attributes: { [string]: any }): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	for key, value in attributes do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	CollectionService:AddTag(p, tag)
	return p
end

local function tree(parent: Instance, base: Vector3, height: number, leafColor: Color3)
	column(parent, "Trunk", height * 0.08, height, base, Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local leaves = part(parent, "Leaves", Vector3.one * height * 0.55, CFrame.new(base + Vector3.new(0, height, 0)), leafColor, Enum.PartType.Ball, Enum.Material.Grass)
	leaves.CastShadow = true
end

local function palm(parent: Instance, base: Vector3, height: number)
	local lean = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(8))
	local trunk = part(parent, "Trunk", Vector3.new(height, 2, 2), lean * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(160, 120, 70), Enum.PartType.Cylinder, Enum.Material.Wood)
	local top = (lean * CFrame.new(0, height, 0)).Position
	part(parent, "Leaves", Vector3.new(12, 3, 12), CFrame.new(top), Color3.fromRGB(60, 170, 70), Enum.PartType.Ball, Enum.Material.Grass)
	trunk.CastShadow = true
end

local function arch(parent: Instance, name: string, position: Vector3, gateColor: Color3, facing: number): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local rot = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0)
	part(model, "PillarL", Vector3.new(3, 16, 3), rot * CFrame.new(-7, 8, 0), Color3.fromRGB(245, 245, 245))
	part(model, "PillarR", Vector3.new(3, 16, 3), rot * CFrame.new(7, 8, 0), Color3.fromRGB(245, 245, 245))
	local top = part(model, "Top", Vector3.new(18, 3, 3.4), rot * CFrame.new(0, 17.5, 0), gateColor)
	local gate = part(model, "Gate", Vector3.new(11, 14.5, 1), rot * CFrame.new(0, 7.25, 0), gateColor, nil, Enum.Material.Neon)
	gate.Transparency = 0.35
	gate.CanCollide = false
	model.PrimaryPart = top
	return model, gate
end

local function eggStand(parent: Instance, eggId: string, position: Vector3)
	local egg = Eggs[eggId]
	local model = Instance.new("Model")
	model.Name = egg.Name
	model.Parent = parent
	column(model, "Pedestal", 4, 2, position, Color3.fromRGB(250, 250, 250))
	local eggPart = part(model, "Egg", Vector3.new(5, 6.5, 5), CFrame.new(position + Vector3.new(0, 5.3, 0)), egg.Color, Enum.PartType.Ball)
	part(model, "Spot1", Vector3.one * 1.3, CFrame.new(position + Vector3.new(-1.6, 6.4, -1.4)), WHITE, Enum.PartType.Ball)
	part(model, "Spot2", Vector3.one * 1.0, CFrame.new(position + Vector3.new(1.4, 4.6, -1.7)), WHITE, Enum.PartType.Ball)

	local odds = {}
	for _, entry in egg.Odds do
		table.insert(odds, `{Animals[entry.Animal].Emoji} {entry.Chance}%`)
	end
	local sign = billboard(eggPart, "Sign", "", Vector2.new(9, 4.5), 6, 80)
	local text = sign:FindFirstChild("Text") :: TextLabel
	text.Size = UDim2.fromScale(1, 0.45)
	text.Text = `{egg.Name}\n🪙 {Util.FormatNumber(egg.Price)}`
	local oddsLabel = label(sign, table.concat(odds, "  "))
	oddsLabel.Name = "Odds"
	oddsLabel.Position = UDim2.fromScale(0, 0.5)
	oddsLabel.Size = UDim2.fromScale(1, 0.3)

	prompt(eggPart, "Hatch", egg.Name, "EggPrompt", { Egg = eggId })
end

local function buildLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 1
		atmosphere.Parent = Lighting
	end
end

local function buildPlaza(world: Instance)
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = world

	local groundSize = Layout.GroundRadius * 2
	part(plaza, "Ground", Vector3.new(2, groundSize, groundSize), CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 190, 90), Enum.PartType.Cylinder, Enum.Material.Grass)
	local size = Layout.PlazaSize
	part(plaza, "Floor", Vector3.new(size, 1, size), CFrame.new(0, -0.4, 0), Color3.fromRGB(240, 230, 210), nil, Enum.Material.Pavement)
	local border = Color3.fromRGB(255, 190, 90)
	part(plaza, "BorderN", Vector3.new(size, 1.2, 3), CFrame.new(0, -0.3, -size / 2), border)
	part(plaza, "BorderS", Vector3.new(size, 1.2, 3), CFrame.new(0, -0.3, size / 2), border)
	part(plaza, "BorderE", Vector3.new(3, 1.2, size), CFrame.new(size / 2, -0.3, 0), border)
	part(plaza, "BorderW", Vector3.new(3, 1.2, size), CFrame.new(-size / 2, -0.3, 0), border)

	-- Fountain in the middle.
	column(plaza, "FountainBase", 14, 2, Vector3.new(0, 0, 0), Color3.fromRGB(200, 200, 210))
	local water = column(plaza, "FountainWater", 12, 0.4, Vector3.new(0, 1.8, 0), Color3.fromRGB(80, 180, 255), Enum.Material.Glass)
	water.Transparency = 0.2
	column(plaza, "FountainPillar", 2, 8, Vector3.new(0, 2, 0), Color3.fromRGB(220, 220, 230))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(Layout.PlazaSpawn - Vector3.new(0, 2.9, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = plaza

	-- Portal arches, one per zone. Locked ones show their gate cost.
	for zoneId, position in Layout.Portals do
		local zone = Zones[zoneId]
		local model, gate = arch(plaza, zoneId .. "Portal", position, zone.GroundColor, 0)
		gate:SetAttribute("Zone", zoneId)
		CollectionService:AddTag(gate, "PortalGate")
		local status = if zone.ComingSoon then "🔒 Soon" elseif zone.GateCost > 0 then `🔒 🪙 {Util.FormatNumber(zone.GateCost)}` else "Open!"
		local sign = billboard(model.PrimaryPart :: BasePart, "Sign", `{zone.Emoji} {zone.Name}`, Vector2.new(12, 4), 4.5, 250)
		local nameLabel = sign:FindFirstChild("Text") :: TextLabel
		nameLabel.Size = UDim2.fromScale(1, 0.55)
		local statusLabel = label(sign, status)
		statusLabel.Name = "Status"
		statusLabel.Position = UDim2.fromScale(0, 0.55)
		statusLabel.Size = UDim2.fromScale(1, 0.45)
		if not zone.ComingSoon and zone.GateCost > 0 then
			prompt(gate, "Unlock", `🪙 {Util.FormatNumber(zone.GateCost)}`, "UnlockPrompt", { Zone = zoneId })
		end
	end

	-- Egg shop.
	for _, stand in Layout.EggStands do
		eggStand(plaza, stand.Egg, stand.Position)
	end

	-- Daily reward chest.
	local chestPos = Layout.DailyChest
	local chest = part(plaza, "DailyChest", Vector3.new(6, 4, 4), CFrame.new(chestPos + Vector3.new(0, 2, 0)), Color3.fromRGB(150, 90, 40), nil, Enum.Material.Wood)
	part(plaza, "DailyChestLid", Vector3.new(6.4, 1.2, 4.4), CFrame.new(chestPos + Vector3.new(0, 4.6, 0)), Color3.fromRGB(255, 200, 50))
	billboard(chest, "Sign", "🎁 Daily Reward", Vector2.new(8, 2), 4, 80)
	prompt(chest, "Open", "Daily reward", "DailyPrompt", {})

	-- Leaderboard facing the Plaza centre.
	local boardPos = Layout.Leaderboard
	column(plaza, "BoardPostL", 0.8, 8, boardPos + Vector3.new(0, 0, -8), Color3.fromRGB(90, 90, 100))
	column(plaza, "BoardPostR", 0.8, 8, boardPos + Vector3.new(0, 0, 8), Color3.fromRGB(90, 90, 100))
	local board = part(plaza, "Leaderboard", Vector3.new(1, 18, 20), CFrame.new(boardPos + Vector3.new(0, 17, 0)), Color3.fromRGB(40, 45, 70))
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Left
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 25
	surface.LightInfluence = 0
	surface.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = surface
	local title = label(surface, "🏆 Top Racers")
	title.Size = UDim2.fromScale(1, 0.14)
	title.LayoutOrder = 0
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	for i = 1, 10 do
		local row = label(surface, "")
		row.Name = `Row{i}`
		row.Size = UDim2.fromScale(1, 0.086)
		row.LayoutOrder = i
		row.TextXAlignment = Enum.TextXAlignment.Left
	end
	CollectionService:AddTag(board, "LeaderboardBoard")
end

local BASE_COLORS = {
	Color3.fromRGB(255, 200, 200), Color3.fromRGB(255, 225, 180), Color3.fromRGB(255, 250, 180), Color3.fromRGB(200, 250, 190),
	Color3.fromRGB(190, 240, 250), Color3.fromRGB(200, 210, 255), Color3.fromRGB(235, 200, 255), Color3.fromRGB(255, 205, 235),
}

local function buildBases(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = world
	for i = 1, Layout.BaseCount do
		local center = Layout.BaseCenter(i)
		local model = Instance.new("Model")
		model.Name = `Base{i}`
		model:SetAttribute("Index", i)
		model.Parent = folder

		local s = Layout.BaseSize
		local floor = part(model, "Floor", Vector3.new(s, 1, s), CFrame.new(center + Vector3.new(0, -0.3, 0)), BASE_COLORS[i])
		model.PrimaryPart = floor
		local curb = WHITE
		part(model, "CurbN", Vector3.new(s, 1, 1), CFrame.new(center + Vector3.new(0, 0.5, -s / 2)), curb)
		part(model, "CurbS", Vector3.new(s, 1, 1), CFrame.new(center + Vector3.new(0, 0.5, s / 2)), curb)
		part(model, "CurbE", Vector3.new(1, 1, s), CFrame.new(center + Vector3.new(s / 2, 0.5, 0)), curb)
		part(model, "CurbW", Vector3.new(1, 1, s), CFrame.new(center + Vector3.new(-s / 2, 0.5, 0)), curb)

		local inward = -center.Unit
		local signPost = column(model, "SignPost", 0.6, 10, center + inward * (s / 2 - 3), Color3.fromRGB(120, 85, 55))
		billboard(signPost, "Owner", "Free plot", Vector2.new(12, 2.5), 7, 200)

		local padPos = center + inward * (s / 2 - 8) + Vector3.new(inward.Z, 0, -inward.X) * 12
		local pad = column(model, "UpgradePad", 3, 0.4, padPos, Color3.fromRGB(80, 220, 120), Enum.Material.Neon)
		prompt(pad, "Upgrade", "Base", "BaseUpgrade", { Index = i })

		local spawn = part(model, "Spawn", Vector3.new(2, 1, 2), CFrame.lookAt(center + Vector3.new(0, 3, 0), center + Vector3.new(0, 3, 0) + inward), WHITE)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CanTouch = false

		local pets = Instance.new("Folder")
		pets.Name = "Pets"
		pets.Parent = model
		CollectionService:AddTag(model, "BasePlot")
	end
end

local function buildVolcano(world: Instance)
	local model = Instance.new("Model")
	model.Name = "Volcano"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = world
	local base = Layout.VolcanoLandmark
	local layers = 6
	local top: Part? = nil
	for i = 0, layers - 1 do
		local radius = 190 - i * 28
		local shade = 70 - i * 8
		top = column(model, `Layer{i}`, radius, 42, base + Vector3.new(0, i * 40, 0), Color3.fromRGB(shade + 40, shade, shade - 10), Enum.Material.Basalt)
	end
	local lava = column(model, "Lava", 40, 3, base + Vector3.new(0, layers * 40 + 1, 0), Color3.fromRGB(255, 90, 20), Enum.Material.Neon)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 80, 80)
	smoke.Size = 60
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 25
	smoke.Parent = lava
	model.PrimaryPart = top
end

local function buildZone(world: Instance, zoneId: string)
	local zone = Zones[zoneId]
	local track = zone.Track
	local origin = Layout.ZoneOrigins[zoneId]
	if not track or not origin then
		return
	end
	local L, W = track.Length, track.Width
	local model = Instance.new("Model")
	model.Name = zoneId
	model.Parent = world
	local rng = Random.new(zone.Order * 1000)

	-- Ground, track floor and walls.
	part(model, "Ground", Vector3.new(L + 420, 1, 380), CFrame.new(origin + Vector3.new(L / 2 - 110, -0.5, 0)), zone.GroundColor, nil, if zoneId == "Beach" then Enum.Material.Sand else Enum.Material.Grass)
	part(model, "Track", Vector3.new(L + 60, 1, W), CFrame.new(origin + Vector3.new(L / 2 + 20, -0.35, 0)), zone.TrackColor, nil, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		local z = side * (W / 2 + 1)
		part(model, "Curb", Vector3.new(L + 60, 1.5, 2), CFrame.new(origin + Vector3.new(L / 2 + 20, 0.6, z)), WHITE)
		local wall = part(model, "Wall", Vector3.new(L + 60, 24, 1), CFrame.new(origin + Vector3.new(L / 2 + 20, 12, side * (W / 2 + 2.5))), WHITE)
		wall.Transparency = 1
	end
	local endWall = part(model, "EndWall", Vector3.new(1, 24, W), CFrame.new(origin + Vector3.new(L + 50, 12, 0)), WHITE)
	endWall.Transparency = 1

	-- Start line, checkpoints and finish.
	part(model, "StartLine", Vector3.new(2, 0.2, W), CFrame.new(origin + Vector3.new(0, 0.2, 0)), WHITE)
	for i = 1, track.Checkpoints do
		local d = L * i / track.Checkpoints
		local isFinish = i == track.Checkpoints
		local color = if isFinish then Color3.fromRGB(30, 30, 30) else Color3.fromRGB(255, 120, 60)
		part(model, "CheckpointL", Vector3.new(2, 16, 2), CFrame.new(origin + Vector3.new(d, 8, -W / 2 - 3)), color)
		part(model, "CheckpointR", Vector3.new(2, 16, 2), CFrame.new(origin + Vector3.new(d, 8, W / 2 + 3)), color)
		local banner = part(model, "Banner", Vector3.new(2, 4, W + 8), CFrame.new(origin + Vector3.new(d, 17, 0)), color)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.LightInfluence = 0
		gui.Parent = banner
		label(gui, if isFinish then "🏁 FINISH 🏁" else `CHECKPOINT {i}`)
		if isFinish then
			part(model, "FinishLine", Vector3.new(4, 0.2, W), CFrame.new(origin + Vector3.new(d, 0.2, 0)), WHITE, nil, Enum.Material.Neon)
		end
	end

	-- Obstacles and terrain sections.
	for _, d in track.Logs or ({} :: { number }) do
		local log = part(model, "Log", Vector3.new(W - 2, 2.6, 2.6), CFrame.new(origin + Vector3.new(d, 1.3, 0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(125, 80, 45), Enum.PartType.Cylinder, Enum.Material.Wood)
		log.CanCollide = false
		log:SetAttribute("Zone", zoneId)
		CollectionService:AddTag(log, "Log")
	end
	for _, section in track.Water or ({} :: { Zones.Section }) do
		local length = section.To - section.From
		local water = part(model, "Water", Vector3.new(length, 0.6, W), CFrame.new(origin + Vector3.new(section.From + length / 2, 0.35, 0)), Color3.fromRGB(50, 150, 230), nil, Enum.Material.Glass)
		water.Transparency = 0.35
		water.CanCollide = false
		billboard(water, "Sign", "💧", Vector2.new(4, 4), 6, 120)
	end
	for _, section in track.Sand or ({} :: { Zones.Section }) do
		local length = section.To - section.From
		local sand = part(model, "Sand", Vector3.new(length, 0.2, W), CFrame.new(origin + Vector3.new(section.From + length / 2, 0.2, 0)), Color3.fromRGB(225, 195, 130), nil, Enum.Material.Sand)
		sand.CanCollide = false
	end

	-- Start pad: stand here to join the next race.
	local pad = part(model, "StartPad", Layout.StartPadSize, CFrame.new(Layout.StartPad(zoneId) + Vector3.new(0, 0.1, 0)), Color3.fromRGB(80, 230, 110), nil, Enum.Material.Neon)
	pad:SetAttribute("Zone", zoneId)
	billboard(pad, "Sign", "🏁 RACE! Stand here", Vector2.new(16, 3), 7, 200)
	CollectionService:AddTag(pad, "StartPad")

	-- Way back to the Plaza, the zone's egg stand and a zone sign.
	local _, gate = arch(model, "ReturnPortal", Layout.ZoneReturnPortal(zoneId), Color3.fromRGB(255, 220, 120), 90)
	gate:SetAttribute("Zone", zoneId)
	billboard(gate, "Sign", "🏠 Plaza", Vector2.new(8, 2.2), 11, 150)
	CollectionService:AddTag(gate, "ReturnGate")
	if zone.Egg then
		eggStand(model, zone.Egg, Layout.ZoneEggStand(zoneId))
	end

	-- Big landmark near the spawn, and scenery along the track.
	local landmarkBase = origin + Vector3.new(-130, 0, 95)
	if zoneId == "Forest" then
		tree(model, landmarkBase, 80, Color3.fromRGB(50, 150, 60))
		for d = 0, L, 55 do
			for _, side in { -1, 1 } do
				local z = side * (W / 2 + 14 + rng:NextNumber(0, 40))
				tree(model, origin + Vector3.new(d + rng:NextNumber(-15, 15), 0, z), rng:NextNumber(18, 30), Color3.fromRGB(60, rng:NextInteger(140, 190), 60))
			end
		end
	elseif zoneId == "Beach" then
		for i = 0, 7 do
			local color = if i % 2 == 0 then Color3.fromRGB(230, 60, 60) else WHITE
			column(model, "Lighthouse", 7 - i * 0.4, 8, landmarkBase + Vector3.new(0, i * 8, 0), color)
		end
		local lamp = part(model, "Lamp", Vector3.one * 6, CFrame.new(landmarkBase + Vector3.new(0, 67, 0)), Color3.fromRGB(255, 240, 150), Enum.PartType.Ball, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 3
		light.Parent = lamp
		for d = 0, L, 70 do
			for _, side in { -1, 1 } do
				palm(model, origin + Vector3.new(d + rng:NextNumber(-20, 20), 0, side * (W / 2 + 16 + rng:NextNumber(0, 40))), rng:NextNumber(14, 22))
			end
		end
	end

	local zoneSign = part(model, "ZoneSign", Vector3.new(1, 1, 1), CFrame.new(Layout.ZoneSpawn(zoneId) + Vector3.new(0, 12, 0)), WHITE)
	zoneSign.Transparency = 1
	zoneSign.CanCollide = false
	billboard(zoneSign, "Sign", `{zone.Emoji} {string.upper(zone.Name)}`, Vector2.new(20, 5), 0, 200)

	local racers = Instance.new("Folder")
	racers.Name = "Racers"
	racers.Parent = model
end

function WorldBuilder.ZoneModel(zoneId: string): Model?
	local world = Workspace:FindFirstChild("World")
	local zones = world and world:FindFirstChild("Zones")
	return zones and zones:FindFirstChild(zoneId) :: Model?
end

function WorldBuilder.Init()
	-- Remove the default template baseplate and spawn (only for this play session, not the saved place).
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace

	buildLighting()
	buildPlaza(world)
	buildBases(world)
	buildVolcano(world)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = world
	for zoneId in Layout.ZoneOrigins do
		buildZone(zonesFolder, zoneId)
	end
end

return WorldBuilder
