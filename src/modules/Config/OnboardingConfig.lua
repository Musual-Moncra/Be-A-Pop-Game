--!strict

--[[
	OnboardingConfig
	Text, steps, target names, timings, sizes and colours of the five-step first-run
	onboarding. Pure data, no functions. Sizes are UIConfig design pixels; positions are
	screen scale 0..1 inside the safe area.

	Fields:
		FirstStep / MaxStep: first and final saved tutorial step, MaxStep = finished (step)
		StepPlay / StepStain / StepSplat / StepLifespan / StepPet: saved step numbers (step)
		SkipStep: remote value that ends the tutorial from any step (remote value)
		StainCells: new stain cells that finish the stain hint (count)
		LifespanSeconds: lifespan below which the upgrade hint unlocks (seconds)
		RemoteRetrySeconds: time before an unconfirmed step advance is sent again (seconds)
		FollowUpdateSeconds: how often a UI target is looked up again (seconds)
		WorldTargetRefresh: how often the nearest soilable prop is recomputed (seconds)
		Text: every hint line and the skip label (text)
		InterfaceNames: candidate GUI names per target, first visible one wins (names)
			Play: PLAY button in the play window
			Upgrades: upgrades button in the lobby dock
			Pets: pets button in the lobby dock
			Menu: MENU button that opens the lobby dock row
		Fallbacks: screen scale point used when the target GUI or prop is not on screen
			Play / Upgrades / Pets / Soil: X and Y inside the safe area (scale 0..1)
		PanelX: hint panel horizontal centre on screen (scale 0..1)
		PanelYInRun: hint panel centre while a run is active (scale 0..1)
		PanelYResult: hint panel centre on the result screen (scale 0..1)
		PanelDockGap: gap kept between the panel bottom and the tallest open dock item (design pixels)
		PanelWidth / PanelHeight: hint panel size (design pixels)
		PanelMargin: smallest gap kept from the safe-area edge (design pixels)
		PanelRadius / PanelPadding: corner radius and inner padding (design pixels)
		PanelColor / PanelTransparency: panel fill (RGB, 0 to 1)
		PanelStrokeColor / PanelStrokeThickness: panel outline (RGB, design pixels)
		TextSize / TextColor: hint line (design pixels, RGB)
		SkipWidth / SkipHeight / SkipRadius / SkipTextSize: small skip pill (design pixels)
		SkipGap: gap between the hint line and the skip button (design pixels)
		ArrowText / ArrowTextSize / ArrowBoxSize / ArrowColor: bouncing pointer (text, design
			pixels, RGB)
		ArrowStrokeColor: pointer outline (RGB)
		ArrowOffsetY: pointer distance above the target centre (design pixels)
		BounceHeight / BounceSpeed: pointer bounce (design pixels, cycles/second)
		RingSize / RingWorldSize: pulse ring diameter for a GUI target / a prop (design pixels)
		RingPadding / RingThickness: ring gap around the target and outline width (design pixels)
		RingColor / RingTransparency: ring outline (RGB, 0 to 1)
		RingPulseAmount / RingPulseSpeed: ring size wobble and speed (multiplier, cycles/second)
]]

return {
	FirstStep = 1,
	StepPlay = 1,
	StepStain = 2,
	StepSplat = 3,
	StepLifespan = 4,
	StepPet = 5,
	MaxStep = 6,
	SkipStep = 255,
	StainCells = 30,
	LifespanSeconds = 10,
	RemoteRetrySeconds = 2,
	FollowUpdateSeconds = 0.25,
	WorldTargetRefresh = 0.3,

	Text = {
		Play = "Tap PLAY to become a poop!",
		Stain = "Roll over the floor to stain it!",
		Splat = "Splat people for big points!",
		Lifespan = "Upgrade Lifespan in the lobby to play longer",
		Pet = "Equip your pet to raise your Stink!",
		Skip = "Skip",
	},

	InterfaceNames = {
		Play = { "OnboardingPlayButton", "PlayButton" },
		Upgrades = { "OnboardingUpgradesButton", "UpgradesButton", "LobbyUpgradesButton" },
		Pets = { "OnboardingPetsButton", "PetsButton", "LobbyPetsButton" },
		Menu = { "OnboardingMenuButton", "MenuButton", "LobbyMenuButton" },
	},

	Fallbacks = {
		Play = { X = 0.5, Y = 0.9 },
		Upgrades = { X = 0.5, Y = 0.86 },
		Pets = { X = 0.5, Y = 0.86 },
		Soil = { X = 0.5, Y = 0.42 },
	},

	PanelX = 0.5,
	PanelYInRun = 0.6,
	PanelYResult = 0.9,
	PanelDockGap = 28,
	PanelWidth = 620,
	PanelHeight = 92,
	PanelMargin = 16,
	PanelRadius = 22,
	PanelPadding = 12,
	PanelColor = Color3.fromRGB(30, 24, 20),
	PanelTransparency = 0.08,
	PanelStrokeColor = Color3.fromRGB(255, 214, 40),
	PanelStrokeThickness = 3,
	TextSize = 22,
	TextColor = Color3.fromRGB(255, 255, 255),
	SkipWidth = 86,
	SkipHeight = 38,
	SkipRadius = 20,
	SkipTextSize = 16,
	SkipGap = 12,

	ArrowText = "⬇",
	ArrowTextSize = 44,
	ArrowBoxSize = 64,
	ArrowColor = Color3.fromRGB(255, 214, 40),
	ArrowStrokeColor = Color3.fromRGB(48, 26, 10),
	ArrowOffsetY = 70,
	BounceHeight = 10,
	BounceSpeed = 1.6,

	RingSize = 96,
	RingWorldSize = 96,
	RingPadding = 10,
	RingThickness = 4,
	RingColor = Color3.fromRGB(255, 214, 40),
	RingTransparency = 0.2,
	RingPulseAmount = 0.12,
	RingPulseSpeed = 1.2,
}
