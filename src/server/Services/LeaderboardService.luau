--!strict
-- Global "Top Racers" board in the Plaza, ranked by total coins earned (OrderedDataStore).
-- Falls back to this server's players when DataStores are unavailable (e.g. Studio without API access).

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Util = require(ReplicatedStorage.Shared.Util)

local UPDATE_INTERVAL = 120

local LeaderboardService = {}

local nameCache: { [number]: string } = {}

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and name then name else "Racer"
	nameCache[userId] = result
	return result
end

local function render(rows: { { Name: string, Coins: number } })
	for _, board in CollectionService:GetTagged("LeaderboardBoard") do
		local gui = board:FindFirstChild("Board")
		if not gui then
			continue
		end
		for i = 1, 10 do
			local label = gui:FindFirstChild(`Row{i}`) :: TextLabel?
			if label then
				local row = rows[i]
				label.Text = if row then `  {i}. {row.Name}  🪙 {Util.FormatNumber(row.Coins)}` else ""
			end
		end
	end
end

local function localRows(): { { Name: string, Coins: number } }
	local rows = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			table.insert(rows, { Name = player.DisplayName, Coins = data.TotalCoins })
		end
	end
	table.sort(rows, function(a, b)
		return a.Coins > b.Coins
	end)
	return rows
end

function LeaderboardService.Start()
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "AnimalRush_TopCoins")
	while true do
		local rows = nil
		if ok and store then
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and data.TotalCoins > 0 then
					pcall(store.SetAsync, store, tostring(player.UserId), data.TotalCoins)
				end
			end
			local success, pages = pcall(store.GetSortedAsync, store, false, 10)
			if success and pages then
				rows = {}
				for _, entry in pages:GetCurrentPage() do
					table.insert(rows, { Name = nameOf(tonumber(entry.key) or 0), Coins = entry.value })
				end
			end
		end
		render(rows or localRows())
		task.wait(if rows then UPDATE_INTERVAL else 15)
	end
end

return LeaderboardService
