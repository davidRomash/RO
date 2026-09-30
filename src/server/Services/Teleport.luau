--!strict
-- Moves a player's character inside this place and records which area they are in.
-- (This is a position move, not TeleportService.)

local Teleport = {}

function Teleport.To(player: Player, position: Vector3, area: string, facing: Vector3?): boolean
	local character = player.Character
	if not character or not character.PrimaryPart then
		return false
	end
	-- Load the destination first so the player does not fall through unstreamed ground.
	pcall(function()
		player:RequestStreamAroundAsync(position, 2)
	end)
	if player.Character ~= character or not character.PrimaryPart then
		return false
	end
	local look = facing or Vector3.new(0, 0, -1)
	character:PivotTo(CFrame.lookAt(position, position + look))
	player:SetAttribute("Zone", area)
	return true
end

return Teleport
