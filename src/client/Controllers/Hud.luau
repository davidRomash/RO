--!strict
-- The always-on-screen HUD: coins, race info, daily reward, menu buttons, ability button,
-- progress to the next zone, notifications, the big countdown text and race results.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Zones = require(ReplicatedStorage.Config.Zones)
local Animals = require(ReplicatedStorage.Config.Animals)
local Util = require(ReplicatedStorage.Shared.Util)
local PetMath = require(ReplicatedStorage.Shared.PetMath)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = UIKit.Colors

local Hud = {} :: any

-- Menus register an opener here, e.g. Hud.MenuOpeners.Pets = PetsMenu.Toggle
Hud.MenuOpeners = {} :: { [string]: () -> () }

local screen = UIKit.Screen("Hud", 1)

-- Coins (top left) ------------------------------------------------------------------

local topLeft = UIKit.Anchor(screen, "TopLeft", Vector2.new(0, 0), UDim2.fromOffset(12, 12), Vector2.new(260, 70))
local coinPill = UIKit.New("Frame", {
	Name = "Coins",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.PanelDark,
	Parent = topLeft,
}, { UIKit.Corner(35), UIKit.Stroke(C.Gold, 3) }) :: Frame
local coinIcon = UIKit.Text({ Text = "🪙", Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(6, 5), Parent = coinPill })
local coinLabel = UIKit.Text({
	Text = "0",
	Size = UDim2.new(1, -84, 0, 50),
	Position = UDim2.fromOffset(72, 10),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = C.Gold,
	Parent = coinPill,
})
local coinScale = UIKit.New("UIScale", { Parent = coinPill }) :: UIScale
local shownCoins = 0
local targetCoins = 0

-- Race info and notifications (top centre) --------------------------------------------

local topCenter = UIKit.Anchor(screen, "TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), Vector2.new(560, 260))
local raceLabel = UIKit.Text({
	Name = "Race",
	Text = "",
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = C.PanelDark,
	Visible = false,
	Parent = topCenter,
})
UIKit.Corner(29).Parent = raceLabel
UIKit.New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = raceLabel })

local toastList = UIKit.New("Frame", {
	Name = "Toasts",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 68),
	Size = UDim2.new(1, 0, 1, -68),
	Parent = topCenter,
}, {
	UIKit.New("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
}) :: Frame
local toastCount = 0

-- Top right: daily reward and settings -----------------------------------------------

-- On computers the player list sits in the top right corner, so leave room for it.
local topRightX = if UserInputService.TouchEnabled then -12 else -200
local topRight = UIKit.Anchor(screen, "TopRight", Vector2.new(1, 0), UDim2.new(1, topRightX, 0, 12), Vector2.new(180, 110))
local dailyButton = UIKit.Button({
	Name = "Daily",
	Text = "🎁",
	Size = UDim2.fromOffset(84, 84),
	Color = C.Orange,
	Parent = topRight,
	OnClick = function()
		local result = State.Call("ClaimDaily")
		if not result.Ok and result.Message then
			Hud.Notify(result.Message, "Info")
		end
	end,
})
local dailyTimer = UIKit.Text({ Text = "", Size = UDim2.fromOffset(84, 24), Position = UDim2.fromOffset(0, 86), Parent = topRight })
UIKit.Button({
	Name = "Settings",
	Text = "⚙️",
	Size = UDim2.fromOffset(84, 84),
	Position = UDim2.fromOffset(96, 0),
	Color = C.Grey,
	Parent = topRight,
	OnClick = function()
		local opener = Hud.MenuOpeners.Settings
		if opener then
			opener()
		end
	end,
})

-- Left side: menu buttons (appear after the first race and hatch) ----------------------

local left = UIKit.Anchor(screen, "Menu", Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0), Vector2.new(100, 330))
UIKit.New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
local MENU_BUTTONS = {
	{ Name = "Pets", Icon = "🐾", Label = "Pets", Color = C.Green },
	{ Name = "Eggs", Icon = "🥚", Label = "Eggs", Color = C.Orange },
	{ Name = "Zones", Icon = "🗺️", Label = "Zones", Color = C.Blue },
}
for i, info in MENU_BUTTONS do
	local button = UIKit.Button({
		Name = info.Name,
		Text = "",
		Size = UDim2.fromOffset(100, 100),
		Color = info.Color,
		LayoutOrder = i,
		Parent = left,
		OnClick = function()
			local opener = Hud.MenuOpeners[info.Name]
			if opener then
				opener()
			end
		end,
	})
	UIKit.Text({ Text = info.Icon, Size = UDim2.fromScale(1, 0.62), Parent = button })
	UIKit.Text({ Text = info.Label, Size = UDim2.fromScale(1, 0.34), Position = UDim2.fromScale(0, 0.66), Parent = button })
