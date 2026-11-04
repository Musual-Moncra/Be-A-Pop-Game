--!strict

--[[
	RunConfig
	Gameplay run timing, NPC patrols and stain visuals. Pure data, no functions.

	Fields:
		RunStateSyncInterval: time between network sync packets to client (seconds)
		PortalTouchDebounce: minimum delay between portal touch triggers per player (seconds)
		RunLoopStepInterval: update tick interval for active run loops (seconds)
		InstanceWaitTimeout: maximum time to wait for workspace child instances (seconds)
		PortalFindRetryInterval: time between retries while searching for the lobby Portal (seconds)
		StainFolderPrefix: name prefix for grouping player stains in Workspace (string)
		StainRayUpOffset: starting offset along character up axis for raycasts (studs)
		StainRayLength: maximum raycast distance downward to detect surfaces (studs)
		StainSurfaceOffset: offset along surface normal to prevent z-fighting (studs)
		StainColor: visual color applied to stain parts (RGB color)
		StainMaterial: material of stain parts (Enum.Material)
		StainThickness: extrusion height of stain parts perpendicular to surface (studs)
		StainTransparency: visual transparency level of stain parts (0 to 1)
		PracticeTimeLeft: time-left value sent to the client for untimed runs (seconds, -1 = no timer)
		NpcPatrols: per map id, the NPCs that walk back and forth between two points (vision and
			chase tuning lives in NpcConfig)
			name: name of the NPC Model inside the map's NPCs folder (string)
			startPos: one end of the patrol line (studs, world position)
			endPos: the other end of the patrol line (studs, world position)
			speed: walking speed of the NPC (studs/second)
]]

local RunConfig = {}

RunConfig.RunStateSyncInterval = 0.25
RunConfig.PortalTouchDebounce = 1.0
RunConfig.RunLoopStepInterval = 0.05
RunConfig.InstanceWaitTimeout = 5
RunConfig.PortalFindRetryInterval = 0.1

RunConfig.StainFolderPrefix = "Stains_"
RunConfig.StainRayUpOffset = 2
RunConfig.StainRayLength = 10
RunConfig.StainSurfaceOffset = 0.05
RunConfig.StainColor = Color3.fromRGB(112, 66, 20)
RunConfig.StainMaterial = Enum.Material.SmoothPlastic
RunConfig.StainThickness = 0.08
RunConfig.StainTransparency = 0.0
RunConfig.PracticeTimeLeft = -1

RunConfig.NpcPatrols = {
	["Zone1"] = {
		{ name = "NPC_Chef1", startPos = Vector3.new(480, 3.5, -22), endPos = Vector3.new(480, 3.5, 30), speed = 8 },
		{ name = "NPC_Chef2", startPos = Vector3.new(525, 3.5, -22), endPos = Vector3.new(525, 3.5, 32), speed = 9 },
		{ name = "NPC_Cat", startPos = Vector3.new(440, 3.5, -15), endPos = Vector3.new(475, 3.5, -15), speed = 12 },
		{ name = "NPC_Dog", startPos = Vector3.new(515, 3.5, 66), endPos = Vector3.new(560, 3.5, 66), speed = 11 },
	},
	["Zone2"] = {
		{ name = "NPC_Shopper1", startPos = Vector3.new(910, 3.5, -70), endPos = Vector3.new(1090, 3.5, -70), speed = 9 },
		{ name = "NPC_Shopper2", startPos = Vector3.new(910, 3.5, 72), endPos = Vector3.new(1090, 3.5, 72), speed = 9 },
		{ name = "NPC_Guard1", startPos = Vector3.new(900, 3.5, -80), endPos = Vector3.new(900, 3.5, 10), speed = 7 },
		{ name = "NPC_Guard2", startPos = Vector3.new(1100, 3.5, -80), endPos = Vector3.new(1100, 3.5, 80), speed = 7 },
		{ name = "NPC_Kid", startPos = Vector3.new(940, 3.5, -45), endPos = Vector3.new(1060, 3.5, -45), speed = 13 },
	},
	["Zone3"] = {
		{ name = "NPC_Staff1", startPos = Vector3.new(1560, 19.75, -232), endPos = Vector3.new(1690, 19.75, -232), speed = 9 },
		{ name = "NPC_Staff2", startPos = Vector3.new(1560, 19.75, -368), endPos = Vector3.new(1690, 19.75, -368), speed = 9 },
		{ name = "NPC_IceCream", startPos = Vector3.new(1530, 19.75, -340), endPos = Vector3.new(1690, 19.75, -340), speed = 6 },
		{ name = "NPC_Jogger", startPos = Vector3.new(1535, 19.75, -270), endPos = Vector3.new(1685, 19.75, -270), speed = 15 },
		{ name = "NPC_Dog", startPos = Vector3.new(1623, 19.75, -245), endPos = Vector3.new(1623, 19.75, -365), speed = 13 },
		{ name = "NPC_Kid", startPos = Vector3.new(1550, 19.75, -225), endPos = Vector3.new(1660, 19.75, -225), speed = 11 },
	},
	["Zone4"] = {
		{ name = "NPC_Butler1", startPos = Vector3.new(2380, 3.5, -120), endPos = Vector3.new(2380, 3.5, 140), speed = 9 },
		{ name = "NPC_Butler2", startPos = Vector3.new(2420, 3.5, -120), endPos = Vector3.new(2420, 3.5, 140), speed = 9 },
		{ name = "NPC_Bellhop", startPos = Vector3.new(2250, 3.5, 0), endPos = Vector3.new(2370, 3.5, 0), speed = 11 },
		{ name = "NPC_Guest1", startPos = Vector3.new(2430, 3.5, 40), endPos = Vector3.new(2550, 3.5, 40), speed = 7 },
		{ name = "NPC_Guest2", startPos = Vector3.new(2250, 3.5, 120), endPos = Vector3.new(2370, 3.5, 120), speed = 8 },
		{ name = "NPC_Maid", startPos = Vector3.new(2460, 3.5, -120), endPos = Vector3.new(2550, 3.5, -120), speed = 10 },
	},
}

return RunConfig
