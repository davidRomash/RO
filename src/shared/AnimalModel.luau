--!strict
-- Builds placeholder animal models from basic parts. Swap for real meshes later by
-- returning a cloned model here instead; everything else uses this one function.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)

local GOLD = Color3.fromRGB(255, 205, 60)

local AnimalModel = {}

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3, offset: CFrame, root: BasePart?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = root == nil -- only the root is anchored; the rest is welded to it
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	if root then
		p.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	else
		p.CFrame = offset
	end
	p.Parent = model
	return p
end

-- Returns a Model whose pivot (the anchored Root part) sits on the ground under the animal,
-- facing -Z (LookVector). Move it by setting Root.CFrame or with Model:PivotTo.
function AnimalModel.Build(animalId: string, golden: boolean?): Model
	local animal = Animals[animalId]
	local model = Instance.new("Model")
	model.Name = animalId
	if not animal then
		return model
	end

	local s = animal.Size
	local body = if golden then GOLD else animal.BodyColor
	local accent = if golden then Color3.fromRGB(255, 240, 170) else animal.AccentColor

	local root = part(model, "Root", Enum.PartType.Block, Vector3.new(1, 1, 1) * 0.2, body, CFrame.new())
	root.Transparency = 1
	model.PrimaryPart = root

	local bodyPart = part(model, "Body", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4) * s, body, CFrame.new(0, 1.2 * s, 0), root)
	local head = part(model, "Head", Enum.PartType.Ball, Vector3.new(1.7, 1.7, 1.7) * s, body, CFrame.new(0, 2.3 * s, -0.9 * s), root)
	part(model, "Belly", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6) * s, accent, CFrame.new(0, 1.0 * s, -0.55 * s), root)

	local eyeColor = Color3.fromRGB(25, 25, 25)
	local eyeSize = if animal.Name == "Frog" then 0.6 else 0.35
	part(model, "EyeL", Enum.PartType.Ball, Vector3.new(eyeSize, eyeSize, eyeSize) * s, eyeColor, CFrame.new(-0.4 * s, 2.5 * s, -1.65 * s), root)
	part(model, "EyeR", Enum.PartType.Ball, Vector3.new(eyeSize, eyeSize, eyeSize) * s, eyeColor, CFrame.new(0.4 * s, 2.5 * s, -1.65 * s), root)
	part(model, "Nose", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3) * s, accent, CFrame.new(0, 2.2 * s, -1.75 * s), root)

	local earColor = if animal.Name == "Panda" then animal.AccentColor else body
	if animal.Ears == "Long" then
		part(model, "EarL", Enum.PartType.Block, Vector3.new(0.35, 1.5, 0.25) * s, earColor, CFrame.new(-0.35 * s, 3.4 * s, -0.8 * s) * CFrame.Angles(0, 0, math.rad(8)), root)
		part(model, "EarR", Enum.PartType.Block, Vector3.new(0.35, 1.5, 0.25) * s, earColor, CFrame.new(0.35 * s, 3.4 * s, -0.8 * s) * CFrame.Angles(0, 0, math.rad(-8)), root)
	elseif animal.Ears == "Pointy" then
		part(model, "EarL", Enum.PartType.Wedge, Vector3.new(0.2, 0.7, 0.6) * s, earColor, CFrame.new(-0.5 * s, 3.2 * s, -0.9 * s), root)
		part(model, "EarR", Enum.PartType.Wedge, Vector3.new(0.2, 0.7, 0.6) * s, earColor, CFrame.new(0.5 * s, 3.2 * s, -0.9 * s), root)
	elseif animal.Ears == "Round" then
		part(model, "EarL", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6) * s, earColor, CFrame.new(-0.6 * s, 3.05 * s, -0.8 * s), root)
		part(model, "EarR", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6) * s, earColor, CFrame.new(0.6 * s, 3.05 * s, -0.8 * s), root)
	end

	-- A few species details so placeholders are easy to tell apart.
	if animal.Name == "Shark" or animal.Name == "Dolphin" then
		part(model, "Fin", Enum.PartType.Wedge, Vector3.new(0.25, 1.2, 1.2) * s, body, CFrame.new(0, 2.7 * s, 0.3 * s), root)
	elseif animal.Name == "Turtle" then
		part(model, "Shell", Enum.PartType.Ball, Vector3.new(2.8, 1.8, 2.8) * s, accent, CFrame.new(0, 1.7 * s, 0.2 * s), root)
	elseif animal.Name == "Crab" then
		part(model, "ClawL", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8) * s, body, CFrame.new(-1.4 * s, 1.4 * s, -1 * s), root)
		part(model, "ClawR", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8) * s, body, CFrame.new(1.4 * s, 1.4 * s, -1 * s), root)
	elseif animal.Name == "Fox" or animal.Name == "Cat" or animal.Name == "Rabbit" then
		part(model, "Tail", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 1.2) * s, accent, CFrame.new(0, 1.3 * s, 1.3 * s), root)
	end

	-- Rare things must look rare.
	local rarity = Rarities[animal.Rarity]
	if rarity.Glow or golden then
		local light = Instance.new("PointLight")
		light.Color = if golden then GOLD else rarity.Color
		light.Range = 8 * s
		light.Brightness = 1.5
		light.Parent = bodyPart
	end
	if rarity.Sparkles or golden then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(if golden then GOLD else rarity.Color)
		sparkles.Size = NumberSequence.new(0.4 * s, 0)
		sparkles.Lifetime = NumberRange.new(0.6, 1)
		sparkles.Rate = 6
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Parent = head
	end

	return model
end

-- Height of the model's centre above the ground, for placing it.
function AnimalModel.Height(animalId: string): number
	local animal = Animals[animalId]
	return if animal then 1.2 * animal.Size else 1.2
end

return AnimalModel
