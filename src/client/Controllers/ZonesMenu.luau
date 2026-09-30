--!strict
-- Zones menu: teleport to unlocked zones, the Plaza or your base; unlock the next zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local Zones = require(ReplicatedStorage.Config.Zones)
local Util = require(ReplicatedStorage.Shared.Util)

local C = UIKit.Colors

local ZonesMenu = {}

local window = UIKit.Window("ZonesMenu", "🗺️ Zones", Vector2.new(560, 560))
local list = UIKit.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ScrollBarThickness = 8,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	BorderSizePixel = 0,
	Parent = window.Content,
}, {
	UIKit.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: ScrollingFrame

local function go(target: string)
	if Players.LocalPlayer:GetAttribute("Racing") then
		Hud.Notify("Finish your race first!", "Error")
		return
	end
	local result = Hud.Call("TeleportZone", target)
	if result.Ok then
		window.Close()
	end
end

local function row(order: number, icon: string, name: string, color: Color3): Frame
	local frame = UIKit.New("Frame", {
		BackgroundColor3 = C.PanelDark,
		Size = UDim2.new(1, -10, 0, 64),
		LayoutOrder = order,
		Parent = list,
	}, { UIKit.Corner(14), UIKit.Stroke(color, 3) }) :: Frame
	UIKit.Text({ Text = `{icon} {name}`, Size = UDim2.new(1, -220, 0, 44), Position = UDim2.fromOffset(14, 10), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	return frame
end

local function rowButton(frame: Frame, text: string, color: Color3, enabled: boolean, onClick: () -> ())
	local button = UIKit.Button({
		Text = text,
		Size = UDim2.fromOffset(190, 50),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = color,
		Parent = frame,
		OnClick = function()
			if enabled then
				onClick()
			end
		end,
	})
	UIKit.SetEnabled(button, enabled, color)
end

local function refresh(state: any)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rowButton(row(0, "🏠", "Plaza", C.Gold), "Go", C.Blue, true, function()
		go("Plaza")
	end)
	rowButton(row(1, "🏡", "My Base", C.Gold), "Go", C.Blue, true, function()
		go("Base")
	end)

	local ordered = {}
	for id, zone in Zones do
		table.insert(ordered, { Id = id, Zone = zone })
	end
	table.sort(ordered, function(a, b)
		return a.Zone.Order < b.Zone.Order
	end)
	local previousUnlocked = true
	for _, entry in ordered do
		local zone = entry.Zone
		local frame = row(10 + zone.Order, zone.Emoji, zone.Name, zone.GroundColor)
		if state.UnlockedZones[entry.Id] then
			rowButton(frame, "Go", C.Green, true, function()
				go(entry.Id)
			end)
		elseif zone.ComingSoon then
			rowButton(frame, "🔒 Soon", C.Grey, false, function() end)
		elseif previousUnlocked then
			rowButton(frame, `Unlock 🪙 {Util.FormatNumber(zone.GateCost)}`, C.Orange, state.Coins >= zone.GateCost, function()
				local result = Hud.Call("UnlockZone", entry.Id)
				if result.Ok then
					go(entry.Id)
				end
			end)
		else
			rowButton(frame, `🔒 🪙 {Util.FormatNumber(zone.GateCost)}`, C.Grey, false, function() end)
		end
		previousUnlocked = state.UnlockedZones[entry.Id] == true
	end
end

function ZonesMenu.Start()
	Hud.MenuOpeners.Zones = function()
		if window.IsOpen() then
			window.Close()
		elseif State.Current then
			refresh(State.Current)
			window.Open()
		end
	end
	State.OnChanged(function(state)
		if window.IsOpen() then
			refresh(state)
		end
	end)
end

return ZonesMenu
