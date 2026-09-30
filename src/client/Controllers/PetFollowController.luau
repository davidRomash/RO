--!strict
-- Equipped animals follow their owner around, hopping as they go. Drawn on each client
-- from the owner's "EquippedPets" attribute, so it costs the server nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimalModel = require(ReplicatedStorage.Shared.AnimalModel)

local localPlayer = Players.LocalPlayer :: Player

local PetFollowController = {}

local DRAW_DISTANCE = 200
local SLOTS = {
	Vector3.new(-4.5, 0, 3.5),
	Vector3.new(4.5, 0, 3.5),
	Vector3.new(0, 0, 6.5),
}

type Follower = { Model: Model, Slot: number, Phase: number }

local folder = Instance.new("Folder")
folder.Name = "PetFollowers"
folder.Parent = Workspace

local followers: { [Player]: { Follower } } = {}

local function clear(player: Player)
	local list = followers[player]
	if list then
		for _, follower in list do
			follower.Model:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local value = player:GetAttribute("EquippedPets")
	if typeof(value) ~= "string" or value == "" then
		return
	end
	local list = {}
	for i, entry in string.split(value, ",") do
		local animalId, golden = entry:match("^(%w+)(:?G?)$")
		if animalId and SLOTS[i] then
			local model = AnimalModel.Build(animalId, golden == ":G")
			model.Parent = folder
			table.insert(list, { Model = model, Slot = i, Phase = i * 1.7 })
		end
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetFollowController.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	local t = 0
	RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		local showOthers = localPlayer:GetAttribute("ShowOtherPets") ~= false
		local alpha = 1 - math.exp(-dt * 10)
		for player, list in followers do
			local character = player.Character
			local root = character and character.PrimaryPart
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local visible = root ~= nil and humanoid ~= nil and (player == localPlayer or showOthers)
				and (root.Position - cameraPosition).Magnitude < DRAW_DISTANCE
			for _, follower in list do
				local model = follower.Model
				if not visible or not root or not humanoid then
					model.Parent = nil
					continue
				end
				model.Parent = folder
				local moving = root.AssemblyLinearVelocity.Magnitude > 2
				local hop = if moving then math.abs(math.sin(t * 10 + follower.Phase)) * 1.2 else 0
				local groundY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
				local slot = (root.CFrame * CFrame.new(SLOTS[follower.Slot])).Position
				local goal = CFrame.lookAt(Vector3.new(slot.X, groundY + hop, slot.Z), Vector3.new(slot.X, groundY + hop, slot.Z) + root.CFrame.LookVector)
				local current = model:GetPivot()
				if (current.Position - goal.Position).Magnitude > 40 then
					model:PivotTo(goal) -- teleported: snap
				else
					model:PivotTo(current:Lerp(goal, alpha))
				end
			end
		end
	end)
end

return PetFollowController
