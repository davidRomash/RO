--!strict
-- Client-side world touches: portal signs and unlock prompts reflect this player's progress,
-- base upgrade prompts only show on your own base, egg stands open the egg menu, and the Frog's leap.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(script.Parent.State)
local EggMenu = require(script.Parent.EggMenu)
local Zones = require(ReplicatedStorage.Config.Zones)
local Util = require(ReplicatedStorage.Shared.Util)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer :: Player

local WorldController = {}

local function updatePortal(gate: Instance)
	local state = State.Current
	local zoneId = gate:GetAttribute("Zone")
	local zone = if typeof(zoneId) == "string" then Zones[zoneId] else nil
	if not state or not zone then
		return
	end
	local unlocked = state.UnlockedZones[zoneId] == true
	local arch = gate.Parent
	local top = arch and arch:FindFirstChild("Top")
	local sign = top and top:FindFirstChild("Sign")
	local status = sign and sign:FindFirstChild("Status") :: TextLabel?
	if status then
		if unlocked then
			status.Text = "✅ Open!"
			status.TextColor3 = Color3.fromRGB(140, 255, 140)
		elseif zone.ComingSoon then
			status.Text = "🔒 Soon"
			status.TextColor3 = Color3.new(1, 1, 1)
		else
			status.Text = `🔒 🪙 {Util.FormatNumber(zone.GateCost)}`
			status.TextColor3 = if state.Coins >= zone.GateCost then Color3.fromRGB(255, 220, 80) else Color3.new(1, 1, 1)
		end
	end
	local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not unlocked
	end
end

local function updateUpgradePrompt(prompt: Instance)
	local pad = prompt.Parent
	local plot = pad and pad.Parent
	if not plot or not prompt:IsA("ProximityPrompt") then
		return
	end
	local mine = plot:GetAttribute("OwnerUserId") == player.UserId
	if prompt.Enabled ~= mine then
		prompt.Enabled = mine
	end
end

local function refreshAll()
	for _, gate in CollectionService:GetTagged("PortalGate") do
		updatePortal(gate)
	end
end

function WorldController.Start()
	State.OnChanged(refreshAll)
	CollectionService:GetInstanceAddedSignal("PortalGate"):Connect(function(gate)
		task.defer(updatePortal, gate)
	end)

	-- Streaming may load base plots at any time, so hook them up as they arrive.
	local function hookUpgrade(instance: Instance)
		local prompt = instance :: ProximityPrompt
		updateUpgradePrompt(prompt)
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			updateUpgradePrompt(prompt)
		end)
		local plot = prompt.Parent and prompt.Parent.Parent
		if plot then
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				updateUpgradePrompt(prompt)
			end)
		end
	end
	for _, prompt in CollectionService:GetTagged("BaseUpgrade") do
		hookUpgrade(prompt)
	end
	CollectionService:GetInstanceAddedSignal("BaseUpgrade"):Connect(hookUpgrade)

	;(Remotes:WaitForChild("OpenMenu") :: RemoteEvent).OnClientEvent:Connect(function(kind, arg)
		if kind == "Egg" then
			EggMenu.Open(arg)
		end
	end)

	;(Remotes:WaitForChild("AbilityFx") :: RemoteEvent).OnClientEvent:Connect(function(kind, power)
		if kind ~= "Leap" then
			return
		end
		local character = player.Character
		local root = character and character.PrimaryPart
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end
		local strength = tonumber(power) or 60
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		task.wait()
		local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if forward.Magnitude > 0 then
			root.AssemblyLinearVelocity = forward.Unit * strength + Vector3.new(0, strength * 0.55, 0)
		end
	end)
end

return WorldController
