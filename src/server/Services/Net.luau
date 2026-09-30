--!strict
-- Remote helpers: every request is rate-limited per player and wrapped in pcall.
-- Remotes only carry requests ("hatch egg X"); the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

export type Result = { Ok: boolean, Message: string?, [string]: any }

local Net = {}

-- Token buckets: [player][remoteName] = { Tokens, Last }
local buckets: { [Player]: { [string]: { Tokens: number, Last: number } } } = {}

function Net.Allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { Tokens = burst, Last = now }
		playerBuckets[key] = bucket
	end
	bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.Last) * perSecond)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function Net.OnInvoke(name: string, perSecond: number, handler: (Player, ...any) -> Result)
	local remote = Remotes:WaitForChild(name) :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, ...: any): Result
		if not Net.Allow(player, name, perSecond, math.max(2, perSecond * 2)) then
			return { Ok = false, Message = "Slow down!" }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[Net] {name} failed for {player.Name}: {result}`)
			return { Ok = false, Message = "Something went wrong" }
		end
		return result
	end
end

function Net.Fire(name: string, player: Player, ...: any)
	local remote = Remotes:FindFirstChild(name) :: RemoteEvent?
	if remote and player.Parent == Players then
		remote:FireClient(player, ...)
	end
end

function Net.Notify(player: Player, text: string, kind: string?)
	Net.Fire("Notify", player, text, kind or "Info")
end

function Net.Init()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Net
