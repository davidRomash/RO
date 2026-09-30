--!strict
-- Base plots: one free plot per player, upgrades, and equipped animals walking around the base.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local Teleport = require(script.Parent.Teleport)
local Economy = require(ReplicatedStorage.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Util = require(ReplicatedStorage.Shared.Util)
local AnimalModel = require(ReplicatedStorage.Shared.AnimalModel)

local BaseService = {}

local plots: { [number]: Model } = {}
local owners: { [number]: Player } = {}
local playerPlot: { [Player]: number } = {}

function BaseService.SpawnCFrame(player: Player): CFrame?
	local index = playerPlot[player]
	local plot = index and plots[index]
	local spawn = plot and plot:FindFirstChild("Spawn") :: BasePart?
	return if spawn then spawn.CFrame else nil
end

local function ownerLabel(plot: Model): TextLabel?
	local post = plot:FindFirstChild("SignPost")
	local gui = post and post:FindFirstChild("Owner")
	return gui and gui:FindFirstChild("Text") :: TextLabel?
end

local function upgradePrompt(plot: Model): ProximityPrompt?
	local pad = plot:FindFirstChild("UpgradePad")
	return pad and pad:FindFirstChildOfClass("ProximityPrompt")
end

local function refreshPlot(index: number)
	local plot = plots[index]
	local owner = owners[index]
	local text = ownerLabel(plot)
	local prompt = upgradePrompt(plot)
	local data = owner and DataService.Get(owner)
	if text then
		text.Text = if owner and data then `🏡 {owner.DisplayName}'s Base (Lv {data.BaseLevel})` else "Free plot"
	end
	if prompt then
		prompt.Enabled = data ~= nil
		local nextLevel = if data then Economy.BaseLevels[data.BaseLevel + 1] else nil
		if data and nextLevel then
			prompt.ActionText = "Upgrade"
			prompt.ObjectText = `Lv {data.BaseLevel + 1}: 🪙 {Util.FormatNumber(nextLevel.Cost)} (+{nextLevel.InventorySlots - DataService.InventorySize(data)} slots)`
		else
			prompt.ActionText = "Max level"
			prompt.ObjectText = "Base"
		end
	end
end

local function rebuildPets(index: number)
	local plot = plots[index]
	local folder = plot:FindFirstChild("Pets") :: Folder
	folder:ClearAllChildren()
	local owner = owners[index]
	local equipped = owner and owner:GetAttribute("EquippedPets") :: string?
	if not equipped or equipped == "" then
		return
	end
	local center = (plot.PrimaryPart :: BasePart).Position
	for i, entry in string.split(equipped, ",") do
		local animalId, golden = entry:match("^(%w+)(:?G?)$")
		if animalId then
			local model = AnimalModel.Build(animalId, golden == ":G")
			local offset = Vector3.new((i - 2) * 6, 0.2, 4)
			model:PivotTo(CFrame.new(center + offset))
			model.Parent = folder
		end
	end
end

local function assign(player: Player)
	for index = 1, Layout.BaseCount do
		if not owners[index] then
			owners[index] = player
			playerPlot[player] = index
			plots[index]:SetAttribute("OwnerUserId", player.UserId)
			refreshPlot(index)
			rebuildPets(index)
			return
		end
	end
end

local function release(player: Player)
	local index = playerPlot[player]
	if not index then
		return
	end
	owners[index] = nil
	playerPlot[player] = nil
	plots[index]:SetAttribute("OwnerUserId", nil)
	refreshPlot(index)
	rebuildPets(index)
end

local function spawnAtBase(player: Player)
	local data = DataService.Get(player)
	if not data or data.Tutorial ~= "Done" then
		return -- new players start in the Plaza
	end
	local character = player.Character
	if not character or not character:WaitForChild("HumanoidRootPart", 5) then
		return
	end
	local spawn = BaseService.SpawnCFrame(player)
	if spawn then
		Teleport.To(player, spawn.Position, "Plaza", spawn.LookVector)
	end
end

local function tryUpgrade(player: Player, index: number)
	if owners[index] ~= player then
		Net.Notify(player, "This is not your base", "Error")
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local nextLevel = Economy.BaseLevels[data.BaseLevel + 1]
	if not nextLevel then
		Net.Notify(player, "Your base is max level!", "Info")
		return
	end
	if not DataService.SpendCoins(player, nextLevel.Cost) then
		Net.Notify(player, `You need 🪙 {Util.FormatNumber(nextLevel.Cost)}`, "Error")
		return
	end
	data.BaseLevel += 1
	DataService.Changed(player)
	refreshPlot(index)
	Net.Notify(player, `Base upgraded! Room for {nextLevel.InventorySlots} animals`, "Success")
end

-- Equipped animals stroll around their base while someone is nearby to see them.
local function wander()
	local rng = Random.new()
	while true do
		task.wait(2.5)
		for index, plot in plots do
			if not owners[index] then
				continue
			end
			local center = (plot.PrimaryPart :: BasePart).Position
			local someoneNear = false
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character and character.PrimaryPart and (character.PrimaryPart.Position - center).Magnitude < 150 then
					someoneNear = true
					break
				end
			end
			if not someoneNear then
				continue
			end
			local half = Layout.BaseSize / 2 - 5
			for _, model in (plot:FindFirstChild("Pets") :: Folder):GetChildren() do
				local root = (model :: Model).PrimaryPart
				if root and rng:NextNumber() < 0.6 then
					local target = center + Vector3.new(rng:NextNumber(-half, half), 0.2, rng:NextNumber(-half, half))
					local from = root.Position
					local goal = CFrame.lookAt(target, target + (target - from) * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.001))
					local duration = math.clamp((target - from).Magnitude / 8, 0.5, 2.2)
					TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine), { CFrame = goal }):Play()
				end
			end
		end
	end
end

function BaseService.Init()
	for _, plot in CollectionService:GetTagged("BasePlot") do
		plots[plot:GetAttribute("Index") :: number] = plot :: Model
	end
end

function BaseService.Start()
	for _, prompt in CollectionService:GetTagged("BaseUpgrade") do
		local index = prompt:GetAttribute("Index") :: number
		local upgrade = prompt :: ProximityPrompt
		upgrade.Enabled = false
		upgrade.Triggered:Connect(function(player)
			tryUpgrade(player, index)
		end)
	end

	DataService.OnLoaded(function(player, _data)
		assign(player)
		spawnAtBase(player)
		player.CharacterAdded:Connect(function()
			task.wait() -- let the default spawn finish first
			spawnAtBase(player)
		end)
		player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
			local index = playerPlot[player]
			if index then
				rebuildPets(index)
				refreshPlot(index)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(release)
	task.spawn(wander)
end

return BaseService
