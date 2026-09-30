--!strict
-- Daily reward chest and small playtime gifts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Config.Economy)

local RewardService = {}

local function claimDaily(player: Player): Net.Result
	local data = DataService.Get(player)
	if not data then
		return { Ok = false }
	end
	local now = os.time()
	local readyAt = data.LastDaily + Economy.DailyCooldown
	if now < readyAt then
		local hours = math.ceil((readyAt - now) / 3600)
		return { Ok = false, Message = `Come back in {hours} hour{if hours == 1 then "" else "s"} for your next reward!` }
	end
	data.LastDaily = now
	DataService.AddCoins(player, Economy.DailyReward, "Daily")
	Net.Notify(player, "🎁 Daily reward!", "Success")
	return { Ok = true }
end

function RewardService.Init()
	Net.OnInvoke("ClaimDaily", 1, claimDaily)
end

function RewardService.Start()
	for _, prompt in CollectionService:GetTagged("DailyPrompt") do
		local chestPrompt = prompt :: ProximityPrompt
		chestPrompt.Triggered:Connect(function(player)
			local result = claimDaily(player)
			if not result.Ok and result.Message then
				Net.Notify(player, result.Message, "Info")
			end
		end)
	end

	-- Playtime gift every few minutes.
	local joinedAt: { [Player]: number } = {}
	DataService.OnLoaded(function(player)
		joinedAt[player] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
	end)
	while true do
		task.wait(10)
		local now = os.clock()
		for player, since in joinedAt do
			if now - since >= Economy.PlaytimeGiftInterval then
				joinedAt[player] = now
				DataService.AddCoins(player, Economy.PlaytimeGift, "Gift")
				Net.Notify(player, `🎁 Playtime gift: +{Economy.PlaytimeGift} coins!`, "Success")
			end
		end
	end
end

return RewardService
