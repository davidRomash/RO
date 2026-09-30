--!strict
-- Zones in unlock order. Tracks are straight strips; distances are in studs from the start line.

export type Section = { From: number, To: number }

export type Zone = {
	Name: string,
	Emoji: string,
	Order: number,
	GateCost: number,
	ComingSoon: boolean,
	Purse: number, -- coins for 1st place
	Egg: string?,
	GroundColor: Color3,
	TrackColor: Color3,
	Track: {
		Length: number,
		Width: number,
		Checkpoints: number, -- evenly spaced, the last one is the finish line
		Logs: { number }?, -- obstacle positions
		Water: { Section }?,
		Sand: { Section }?,
	}?,
}

local Zones: { [string]: Zone } = {
	Forest = {
		Name = "Forest", Emoji = "🌲", Order = 1, GateCost = 0, ComingSoon = false,
		Purse = 150, Egg = "Forest",
		GroundColor = Color3.fromRGB(95, 175, 75), TrackColor = Color3.fromRGB(170, 130, 85),
		Track = {
			Length = 1300, Width = 44, Checkpoints = 6,
			Logs = { 220, 420, 560, 760, 900, 1100 },
		},
	},
	Beach = {
		Name = "Beach", Emoji = "🏖️", Order = 2, GateCost = 2500, ComingSoon = false,
		Purse = 600, Egg = "Beach",
		GroundColor = Color3.fromRGB(240, 220, 160), TrackColor = Color3.fromRGB(250, 235, 185),
		Track = {
			Length = 1500, Width = 44, Checkpoints = 6,
			Water = { { From = 250, To = 420 }, { From = 700, To = 880 }, { From = 1150, To = 1320 } },
			Sand = { { From = 480, To = 620 }, { From = 950, To = 1080 } },
		},
	},
	Desert = { Name = "Desert", Emoji = "🏜️", Order = 3, GateCost = 12000, ComingSoon = true, Purse = 0, GroundColor = Color3.fromRGB(230, 170, 90), TrackColor = Color3.fromRGB(210, 150, 80) },
	Ice = { Name = "Ice World", Emoji = "🧊", Order = 4, GateCost = 60000, ComingSoon = true, Purse = 0, GroundColor = Color3.fromRGB(225, 240, 255), TrackColor = Color3.fromRGB(180, 215, 245) },
	Volcano = { Name = "Volcano", Emoji = "🌋", Order = 5, GateCost = 300000, ComingSoon = true, Purse = 0, GroundColor = Color3.fromRGB(60, 30, 30), TrackColor = Color3.fromRGB(40, 20, 20) },
}

return Zones
