--!strict
-- Rarity tiers. Higher tiers are faster and look flashier.

export type Rarity = {
	Order: number,
	Color: Color3,
	Speed: number, -- added to race walk speed when equipped
	SellValue: number,
	Glow: boolean, -- PointLight on the model
	Sparkles: boolean, -- particle effect on the model
}

local Rarities: { [string]: Rarity } = {
	Common = { Order = 1, Color = Color3.fromRGB(190, 190, 190), Speed = 2, SellValue = 20, Glow = false, Sparkles = false },
	Uncommon = { Order = 2, Color = Color3.fromRGB(85, 200, 90), Speed = 3, SellValue = 40, Glow = false, Sparkles = false },
	Rare = { Order = 3, Color = Color3.fromRGB(60, 140, 255), Speed = 5, SellValue = 100, Glow = true, Sparkles = false },
	Epic = { Order = 4, Color = Color3.fromRGB(170, 80, 255), Speed = 7, SellValue = 300, Glow = true, Sparkles = true },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 185, 30), Speed = 10, SellValue = 1000, Glow = true, Sparkles = true },
}

return Rarities
