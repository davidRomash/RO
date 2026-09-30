--!strict
-- Shows race info from the server: lobby countdown, 3-2-1-GO, live place, checkpoints and results.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local Hud = require(script.Parent.Hud)
local Util = require(ReplicatedStorage.Shared.Util)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = UIKit.Colors
local player = Players.LocalPlayer :: Player

local RaceController = {}

local racing = false
local lastInfo = 0

local PLACE_EMOJI = { "🥇", "🥈", "🥉" }

local handlers: { [string]: (any) -> () } = {
	Lobby = function(payload)
		if racing then
			return
		end
		lastInfo = os.clock()
		if payload.Running then
			Hud.SetRaceText("🏁 Race in progress... next one soon!")
		elseif payload.Seconds then
			Hud.SetRaceText(`🏁 Race starts in {payload.Seconds}s  ({payload.OnPad} ready)`)
		else
			Hud.SetRaceText("🏁 Stand on the green pad to race!")
		end
	end,
	Countdown = function(payload)
		racing = true
		lastInfo = os.clock()
		Hud.SetRaceText("🏁 Get ready!")
		Hud.Big(tostring(payload.Seconds), C.White, 0.9)
		UIKit.PlaySound("Countdown")
	end,
	Go = function()
		racing = true
		lastInfo = os.clock()
		Hud.Big("GO!", C.Green, 1)
		UIKit.PlaySound("Go")
	end,
	Standings = function(payload)
		lastInfo = os.clock()
		local place = payload.Place :: number
		Hud.SetRaceText(`⏱ {Util.FormatTime(payload.Elapsed)}    {PLACE_EMOJI[place] or "🏅"} {Util.Ordinal(place)} of {payload.Total}`)
	end,
	Checkpoint = function(payload)
		Hud.Notify(`✅ Checkpoint {payload.Index}/{payload.Total}`, "Success")
	end,
	Bonk = function()
		Hud.Big("Bonk! 🪵 Jump over logs!", C.Orange, 1.1)
	end,
	Shield = function()
		Hud.Big("🐢 Shield saved you!", C.Green, 1.1)
	end,
	Finished = function(payload)
		local place = payload.Place :: number
		Hud.Big(`🏁 {Util.Ordinal(place)}!`, if place == 1 then C.Gold else C.White, 1.5)
		Hud.SetRaceText(`🏁 Finished in {Util.FormatTime(payload.Time)}! Waiting for others...`)
	end,
	Results = function(payload)
		racing = false
		lastInfo = os.clock()
		Hud.SetRaceText(nil)
		Hud.ShowResults(payload)
	end,
}

function RaceController.Start()
	(Remotes:WaitForChild("RaceEvent") :: RemoteEvent).OnClientEvent:Connect(function(kind, payload)
		local handler = handlers[kind]
		if handler then
			handler(payload)
		end
	end)
	-- Hide the race banner once we have left the zone (no lobby updates arrive).
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not racing and os.clock() - lastInfo > 2.5 then
				Hud.SetRaceText(nil)
			end
			if racing and not player:GetAttribute("Racing") and os.clock() - lastInfo > 5 then
				racing = false
			end
		end
	end)
end

return RaceController
