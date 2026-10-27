--!strict

--[[
	RunConfig
	Pure data tuning for gameplay runs, NPCs, and stain visuals.

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
		StainThickness: extrusion height of stain parts perpendicular to surface (studs)
		StainTransparency: visual transparency level of stain parts (0 to 1)
		PracticeTimeLeft: special time-left value sent during untimed practice runs (seconds)
		NpcPatrols: map of map IDs to arrays of NPC patrol configurations (table)
]]

export type NpcPatrolConfig = {
	name: string,
	startPos: Vector3,
	endPos: Vector3,
	speed: number,
}

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
RunConfig.StainThickness = 0.08
RunConfig.StainTransparency = 0.0
RunConfig.PracticeTimeLeft = -1

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
} :: { [string]: { NpcPatrolConfig } }

return RunConfig
