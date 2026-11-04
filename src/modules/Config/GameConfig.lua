--!strict

--[[
	GameConfig
	Global tuning shared by server and client. Pure data, no functions.

	Fields:
		RunStates: valid run state strings sent to the client (Idle, Running)
		LobbySpawn: where players return after a run (studs, world position)
		StainInterval: delay between two stain attempts while moving (seconds)
		StainCellSize: grid cell used to decide if a spot is already stained (studs)
		MaxStainParts: most stain parts one player may have in the world at once (count)
		PointsPerStud: score earned per square stud of newly stained surface (points)
		CoinsPerPoint: coins paid per score point at the end of a rewarded run (coins)
		XpPerPoint: experience earned per score point at the end of a run (xp)
		LevelXpBase: experience needed to go from level 1 to level 2 (xp)
		LevelXpGrowth: each next level needs this many times more xp than the previous (multiplier)
		MaxLevel: highest player level (level)
		GemsPerLevelUp: gems awarded every time the player levels up (gems)
]]

return {
	RunStates = {
		Idle = "Idle",
		Running = "Running",
	},

	LobbySpawn = Vector3.new(1.7, 13.5, -3),

	StainInterval = 0.12,

	StainCellSize = 3,

	MaxStainParts = 900,

	PointsPerStud = 0.25,

	CoinsPerPoint = 0.5,

	XpPerPoint = 1,

	LevelXpBase = 100,

	LevelXpGrowth = 1.35,

	MaxLevel = 100,

	GemsPerLevelUp = 5,
}
