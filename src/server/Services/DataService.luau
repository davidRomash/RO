--!strict
-- Loads, saves and session-locks player data with ProfileStore.
-- Saves on leave, periodically (ProfileStore auto-save) and on shutdown (ProfileStore BindToClose).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Net = require(script.Parent.Net)
local Economy = require(ReplicatedStorage.Config.Economy)
local Zones = require(ReplicatedStorage.Config.Zones)
local PetMath = require(ReplicatedStorage.Shared.PetMath)

local DATA_VERSION = 1

export type Pet = PetMath.Pet

export type PlayerData = {
	Version: number,
	Coins: number,
	TotalCoins: number,
	Pets: { Pet },
	Equipped: { string },
	NextPetId: number,
	Discovered: { [string]: boolean },
	UnlockedZones: { [string]: boolean },
	PityCounter: number,
	Hatches: number,
	BaseLevel: number,
	LastDaily: number,
	Tutorial: string, -- "Start" | "GoForest" | "Race" | "GoEgg" | "Done"
	Races: number,
	RacesWon: number,
	Settings: { [string]: boolean },
}

local TEMPLATE: PlayerData = {
	Version = DATA_VERSION,
	Coins = Economy.StartingCoins,
	TotalCoins = 0,
	Pets = {},
	Equipped = {},
	NextPetId = 1,
	Discovered = {},
	UnlockedZones = { Forest = true },
	PityCounter = 0,
	Hatches = 0,
	BaseLevel = 1,
	LastDaily = 0,
	Tutorial = "Start",
	Races = 0,
	RacesWon = 0,
	Settings = { FastHatch = false, ShowOtherPets = true },
}

local store = ProfileStore.New("AnimalRush_PlayerData", TEMPLATE)
local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}
local pendingPush: { [Player]: boolean } = {}

local DataService = {}

-- Upgrades saved data from older versions. Add a step here whenever the data shape changes.
local function migrate(data: PlayerData)
	if data.Version < DATA_VERSION then
		data.Version = DATA_VERSION
	end
end

function DataService.Get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.OnLoaded(callback: (Player, PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.InventorySize(data: PlayerData): number
	local level = Economy.BaseLevels[data.BaseLevel] or Economy.BaseLevels[1]
	return level.InventorySlots
end

function DataService.NextGate(data: PlayerData): (string?, number?)
	local bestId, bestOrder = nil, math.huge
	for id, zone in Zones do
		if not data.UnlockedZones[id] and zone.Order < bestOrder then
			bestId, bestOrder = id, zone.Order
		end
	end
	if bestId then
		return bestId, Zones[bestId].GateCost
	end
	return nil, nil
end

-- What the client is allowed to see about its own data.
local function snapshot(data: PlayerData)
	return {
		Coins = data.Coins,
		Pets = data.Pets,
		Equipped = data.Equipped,
		Discovered = data.Discovered,
		UnlockedZones = data.UnlockedZones,
		PityCounter = data.PityCounter,
		Hatches = data.Hatches,
		BaseLevel = data.BaseLevel,
		InventorySize = DataService.InventorySize(data),
		DailyReadyAt = data.LastDaily + Economy.DailyCooldown,
		ServerTime = os.time(),
		Tutorial = data.Tutorial,
		Settings = data.Settings,
		Races = data.Races,
		RacesWon = data.RacesWon,
	}
end

local function equippedAttribute(data: PlayerData): string
	local parts = {}
	for _, pet in PetMath.EquippedPets(data.Pets, data.Equipped) do
		table.insert(parts, pet.Animal .. (if pet.Golden then ":G" else ""))
	end
	return table.concat(parts, ",")
end

-- Call after changing a player's data: updates leaderstats, pet display and the client (batched per frame).
function DataService.Changed(player: Player)
	if pendingPush[player] then
		return
	end
	pendingPush[player] = true
	task.defer(function()
		pendingPush[player] = nil
		local data = DataService.Get(player)
		if not data then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
		if coins then
			coins.Value = data.Coins
		end
		player:SetAttribute("EquippedPets", equippedAttribute(data))
		player:SetAttribute("ShowOtherPets", data.Settings.ShowOtherPets ~= false)
		Net.Fire("StateChanged", player, snapshot(data))
	end)
end

function DataService.AddCoins(player: Player, amount: number, source: string?)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.Coins += amount
	data.TotalCoins += amount
	Net.Fire("CoinsAwarded", player, amount, source or "")
	DataService.Changed(player)
end

function DataService.SpendCoins(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	DataService.Changed(player)
	return true
end

local function createLeaderstats(player: Player, data: PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats
	leaderstats.Parent = player
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your data could not be loaded. Please rejoin!")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your game was opened somewhere else. Please rejoin!")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	migrate(profile.Data)
	profiles[player] = profile
	createLeaderstats(player, profile.Data)
	DataService.Changed(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile.Data)
	end
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- Wipes a player's data back to a brand new save (admin command).
function DataService.Reset(player: Player): boolean
	local data = DataService.Get(player) :: any
	if not data then
		return false
	end
	for key in data do
		data[key] = nil
	end
	for key, value in deepCopy(TEMPLATE) do
		data[key] = value
	end
	DataService.Changed(player)
	return true
end

local SETTING_KEYS = { FastHatch = true, ShowOtherPets = true }

function DataService.Init()
	Net.OnInvoke("UpdateSetting", 3, function(player, key, value)
		local data = DataService.Get(player)
		if not data or typeof(key) ~= "string" or not SETTING_KEYS[key] or typeof(value) ~= "boolean" then
			return { Ok = false }
		end
		data.Settings[key] = value
		DataService.Changed(player)
		return { Ok = true }
	end)
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		pendingPush[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
