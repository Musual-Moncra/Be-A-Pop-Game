--!strict

--[[
	NpcConfig
	NPC vision, chase, catch, panic, panic-coin drops and pathfinding. Pure data, no functions.

	Fields:
		ViewLength: how far the vision triangle reaches in front of the NPC (studs)
		ViewWidth: width of the far edge of the vision triangle (studs)
		ViewHeight: how far above or below the NPC a player can be and still be seen (studs)
		LoseMargin: extra reach around the triangle a chased player may use before losing time counts (studs)
		LoseTime: time a chased player must stay outside the triangle and margin before the NPC gives up (seconds)
		ChaseSpeed: chase speed as a multiplier of the NPC's patrol speed (multiplier)
		ChaseMax: highest chase speed, keep it below the player's base speed so a chase can be escaped (studs/second)
		ReturnSpeed: walk-back speed as a multiplier of the NPC's patrol speed (multiplier)
		CatchRadius: distance at which an NPC catches the poop, also the radius of the red circle (studs)
		CatchHeight: how far above or below the NPC a player can be and still be caught (studs)
		CatchCooldown: time after a catch before any NPC can catch that player again (seconds)
		CatchPenalty: lifespan removed when an NPC catches the poop (seconds)
		RestTime: after catching its target, how long an NPC walks back and ignores players (seconds)
		TurnaroundPause: pause at each end of a patrol line (seconds)
		PanicSpeed: flee speed of a panicking NPC (studs/second)
		PanicSeconds: how long a panic lasts before the NPC returns to its patrol line (seconds)
		PanicRadius: a fully soiled prop within this distance makes a patrolling NPC panic (studs)
		SoilContactRadius: distance from the poop hitbox to an NPC that soils it on contact, scaled
			by Hitbox.Scale so bigger characters reach further (studs)
		SoilCheckRadius: coarse pre-check around the poop; only NPCs this close run the contact test (studs)
		PanicSoilBonus: score paid the first time an NPC itself is soiled (points)
		PanicCoinCount: coin orbs dropped by a soiled NPC (count)
		PanicCoinPoints: score paid when one coin orb is picked up (points)
		PanicCoinLifetime: time before an uncollected coin orb disappears (seconds)
		PanicCoinPickupRadius: pickup distance from the player hitbox to the orb centre (studs)
		PanicCoinSize: diameter of one coin orb (studs)
		PanicCoinHeight: orb height above the soiled NPC pivot (studs)
		PanicCoinSpread: orb distance from the NPC pivot on the ground plane (studs)
		PanicCoinColor: orb colour (RGB)
		PanicCoinMaterial: orb material (Enum.Material)
		PanicCoinFolderName: folder created under the map copy for the dropped orbs (string)
		PanicBillboardText: text shown above a soiled NPC (text)
		PanicBillboardColor: text colour (RGB)
		PanicBillboardWidth: BillboardGui width (pixels)
		PanicBillboardHeight: BillboardGui height (pixels)
		PanicBillboardOffset: height of the BillboardGui above its anchor part (studs)
		PanicSoundKey: SoundConfig.Sfx key played when an NPC is soiled (string)
		PathsPerSecond: PathfindingService compute budget for the whole server (paths/second)
		PathAgentRadius: pathfinding agent radius (studs)
		PathAgentHeight: pathfinding agent height (studs)
		PathAgentCanJump: whether computed paths may include jumps (true/false)
		PathWaypointRadius: distance at which a waypoint counts as reached (studs)
		ZoneColor: vision triangle colour while the NPC patrols or returns (RGB colour)
		ChaseColor: vision triangle colour while the NPC chases (RGB colour)
		ZoneTransparency: vision triangle transparency (0 to 1)
		RingColor: colour of the catch circle around the NPC (RGB colour)
		RingTransparency: catch circle transparency (0 to 1)
		ZoneHeight: thickness of the triangle and circle parts (studs)
		FloorRayHeight: the floor snap ray starts this far above the NPC and is twice as long (studs)
]]

return {
	ViewLength = 22,
	ViewWidth = 16,
	ViewHeight = 3,
	LoseMargin = 3,
	LoseTime = 2,
	ChaseSpeed = 1.15,
	ChaseMax = 13,
	ReturnSpeed = 1.1,
	CatchRadius = 4,
	CatchHeight = 3,
	CatchCooldown = 2,
	CatchPenalty = 5,
	RestTime = 4,
	TurnaroundPause = 0.5,
	PanicSpeed = 18,
	PanicSeconds = 4,
	PanicRadius = 45,
	SoilContactRadius = 3,
	SoilCheckRadius = 14,
	PanicSoilBonus = 100,
	PanicCoinCount = 3,
	PanicCoinPoints = 25,
	PanicCoinLifetime = 15,
	PanicCoinPickupRadius = 4,
	PanicCoinSize = 1.4,
	PanicCoinHeight = 2,
	PanicCoinSpread = 3,
	PanicCoinColor = Color3.fromRGB(255, 205, 60),
	PanicCoinMaterial = Enum.Material.Neon,
	PanicCoinFolderName = "PanicCoins",
	PanicBillboardText = "!",
	PanicBillboardColor = Color3.fromRGB(255, 60, 60),
	PanicBillboardWidth = 48,
	PanicBillboardHeight = 64,
	PanicBillboardOffset = 5,
	PanicSoundKey = "NpcSqueal",
	PathsPerSecond = 4,
	PathAgentRadius = 2,
	PathAgentHeight = 5,
	PathAgentCanJump = false,
	PathWaypointRadius = 2,
	ZoneColor = Color3.fromRGB(255, 150, 60),
	ChaseColor = Color3.fromRGB(255, 30, 30),
	ZoneTransparency = 0.55,
	RingColor = Color3.fromRGB(255, 40, 40),
	RingTransparency = 0.35,
	ZoneHeight = 0.2,
	FloorRayHeight = 30,
}
