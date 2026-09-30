--!strict
-- Pets menu: collection index, owned animals (rarity shown by border colour), equip up to 3,
-- sell, and merge 5 copies into a Golden animal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local Animals = require(ReplicatedStorage.Config.Animals)
local Rarities = require(ReplicatedStorage.Config.Rarities)
local Zones = require(ReplicatedStorage.Config.Zones)
local Economy = require(ReplicatedStorage.Config.Economy)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Util = require(ReplicatedStorage.Shared.Util)

local C = UIKit.Colors

local PetsMenu = {}

local window = UIKit.Window("PetsMenu", "🐾 My Animals", Vector2.new(900, 560))
local content = window.Content
local selectedId: string? = nil

-- Collection index: every animal, greyed out until discovered.
local indexRow = UIKit.New("Frame", {
	BackgroundColor3 = C.PanelDark,
	Size = UDim2.new(1, -182, 0, 56),
	Parent = content,
}, {
	UIKit.Corner(14),
	UIKit.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
}) :: Frame

local grid = UIKit.New("ScrollingFrame", {
	BackgroundColor3 = C.PanelDark,
	Position = UDim2.fromOffset(0, 66),
	Size = UDim2.new(1, -250, 1, -66),
	ScrollBarThickness = 10,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	BorderSizePixel = 0,
	Parent = content,
}, {
	UIKit.Corner(14),
	UIKit.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 118),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	UIKit.New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
}) :: ScrollingFrame

-- Detail pane on the right.
local detail = UIKit.New("Frame", {
	BackgroundColor3 = C.PanelDark,
	Position = UDim2.new(1, 0, 0, 66),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.new(0, 238, 1, -66),
	Parent = content,
}, { UIKit.Corner(14) }) :: Frame
local detailEmoji = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 6), Parent = detail })
local detailName = UIKit.Text({ Text = "Tap an animal", Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 88), Parent = detail })
local detailRarity = UIKit.Text({ Text = "", Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 122), Parent = detail })
local detailInfo = UIKit.Text({
	Text = "",
	Size = UDim2.new(1, -20, 0, 70),
	Position = UDim2.fromOffset(10, 150),
	TextScaled = true,
	TextWrapped = true,
	Parent = detail,
})

local equipButton = UIKit.Button({
	Text = "Equip",
	Size = UDim2.new(1, -20, 0, 50),
	Position = UDim2.fromOffset(10, 226),
	Color = C.Green,
	Parent = detail,
	OnClick = function()
		local state = State.Current
		if not selectedId or not state then
			return
		end
		if table.find(state.Equipped, selectedId) then
			Hud.Call("UnequipPet", selectedId)
		else
			Hud.Call("EquipPet", selectedId)
		end
	end,
})
local goldenButton = UIKit.Button({
	Text = "Golden",
	Size = UDim2.new(1, -20, 0, 50),
	Position = UDim2.fromOffset(10, 284),
	Color = C.Gold,
	Parent = detail,
	OnClick = function()
		local state = State.Current
		local pet = state and selectedId and PetMath.FindPet(state.Pets, selectedId)
		if pet then
			local result = Hud.Call("MergeGolden", pet.Animal)
			if result.Ok then
				Hud.Big("⭐ GOLDEN! ⭐", C.Gold, 1.5)
				selectedId = result.Pet and result.Pet.Id or nil
			end
		end
	end,
})
local sellButton = UIKit.Button({
	Text = "Sell",
	Size = UDim2.new(1, -20, 0, 44),
	Position = UDim2.new(0, 10, 1, -10),
	AnchorPoint = Vector2.new(0, 1),
	Color = C.Red,
	Parent = detail,
	OnClick = function()
		if selectedId then
			local result = Hud.Call("SellPet", selectedId)
			if result.Ok then
				selectedId = nil
			end
		end
	end,
})

UIKit.Button({
	Text = "⭐ Equip Best",
	Size = UDim2.fromOffset(172, 56),
	Position = UDim2.new(1, 0, 0, 0),
	AnchorPoint = Vector2.new(1, 0),
	Color = C.Blue,
	Parent = content,
	OnClick = function()
		Hud.Call("EquipBest")
	end,
})

local function sortedAnimalIds(): { string }
	local ids = {}
	for id in Animals do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local za, zb = Zones[Animals[a].Zone].Order, Zones[Animals[b].Zone].Order
		if za ~= zb then
			return za < zb
		end
		return Rarities[Animals[a].Rarity].Order < Rarities[Animals[b].Rarity].Order
	end)
	return ids
