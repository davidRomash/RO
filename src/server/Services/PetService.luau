--!strict
-- Owning, equipping, selling and merging animals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)
local Economy = require(ReplicatedStorage.Config.Economy)
local PetMath = require(ReplicatedStorage.Shared.PetMath)

type Pet = PetMath.Pet

local PetService = {}

function PetService.HasSpace(player: Player, count: number): boolean
	local data = DataService.Get(player)
	return data ~= nil and #data.Pets + count <= DataService.InventorySize(data)
end

-- Adds an animal. Returns the new pet and whether this animal was never owned before.
function PetService.Grant(player: Player, animalId: string, golden: boolean?): (Pet?, boolean)
	local data = DataService.Get(player)
	if not data or not Animals[animalId] then
		return nil, false
	end
	local pet: Pet = { Id = tostring(data.NextPetId), Animal = animalId, Golden = golden == true }
	data.NextPetId += 1
	table.insert(data.Pets, pet)
	local isNew = not data.Discovered[animalId]
	data.Discovered[animalId] = true
	if #data.Equipped < Economy.MaxEquipped then
		table.insert(data.Equipped, pet.Id)
	end
	DataService.Changed(player)
	return pet, isNew
end

local function removeEquipped(data: DataService.PlayerData, id: string)
	local index = table.find(data.Equipped, id)
	if index then
		table.remove(data.Equipped, index)
	end
end

local function sortBySpeed(pets: { Pet }): { Pet }
	local sorted = table.clone(pets)
	table.sort(sorted, function(a, b)
		local sa, sb = PetMath.PetSpeed(a), PetMath.PetSpeed(b)
		if sa ~= sb then
			return sa > sb
		end
		return Rarities[Animals[a.Animal].Rarity].Order > Rarities[Animals[b.Animal].Rarity].Order
	end)
	return sorted
end

function PetService.Init()
	Net.OnInvoke("EquipPet", 5, function(player, id)
		local data = DataService.Get(player)
		if not data or typeof(id) ~= "string" then
			return { Ok = false }
		end
		if not PetMath.FindPet(data.Pets, id) then
			return { Ok = false, Message = "Animal not found" }
		end
		if table.find(data.Equipped, id) then
			return { Ok = true }
		end
		if #data.Equipped >= Economy.MaxEquipped then
			return { Ok = false, Message = `You can equip {Economy.MaxEquipped} animals. Unequip one first!` }
		end
		table.insert(data.Equipped, id)
		DataService.Changed(player)
		return { Ok = true }
	end)

	Net.OnInvoke("UnequipPet", 5, function(player, id)
		local data = DataService.Get(player)
		if not data or typeof(id) ~= "string" then
			return { Ok = false }
		end
		removeEquipped(data, id)
		DataService.Changed(player)
		return { Ok = true }
	end)

	Net.OnInvoke("EquipBest", 2, function(player)
		local data = DataService.Get(player)
		if not data then
			return { Ok = false }
		end
		data.Equipped = {}
		for i, pet in sortBySpeed(data.Pets) do
			if i > Economy.MaxEquipped then
				break
			end
			table.insert(data.Equipped, pet.Id)
		end
		DataService.Changed(player)
		return { Ok = true }
	end)

	Net.OnInvoke("SellPet", 4, function(player, id)
		local data = DataService.Get(player)
		if not data or typeof(id) ~= "string" then
			return { Ok = false }
		end
		local pet, index = PetMath.FindPet(data.Pets, id)
		if not pet or not index then
			return { Ok = false, Message = "Animal not found" }
		end
		if #data.Pets <= 1 then
			return { Ok = false, Message = "Keep at least one animal!" }
		end
		local value = PetMath.SellValue(pet)
		removeEquipped(data, id)
		table.remove(data.Pets, index)
		DataService.AddCoins(player, value, "Sell")
		return { Ok = true, Coins = value }
	end)

	-- Five normal copies of the same animal become one Golden copy.
	Net.OnInvoke("MergeGolden", 2, function(player, animalId)
		local data = DataService.Get(player)
		if not data or typeof(animalId) ~= "string" or not Animals[animalId] then
			return { Ok = false }
		end
		local copies = {}
		for _, pet in data.Pets do
			if pet.Animal == animalId and not pet.Golden then
				table.insert(copies, pet.Id)
			end
		end
		if #copies < Economy.GoldenMergeCount then
			return { Ok = false, Message = `You need {Economy.GoldenMergeCount} of the same animal` }
		end
		-- Prefer merging copies that are not equipped.
		table.sort(copies, function(a, b)
			local ea, eb = table.find(data.Equipped, a) ~= nil, table.find(data.Equipped, b) ~= nil
			return not ea and eb
		end)
		local wasEquipped = false
		for i = 1, Economy.GoldenMergeCount do
			local id = copies[i]
			if table.find(data.Equipped, id) then
				wasEquipped = true
				removeEquipped(data, id)
			end
			local _, index = PetMath.FindPet(data.Pets, id)
			if index then
				table.remove(data.Pets, index)
			end
		end
		local golden = PetService.Grant(player, animalId, true)
		if golden and wasEquipped and not table.find(data.Equipped, golden.Id) and #data.Equipped < Economy.MaxEquipped then
			table.insert(data.Equipped, golden.Id)
		end
		DataService.Changed(player)
		return { Ok = true, Pet = golden }
	end)
end

return PetService
