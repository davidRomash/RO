--!strict
-- Egg menu: odds, price and Hatch x1 / x3. Opens at an egg stand (or from the Eggs button).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local HatchController = require(script.Parent.HatchController)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)
local Zones = require(ReplicatedStorage.Config.Zones)
local Economy = require(ReplicatedStorage.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Util = require(ReplicatedStorage.Shared.Util)

local C = UIKit.Colors
local STAND_RANGE = 20

local EggMenu = {}

local window = UIKit.Window("EggMenu", "🥚 Egg", Vector2.new(600, 520))
local content = window.Content
local currentEgg = "Forest"

local oddsList = UIKit.New("Frame", {
	BackgroundColor3 = C.PanelDark,
	Size = UDim2.new(1, 0, 0, 250),
	Parent = content,
}, {
	UIKit.Corner(16),
	UIKit.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	UIKit.New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
}) :: Frame
local pityLabel = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 258), TextColor3 = C.Gold, Parent = content })
local hintLabel = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 290), TextTransparency = 0.15, Parent = content })

local busy = false
local hatch1: TextButton
local hatch3: TextButton

local function standPositions(eggId: string): { Vector3 }
	local positions = {}
	for _, stand in Layout.EggStands do
		if stand.Egg == eggId then
			table.insert(positions, stand.Position)
		end
	end
	local egg = Eggs[eggId]
	if egg and Layout.ZoneOrigins[egg.Zone] then
		table.insert(positions, Layout.ZoneEggStand(egg.Zone))
	end
	return positions
end

local function distanceToStand(eggId: string): number
	local character = (Players.LocalPlayer :: Player).Character
	local root = character and character.PrimaryPart
	if not root then
		return math.huge
	end
	local best = math.huge
	for _, position in standPositions(eggId) do
		best = math.min(best, ((root.Position - position) * Vector3.new(1, 0, 1)).Magnitude)
	end
	return best
end

local function hatch(count: number)
	if busy or HatchController.IsPlaying() then
		return
	end
	busy = true
	local result = Hud.Call("HatchEgg", currentEgg, count)
	busy = false
	if result.Ok then
		window.Close()
		HatchController.Play(result)
	end
end

hatch1 = UIKit.Button({
	Text = "Hatch x1",
	Size = UDim2.new(0.5, -8, 0, 70),
	Position = UDim2.new(0, 0, 1, 0),
	AnchorPoint = Vector2.new(0, 1),
	Color = C.Green,
	Parent = content,
	OnClick = function()
		hatch(1)
	end,
})
hatch3 = UIKit.Button({
	Text = "Hatch x3",
	Size = UDim2.new(0.5, -8, 0, 70),
	Position = UDim2.new(1, 0, 1, 0),
	AnchorPoint = Vector2.new(1, 1),
	Color = C.Orange,
	Parent = content,
	OnClick = function()
		hatch(3)
	end,
})

local function refresh()
	local egg = Eggs[currentEgg]
	local state = State.Current
	if not egg or not state then
		return
	end
	window.Title.Text = `🥚 {egg.Name}`
	for _, child in oddsList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, entry in egg.Odds do
		local animal = Animals[entry.Animal]
		local rarity = Rarities[animal.Rarity]
		local owned = state.Discovered[entry.Animal]
		UIKit.Text({
			Text = `{animal.Emoji} {animal.Name}  ·  {animal.Rarity}  ·  {entry.Chance}%{if owned then "  ✅" else ""}`,
			TextColor3 = rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 42),
			LayoutOrder = i,
			Parent = oddsList,
		})
	end
	local left = math.max(1, Economy.PityHatches - state.PityCounter)
	pityLabel.Text = `Rare or better guaranteed within {left} hatch{if left == 1 then "" else "es"}`

	local unlocked = state.UnlockedZones[egg.Zone]
	local near = distanceToStand(currentEgg) <= STAND_RANGE
	if not unlocked then
		hintLabel.Text = `🔒 Unlock {Zones[egg.Zone].Name} first`
	elseif not near then
		hintLabel.Text = "Walk to the egg stand to hatch"
	else
		hintLabel.Text = ""
	end
	hatch1.Text = `Hatch x1  🪙 {Util.FormatNumber(egg.Price)}`
	hatch3.Text = `Hatch x3  🪙 {Util.FormatNumber(egg.Price * 3)}`
	local canHatch = unlocked and near
	UIKit.SetEnabled(hatch1, canHatch and state.Coins >= egg.Price, C.Green)
	UIKit.SetEnabled(hatch3, canHatch and state.Coins >= egg.Price * 3, C.Orange)
end

function EggMenu.Open(eggId: string?)
	if eggId and Eggs[eggId] then
		currentEgg = eggId
	else
		-- Pick the closest egg stand, or the best unlocked egg.
		local state = State.Current
		local best, bestDistance = currentEgg, math.huge
		for id, egg in Eggs do
			if state and state.UnlockedZones[egg.Zone] then
				local distance = distanceToStand(id)
				if distance < bestDistance then
					best, bestDistance = id, distance
				end
			end
		end
		currentEgg = best
	end
	refresh()
	window.Open()
end

function EggMenu.Start()
	Hud.MenuOpeners.Eggs = function()
		if window.IsOpen() then
			window.Close()
		else
			EggMenu.Open()
		end
	end
	State.OnChanged(function()
		if window.IsOpen() then
			refresh()
		end
	end)
	-- Keep the "walk closer" hint fresh while the menu is open.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if window.IsOpen() then
				refresh()
			end
		end
	end)
end

return EggMenu
