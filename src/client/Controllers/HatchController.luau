--!strict
-- Hatch animation: the egg wobbles (~2 seconds), flashes, and the animal pops out.
-- After the first hatch, tapping skips the wobble (or turn on "Fast hatch" in settings).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local AnimalModel = require(ReplicatedStorage.Shared.AnimalModel)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = UIKit.Colors

local HatchController = {}

local screen = UIKit.Screen("Hatch", 20, Enum.ScreenInsets.None)
local overlay = UIKit.New("TextButton", {
	Name = "Overlay",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = screen,
}) :: TextButton
local flash = UIKit.New("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 5,
	Parent = overlay,
}) :: Frame
local stage = UIKit.Anchor(overlay, "Stage", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(900, 520))
local title = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 70), Parent = stage })
local cards = UIKit.New("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 0, 380),
	Parent = stage,
}, {
	UIKit.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 20),
	}),
}) :: Frame
local hint = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 470), TextTransparency = 0.2, Parent = stage })

local playing = false
local queue: { any } = {}

local function makeViewport(parent: Instance): (ViewportFrame, Camera)
	local viewport = UIKit.New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 260),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	}) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, 11), Vector3.new(0, 1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport, camera
end

local function waitOrSkip(seconds: number, canSkip: boolean): ()
	local skipped = false
	local connection = overlay.Activated:Connect(function()
		if canSkip then
			skipped = true
		end
	end)
	local start = os.clock()
	while os.clock() - start < seconds and not skipped do
		RunService.RenderStepped:Wait()
	end
	connection:Disconnect()
end

local function play(payload: any)
	playing = true
	local state = State.Current
	local results = payload.Results or {}
	local egg = Eggs[payload.Egg] or Eggs.Forest
	local canSkip = state ~= nil and (state.Settings.FastHatch or (state.Hatches or 0) > 1)

	for _, child in cards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	title.Text = if payload.Free then "🎉 Your first animal!" else `{egg.Name}`
	hint.Text = if canSkip then "Tap to skip" else ""
	overlay.Visible = true

	-- One card per egg with a wobbling egg inside.
	local eggs = {}
	for i, result in results do
		local card = UIKit.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(260, 380),
			LayoutOrder = i,
			Parent = cards,
		}) :: Frame
		local viewport = makeViewport(card)
		local eggPart = Instance.new("Part")
		eggPart.Shape = Enum.PartType.Ball
		eggPart.Size = Vector3.new(4, 5.2, 4)
		eggPart.Color = egg.Color
		eggPart.CFrame = CFrame.new(0, 1, 0)
		eggPart.Parent = viewport
		table.insert(eggs, { Card = card, Viewport = viewport, Egg = eggPart, Result = result })
	end

	UIKit.PlaySound("Hatch")
	local wobbleStart = os.clock()
	local wobble = RunService.RenderStepped:Connect(function()
		local t = os.clock() - wobbleStart
		local strength = math.min(1, t / 2) * 0.35
		for i, entry in eggs do
			entry.Egg.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.sin(t * 18 + i) * strength)
		end
	end)
	waitOrSkip(if state and state.Settings.FastHatch then 0.3 else 2.2, canSkip)
	wobble:Disconnect()

	flash.BackgroundTransparency = 0
	UIKit.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	UIKit.PlaySound("Reveal")

	-- Reveal the animals.
	local spinners = {}
	for _, entry in eggs do
		entry.Egg:Destroy()
		local result = entry.Result
		local animal = Animals[result.Animal]
		if not animal then
			continue
		end
		local rarity = Rarities[animal.Rarity]
		local model = AnimalModel.Build(result.Animal, result.Golden)
		model:PivotTo(CFrame.new(0, -1.2 * animal.Size, 0) * CFrame.Angles(0, math.pi, 0))
		model:ScaleTo(1.6 / animal.Size)
		model.Parent = entry.Viewport
		table.insert(spinners, model)

		UIKit.Text({
			Text = `{if result.Golden then "Golden " else ""}{animal.Rarity}`,
			TextColor3 = rarity.Color,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 262),
			TextStrokeTransparency = 0,
			Parent = entry.Card,
		})
		UIKit.Text({
			Text = `{animal.Emoji} {animal.Name}`,
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 300),
			Parent = entry.Card,
		})
		if result.New then
			UIKit.Text({
				Text = "NEW!",
				TextColor3 = C.Gold,
				Rotation = -12,
				Size = UDim2.fromOffset(110, 44),
				Position = UDim2.fromOffset(0, 10),
				TextStrokeTransparency = 0,
				Parent = entry.Card,
			})
		end
	end
	local spinStart = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - spinStart
		for _, model in spinners do
			local root = model.PrimaryPart
			if root then
				model:PivotTo(CFrame.new(root.Position) * CFrame.Angles(0, math.pi + math.sin(t * 1.5) * 0.6, 0))
			end
		end
	end)
	hint.Text = "Tap to continue"
	waitOrSkip(3, true)
	spin:Disconnect()
	overlay.Visible = false
	playing = false

	local nextPayload = table.remove(queue, 1)
	if nextPayload then
		play(nextPayload)
	end
end

function HatchController.Play(payload: any)
	if playing then
		table.insert(queue, payload)
		return
	end
	task.spawn(play, payload)
end

function HatchController.IsPlaying(): boolean
	return playing
end

function HatchController.Start()
	(Remotes:WaitForChild("HatchPlay") :: RemoteEvent).OnClientEvent:Connect(function(payload)
		HatchController.Play(payload)
	end)
end

return HatchController
