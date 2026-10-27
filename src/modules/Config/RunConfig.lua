--!strict

--[[
	RunConfig
	Gameplay run timing, NPC patrols and stain visuals. Pure data, no functions.

	Fields:
		RunStateSyncInterval: time between network sync packets to client (seconds)
		PortalTouchDebounce: minimum delay between portal touch triggers per player (seconds)
		RunLoopStepInterval: update tick interval for active run loops (seconds)
		NpcTurnaroundPause: pause duration when NPC reaches patrol boundary (seconds)
		InstanceWaitTimeout: maximum time to wait for workspace child instances (seconds)
		StainFolderPrefix: name prefix for grouping player stains in Workspace (string)
		StainRayUpOffset: starting offset along character up axis for raycasts (studs)
		StainRayLength: maximum raycast distance downward to detect surfaces (studs)
		StainSurfaceOffset: offset along surface normal to prevent z-fighting (studs)
		StainColor: visual color applied to stain parts (RGB color)
		StainMaterial: material of stain parts (Enum.Material)
		StainThickness: extrusion height of stain parts perpendicular to surface (studs)
		StainTransparency: visual transparency level of stain parts (0 to 1)
		PracticeTimeLeft: time-left value sent to the client for untimed runs (seconds, -1 = no timer)
		NpcCatchRadius: distance at which a patrolling NPC catches the poop (studs)
		NpcCatchTimePenalty: lifespan removed when an NPC catches the poop (seconds)
		NpcCatchCooldown: time after a catch before any NPC can catch again (seconds)
		NpcPatrols: per map id, the NPCs that walk back and forth between two points
			name: name of the NPC Model inside the map's NPCs folder (string)
			startPos: one end of the patrol line (studs, world position)
			endPos: the other end of the patrol line (studs, world position)
			speed: walking speed of the NPC (studs/second)
]]

local RunConfig = {}

RunConfig.RunStateSyncInterval = 0.25
RunConfig.PortalTouchDebounce = 1.0
RunConfig.RunLoopStepInterval = 0.05
RunConfig.NpcTurnaroundPause = 0.5
RunConfig.InstanceWaitTimeout = 5

RunConfig.StainFolderPrefix = "Stains_"
RunConfig.StainRayUpOffset = 2
RunConfig.StainRayLength = 10
RunConfig.StainSurfaceOffset = 0.05
RunConfig.StainColor = Color3.fromRGB(112, 66, 20)
RunConfig.StainMaterial = Enum.Material.SmoothPlastic
RunConfig.StainThickness = 0.08
RunConfig.StainTransparency = 0.0
RunConfig.PracticeTimeLeft = -1
RunConfig.NpcCatchRadius = 4
RunConfig.NpcCatchTimePenalty = 5
RunConfig.NpcCatchCooldown = 2

RunConfig.NpcPatrols = {
	["Zone1"] = {
		{
			name = "NPC_Chef1",
			startPos = Vector3.new(475, 3.5, -30),
			endPos = Vector3.new(475, 3.5, 30),
			speed = 8,
		},
		{
			name = "NPC_Chef2",
			startPos = Vector3.new(525, 3.5, -30),
			endPos = Vector3.new(525, 3.5, 30),
			speed = 10,
		},
		{
			name = "NPC_Chef3",
			startPos = Vector3.new(470, 3.5, 30),
			endPos = Vector3.new(530, 3.5, 30),
			speed = 9,
		},
		{
			name = "NPC_Chef4",
			startPos = Vector3.new(440, 3.5, 40),
			endPos = Vector3.new(490, 3.5, 40),
			speed = 7,
		},
	},
	["Zone2"] = {
		{
			name = "NPC_Mom1",
			startPos = Vector3.new(930, 3.5, -90),
			endPos = Vector3.new(1070, 3.5, -90),
			speed = 9,
		},
		{
			name = "NPC_Dad1",
			startPos = Vector3.new(920, 3.5, 70),
			endPos = Vector3.new(920, 3.5, -100),
			speed = 8,
		},
		{
			name = "NPC_Grandma1",
			startPos = Vector3.new(960, 3.5, 92),
			endPos = Vector3.new(1040, 3.5, 92),
			speed = 6,
		},
		{
			name = "NPC_Kid1",
			startPos = Vector3.new(1090, 3.5, 30),
			endPos = Vector3.new(1090, 3.5, -40),
			speed = 12,
		},
	},
	["Zone3"] = {
		{
			name = "NPC_Waiter1",
			startPos = Vector3.new(1500, 3.5, -60),
			endPos = Vector3.new(1500, 3.5, 110),
			speed = 10,
		},
		{
			name = "NPC_Waiter2",
			startPos = Vector3.new(1700, 3.5, -60),
			endPos = Vector3.new(1700, 3.5, 110),
			speed = 10,
		},
		{
			name = "NPC_Waiter3",
			startPos = Vector3.new(1470, 3.5, -110),
			endPos = Vector3.new(1730, 3.5, -110),
			speed = 12,
		},
		{
			name = "NPC_Waiter4",
			startPos = Vector3.new(1470, 3.5, 115),
			endPos = Vector3.new(1730, 3.5, 115),
			speed = 11,
		},
		{
			name = "NPC_Waiter5",
			startPos = Vector3.new(1600, 3.5, 40),
			endPos = Vector3.new(1600, 3.5, 110),
			speed = 8,
		},
	},
}

return RunConfig