end
left.Visible = false

-- Bottom right: ability button (kept above the mobile jump button) ------------------

local abilityPosition = if UserInputService.TouchEnabled then UDim2.new(1, -24, 1, -190) else UDim2.new(1, -24, 1, -24)
local bottomRight = UIKit.Anchor(screen, "Ability", Vector2.new(1, 1), abilityPosition, Vector2.new(140, 160))
local abilityButton = UIKit.Button({
	Name = "AbilityButton",
	Text = "",
	Size = UDim2.fromOffset(140, 140),
	Color = C.Gold,
	Radius = 70,
	Parent = bottomRight,
})
local abilityIcon = UIKit.Text({ Text = "⚡", Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0, 0.05), Parent = abilityButton })
local abilityHint = UIKit.Text({ Text = "Ability", Size = UDim2.fromScale(1, 0.26), Position = UDim2.fromScale(0, 0.7), Parent = abilityButton })
local cooldownShade = UIKit.New("Frame", {
	Name = "Cooldown",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	ZIndex = 2,
	Parent = abilityButton,
}, { UIKit.Corner(70) }) :: Frame
local keyHint = UIKit.Text({
	Text = if UserInputService.KeyboardEnabled then "[F]" else "",
	Size = UDim2.fromOffset(140, 20),
	Position = UDim2.fromOffset(0, 142),
	Parent = bottomRight,
})
local abilityReadyAt = 0
local abilityCooldown = 10
local hasActiveAbility = false

-- Bottom centre: progress to the next zone gate ---------------------------------------

local bottomCenter = UIKit.Anchor(screen, "Progress", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), Vector2.new(480, 50))
local progressBack = UIKit.New("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.PanelDark,
	Parent = bottomCenter,
}, { UIKit.Corner(25), UIKit.Stroke(nil, 3) }) :: Frame
local progressFill = UIKit.New("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.Green,
	Parent = progressBack,
}, { UIKit.Corner(25) }) :: Frame
local progressLabel = UIKit.Text({
	Text = "",
	Size = UDim2.new(1, -24, 1, -10),
	Position = UDim2.fromOffset(12, 5),
	ZIndex = 2,
	Parent = progressBack,
})

-- Centre: big text and results -------------------------------------------------------

local center = UIKit.Anchor(screen, "Center", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42), Vector2.new(640, 200))
local bigText = UIKit.Text({ Text = "", Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0, Visible = false, Parent = center })
local bigScale = UIKit.New("UIScale", { Parent = bigText }) :: UIScale
local bigToken = 0

local resultsHolder = UIKit.Anchor(screen, "Results", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(460, 420))
resultsHolder.Visible = false
local resultsFrame = UIKit.New("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Panel,
	Parent = resultsHolder,
}, { UIKit.Corner(22), UIKit.Stroke(nil, 5) }) :: Frame
local resultsTitle = UIKit.Text({ Text = "", Size = UDim2.new(1, -30, 0, 60), Position = UDim2.fromOffset(15, 12), Parent = resultsFrame })
local resultsCoins = UIKit.Text({ Text = "", Size = UDim2.new(1, -30, 0, 44), Position = UDim2.fromOffset(15, 72), TextColor3 = C.Gold, Parent = resultsFrame })
local standingsList = UIKit.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -40, 0, 210),
	Position = UDim2.fromOffset(20, 124),
	Parent = resultsFrame,
}, { UIKit.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) }) :: Frame
local resultsToken = 0
UIKit.Button({
	Text = "OK!",
	Size = UDim2.fromOffset(180, 60),
	Position = UDim2.new(0.5, 0, 1, -16),
	AnchorPoint = Vector2.new(0.5, 1),
	Color = C.Green,
	Parent = resultsFrame,
	OnClick = function()
		resultsHolder.Visible = false
	end,
})

-- Coin fly layer (not scaled: positions are absolute pixels).
local flyLayer = UIKit.New("Frame", { Name = "Fly", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen }) :: Frame

-- API ----------------------------------------------------------------------------------

local TOAST_COLORS = { Info = C.PanelDark, Success = Color3.fromRGB(40, 140, 70), Error = Color3.fromRGB(170, 50, 50) }

