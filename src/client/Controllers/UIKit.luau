--!strict
-- Small UI toolkit: instance builder, styled buttons, windows and screen scaling.
-- Layouts are designed at 1280x720 and scaled with UIScale, so they fit phones held sideways.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Config.Sounds)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.Colors = {
	Panel = Color3.fromRGB(40, 46, 82),
	PanelDark = Color3.fromRGB(26, 30, 56),
	Card = Color3.fromRGB(60, 68, 115),
	Blue = Color3.fromRGB(70, 150, 255),
	Green = Color3.fromRGB(70, 200, 100),
	Red = Color3.fromRGB(235, 80, 80),
	Gold = Color3.fromRGB(255, 200, 50),
	Orange = Color3.fromRGB(255, 150, 50),
	Grey = Color3.fromRGB(120, 125, 140),
	White = Color3.new(1, 1, 1),
	Stroke = Color3.fromRGB(20, 22, 40),
}

local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

function UIKit.New(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className) :: any
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UIKit.Corner(radius: number?): Instance
	return UIKit.New("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function UIKit.Stroke(color: Color3?, thickness: number?): Instance
	return UIKit.New("UIStroke", {
		Color = color or UIKit.Colors.Stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.Text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextScaled = true,
		TextColor3 = UIKit.Colors.White,
		TextStrokeTransparency = 0.5,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UIKit.New("TextLabel", defaults)
end

function UIKit.Tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

function UIKit.PlaySound(name: string)
	local id = (Sounds :: any)[name]
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- A chunky, kid-friendly button that squishes when pressed.
function UIKit.Button(props: { [string]: any }): TextButton
	local onClick = props.OnClick
	local color = props.Color or UIKit.Colors.Blue
	local button = UIKit.New("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = UIKit.Font,
		Text = props.Text or "",
		TextScaled = true,
		TextColor3 = props.TextColor or UIKit.Colors.White,
		TextStrokeTransparency = 0.6,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	}, {
		UIKit.Corner(props.Radius),
		UIKit.Stroke(nil, 3),
		UIKit.New("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	}) :: TextButton
	local scale = UIKit.New("UIScale", { Parent = button }) :: UIScale
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.08, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	if onClick then
		button.Activated:Connect(function()
			UIKit.PlaySound("Click")
			onClick()
		end)
	end
	return button
end

-- Buttons can be greyed out without losing their colour setting.
function UIKit.SetEnabled(button: GuiButton, enabled: boolean, color: Color3?)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundColor3 = if enabled then (color or UIKit.Colors.Blue) else UIKit.Colors.Grey
end

-- Screen scaling -----------------------------------------------------------------

local scalers: { UIScale } = {}

local function currentScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1.3)
end

local function updateScalers()
	local scale = currentScale()
	for _, scaler in scalers do
		scaler.Scale = scale
	end
end

-- Adds a UIScale to a container anchored at a screen edge; it scales around its AnchorPoint.
function UIKit.Scale(container: GuiObject)
	local scaler = UIKit.New("UIScale", { Scale = currentScale(), Parent = container }) :: UIScale
	table.insert(scalers, scaler)
end

local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScalers)
	end
	updateScalers()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- CoreUISafeInsets keeps the HUD clear of Roblox's top bar and phone notches.
function UIKit.Screen(name: string, displayOrder: number, insets: Enum.ScreenInsets?): ScreenGui
	return UIKit.New("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder,
		ResetOnSpawn = false,
		ScreenInsets = insets or Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
end

-- Invisible container pinned to a point of the screen, with a size designed at 1280x720.
function UIKit.Anchor(parent: Instance, name: string, anchor: Vector2, position: UDim2, size: Vector2): Frame
	local frame = UIKit.New("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	UIKit.Scale(frame)
	return frame
end

-- Windows (one open at a time) ----------------------------------------------------

local menuScreen = UIKit.Screen("Menus", 10)
local openWindow: Frame? = nil

export type Window = {
	Frame: Frame,
	Content: Frame,
	Title: TextLabel,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
	OnOpen: (() -> ())?,
}

function UIKit.Window(name: string, title: string, size: Vector2): Window
	local holder = UIKit.Anchor(menuScreen, name, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), size)
	holder.Visible = false
	local frame = UIKit.New("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Colors.Panel,
		Parent = holder,
	}, { UIKit.Corner(22), UIKit.Stroke(nil, 5) }) :: Frame
	local titleLabel = UIKit.Text({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -140, 0, 52),
		Position = UDim2.fromOffset(24, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local content = UIKit.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 76),
		Size = UDim2.new(1, -40, 1, -96),
		Parent = frame,
	}) :: Frame

	local window: Window
	local function close()
		holder.Visible = false
		if openWindow == holder then
			openWindow = nil
		end
	end
	local function open()
		if openWindow and openWindow ~= holder then
			openWindow.Visible = false
		end
		openWindow = holder
		holder.Visible = true
		frame.Size = UDim2.fromScale(0.9, 0.9)
		frame.Position = UDim2.fromScale(0.05, 0.05)
		UIKit.Tween(frame, 0.18, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
		if window.OnOpen then
			window.OnOpen()
		end
	end
	UIKit.Button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(1, -16, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		Color = UIKit.Colors.Red,
		OnClick = close,
		Parent = frame,
	})

	window = {
		Frame = frame,
		Content = content,
		Title = titleLabel,
		Open = open,
		Close = close,
		IsOpen = function()
			return holder.Visible
		end,
	}
	return window
end

function UIKit.CloseWindows()
	if openWindow then
		openWindow.Visible = false
		openWindow = nil
	end
end

return UIKit
