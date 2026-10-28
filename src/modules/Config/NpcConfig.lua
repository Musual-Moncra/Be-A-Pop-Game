--!strict

--[[
	NpcConfig
	NPC vision, chase, catch and vision-zone visuals. Pure data, no functions.

	Fields:
		ViewLength: depth of the vision oval along the NPC's look direction (studs)
		ViewWidth: width of the vision oval across the NPC's shoulders (studs)
		ViewOffset: distance from the NPC to the centre of the vision oval (studs ahead)
		LoseMargin: extra reach around the oval a chased player may use before losing time counts (studs)
		LoseTime: time a chased player must stay outside the oval and margin before the NPC gives up (seconds)
		ChaseSpeed: chase speed as a multiplier of the NPC's patrol speed (multiplier)
		ReturnSpeed: walk-back speed as a multiplier of the NPC's patrol speed (multiplier)
		CatchRadius: distance at which an NPC catches the poop (studs)
		CatchCooldown: time after a catch before any NPC can catch that player again (seconds)
		CatchPenalty: lifespan removed when an NPC catches the poop (seconds)
		TurnaroundPause: pause at each end of a patrol line (seconds)
		ZoneColor: vision oval colour while the NPC patrols or returns (RGB colour)
		ChaseColor: vision oval colour while the NPC chases (RGB colour)
		ZoneTransparency: vision oval transparency (0 to 1)
		ZoneHeight: thickness of the vision oval part (studs)
]]

local NpcConfig = {}

NpcConfig.ViewLength = 26
NpcConfig.ViewWidth = 14
NpcConfig.ViewOffset = 13
NpcConfig.LoseMargin = 3
NpcConfig.LoseTime = 2.5
NpcConfig.ChaseSpeed = 1.35
NpcConfig.ReturnSpeed = 1.15
NpcConfig.CatchRadius = 4
NpcConfig.CatchCooldown = 2
NpcConfig.CatchPenalty = 5
NpcConfig.TurnaroundPause = 0.5

NpcConfig.ZoneColor = Color3.fromRGB(255, 96, 72)
NpcConfig.ChaseColor = Color3.fromRGB(255, 24, 24)
NpcConfig.ZoneTransparency = 0.6
NpcConfig.ZoneHeight = 0.24

return NpcConfig
