--!strict
-- Admin commands, run from the admin panel or typed in chat starting with ";" (";help" lists them).
-- Targets: "me" (default), "all", or the start of a player's name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local Teleport = require(script.Parent.Teleport)
local BaseService = require(script.Parent.BaseService)
local Admins = require(ReplicatedStorage.Config.Admins)
local Animals = require(ReplicatedStorage.Config.Animals)
local Zones = require(ReplicatedStorage.Config.Zones)
local Economy = require(ReplicatedStorage.Config.Economy)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Util = require(ReplicatedStorage.Shared.Util)

local PREFIX = ";"

local AdminService = {}

local adminCache: { [Player]: boolean } = {}

local function isAdmin(player: Player): boolean
	if adminCache[player] ~= nil then
		return adminCache[player]
	end
	local admin = RunService:IsStudio() or table.find(Admins.UserIds, player.UserId) ~= nil
	if not admin then
		if game.CreatorType == Enum.CreatorType.User then
			admin = player.UserId == game.CreatorId
		elseif game.CreatorType == Enum.CreatorType.Group then
			local ok, rank = pcall(player.GetRankInGroupAsync, player, game.CreatorId)
			admin = ok and rank >= 254
		end
	end
	adminCache[player] = admin
	return admin
end

local function findTargets(caller: Player, name: string?): { Player }
	if not name or name == "" or name == "me" then
		return { caller }
	end
	if name == "all" then
		return Players:GetPlayers()
	end
	local lower = string.lower(name)
	for _, player in Players:GetPlayers() do
		if string.sub(string.lower(player.Name), 1, #lower) == lower or string.sub(string.lower(player.DisplayName), 1, #lower) == lower then
			return { player }
		end
	end
	return {}
end

local function findKey(map: { [string]: any }, name: string?): string?
	if not name then
		return nil
	end
	local lower = string.lower(name)
	for key in map do
		if string.lower(key) == lower then
			return key
		end
	end
	return nil
end

type Command = { Usage: string, Help: string, Run: (Player, { string }) -> string }

local commands: { [string]: Command } = {}

commands.coins = {
	Usage = ";coins <amount> [player]",
	Help = "Give coins",
	Run = function(caller, args)
		local amount = tonumber(args[1])
		if not amount or amount <= 0 then
			return "Usage: ;coins 1000"
		end
		local targets = findTargets(caller, args[2])
		for _, player in targets do
			DataService.AddCoins(player, amount, "Admin")
		end
		return `Gave 🪙 {Util.FormatNumber(amount)} to {#targets} player(s)`
	end,
}

commands.setcoins = {
	Usage = ";setcoins <amount> [player]",
	Help = "Set coins exactly",
	Run = function(caller, args)
		local amount = tonumber(args[1])
		if not amount or amount < 0 then
			return "Usage: ;setcoins 0"
		end
		local targets = findTargets(caller, args[2])
		for _, player in targets do
			local data = DataService.Get(player)
			if data then
				data.Coins = math.floor(amount)
				DataService.Changed(player)
			end
		end
		return `Set coins to {Util.FormatNumber(amount)} for {#targets} player(s)`
	end,
}

commands.pet = {
	Usage = ";pet <animal> [golden] [player]",
	Help = "Give an animal",
	Run = function(caller, args)
		local animalId = findKey(Animals, args[1])
		if not animalId then
			local names = {}
			for id in Animals do
				table.insert(names, id)
			end
			table.sort(names)
			return "Animals: " .. table.concat(names, ", ")
		end
		local golden = args[2] == "golden"
		local targets = findTargets(caller, if golden then args[3] else args[2])
		for _, player in targets do
			PetService.Grant(player, animalId, golden)
		end
		return `Gave {if golden then "Golden " else ""}{animalId} to {#targets} player(s)`
	end,
}

commands.unlock = {
	Usage = ";unlock [zone|all] [player]",
	Help = "Unlock zones for free",
	Run = function(caller, args)
		local zoneId = findKey(Zones, args[1])
		local targets = findTargets(caller, args[2])
		for _, player in targets do
			local data = DataService.Get(player)
			if data then
				for id, zone in Zones do
					if (zoneId == nil and not zone.ComingSoon) or id == zoneId then
						data.UnlockedZones[id] = true
					end
				end
				DataService.Changed(player)
			end
		end
		return `Unlocked {zoneId or "all zones"} for {#targets} player(s)`
	end,
}

commands.tp = {
	Usage = ";tp <zone|plaza|base> [player]",
	Help = "Teleport",
	Run = function(caller, args)
		local where = string.lower(args[1] or "")
		local targets = findTargets(caller, args[2])
		for _, player in targets do
			if where == "plaza" then
				task.spawn(Teleport.To, player, Layout.PlazaSpawn, "Plaza")
			elseif where == "base" then
				local spawn = BaseService.SpawnCFrame(player)
				if spawn then
					task.spawn(Teleport.To, player, spawn.Position, "Plaza", spawn.LookVector)
				end
			else
				local zoneId = findKey(Layout.ZoneOrigins, args[1])
				if not zoneId then
					return "Usage: ;tp forest / beach / plaza / base"
				end
				task.spawn(Teleport.To, player, Layout.ZoneSpawn(zoneId), zoneId, Vector3.xAxis)
			end
		end
		return `Teleported {#targets} player(s)`
	end,
}

commands.speed = {
	Usage = ";speed <number> [player]",
	Help = "Set walk speed until respawn (races override it)",
	Run = function(caller, args)
		local speed = tonumber(args[1])
		if not speed then
			return "Usage: ;speed 50"
		end
		local targets = findTargets(caller, args[2])
		for _, player in targets do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = math.clamp(speed, 0, 500)
			end
		end
		return `Speed set to {speed}`
	end,
}

commands.base = {
	Usage = ";base <level> [player]",
	Help = "Set base level",
	Run = function(caller, args)
		local level = tonumber(args[1])
		if not level or not Economy.BaseLevels[level] then
			return `Usage: ;base 1-{#Economy.BaseLevels}`
		end
		local targets = findTargets(caller, args[2])
		for _, player in targets do
			local data = DataService.Get(player)
			if data then
				data.BaseLevel = level
				DataService.Changed(player)
			end
		end
		return `Base level set to {level}`
	end,
}

commands.skiptutorial = {
	Usage = ";skiptutorial [player]",
	Help = "Finish the first-minute tutorial",
	Run = function(caller, args)
		local targets = findTargets(caller, args[1])
		for _, player in targets do
			local data = DataService.Get(player)
			if data then
				data.Tutorial = "Done"
				DataService.Changed(player)
			end
		end
		return "Tutorial skipped"
	end,
}

commands.reset = {
	Usage = ";reset [player]",
	Help = "Wipe data to a brand new save (player is kicked to rejoin)",
	Run = function(caller, args)
		local targets = findTargets(caller, args[1])
		for _, player in targets do
			if DataService.Reset(player) then
				task.delay(0.5, function()
					player:Kick("Your data was reset by an admin. Rejoin to start fresh!")
				end)
			end
		end
		return `Reset {#targets} player(s)`
	end,
}

commands.help = {
	Usage = ";help",
	Help = "List commands",
	Run = function(caller)
		local names = {}
		for name in commands do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			Net.Notify(caller, `{commands[name].Usage}: {commands[name].Help}`, "Info")
			task.wait(0.4)
		end
		return "That's all the commands!"
	end,
}

-- Runs one command line like "coins 1000 me". Returns (ok, message).
local function runCommand(player: Player, line: string): (boolean, string)
	if not isAdmin(player) then
		return false, "Admins only"
	end
	local args = string.split(line, " ")
	for i = #args, 1, -1 do
		if args[i] == "" then
			table.remove(args, i)
		end
	end
	local name = string.lower(table.remove(args, 1) or "")
	local command = commands[name]
	if not command then
		return false, `Unknown command ;{name}. Try ;help`
	end
	local ok, result = pcall(command.Run, player, args)
	return ok, if ok then result else `Error: {result}`
end

function AdminService.Init()
	-- Used by the admin panel and by chat (the client forwards ";" messages here).
	Net.OnInvoke("AdminCommand", 5, function(player, line)
		if typeof(line) ~= "string" or #line > 200 then
			return { Ok = false }
		end
		if string.sub(line, 1, #PREFIX) == PREFIX then
			line = string.sub(line, #PREFIX + 1)
		end
		local ok, message = runCommand(player, line)
		return { Ok = ok, Message = message }
	end)
end

function AdminService.Start()
	local function onPlayer(player: Player)
		task.spawn(function()
			player:SetAttribute("IsAdmin", isAdmin(player)) -- shows the admin panel button
		end)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		adminCache[player] = nil
	end)
end

return AdminService
