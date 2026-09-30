--!strict
-- Zone gates (unlock with coins) and moving between the Plaza, bases and zones.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local Teleport = require(script.Parent.Teleport)
local TutorialService = require(script.Parent.TutorialService)
local BaseService = require(script.Parent.BaseService)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Util = require(ReplicatedStorage.Shared.Util)
local Zones = require(ReplicatedStorage.Config.Zones)

local ZoneService = {}

local lastMove: { [Player]: number } = {}

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

function ZoneService.TryUnlock(player: Player, zoneId: string): Net.Result
	local data = DataService.Get(player)
	local zone = Zones[zoneId]
	if not data or not zone then
		return { Ok = false }
	end
	if data.UnlockedZones[zoneId] then
		return { Ok = true }
	end
	if zone.ComingSoon then
		return { Ok = false, Message = `{zone.Name} is coming soon!` }
	end
	for id, other in Zones do
		if other.Order == zone.Order - 1 and not data.UnlockedZones[id] then
			return { Ok = false, Message = `Unlock {other.Name} first!` }
		end
	end
	if not DataService.SpendCoins(player, zone.GateCost) then
		return { Ok = false, Message = `You need 🪙 {Util.FormatNumber(zone.GateCost)} to unlock {zone.Name}` }
	end
	data.UnlockedZones[zoneId] = true
	DataService.Changed(player)
	Net.Notify(player, `{zone.Emoji} {zone.Name} unlocked!`, "Success")
	return { Ok = true }
end

-- target: a zone id, "Plaza" or "Base".
function ZoneService.GoTo(player: Player, target: string): Net.Result
	local data = DataService.Get(player)
	if not data then
		return { Ok = false }
	end
	if player:GetAttribute("Racing") then
		return { Ok = false, Message = "Finish your race first!" }
	end
	local now = os.clock()
	if now - (lastMove[player] or 0) < 1.5 then
		return { Ok = false }
	end
	lastMove[player] = now

	if target == "Plaza" then
		Teleport.To(player, Layout.PlazaSpawn, "Plaza")
		return { Ok = true }
	elseif target == "Base" then
		local spawn = BaseService.SpawnCFrame(player)
		if not spawn then
			return { Ok = false, Message = "No base plot is free on this server" }
		end
		Teleport.To(player, spawn.Position, "Plaza", spawn.LookVector)
		return { Ok = true }
	end

	local zone = Zones[target]
	if not zone or not Layout.ZoneOrigins[target] then
		return { Ok = false, Message = "That zone is coming soon!" }
	end
	if not data.UnlockedZones[target] then
		return { Ok = false, Message = `Unlock {zone.Name} for 🪙 {Util.FormatNumber(zone.GateCost)}` }
	end
	Teleport.To(player, Layout.ZoneSpawn(target), target, Vector3.new(1, 0, 0))
	TutorialService.OnEnterZone(player, target)
	return { Ok = true }
end

function ZoneService.Init()
	Net.OnInvoke("TeleportZone", 1, function(player, target)
		if typeof(target) ~= "string" then
			return { Ok = false }
		end
		return ZoneService.GoTo(player, target)
	end)

	Net.OnInvoke("UnlockZone", 2, function(player, zoneId)
		if typeof(zoneId) ~= "string" then
			return { Ok = false }
		end
		return ZoneService.TryUnlock(player, zoneId)
	end)
end

function ZoneService.Start()
	local touchCooldown: { [Player]: number } = {}
	local function onGateTouched(hit: BasePart, target: string)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local now = os.clock()
		if now - (touchCooldown[player] or 0) < 2 then
			return
		end
		touchCooldown[player] = now
		local result = ZoneService.GoTo(player, target)
		if not result.Ok and result.Message then
			Net.Notify(player, result.Message, "Error")
		end
	end

	for _, gate in CollectionService:GetTagged("PortalGate") do
		local zoneId = gate:GetAttribute("Zone") :: string
		local gatePart = gate :: BasePart
		gatePart.Touched:Connect(function(hit)
			onGateTouched(hit, zoneId)
		end)
	end
	for _, gate in CollectionService:GetTagged("ReturnGate") do
		local gatePart = gate :: BasePart
		gatePart.Touched:Connect(function(hit)
			onGateTouched(hit, "Plaza")
		end)
	end
	for _, prompt in CollectionService:GetTagged("UnlockPrompt") do
		local zoneId = prompt:GetAttribute("Zone") :: string
		local unlockPrompt = prompt :: ProximityPrompt
		unlockPrompt.Triggered:Connect(function(player)
			local result = ZoneService.TryUnlock(player, zoneId)
			if result.Ok then
				ZoneService.GoTo(player, zoneId)
			elseif result.Message then
				Net.Notify(player, result.Message, "Error")
			end
		end)
	end

	local function onPlayer(player: Player)
		player:SetAttribute("Zone", "Plaza")
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Zone", "Plaza")
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastMove[player] = nil
		touchCooldown[player] = nil
	end)
end

return ZoneService
