--!strict
-- First-minute guide: a glowing arrow above the player points to the next goal
-- (Forest portal -> start pad -> egg stand). Teach by pointing, not by explaining.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.State)
local Layout = require(ReplicatedStorage.Shared.Layout)

local player = Players.LocalPlayer :: Player

local GuideController = {}

local ARRIVED_DISTANCE = 14
local COLOR = Color3.fromRGB(255, 225, 60)

local arrow = Instance.new("Model")
arrow.Name = "GuideArrow"

local function arrowPart(name: string, size: Vector3, offset: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = COLOR
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p:SetAttribute("Offset", offset)
	p.Parent = arrow
	return p
end

-- Arrow pointing along -Z: a shaft and two angled bars for the head.
local parts = {
	arrowPart("Shaft", Vector3.new(0.7, 0.5, 4), CFrame.new(0, 0, 0.6)),
	arrowPart("HeadL", Vector3.new(0.7, 0.5, 2.4), CFrame.new(-0.72, 0, -1.05) * CFrame.Angles(0, math.rad(-40), 0)),
	arrowPart("HeadR", Vector3.new(0.7, 0.5, 2.4), CFrame.new(0.72, 0, -1.05) * CFrame.Angles(0, math.rad(40), 0)),
}

local function currentTarget(): Vector3?
	local state = State.Current
	if not state then
		return nil
	end
	local zone = player:GetAttribute("Zone")
	local step = state.Tutorial
	if step == "GoForest" or step == "Race" then
		if player:GetAttribute("Racing") then
			return nil
		end
		return if zone == "Forest" then Layout.StartPad("Forest") else Layout.Portals.Forest
	elseif step == "GoEgg" then
		if zone == "Forest" then
			return Layout.ZoneEggStand("Forest")
		end
		return Layout.EggStands[1].Position
	end
	return nil
end

function GuideController.Start()
	local t = 0
	RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		local target = currentTarget()
		local character = player.Character
		local root = character and character.PrimaryPart
		if not target or not root then
			arrow.Parent = nil
			return
		end
		local flat = (target - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < ARRIVED_DISTANCE then
			arrow.Parent = nil
			return
		end
		local direction = flat.Unit
		local position = root.Position + Vector3.new(0, 4.5 + math.sin(t * 4) * 0.3, 0) + direction * 3.5
		local base = CFrame.lookAt(position, position + direction)
		for _, p in parts do
			p.CFrame = base * (p:GetAttribute("Offset") :: CFrame)
		end
		arrow.Parent = Workspace
	end)
end

return GuideController