function Hud.Notify(text: string, kind: string?)
	toastCount += 1
	local toast = UIKit.Text({
		Text = text,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = TOAST_COLORS[kind or "Info"] or C.PanelDark,
		LayoutOrder = toastCount,
		Parent = toastList,
	})
	UIKit.Corner(23).Parent = toast
	UIKit.New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = toast })
	local children = toastList:GetChildren()
	local labels = 0
	for _, child in children do
		if child:IsA("TextLabel") then
			labels += 1
		end
	end
	if labels > 3 then
		for _, child in children do
			if child:IsA("TextLabel") and child ~= toast then
				child:Destroy()
				break
			end
		end
	end
	task.delay(3, function()
		if toast.Parent then
			UIKit.Tween(toast, 0.3, { BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

-- Calls a remote and shows the server's message if it refused.
function Hud.Call(name: string, ...: any): { Ok: boolean, Message: string?, [string]: any }
	local result = State.Call(name, ...)
	if not result.Ok and result.Message then
		Hud.Notify(result.Message, "Error")
	end
	return result
end

function Hud.SetRaceText(text: string?)
	raceLabel.Visible = text ~= nil
	if text then
		raceLabel.Text = text
	end
end

function Hud.Big(text: string, color: Color3?, seconds: number?)
	bigToken += 1
	local token = bigToken
	bigText.Text = text
	bigText.TextColor3 = color or C.White
	bigText.Visible = true
	bigScale.Scale = 1.6
	UIKit.Tween(bigScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(seconds or 0.9, function()
		if bigToken == token then
			bigText.Visible = false
		end
	end)
end

local PLACE_EMOJI = { "🥇", "🥈", "🥉" }

function Hud.ShowResults(payload: { [string]: any })
	resultsToken += 1
	local token = resultsToken
	local place = payload.Place :: number
	resultsTitle.Text = if payload.Finished then `{PLACE_EMOJI[place] or "🏁"} {Util.Ordinal(place)} place!` else "⏰ Time's up!"
	resultsCoins.Text = if payload.Coins > 0 then `+{Util.FormatNumber(payload.Coins)} 🪙` else "Run past a checkpoint to earn coins!"
	for _, child in standingsList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, row in payload.Standings do
		if i > 8 then
			break
		end
		local time = if row.Time then Util.FormatTime(row.Time) else "--"
		UIKit.Text({
			Text = `{i}. {if row.IsBot then "🤖 " else ""}{row.Name}   {time}`,
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if i == place then C.Gold else C.White,
			LayoutOrder = i,
			Parent = standingsList,
		})
	end
	resultsHolder.Visible = true
	resultsFrame.Size = UDim2.fromScale(0.8, 0.8)
	resultsFrame.Position = UDim2.fromScale(0.1, 0.1)
	UIKit.Tween(resultsFrame, 0.25, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	task.delay(7, function()
		if resultsToken == token then
			resultsHolder.Visible = false
		end
	end)
end

-- Coins fly from the middle of the screen into the counter.
function Hud.CoinBurst(amount: number)
	UIKit.PlaySound("Coins")
	local viewport = flyLayer.AbsoluteSize
	local target = coinIcon.AbsolutePosition + coinIcon.AbsoluteSize / 2 - flyLayer.AbsolutePosition
	local count = math.clamp(math.floor(amount / 25), 3, 10)
	for i = 1, count do
		local start = viewport / 2 + Vector2.new(math.random(-80, 80), math.random(-60, 60))
		local coin = UIKit.Text({
			Text = "🪙",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(start.X, start.Y),
			Parent = flyLayer,
		})
		task.delay(i * 0.04, function()
			local tween = UIKit.Tween(coin, 0.55, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(28, 28) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Wait()
			coin:Destroy()
		end)
	end
	local plus = UIKit.Text({
		Text = `+{Util.FormatNumber(amount)}`,
		TextColor3 = C.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(220, 60),
		Position = UDim2.fromOffset(viewport.X / 2, viewport.Y / 2 - 90),
		TextStrokeTransparency = 0,
		Parent = flyLayer,
	})
	UIKit.Tween(plus, 1.2, { Position = UDim2.fromOffset(viewport.X / 2, viewport.Y / 2 - 170), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(1.2, function()
		plus:Destroy()
	end)
end

function Hud.StartAbilityCooldown(seconds: number)
	abilityCooldown = seconds
	abilityReadyAt = os.clock() + seconds
end

local function useAbility()
	if os.clock() < abilityReadyAt then
		return
	end
	local result = Hud.Call("UseAbility")
	if result.Ok then
		UIKit.PlaySound("Ability")
		Hud.StartAbilityCooldown(result.Cooldown or 10)
		local used = result.Used or {}
		local names = { SpeedBurst = "⚡ Speed burst!", HighJump = "🐱 High jump!", Leap = "🐸 Leap!" }
		local parts = {}
		for _, kind in used do
			table.insert(parts, names[kind] or kind)
		end
		Hud.Big(table.concat(parts, "  "), C.Gold, 0.8)
	elseif result.Cooldown then
		Hud.StartAbilityCooldown(result.Cooldown)
	end
end

abilityButton.Activated:Connect(useAbility)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX) then
		useAbility()
	end
end)

-- Updates from the server -------------------------------------------------------------

local function nextGateText(state: any): (string, number)
	local order = {}
	for id, zone in Zones do
		table.insert(order, { Id = id, Zone = zone })
	end
	table.sort(order, function(a, b)
		return a.Zone.Order < b.Zone.Order
	end)
	for _, entry in order do
		if not state.UnlockedZones[entry.Id] then
			if entry.Zone.ComingSoon then
				return `{entry.Zone.Emoji} More zones coming soon!`, 1
			end
			local cost = entry.Zone.GateCost
			return `{entry.Zone.Emoji} {entry.Zone.Name}: 🪙 {Util.FormatNumber(math.min(state.Coins, cost))} / {Util.FormatNumber(cost)}`, math.clamp(state.Coins / cost, 0, 1)
		end
	end
	return "All zones unlocked!", 1
end

local function onState(state: any)
	targetCoins = state.Coins
	local text, fraction = nextGateText(state)
	progressLabel.Text = text
	UIKit.Tween(progressFill, 0.4, { Size = UDim2.fromScale(math.max(fraction, 0.06), 1) })
	progressFill.BackgroundColor3 = if fraction >= 1 then C.Gold else C.Green
	left.Visible = state.Tutorial == "Done"

	local pets = PetMath.EquippedPets(state.Pets, state.Equipped)
	hasActiveAbility = PetMath.HasActiveAbility(pets)
	local icons = {}
	for _, pet in pets do
		local animal = Animals[pet.Animal]
		if animal and PetMath.ActiveAbilities[animal.Ability] then
			table.insert(icons, animal.Emoji)
		end
	end
	abilityIcon.Text = if #icons > 0 then table.concat(icons, "") else "⚡"
	abilityHint.Text = if hasActiveAbility then "Ability" else "No ability"
end

function Hud.Start()
	State.OnChanged(onState)
	;(Remotes:WaitForChild("Notify") :: RemoteEvent).OnClientEvent:Connect(function(text, kind)
		Hud.Notify(text, kind)
	end)
	;(Remotes:WaitForChild("CoinsAwarded") :: RemoteEvent).OnClientEvent:Connect(function(amount)
		Hud.CoinBurst(amount)
	end)

	local pulse = 0
	RunService.RenderStepped:Connect(function(dt: number)
		-- Counting coin display with a bounce when coins arrive.
		if shownCoins ~= targetCoins then
			local diff = targetCoins - shownCoins
			local step = math.max(1, math.abs(diff) * math.min(1, dt * 6))
			if math.abs(diff) <= step then
				shownCoins = targetCoins
			else
				shownCoins += math.sign(diff) * step
			end
			coinLabel.Text = Util.FormatNumber(shownCoins)
			if diff > 0 then
				coinScale.Scale = 1.12
			end
		end
		coinScale.Scale += (1 - coinScale.Scale) * math.min(1, dt * 10)

		-- Ability cooldown shade.
		local remaining = abilityReadyAt - os.clock()
		cooldownShade.Size = UDim2.fromScale(1, math.clamp(remaining / abilityCooldown, 0, 1))
		abilityButton.BackgroundColor3 = if remaining <= 0 and hasActiveAbility then C.Gold else C.Grey
		keyHint.Visible = UserInputService.KeyboardEnabled

		-- Daily reward timer; the icon pulses when ready.
		local state = State.Current
		if state then
			local secondsLeft = state.DailyReadyAt - State.ServerNow()
			if secondsLeft <= 0 then
				dailyTimer.Text = "READY!"
				pulse += dt * 4
				dailyButton.Rotation = math.sin(pulse) * 8
			else
				local hours = secondsLeft // 3600
				local minutes = (secondsLeft % 3600) // 60
				dailyTimer.Text = string.format("%d:%02d:%02d", hours, minutes, secondsLeft % 60)
				dailyButton.Rotation = 0
			end
		end
	end)
end

return Hud
