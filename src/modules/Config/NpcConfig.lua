--!strict

--[[
	NpcConfig
	NPC vision, chase, catch and vision-zone visuals. Pure data, no functions.

	Fields:
		ViewLength: how far the vision triangle reaches in front of the NPC (studs)
		ViewWidth: width of the far edge of the vision triangle (studs)
		LoseMargin: extra reach around the triangle a chased player may use before losing time counts (studs)
		LoseTime: time a chased player must stay outside the triangle and margin before the NPC gives up (seconds)
		ChaseSpeed: chase speed as a multiplier of the NPC's patrol speed (multiplier)
		ChaseMax: highest chase speed, keep it below the player's base speed so a chase can be escaped (studs/second)
		ReturnSpeed: walk-back speed as a multiplier of the NPC's patrol speed (multiplier)
		CatchRadius: distance at which an NPC catches the poop, also the radius of the red circle (studs)
		CatchCooldown: time after a catch before any NPC can catch that player again (seconds)
		CatchPenalty: lifespan removed when an NPC catches the poop (seconds)
		RestTime: after catching its target, how long an NPC walks back and ignores players (seconds)
		TurnaroundPause: pause at each end of a patrol line (seconds)
		ZoneColor: vision triangle colour while the NPC patrols or returns (RGB colour)
		ChaseColor: vision triangle colour while the NPC chases (RGB colour)
		ZoneTransparency: vision triangle transparency (0 to 1)
		RingColor: colour of the catch circle around the NPC (RGB colour)
		RingTransparency: catch circle transparency (0 to 1)
		ZoneHeight: thickness of the triangle and circle parts (studs)
		FloorRayHeight: the floor snap ray starts this far above the NPC and is twice as long (studs)
]]

local NpcConfig = {}

NpcConfig.ViewLength = 22
NpcConfig.ViewWidth = 16
NpcConfig.LoseMargin = 3
NpcConfig.LoseTime = 2
NpcConfig.ChaseSpeed = 1.15
NpcConfig.ChaseMax = 13
NpcConfig.ReturnSpeed = 1.1
NpcConfig.CatchRadius = 4
NpcConfig.CatchCooldown = 2
NpcConfig.CatchPenalty = 5
NpcConfig.RestTime = 4
NpcConfig.TurnaroundPause = 0.5

NpcConfig.ZoneColor = Color3.fromRGB(255, 150, 60)
NpcConfig.ChaseColor = Color3.fromRGB(255, 30, 30)
NpcConfig.ZoneTransparency = 0.55
NpcConfig.RingColor = Color3.fromRGB(255, 40, 40)
NpcConfig.RingTransparency = 0.35
NpcConfig.ZoneHeight = 0.2
NpcConfig.FloorRayHeight = 30

return NpcConfig
