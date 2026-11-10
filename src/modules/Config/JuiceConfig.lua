--!strict

--[[
	JuiceConfig
	Every tunable of the client "juice" pass: combo meter, floating numbers, milestone
	banners, camera feel, squash and stretch, splat particles and pet poop VFX. Pure data,
	no functions. Colours are RGB, sizes in design pixels unless marked studs.

	Fields:
		Combo meter (drawn under the Lifespan bar):
			ComboFormat: combo label text, %d = combo level (format)
			ComboMinLevel: lowest combo level that shows the meter (level)
			ComboTextSize: label text size (design pixels)
			ComboOffsetY: gap below the Lifespan bar (design pixels)
			ComboWidth / ComboHeight: label box size (design pixels)
			ComboPunchScale: size the meter jumps to on a level up (multiplier)
			ComboPunchTime: time of the level-up punch (seconds)
			ComboShakeDegrees / ComboShakeSpeed: rotation wobble at max combo (degrees, cycles/second)
			ComboColors: label colour per combo level, index 1 = level 1 (RGB)
		Floating numbers on the poop:
			FloatFormat: score popup text, %s = amount (format)
			FloatLifetime: how long a popup lives (seconds)
			FloatRise: how far a popup floats up (studs)
			FloatHeight: popup spawn height above the root (studs)
			FloatGuiWidth / FloatGuiHeight: BillboardGui box size (design pixels)
			FloatMaxDistance: how far the popup is visible (studs)
			FloatTiers: popup look by amount, each { Min, TextSize, Color }, the highest
				Min that the amount reaches is used (points, design pixels, RGB)
			FloatSoilFormat: target soil popup, first %s = bonus amount, second %s = target name (format)
			FloatSoilTextSize: target soil text size (design pixels)
			FloatSoilColor: target soil text colour (RGB)
			FloatSoilRise: how far the target soil popup floats up (studs)
			FloatSoilHeight: target soil popup height above the object pivot (studs)
			FloatSoilGuiWidth / FloatSoilGuiHeight: target soil BillboardGui box size (design pixels)
		Milestones:
			Milestones: stain percent thresholds that show a banner (percent)
			MilestoneFormat: banner text, %d = percent (format)
			MilestoneClearText: full-screen text at 100% (text)
			MilestoneSeconds / MilestoneClearSeconds: how long each stays on screen (seconds)
			MilestoneTextSize / MilestoneClearTextSize: text sizes (design pixels)
			MilestoneColor / MilestoneClearColor: text colours (RGB)
			MilestoneBannerY: vertical centre of the normal banner on screen (scale 0 to 1)
			MilestoneBannerWidth / MilestoneBannerHeight: banner box size (design pixels)
			MilestoneClearWidth / MilestoneClearHeight: full-screen message box size (design pixels)
			MilestoneClearRaysSize: diameter of the sunburst behind MAP CLEARED! (design pixels)
			MilestoneClearSparkles: star decorations around MAP CLEARED!, each { X, Y, Size } as
				screen scale and design-pixel text size
			MilestoneSparkleDelay: extra delay per sparkle (seconds)
			MilestonePunchScale / MilestonePunchTime: banner pop-in size and time (multiplier, seconds)
		Camera and body feel:
			ShakeTargetAmplitude / ShakeTargetDuration: shake when a target is fully soiled (studs, seconds)
			ShakeMiniBombAmplitude / ShakeMiniBombDuration: shake on Mini Bomb pickup (studs, seconds)
			ShakeRollDegrees: camera roll wobble during a shake (degrees)
			ShakeMinDuration: smallest shake duration allowed, guards a zero-time shake (seconds)
			SpeedFovKick: extra field of view on Speed Boost (degrees)
			SpeedFovInTime / SpeedFovHoldTime / SpeedFovOutTime: FOV kick shape (seconds)
			PowerupShakeId / PowerupFovId: powerup ids that trigger the two effects (powerup id)
			SquashParts: mesh part names that squash and stretch (string)
			SquashLandScale: Size multiplier on landing (multiplier)
			SquashJumpScale: Size multiplier on jump (multiplier)
			SquashProbeDistance: downward probe from the body centre that detects contact (studs)
			SquashAirTime: shortest airborne time that turns a contact into a landing (seconds)
			SquashInTime / SquashOutTime: squash in and return times (seconds)
			SquashStyle / SquashDirection: tween easing (Enum.EasingStyle / Enum.EasingDirection)
		Splat particles:
			SplatColor: particle colour (RGB)
			SplatLifetime / SplatSpeed: particle life and speed ranges, each { Min, Max }
				(seconds, studs/second)
			SplatSpreadAngle: emission cone (degrees, X and Y)
			SplatAcceleration: particle acceleration (studs/second^2)
			SplatSize / SplatTransparency: particle size and fade over its life (NumberSequence)
			SplatLightEmission: how much particles glow (0 to 1)
			SplatDrag: particle drag (number)
			SplatMinSpeed: slowest character speed that emits (studs/second)
			SplatInterval: emission interval at SplatSpeedRef (seconds)
			SplatMinInterval: shortest interval allowed at high speed (seconds)
			SplatSpeedRef: speed the interval is measured against, faster = more particles (studs/second)
			SplatBurst: particles per moving burst (count)
			SplatProbeDistance: downward probe from the body to the ground (studs)
			SplatSurfaceOffset: gap kept above the ground (studs)
			SplatSoilBurst / SplatPetBurst: particles in a soil burst / pet poop burst (count)
			SplatFxPartSize: size of the invisible emitter part (studs)
		Pet poop:
			PetPoopColor: poop puddle colour (RGB)
			PetPoopMaterial: poop puddle material (Enum.Material)
			PetPoopSize: poop puddle width (studs)
			PetPoopHeightRatio: puddle height as a share of its width (multiplier)
			PetPoopLiftRatio: puddle lift above the follower as a share of its width (multiplier)
			PetPoopLifetime: how long the puddle stays (seconds)
			PetPoopGemFormat: gem popup text, %d = gems (format)
			PetPoopGemTextSize: gem popup text size (design pixels)
			PetPoopGemColor: gem popup colour (RGB)
			PetPoopGemLifetime: how long the gem popup lives (seconds)
			PetPoopGemRise: how far the gem popup floats up (studs)
			PetPoopGemGuiWidth / PetPoopGemGuiHeight: gem popup BillboardGui box size (design pixels)
			PetPoopGemHeight: gem popup height above the follower (studs)
		Sound keys (SoundConfig.Sfx keys):
			SoundCombo / SoundMilestone / SoundPetReveal / SoundPetPoop: clip played for each event
]]

