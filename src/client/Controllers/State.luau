--!strict
-- The latest copy of this player's data sent by the server, plus a safe way to call remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = {}

State.Current = nil :: any
local listeners: { (any) -> () } = {}
local timeOffset = 0

-- Calls fn now (if data has arrived) and every time the data changes.
function State.OnChanged(fn: (any) -> ())
	table.insert(listeners, fn)
	if State.Current then
		task.spawn(fn, State.Current)
	end
end

function State.ServerNow(): number
	return os.time() + timeOffset
end

function State.Call(name: string, ...: any): { Ok: boolean, Message: string?, [string]: any }
	local remote = Remotes:FindFirstChild(name) :: RemoteFunction?
	if not remote then
		return { Ok = false, Message = "Missing remote " .. name }
	end
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or typeof(result) ~= "table" then
		return { Ok = false, Message = "Connection problem, try again" }
	end
	return result
end

function State.Start()
	local remote = Remotes:WaitForChild("StateChanged") :: RemoteEvent
	remote.OnClientEvent:Connect(function(snapshot)
		State.Current = snapshot
		timeOffset = snapshot.ServerTime - os.time()
		for _, fn in listeners do
			task.spawn(fn, snapshot)
		end
	end)
end

return State
