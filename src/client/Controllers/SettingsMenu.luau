--!strict
-- Settings: simple on/off switches saved with the player's data.

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local C = UIKit.Colors

local SettingsMenu = {}

local OPTIONS = {
	{ Key = "FastHatch", Label = "⚡ Fast hatch" },
	{ Key = "ShowOtherPets", Label = "🐾 Show other players' animals" },
}

local window = UIKit.Window("SettingsMenu", "⚙️ Settings", Vector2.new(560, 300))
UIKit.New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = window.Content })

local toggles: { [string]: TextButton } = {}
for i, option in OPTIONS do
	local frame = UIKit.New("Frame", {
		BackgroundColor3 = C.PanelDark,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = i,
		Parent = window.Content,
	}, { UIKit.Corner(14) }) :: Frame
	UIKit.Text({ Text = option.Label, Size = UDim2.new(1, -150, 0, 40), Position = UDim2.fromOffset(14, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	toggles[option.Key] = UIKit.Button({
		Text = "",
		Size = UDim2.fromOffset(120, 48),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = frame,
		OnClick = function()
			local state = State.Current
			if state then
				Hud.Call("UpdateSetting", option.Key, not state.Settings[option.Key])
			end
		end,
	})
end

local function refresh(state: any)
	for key, button in toggles do
		local on = state.Settings[key] == true
		button.Text = if on then "ON" else "OFF"
		button.BackgroundColor3 = if on then C.Green else C.Grey
	end
end

function SettingsMenu.Start()
	Hud.MenuOpeners.Settings = function()
		if window.IsOpen() then
			window.Close()
		else
			if State.Current then
				refresh(State.Current)
			end
			window.Open()
		end
	end
	State.OnChanged(refresh)
end

return SettingsMenu