return {
	ComboFormat = "x%d COMBO!",
	ComboMinLevel = 2,
	ComboTextSize = 22,
	ComboOffsetY = 0,
	ComboWidth = 420,
	ComboHeight = 22,
	ComboPunchScale = 1.35,
	ComboPunchTime = 0.18,
	ComboShakeDegrees = 6,
	ComboShakeSpeed = 18,
	ComboColors = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(150, 240, 80),
		Color3.fromRGB(96, 200, 255),
		Color3.fromRGB(200, 120, 255),
		Color3.fromRGB(255, 214, 40),
	},

	FloatFormat = "+%s",
	FloatLifetime = 0.9,
	FloatRise = 5,
	FloatHeight = 3.2,
	FloatGuiWidth = 180,
	FloatGuiHeight = 54,
	FloatMaxDistance = 300,
	FloatTiers = {
		{ Min = 0, TextSize = 22, Color = Color3.fromRGB(255, 255, 255) },
		{ Min = 100, TextSize = 28, Color = Color3.fromRGB(150, 240, 80) },
		{ Min = 500, TextSize = 34, Color = Color3.fromRGB(96, 200, 255) },
		{ Min = 2000, TextSize = 42, Color = Color3.fromRGB(255, 214, 40) },
	},
	FloatSoilFormat = "+%s\n%s splatted!",
	FloatSoilTextSize = 38,
	FloatSoilColor = Color3.fromRGB(255, 214, 40),
	FloatSoilRise = 7,
	FloatSoilHeight = 5,
	FloatSoilGuiWidth = 320,
	FloatSoilGuiHeight = 110,

	Milestones = { 25, 50, 75 },
	MilestoneFormat = "%d%% STAINED!",
	MilestoneClearText = "MAP CLEARED!",
	MilestoneSeconds = 1.8,
	MilestoneClearSeconds = 3,
	MilestoneTextSize = 46,
	MilestoneClearTextSize = 96,
	MilestoneColor = Color3.fromRGB(255, 214, 40),
	MilestoneClearColor = Color3.fromRGB(255, 232, 90),
	MilestoneBannerY = 0.32,
	MilestoneBannerWidth = 760,
	MilestoneBannerHeight = 90,
	MilestoneClearWidth = 920,
	MilestoneClearHeight = 240,
	MilestoneClearRaysSize = 760,
	MilestoneClearSparkles = {
		{ X = 0.3, Y = 0.3, Size = 54 },
		{ X = 0.7, Y = 0.28, Size = 44 },
		{ X = 0.24, Y = 0.48, Size = 38 },
		{ X = 0.76, Y = 0.5, Size = 48 },
	},
	MilestoneSparkleDelay = 0.12,
	MilestonePunchScale = 0.6,
	MilestonePunchTime = 0.22,

	ShakeTargetAmplitude = 0.18,
	ShakeTargetDuration = 0.2,
	ShakeMiniBombAmplitude = 0.8,
	ShakeMiniBombDuration = 0.45,
	ShakeRollDegrees = 0.6,
	ShakeMinDuration = 0.01,
	SpeedFovKick = 6,
	SpeedFovInTime = 0.1,
	SpeedFovHoldTime = 0.25,
	SpeedFovOutTime = 0.35,
	PowerupShakeId = "MiniBomb",
	PowerupFovId = "SpeedBoost",

	SquashParts = { "node_0", "node_0.002" },
	SquashLandScale = Vector3.new(1.08, 0.88, 1.08),
	SquashJumpScale = Vector3.new(0.94, 1.08, 0.94),
	SquashProbeDistance = 3,
	SquashAirTime = 0.12,
	SquashInTime = 0.08,
	SquashOutTime = 0.16,
	SquashStyle = Enum.EasingStyle.Quad,
	SquashDirection = Enum.EasingDirection.Out,

	SplatColor = Color3.fromRGB(112, 66, 20),
	SplatLifetime = { Min = 0.3, Max = 0.55 },
	SplatSpeed = { Min = 4, Max = 9 },
	SplatSpreadAngle = Vector2.new(70, 70),
	SplatAcceleration = Vector3.new(0, -70, 0),
	SplatSize = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	}),
	SplatTransparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),
	SplatLightEmission = 0,
	SplatDrag = 2,
	SplatMinSpeed = 3,
	SplatInterval = 0.14,
	SplatMinInterval = 0.04,
	SplatSpeedRef = 18,
	SplatBurst = 2,
	SplatProbeDistance = 5,
	SplatSurfaceOffset = 0.06,
	SplatSoilBurst = 20,
	SplatPetBurst = 12,
	SplatFxPartSize = 0.2,

	PetPoopColor = Color3.fromRGB(112, 66, 20),
	PetPoopMaterial = Enum.Material.SmoothPlastic,
	PetPoopSize = 1,
	PetPoopHeightRatio = 0.55,
	PetPoopLiftRatio = 0.2,
	PetPoopLifetime = 1.4,
	PetPoopGemFormat = "+%d 💎",
	PetPoopGemTextSize = 30,
	PetPoopGemColor = Color3.fromRGB(120, 230, 255),
	PetPoopGemLifetime = 1.2,
	PetPoopGemRise = 4,
	PetPoopGemGuiWidth = 180,
	PetPoopGemGuiHeight = 50,
	PetPoopGemHeight = 1.6,

	SoundCombo = "Combo",
	SoundMilestone = "Milestone",
	SoundPetReveal = "PetReveal",
	SoundPetPoop = "PetPoop",
}