end
local ANIMAL_ORDER = sortedAnimalIds()

local function refreshDetail(state: any)
	local pet = selectedId and PetMath.FindPet(state.Pets, selectedId)
	equipButton.Visible = pet ~= nil
	goldenButton.Visible = pet ~= nil
	sellButton.Visible = pet ~= nil
	if not pet then
		selectedId = nil
		detailEmoji.Text = "🐾"
		detailName.Text = "Tap an animal"
		detailRarity.Text = ""
		detailInfo.Text = "Equip up to 3. Their speed adds up in races!"
		return
	end
	local animal = Animals[pet.Animal]
	local rarity = Rarities[animal.Rarity]
	detailEmoji.Text = animal.Emoji
	detailName.Text = (if pet.Golden then "⭐ Golden " else "") .. animal.Name
	detailRarity.Text = animal.Rarity
	detailRarity.TextColor3 = rarity.Color
	detailInfo.Text = `Speed +{PetMath.PetSpeed(pet)}\n{animal.AbilityText}`

	local equipped = table.find(state.Equipped, pet.Id) ~= nil
	equipButton.Text = if equipped then "Unequip" else "Equip"
	UIKit.SetEnabled(equipButton, true, if equipped then C.Grey else C.Green)

	local copies = 0
	for _, other in state.Pets do
		if other.Animal == pet.Animal and not other.Golden then
			copies += 1
		end
	end
	goldenButton.Visible = not pet.Golden
	goldenButton.Text = `⭐ Golden {math.min(copies, Economy.GoldenMergeCount)}/{Economy.GoldenMergeCount}`
	UIKit.SetEnabled(goldenButton, copies >= Economy.GoldenMergeCount, C.Gold)
	sellButton.Text = `Sell 🪙 {Util.FormatNumber(PetMath.SellValue(pet))}`
end

local function refresh(state: any)
	local speed = math.floor(PetMath.RaceSpeed(PetMath.EquippedPets(state.Pets, state.Equipped)))
	window.Title.Text = `🐾 My Animals  {#state.Pets}/{state.InventorySize}   ⚡ Speed {speed}`

	for _, child in indexRow:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, id in ANIMAL_ORDER do
		local found = state.Discovered[id]
		UIKit.Text({
			Text = if found then Animals[id].Emoji else "❔",
			TextTransparency = if found then 0 else 0.5,
			Size = UDim2.fromOffset(46, 46),
			LayoutOrder = i,
			Parent = indexRow,
		})
	end

	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	-- Equipped first, then by speed.
	local pets = table.clone(state.Pets)
	table.sort(pets, function(a, b)
		local ea, eb = table.find(state.Equipped, a.Id) ~= nil, table.find(state.Equipped, b.Id) ~= nil
		if ea ~= eb then
			return ea
		end
		local sa, sb = PetMath.PetSpeed(a), PetMath.PetSpeed(b)
		if sa ~= sb then
			return sa > sb
		end
		return a.Animal < b.Animal
	end)
	for i, pet in pets do
		local animal = Animals[pet.Animal]
		if not animal then
			continue
		end
		local rarityColor = if pet.Golden then C.Gold else Rarities[animal.Rarity].Color
		local card = UIKit.New("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if pet.Id == selectedId then Color3.fromRGB(90, 100, 160) else C.Card,
			LayoutOrder = i,
			Parent = grid,
		}, {
			UIKit.Corner(14),
			UIKit.Stroke(rarityColor, if pet.Id == selectedId then 5 else 3),
		}) :: TextButton
		UIKit.Text({ Text = animal.Emoji, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 6), Parent = card })
		UIKit.Text({ Text = animal.Name, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 74), Parent = card })
		if table.find(state.Equipped, pet.Id) then
			UIKit.Text({ Text = "✅", Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(2, 2), Parent = card })
		end
		if pet.Golden then
			UIKit.Text({ Text = "⭐", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -32, 0, 2), Parent = card })
		end
		card.Activated:Connect(function()
			selectedId = pet.Id
			refresh(State.Current)
		end)
	end
	refreshDetail(state)
end

function PetsMenu.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		if State.Current then
			refresh(State.Current)
		end
		window.Open()
	end
end

function PetsMenu.Start()
	Hud.MenuOpeners.Pets = PetsMenu.Toggle
	State.OnChanged(function(state)
		if window.IsOpen() then
			refresh(state)
		end
	end)
end

return PetsMenu
