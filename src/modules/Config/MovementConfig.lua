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
		AirGravityHoldTime: time airborne before GravityUp blends back to world up (seconds)
		AirControl: fraction of walking speed the player can steer with while airborne (0 to 1)
		MoveInputDeadzone: smallest stick/thumbstick magnitude treated as movement (0 to 1)
		MoveSmoothingSpeed: how quickly the poop reaches its walking velocity (1/s, larger = snappier)
		NormalLerpSpeed: how quickly GravityUp blends toward a new surface normal (1/s)
		AlignmentResponsiveness: how quickly the body twists to match GravityUp (Roblox AlignOrientation units)
		AlignmentTorquePerMass: torque limit of the body alignment, per unit of character mass (torque/mass)
		GravityUpPublishMinAngleDegrees: smallest GravityUp change worth publishing to the attribute (degrees)
		TeleportResetDistance: position jump treated as a teleport, resetting gravity to world up (studs)
		GroundProbeDistance: downward raycast length for the surface underfoot (studs)
		WallProbeDistance: perpendicular reach at which a wall walked into counts as contact (studs)
		WallClimbHeadOnDot: how head-on a forward wall must be before it is climbable (0 to 1)
		EdgeProbeDistance: down-forward raycast length used to wrap over convex edges (studs)
		EdgeProbeUpOffset: height above the body center where the edge ray starts (studs)
		EdgeProbeDownBias: how much the edge ray tilts downward instead of forward (0 to 1)
		MinWallAngleDegrees: smallest tilt from world up at which a surface walked into counts as a wall (degrees)
		MaxClimbAngleDegrees: largest angle from GravityUp the poop will climb onto (degrees)

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

local MovementConfig = {}

MovementConfig.GravityStrength = 196
MovementConfig.TerminalFallSpeed = 150
MovementConfig.MaxAcceleration = 900
MovementConfig.GroundStickSpeed = 8
MovementConfig.JumpVelocity = 50
MovementConfig.JumpCooldown = 0.2
MovementConfig.AirGravityHoldTime = 0.35
MovementConfig.AirControl = 0.45
MovementConfig.MoveInputDeadzone = 0.08
MovementConfig.MoveSmoothingSpeed = 18

MovementConfig.NormalLerpSpeed = 7
MovementConfig.AlignmentResponsiveness = 90
MovementConfig.AlignmentTorquePerMass = 8000
MovementConfig.GravityUpPublishMinAngleDegrees = 2
MovementConfig.TeleportResetDistance = 40

MovementConfig.GroundProbeDistance = 3
MovementConfig.WallProbeDistance = 3.2
MovementConfig.WallClimbHeadOnDot = 0.35
MovementConfig.EdgeProbeDistance = 2.6
MovementConfig.EdgeProbeUpOffset = 0.6
MovementConfig.EdgeProbeDownBias = 0.9
MovementConfig.MinWallAngleDegrees = 35
MovementConfig.MaxClimbAngleDegrees = 110

MovementConfig.CameraDistance = 14
MovementConfig.CameraMinDistance = 2.5
MovementConfig.CameraHeightOffset = 2
MovementConfig.CameraUpLerpSpeed = 6
MovementConfig.CameraFollowLerpSpeed = 14
MovementConfig.CameraMinPitchDegrees = -25
MovementConfig.CameraMaxPitchDegrees = 75
MovementConfig.CameraDefaultPitchDegrees = 14
MovementConfig.CameraDefaultYawDegrees = 0
MovementConfig.CameraMouseSensitivity = 0.35
MovementConfig.CameraTouchSensitivity = 0.3
MovementConfig.CameraGamepadYawSpeed = 130
MovementConfig.CameraGamepadPitchSpeed = 90
MovementConfig.CameraTouchOrbitScreenFraction = 0.5
MovementConfig.CameraCollisionPadding = 0.6

return MovementConfig
