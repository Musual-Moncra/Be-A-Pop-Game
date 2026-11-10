--!strict

--[[
	MovementConfig
	Pure data tuning for wall-climbing poop movement and the gravity camera.
	Read by GravityController (movement, surface detection, jump) and GravityCamera (orbit camera).

	Movement fields:
		GravityStrength: acceleration pulling the poop along -GravityUp while airborne (studs/s^2)
		TerminalFallSpeed: maximum speed the poop can fall along -GravityUp (studs/s)
		MaxAcceleration: force authority of the velocity actuator, expressed as acceleration (studs/s^2)
		GroundStickSpeed: speed pressing the poop into the surface while grounded (studs/s)
		JumpVelocity: launch speed along GravityUp when jumping (studs/s)
		JumpCooldown: time after a jump before a surface can grab the poop again (seconds)
		GroundCoyoteTime: time the poop keeps its last surface after losing contact, so walking over
			convex edges does not flicker between grounded and airborne (seconds)
		AirGravityHoldTime: time airborne before GravityUp blends back to world up (seconds)
		AirControl: fraction of walking speed the player can steer with while airborne (0 to 1)
		MoveInputDeadzone: smallest stick/thumbstick magnitude treated as movement (0 to 1)
		MoveSmoothingSpeed: how quickly the poop reaches its walking velocity (1/s, larger = snappier)
		BodyTurnSpeed: how quickly the body turns to face the direction it moves (1/s, larger = snappier)
		NormalLerpSpeed: how quickly GravityUp blends toward a new surface normal (1/s)
		AlignmentResponsiveness: how quickly the body twists to match GravityUp (Roblox AlignOrientation units)
		AlignmentTorquePerMass: torque limit of the body alignment, per unit of character mass (torque/mass)
		GravityUpPublishMinAngleDegrees: smallest GravityUp change worth publishing to the attribute (degrees)
		TeleportResetDistance: position jump treated as a teleport, resetting gravity to world up (studs)
		GroundProbeDistance: how far below the body the poop still counts as standing on a surface (studs)
		WallProbeDistance: gap between the body and a wall at which climbing starts (studs)
		WallClimbHeadOnDot: how head-on a forward wall must be before it is climbable (0 to 1)
		EdgeProbeDistance: down-forward raycast length used to wrap over convex edges (studs)
		EdgeProbeUpOffset: height above the body center where the edge ray starts (studs)
		EdgeProbeDownBias: how much the edge ray tilts downward instead of forward (0 to 1)
		MinWallAngleDegrees: while on a floor, smallest tilt from world up at which a surface walked into counts as a wall (degrees)
		MaxClimbAngleDegrees: largest angle from GravityUp the poop will climb onto (degrees)
		ProbeMinInput: smallest movement input strength that makes the poop probe ahead for walls and edges (0 to 1)
		CharacterWaitTimeout: how long to wait for the character's parts and PlayerScripts to load (seconds)
		BodyFriction: friction of the poop's root ball; 0 stops it locking against floors and walls while pressed into them (0 to 2)
		BodyFrictionWeight: how strongly BodyFriction wins over the touched surface's friction (weight)
		BodyElasticity: bounciness of the poop's root ball (0 to 1)
		BodyElasticityWeight: how strongly BodyElasticity wins over the touched surface's elasticity (weight)
	All probe distances above are for a normal-size poop and are multiplied by the character's
	current scale, so a poop grown by food still sticks and climbs.

	Camera fields:
		CameraDistance: distance from the poop to the camera (studs)
		CameraMinDistance: closest the camera may be pulled in by geometry (studs)
		CameraHeightOffset: focus point offset from the body center along GravityUp (studs)
		CameraUpLerpSpeed: how quickly the camera up vector follows GravityUp (1/s)
		CameraFollowLerpSpeed: how quickly the camera focus follows the poop (1/s)
		CameraMinPitchDegrees: lowest camera elevation, below the surface plane (degrees)
		CameraMaxPitchDegrees: highest camera elevation, above the surface plane (degrees)
		CameraDefaultPitchDegrees: camera elevation used on spawn (degrees)
		CameraDefaultYawDegrees: camera yaw around the poop used on spawn (degrees)
		CameraMouseSensitivity: orbit degrees per pixel of right-button mouse drag (degrees/pixel)
		CameraTouchSensitivity: orbit degrees per pixel of touch drag (degrees/pixel)
		CameraGamepadYawSpeed: orbit yaw speed at full right-stick tilt (degrees/s)
		CameraGamepadPitchSpeed: orbit pitch speed at full right-stick tilt (degrees/s)
		CameraTouchOrbitScreenFraction: leftmost screen fraction where a touch drag orbits (0 to 1)
		CameraCollisionPadding: gap kept between the camera and geometry it would clip (studs)
]]

return {
	GravityStrength = 196,
	TerminalFallSpeed = 150,
	MaxAcceleration = 900,
	GroundStickSpeed = 8,
	JumpVelocity = 50,
	JumpCooldown = 0.2,
	GroundCoyoteTime = 0.12,
	AirGravityHoldTime = 0.35,
	AirControl = 0.45,
	MoveInputDeadzone = 0.08,
	MoveSmoothingSpeed = 18,
	BodyTurnSpeed = 14,
	NormalLerpSpeed = 7,
	AlignmentResponsiveness = 90,
	AlignmentTorquePerMass = 8000,
	GravityUpPublishMinAngleDegrees = 2,
	TeleportResetDistance = 40,
	GroundProbeDistance = 1.25,
	WallProbeDistance = 0.3,
	WallClimbHeadOnDot = 0.35,
	EdgeProbeDistance = 2.6,
	EdgeProbeUpOffset = 0.6,
	EdgeProbeDownBias = 0.9,
	MinWallAngleDegrees = 35,
	MaxClimbAngleDegrees = 110,
	ProbeMinInput = 0.5,
	CharacterWaitTimeout = 10,
	BodyFriction = 0,
	BodyFrictionWeight = 100,
	BodyElasticity = 0,
	BodyElasticityWeight = 100,
	CameraDistance = 14,
	CameraMinDistance = 2.5,
	CameraHeightOffset = 0.65,
	CameraUpLerpSpeed = 6,
	CameraFollowLerpSpeed = 14,
	CameraMinPitchDegrees = -25,
	CameraMaxPitchDegrees = 75,
	CameraDefaultPitchDegrees = 14,
	CameraDefaultYawDegrees = 0,
	CameraMouseSensitivity = 0.35,
	CameraTouchSensitivity = 0.3,
	CameraGamepadYawSpeed = 130,
	CameraGamepadPitchSpeed = 90,
	CameraTouchOrbitScreenFraction = 0.5,
	CameraCollisionPadding = 0.6,
}
