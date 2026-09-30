--!strict
-- Stats derived from a player's pets. Used by the server for racing and by the client for display.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)
local Economy = require(ReplicatedStorage.Config.Economy)

export type Pet = { Id: string, Animal: string, Golden: boolean }

local PetMath = {}

function PetMath.PetSpeed(pet: Pet): number
	local animal = Animals[pet.Animal]
	if not animal then
		return 0
	end
	local speed = Rarities[animal.Rarity].Speed
	if pet.Golden then
		speed *= Economy.GoldenMultiplier
	end
	return speed
end

function PetMath.SellValue(pet: Pet): number
	local animal = Animals[pet.Animal]
	if not animal then
		return 0
	end
	local value = Rarities[animal.Rarity].SellValue
	if pet.Golden then
		value *= Economy.GoldenMultiplier * Economy.GoldenMergeCount
	end
	return math.floor(value)
end

function PetMath.FindPet(pets: { Pet }, id: string): (Pet?, number?)
	for index, pet in pets do
		if pet.Id == id then
			return pet, index
		end
	end
	return nil, nil
end

function PetMath.EquippedPets(pets: { Pet }, equipped: { string }): { Pet }
	local result = {}
	for _, id in equipped do
		local pet = PetMath.FindPet(pets, id)
		if pet then
			table.insert(result, pet)
		end
	end
	return result
end

function PetMath.RaceSpeed(equippedPets: { Pet }): number
	local speed = Economy.Race.BaseWalkSpeed
	for _, pet in equippedPets do
		speed += PetMath.PetSpeed(pet)
	end
	return speed
end

-- Returns ability kind -> strongest value among equipped pets (true-ish value 1 when the ability has no Value).
function PetMath.Abilities(equippedPets: { Pet }): { [string]: number }
	local abilities: { [string]: number } = {}
	for _, pet in equippedPets do
		local animal = Animals[pet.Animal]
		if animal then
			local value = animal.Value or 1
			if abilities[animal.Ability] == nil or value > abilities[animal.Ability] then
				abilities[animal.Ability] = value
			end
		end
	end
	return abilities
end

PetMath.ActiveAbilities = { SpeedBurst = true, HighJump = true, Leap = true }

function PetMath.HasActiveAbility(equippedPets: { Pet }): boolean
	for kind in PetMath.Abilities(equippedPets) do
		if PetMath.ActiveAbilities[kind] then
			return true
		end
	end
	return false
end

return PetMath
