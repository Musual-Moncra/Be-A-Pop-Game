--!strict

--[[
	AnimConfig
	Tuning for the procedural poop animation played by PoopAnimController on every poop
	character. The poop is a skinned log with a bone chain from the head (first bone) to the
	tail (last bone). It moves like a snake: every pose bends the body sideways, never up and
	down, and every bone eases toward its pose through a near-critically damped spring so the
	motion stays smooth. Pure data, no functions.

	Bone axes (each bone's local space): X = right, Y = along the body towards the tail,
	Z = down. Yaw turns about Z (bends left and right), Roll about Y (leans sideways).

	States, blended every frame:
		idle    a slow S-curve sway, like a resting snake
		slither a sideways wave that runs head to tail, paced by distance crawled; the tail
		        swings wider than the head, so the head points where it goes
		sprint  faster than ReferenceSpeed widens the wave up to SprintWidth
		turn    the body curves into the turn and the head leans with it
		stop    speed and wave fade out together, so the body settles without a snap
		air     the wave calms and the body glides straight
		land    a quick side wiggle runs along the body
		splat   splatting a target gives this player's poop a short happy wiggle

	Fields:
		BoneNames: bone names from head to tail, found anywhere under the HumanoidRootPart (string)
		Weights: how far each bone in BoneNames swings, same order; rises toward the tail (0 to 1)
		CullDistance: poops farther than this from the camera are not animated (studs)
		MaxStep: longest frame time fed to the springs, so a hitch cannot explode them (seconds)
		SpringStiffness: how hard every bone pulls toward its pose; higher = tighter (1/s^2)
		SpringDamping: how fast motion settles; 2 x sqrt(SpringStiffness) is critical, no overshoot (1/s)
		ReferenceSpeed: surface speed that counts as a full slither (studs/s)
		SpeedSmoothing: how quickly the measured speed follows the real one, smooths starts and stops (1/s)
		IdleSway: idle S-curve swing per bone (degrees)
		IdleRate: idle sway cycles per second (Hz)
		IdlePhaseStep: idle phase delay between neighbouring bones (radians)
		WaveStudsPerCycle: distance crawled for one full side-to-side wave at normal size; scales with the poop (studs)
		WavePhaseStep: phase delay between neighbouring bones, so the wave runs head to tail (radians)
		SlitherYaw: side swing per bone at a full slither (degrees)
		SprintWidth: largest extra swing when faster than ReferenceSpeed, as a share of SlitherYaw (0 to 1)
		MaxSpeedRatio: speed / ReferenceSpeed where SprintWidth is fully reached (multiplier)
		SlitherRoll: head lean that follows the wave, the slide-and-tilt of a snake (degrees)
		TurnBend: body curve into a turn per degree per second of turning (degrees per deg/s)
		MaxTurnBend: largest curve per bone (degrees)
		TurnLean: head lean into a turn per degree per second of turning, at a full slither (degrees per deg/s)
		MaxTurnLean: largest turn lean (degrees)
		TurnSmoothing: how quickly the measured turn rate follows the real one (1/s)
		AirSpeed: vertical speed above which the poop counts as airborne (studs/s)
		AirCalm: share of the wave kept while airborne (0 to 1)
		LandSpeed: falling speed that makes a landing wiggle (studs/s)
		LandWiggle: sideways kick per bone on landing, alternating left and right along the body (degrees/s)
		SplatWiggle: sideways kick per bone when this player splats a target (degrees/s)
		YawSign / RollSign: flip a pose direction if it reads backwards on the model (1 or -1)
]]

return {
	BoneNames = { "Bone", "Bone.001", "Bone.002", "Bone.003" },
	Weights = { 0.3, 0.6, 0.85, 1 },
	CullDistance = 160,
	MaxStep = 1 / 30,
	SpringStiffness = 110,
	SpringDamping = 19,
	ReferenceSpeed = 16,
	SpeedSmoothing = 6,
	IdleSway = 4,
	IdleRate = 0.35,
	IdlePhaseStep = 0.9,
	WaveStudsPerCycle = 9,
	WavePhaseStep = 0.95,
	SlitherYaw = 18,
	SprintWidth = 0.35,
	MaxSpeedRatio = 2,
	SlitherRoll = 6,
	TurnBend = 0.06,
	MaxTurnBend = 12,
	TurnLean = 0.06,
	MaxTurnLean = 12,
	TurnSmoothing = 7,
	AirSpeed = 6,
	AirCalm = 0.3,
	LandSpeed = 18,
	LandWiggle = 160,
	SplatWiggle = 220,
	YawSign = 1,
	RollSign = 1,
}
