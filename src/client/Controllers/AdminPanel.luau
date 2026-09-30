--!strict
-- Admin panel: buttons for the admin commands, only shown to admins (the server sets "IsAdmin").
-- Chat messages starting with ";" are also sent to the server as commands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local UIKit = require(script.Parent.UIKit)
local Hud = require(script.Parent.Hud)
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)

local C = UIKit.Colors
local player = Players.LocalPlayer :: Player

local AdminPanel = {}

local window = UIKit.Window("AdminPanel", "🛠️ Admin", Vector2.new(820, 580))
local content = window.Content
local golden = false

local function run(line: string)
	local result = Hud.Call("AdminCommand", line)
	if result.Ok and result.Message then
		Hud.Notify(result.Message, "Success")
	end
end

-- Target box: who the buttons affect.
UIKit.Text({ Text = "Player:", Size = UDim2.fromOffset(110, 44), TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
local targetBox = UIKit.New("TextBox", {
	Text = "me",
	PlaceholderText = "me / all / name",
	ClearTextOnFocus = false,
	Font = UIKit.Font,
	TextScaled = true,
	TextColor3 = C.White,
	BackgroundColor3 = C.PanelDark,
	Position = UDim2.fromOffset(110, 0),
	Size = UDim2.fromOffset(260, 44),
	Parent = content,
}, { UIKit.Corner(10), UIKit.Stroke(nil, 2) }) :: TextBox

local function target(): string
	local text = targetBox.Text:gsub("%s", "")
	return if text == "" then "me" else text
end

local scroller = UIKit.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 1, -56),
	ScrollBarThickness = 8,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	BorderSizePixel = 0,
	Parent = content,
}, {
	UIKit.New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: ScrollingFrame

local order = 0
local function section(title: string): Frame
	order += 1
	UIKit.Text({ Text = title, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Gold, LayoutOrder = order, Parent = scroller })
	order += 1
	return UIKit.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = scroller,
	}, {
		UIKit.New("UIGridLayout", { CellSize = UDim2.fromOffset(180, 50), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame
end

local function button(parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	return UIKit.Button({ Text = text, Color = color, Parent = parent, OnClick = onClick })
end

local coins = section("🪙 Coins")
for _, amount in { 1000, 10000, 100000, 1000000 } do
	button(coins, `+{amount >= 1000000 and "1M" or amount >= 1000 and `{amount // 1000}K` or tostring(amount)}`, C.Green, function()
		run(`coins {amount} {target()}`)
	end)
end
button(coins, "Set to 0", C.Red, function()
	run(`setcoins 0 {target()}`)
end)

local progress = section("🗺️ Progress")
button(progress, "Unlock all zones", C.Blue, function()
	run(`unlock all {target()}`)
end)
button(progress, "Skip tutorial", C.Blue, function()
	run(`skiptutorial {target()}`)
end)
for level = 1, 3 do
	button(progress, `Base level {level}`, C.Blue, function()
		run(`base {level} {target()}`)
	end)
end

local move = section("🚀 Teleport & speed")
for _, place in { "Plaza", "Base", "Forest", "Beach" } do
	button(move, `Go to {place}`, C.Orange, function()
		run(`tp {string.lower(place)} {target()}`)
	end)
end
button(move, "Speed 60", C.Orange, function()
	run(`speed 60 {target()}`)
end)
button(move, "Normal speed", C.Grey, function()
	run(`speed 16 {target()}`)
end)

local pets = section("🐾 Give animal")
local goldenButton = button(pets, "Golden: OFF", C.Grey, function() end)
goldenButton.Activated:Connect(function()
	golden = not golden
	goldenButton.Text = if golden then "Golden: ON" else "Golden: OFF"
	goldenButton.BackgroundColor3 = if golden then C.Gold else C.Grey
end)
local ids = {}
for id in Animals do
	table.insert(ids, id)
end
table.sort(ids, function(a, b)
	local ra, rb = Rarities[Animals[a].Rarity].Order, Rarities[Animals[b].Rarity].Order
	if ra ~= rb then
		return ra < rb
	end
	return a < b
end)
for _, id in ids do
	local animal = Animals[id]
	local b = button(pets, `{animal.Emoji} {animal.Name}`, C.Card, function()
		run(`pet {id} {if golden then "golden " else ""}{target()}`)
	end)
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Rarities[animal.Rarity].Color
	end
end

local danger = section("⚠️ Danger")
local armed = false
local resetButton: TextButton
resetButton = button(danger, "Reset data", C.Red, function()
	if not armed then
		armed = true
		resetButton.Text = "Tap again!"
		task.delay(3, function()
			armed = false
			resetButton.Text = "Reset data"
		end)
		return
	end
	armed = false
	run(`reset {target()}`)
end)

-- Button to open the panel (admins only).
local screen = UIKit.Screen("AdminButton", 2)
local anchor = UIKit.Anchor(screen, "Admin", Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0), Vector2.new(84, 84))
anchor.Visible = false
UIKit.Button({
	Text = "🛠️",
	Size = UDim2.fromScale(1, 1),
	Color = C.Red,
	Parent = anchor,
	OnClick = function()
		if window.IsOpen() then
			window.Close()
		else
			window.Open()
		end
	end,
})

function AdminPanel.Start()
	local function update()
		anchor.Visible = player:GetAttribute("IsAdmin") == true
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(update)
	update()

	-- Chat: send ";command" messages to the server.
	TextChatService.SendingMessage:Connect(function(message)
		local text = message.Text
		if player:GetAttribute("IsAdmin") and string.sub(text, 1, 1) == ";" then
			run(text)
		end
	end)
end

return AdminPanel
