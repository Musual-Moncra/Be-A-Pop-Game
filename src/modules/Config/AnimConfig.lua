--!strict

--[[
	AnimConfig
	Tuning for the procedural poop animation played by PoopAnimController on every poop
	character. The poop is a skinned log with a bone chain that runs from the head (first
	bone) to the tail (last bone); every pose is built from springs on those bones, so it
	wobbles like jelly. Pure data, no functions.

	Bone axes (each bone's local space): X = right, Y = along the body towards the tail,
	Z = down. Pitch turns about X (humps up and down), Yaw about Z (bends left and right),
	Roll about Y (leans sideways).

	Fields:
		BoneNames: bone names from head to tail, found anywhere under the HumanoidRootPart (string)
		Weights: how strongly each bone in BoneNames follows the wave and bend poses, same order (0 to 1)
		CullDistance: poops farther than this from the camera are not animated (studs)
		MaxStep: longest frame time fed to the springs, so a hitch cannot explode them (seconds)
		SpringStiffness: how hard every bone pulls toward its pose; higher = snappier (1/s^2)
		SpringDamping: how fast the wobble settles; lower = more jelly (1/s)
		ReferenceSpeed: surface speed that counts as full crawl; faster still caps at 1 (studs/s)
		BreathRate: idle breathing cycles per second (Hz)
		BreathPitch: idle breathing hump on the tail half (degrees)
		WaveStudsPerCycle: distance crawled for one full body wave at normal size; scales with the poop (studs)
		WavePhaseStep: phase delay between neighbouring bones, so the hump travels along the body (radians)
		WavePitch: crawl hump at full speed (degrees)
		WiggleYaw: side-to-side squirm at full speed (degrees)
		WiggleRate: squirm cycles per body wave (multiplier)
		StretchStuds: how far each segment slides in and out with the wave at normal size (studs)
		TurnBend: body bend into a turn per degree per second of turning (degrees per deg/s)
		MaxTurnBend: largest bend per bone (degrees)
		TurnRoll: lean into a turn per degree per second of turning, at full speed (degrees per deg/s)
		MaxTurnRoll: largest lean (degrees)
		AccelPitch: head lift per stud/s^2 of speeding up; negative acceleration dips it (degrees per stud/s^2)
		MaxAccelPitch: largest head lift or dip (degrees)
		AccelSmoothing: how quickly the measured acceleration follows the real one (1/s)
		AirSpeed: vertical speed above which the poop counts as airborne (studs/s)
		AirPitch: tail droop per stud/s of vertical speed while airborne (degrees per stud/s)
		MaxAirPitch: largest airborne droop (degrees)
		LandSpeed: falling speed that makes a landing splat (studs/s)
		LandKick: wobble kick given to every bone's pitch spring on a landing splat (degrees/s)
		PitchSign / YawSign / RollSign: flip a pose direction if it reads backwards on the model (1 or -1)
]]

return {
	BoneNames = { "Bone", "Bone.001", "Bone.002", "Bone.003" },
	Weights = { 0.35, 0.8, 1, 1 },
	CullDistance = 160,
	MaxStep = 1 / 30,
	SpringStiffness = 170,
	SpringDamping = 11,
	ReferenceSpeed = 16,
	BreathRate = 0.6,
	BreathPitch = 3,
	WaveStudsPerCycle = 7,
	WavePhaseStep = 1.15,
	WavePitch = 9,
	WiggleYaw = 5,
	WiggleRate = 0.5,
	StretchStuds = 0.18,
	TurnBend = 0.05,
	MaxTurnBend = 9,
	TurnRoll = 0.08,
	MaxTurnRoll = 16,
	AccelPitch = 0.12,
	MaxAccelPitch = 8,
	AccelSmoothing = 8,
	AirSpeed = 6,
	AirPitch = 0.35,
	MaxAirPitch = 14,
	LandSpeed = 18,
	LandKick = 260,
	PitchSign = 1,
	YawSign = 1,
	RollSign = 1,
}
