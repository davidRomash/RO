--!strict
-- Egg hatching. All rolls happen here on the server, with a pity counter:
-- a Rare or better animal is guaranteed within every Economy.PityHatches hatches.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local TutorialService = require(script.Parent.TutorialService)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)
local Economy = require(ReplicatedStorage.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Util = require(ReplicatedStorage.Shared.Util)

local STAND_RANGE = 22
local RARE_ORDER = Rarities.Rare.Order

local rng = Random.new()

local EggService = {}

function EggService.StandPositions(eggId: string): { Vector3 }
	local positions = {}
	for _, stand in Layout.EggStands do
		if stand.Egg == eggId then
			table.insert(positions, stand.Position)
		end
	end
	local egg = Eggs[eggId]
	if egg and Layout.ZoneOrigins[egg.Zone] then
		table.insert(positions, Layout.ZoneEggStand(egg.Zone))
	end
	return positions
end

local function nearStand(player: Player, eggId: string): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	if not root then
		return false
	end
	for _, position in EggService.StandPositions(eggId) do
		local offset = (root.Position - position) * Vector3.new(1, 0, 1)
		if offset.Magnitude <= STAND_RANGE then
			return true
		end
	end
	return false
end

local function roll(data: DataService.PlayerData, egg: Eggs.Egg): string
	data.PityCounter += 1
	local pool = egg.Odds
	if data.PityCounter >= Economy.PityHatches then
		pool = {}
		for _, entry in egg.Odds do
			if Rarities[Animals[entry.Animal].Rarity].Order >= RARE_ORDER then
				table.insert(pool, entry)
			end
		end
	end
	local total = 0
	for _, entry in pool do
		total += entry.Chance
	end
	local pick = rng:NextNumber(0, total)
	local chosen = pool[#pool].Animal
	for _, entry in pool do
		pick -= entry.Chance
		if pick <= 0 then
			chosen = entry.Animal
			break
		end
	end
	if Rarities[Animals[chosen].Rarity].Order >= RARE_ORDER then
		data.PityCounter = 0
	end
	return chosen
end

function EggService.Init()
	Net.OnInvoke("HatchEgg", 1, function(player, eggId, count)
		local data = DataService.Get(player)
		if not data or typeof(eggId) ~= "string" or (count ~= 1 and count ~= 3) then
			return { Ok = false }
		end
		local egg = Eggs[eggId]
		if not egg then
			return { Ok = false }
		end
		if not data.UnlockedZones[egg.Zone] then
			return { Ok = false, Message = `Unlock the {egg.Zone} first!` }
		end
		if not nearStand(player, eggId) then
			return { Ok = false, Message = `Walk to a {egg.Name} stand to hatch` }
		end
		if not PetService.HasSpace(player, count) then
			return { Ok = false, Message = "Your animal bag is full! Sell animals or upgrade your base." }
		end
		local cost = egg.Price * count
		if not DataService.SpendCoins(player, cost) then
			return { Ok = false, Message = `You need 🪙 {Util.FormatNumber(cost)}` }
		end

		local results = {}
		for _ = 1, count do
			local animalId = roll(data, egg)
			local pet, isNew = PetService.Grant(player, animalId)
			if pet then
				table.insert(results, { Id = pet.Id, Animal = pet.Animal, Golden = false, New = isNew })
			end
		end
		data.Hatches += count
		DataService.Changed(player)
		TutorialService.OnHatch(player)
		return { Ok = true, Egg = eggId, Results = results }
	end)
end

function EggService.Start()
	for _, prompt in CollectionService:GetTagged("EggPrompt") do
		local eggId = prompt:GetAttribute("Egg") :: string
		local eggPrompt = prompt :: ProximityPrompt
		eggPrompt.Triggered:Connect(function(player)
			Net.Fire("OpenMenu", player, "Egg", eggId)
		end)
	end
end

return EggService
