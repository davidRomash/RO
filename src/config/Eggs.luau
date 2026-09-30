--!strict
-- Price and odds per egg. Odds are shown to players on the egg stand and in the egg menu.

export type Egg = {
	Name: string,
	Zone: string,
	Price: number,
	Color: Color3,
	Odds: { { Animal: string, Chance: number } }, -- chances add up to 100
}

local Eggs: { [string]: Egg } = {
	Forest = {
		Name = "Forest Egg",
		Zone = "Forest",
		Price = 200,
		Color = Color3.fromRGB(120, 200, 100),
		Odds = {
			{ Animal = "Rabbit", Chance = 60 },
			{ Animal = "Cat", Chance = 25 },
			{ Animal = "Fox", Chance = 10 },
			{ Animal = "Bear", Chance = 4 },
			{ Animal = "Panda", Chance = 1 },
		},
	},
	Beach = {
		Name = "Beach Egg",
		Zone = "Beach",
		Price = 1200,
		Color = Color3.fromRGB(90, 200, 220),
		Odds = {
			{ Animal = "Crab", Chance = 60 },
			{ Animal = "Turtle", Chance = 25 },
			{ Animal = "Frog", Chance = 10 },
			{ Animal = "Dolphin", Chance = 4 },
			{ Animal = "Shark", Chance = 1 },
		},
	},
}

return Eggs
