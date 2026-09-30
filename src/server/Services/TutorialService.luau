--!strict
-- The first 60 seconds: free Rabbit -> go to the Forest -> win a race -> hatch an egg.
-- No text tutorial; the client shows an arrow based on the current step.

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local TutorialService = {}

local function setStep(player: Player, step: string)
	local data = DataService.Get(player)
	if data then
		data.Tutorial = step
		DataService.Changed(player)
	end
end

function TutorialService.Step(player: Player): string?
	local data = DataService.Get(player)
	return if data then data.Tutorial else nil
end

-- True while the player has not finished their first race: bots are tuned so they finish 1st or 2nd.
function TutorialService.IsFirstRace(player: Player): boolean
	local step = TutorialService.Step(player)
	return step == "Start" or step == "GoForest" or step == "Race"
end

function TutorialService.OnEnterZone(player: Player, zoneId: string)
	if zoneId == "Forest" and TutorialService.Step(player) == "GoForest" then
		setStep(player, "Race")
	end
end

function TutorialService.OnRaceFinished(player: Player)
	if TutorialService.IsFirstRace(player) then
		setStep(player, "GoEgg")
	end
end

function TutorialService.OnHatch(player: Player)
	if TutorialService.Step(player) ~= "Done" then
		setStep(player, "Done")
	end
end

function TutorialService.Init()
	DataService.OnLoaded(function(player, data)
		if data.Tutorial ~= "Start" then
			return
		end
		-- A free Rabbit hatches right away, with the full animation.
		local pet = PetService.Grant(player, "Rabbit")
		setStep(player, "GoForest")
		if pet then
			task.wait(1.5) -- let the client finish loading
			Net.Fire("HatchPlay", player, {
				Egg = "Forest",
				Free = true,
				Results = { { Id = pet.Id, Animal = pet.Animal, Golden = false, New = true } },
			})
		end
	end)
end

return TutorialService
