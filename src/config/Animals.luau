--!strict
-- Every animal's stats and ability. Balance numbers live here.
--
-- Ability kinds:
--   Active (ability button):  SpeedBurst, HighJump, Leap
--   Passive (automatic):      ForestRunner, Tough, CoinBonus, SandWalker, Shield, WaterSpeed

export type Animal = {
	Name: string,
	Emoji: string,
	Zone: string,
	Rarity: string,
	Ability: string,
	AbilityText: string,
	Value: number?, -- ability strength (meaning depends on the ability)
	BodyColor: Color3,
	AccentColor: Color3,
	Ears: string, -- "Long" | "Pointy" | "Round" | "None"
	Size: number, -- model scale
}

local Animals: { [string]: Animal } = {
	-- Forest
	Rabbit = {
		Name = "Rabbit", Emoji = "🐰", Zone = "Forest", Rarity = "Common",
		Ability = "SpeedBurst", Value = 1.5, AbilityText = "Speed burst for 3 seconds",
		BodyColor = Color3.fromRGB(235, 225, 215), AccentColor = Color3.fromRGB(255, 170, 190), Ears = "Long", Size = 1,
	},
	Cat = {
		Name = "Cat", Emoji = "🐱", Zone = "Forest", Rarity = "Uncommon",
		Ability = "HighJump", Value = 95, AbilityText = "High jump over logs",
		BodyColor = Color3.fromRGB(240, 160, 70), AccentColor = Color3.fromRGB(255, 230, 200), Ears = "Pointy", Size = 1,
	},
	Fox = {
		Name = "Fox", Emoji = "🦊", Zone = "Forest", Rarity = "Rare",
		Ability = "ForestRunner", Value = 1.2, AbilityText = "Knows the forest: +20% speed on Forest tracks",
		BodyColor = Color3.fromRGB(230, 110, 40), AccentColor = Color3.fromRGB(255, 255, 255), Ears = "Pointy", Size = 1.1,
	},
	Bear = {
		Name = "Bear", Emoji = "🐻", Zone = "Forest", Rarity = "Epic",
		Ability = "Tough", AbilityText = "Never slowed by logs",
		BodyColor = Color3.fromRGB(120, 75, 45), AccentColor = Color3.fromRGB(190, 140, 100), Ears = "Round", Size = 1.4,
	},
	Panda = {
		Name = "Panda", Emoji = "🐼", Zone = "Forest", Rarity = "Legendary",
		Ability = "CoinBonus", Value = 0.25, AbilityText = "Earns 25% more coins",
		BodyColor = Color3.fromRGB(250, 250, 250), AccentColor = Color3.fromRGB(30, 30, 30), Ears = "Round", Size = 1.4,
	},

	-- Beach
	Crab = {
		Name = "Crab", Emoji = "🦀", Zone = "Beach", Rarity = "Common",
		Ability = "SandWalker", AbilityText = "Never slowed by sand",
		BodyColor = Color3.fromRGB(230, 70, 50), AccentColor = Color3.fromRGB(255, 200, 180), Ears = "None", Size = 0.9,
	},
	Turtle = {
		Name = "Turtle", Emoji = "🐢", Zone = "Beach", Rarity = "Uncommon",
		Ability = "Shield", AbilityText = "Shield ignores one obstacle hit per race",
		BodyColor = Color3.fromRGB(90, 170, 90), AccentColor = Color3.fromRGB(140, 100, 60), Ears = "None", Size = 1,
	},
	Frog = {
		Name = "Frog", Emoji = "🐸", Zone = "Beach", Rarity = "Rare",
		Ability = "Leap", Value = 70, AbilityText = "Long leap over water and gaps",
		BodyColor = Color3.fromRGB(80, 200, 70), AccentColor = Color3.fromRGB(230, 255, 180), Ears = "None", Size = 0.9,
	},
	Dolphin = {
		Name = "Dolphin", Emoji = "🐬", Zone = "Beach", Rarity = "Epic",
		Ability = "WaterSpeed", Value = 1.3, AbilityText = "Double speed in water",
		BodyColor = Color3.fromRGB(90, 150, 220), AccentColor = Color3.fromRGB(220, 235, 255), Ears = "None", Size = 1.2,
	},
	Shark = {
		Name = "Shark", Emoji = "🦈", Zone = "Beach", Rarity = "Legendary",
		Ability = "WaterSpeed", Value = 1.9, AbilityText = "Triple speed in water",
		BodyColor = Color3.fromRGB(120, 135, 155), AccentColor = Color3.fromRGB(240, 240, 240), Ears = "None", Size = 1.4,
	},
}

return Animals
