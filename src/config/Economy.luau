--!strict
-- Coin rewards, costs and timers. Starting guesses: tune from real play data.

return {
	StartingCoins = 50,

	-- Share of the zone purse by finishing place (4th and lower get the last value).
	PlacePayout = { 1.0, 0.7, 0.5, 0.3 },

	DailyReward = 250,
	DailyCooldown = 20 * 60 * 60, -- seconds

	PlaytimeGift = 25,
	PlaytimeGiftInterval = 5 * 60,

	MaxEquipped = 3,
	GoldenMergeCount = 5,
	GoldenMultiplier = 1.5, -- speed and sell value
	PityHatches = 20, -- guaranteed Rare or better within this many hatches

	-- Base upgrades: index = level. Level 1 is free.
	BaseLevels = {
		{ Cost = 0, InventorySlots = 50 },
		{ Cost = 1500, InventorySlots = 75 },
		{ Cost = 7500, InventorySlots = 100 },
	},

	Race = {
		BaseWalkSpeed = 16,
		IntermissionSeconds = 15,
		TutorialIntermissionSeconds = 3,
		CountdownSeconds = 3,
		MaxRaceSeconds = 120,
		MinLineup = 4, -- bots fill up to this many racers when fewer than 3 players join
		AbilityCooldown = 10,
		LogSlowMultiplier = 0.45,
		LogSlowSeconds = 1.5,
		WaterMultiplier = 0.6,
		SandMultiplier = 0.75,
	},
}
