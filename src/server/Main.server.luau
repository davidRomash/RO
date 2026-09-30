--!strict
-- Boots every server service: Init (set up, no yielding) then Start (connect and run).

local Services = script.Parent.Services

local ORDER = {
	"Net",
	"DataService",
	"WorldBuilder",
	"PetService",
	"TutorialService",
	"ZoneService",
	"BaseService",
	"EggService",
	"RaceService",
	"RewardService",
	"LeaderboardService",
	"AdminService",
}

local modules = {}
for _, name in ORDER do
	local module = require(Services:WaitForChild(name)) :: any
	modules[name] = module
	if module.Init then
		module.Init()
	end
end

for _, name in ORDER do
	local module = modules[name]
	if module.Start then
		task.spawn(module.Start)
	end
end

print("[Animal Rush] Server started")
