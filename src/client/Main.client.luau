--!strict
-- Boots every client controller. The client only shows things and sends requests;
-- the server decides everything that matters.

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"State",
	"Hud",
	"HatchController",
	"PetsMenu",
	"EggMenu",
	"ZonesMenu",
	"SettingsMenu",
	"RaceController",
	"GuideController",
	"PetFollowController",
	"WorldController",
	"AdminPanel",
}

local modules = {}
for _, name in ORDER do
	modules[name] = require(Controllers:WaitForChild(name)) :: any
end
for _, name in ORDER do
	local module = modules[name]
	if module.Start then
		task.spawn(module.Start)
	end
end
