--!strict
-- World positions shared by the server (which builds the world) and the client (guide arrow, menus).
-- Every track runs along +X from its zone's Origin (the start line centre).

local Layout = {}

Layout.PlazaSize = 200
Layout.PlazaSpawn = Vector3.new(0, 3, 50)
Layout.GroundRadius = 280

-- Portal arches along the north edge of the Plaza, in zone order.
Layout.Portals = {
	Forest = Vector3.new(-64, 0, -80),
	Beach = Vector3.new(-32, 0, -80),
	Desert = Vector3.new(0, 0, -80),
	Ice = Vector3.new(32, 0, -80),
	Volcano = Vector3.new(64, 0, -80),
} :: { [string]: Vector3 }

Layout.DailyChest = Vector3.new(60, 0, 40)
Layout.Leaderboard = Vector3.new(85, 0, 0)

-- Egg stands: one per zone in the Plaza egg shop, plus one inside each zone.
Layout.EggStands = {
	{ Egg = "Forest", Position = Vector3.new(-75, 0, 10) },
	{ Egg = "Beach", Position = Vector3.new(-75, 0, 40) },
} :: { { Egg: string, Position: Vector3 } }

Layout.BaseCount = 8
Layout.BaseRadius = 190
Layout.BaseSize = 48

function Layout.BaseCenter(index: number): Vector3
	local angle = math.rad(22.5 + (index - 1) * 45)
	return Vector3.new(math.cos(angle) * Layout.BaseRadius, 0, math.sin(angle) * Layout.BaseRadius)
end

-- Zone origins (start line centre). Zones sit far from the Plaza; portals move players there.
Layout.ZoneOrigins = {
	Forest = Vector3.new(1200, 0, -700),
	Beach = Vector3.new(1200, 0, 700),
} :: { [string]: Vector3 }

function Layout.ZoneSpawn(zoneId: string): Vector3
	return Layout.ZoneOrigins[zoneId] + Vector3.new(-90, 3, 0)
end

function Layout.StartPad(zoneId: string): Vector3
	return Layout.ZoneOrigins[zoneId] + Vector3.new(-40, 0, 0)
end

Layout.StartPadSize = Vector3.new(28, 1, 40)

function Layout.ZoneEggStand(zoneId: string): Vector3
	return Layout.ZoneOrigins[zoneId] + Vector3.new(-100, 0, -45)
end

function Layout.ZoneReturnPortal(zoneId: string): Vector3
	return Layout.ZoneOrigins[zoneId] + Vector3.new(-150, 0, 0)
end

-- Big landmark visible from the Plaza so players see where they are heading.
Layout.VolcanoLandmark = Vector3.new(-700, 0, -900)

return Layout
