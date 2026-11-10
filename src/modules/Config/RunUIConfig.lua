--!strict

--[[
	RunUIConfig
	Look, layout and text of the run HUD, result screen and pet reveal. Swatch names are
	UIConfig.Swatches keys; sizes are UIConfig design pixels. Pure data, no functions.

	Fields:
		Lifespan: top-centre Lifespan pill during a run
			Width / Height: pill size (design pixels)
			IconSize: clock icon circle diameter (design pixels)
			Icon: clock emoji (text)
			TextSize: seconds label (design pixels)
			Format / Untimed: seconds text and the no-timer label (formats)
			SwatchHigh / SwatchMid / SwatchLow: fill colour above MidRatio, above the low
				threshold and below it (UIConfig.Swatches keys)
			MidRatio: ratio where the fill turns from green to gold (0 to 1)
			ShakeDegrees / ShakeSpeed: rotation wobble while low (degrees, cycles/second)
			ShakeScale: scale pulse while low (multiplier)
		Meter: map stain bar under the Lifespan pill
			Width / Height: bar size (design pixels)
			Swatch: fill colour (UIConfig.Swatches key)
			TrackTransparency: transparency of the Ink track behind the fill (0 to 1)
			Format: bar text (format: percent with one decimal)
			TextSize: bar label text size (design pixels)
			PoopIcon / PoopTextSize: icon riding above the fill edge (text, design pixels)
			PoopRise: gap between the bar top and the icon bottom (design pixels)
			PoopMinPercent: lowest percent that shows the riding icon (percent)
			Ticks: percent marks on the bar (percent)
			TickWidth / TickHeightRatio: tick line width and height as a share of the bar height
			TickColor / TickDoneColor: tick colour before / after the mark (RGB)
			TickPopScale / TickPopTime: tick punch when passed (multiplier, seconds)
			BestChip: "Best" chip right of the bar
				Width / Height: reserved size (design pixels)
				Swatch: chip colour (UIConfig.Swatches key)
				TextSize: chip text size (design pixels)
				Format: chip text (format: best percent)
			Gap: space between bar and chip (design pixels)
		Stack: vertical spacing of the top centre run HUD (design pixels)
			LifespanToMeter: gap under the Lifespan pill, also the space the riding poop icon uses
			MeterToCombo: gap under the map bar (also used by RunJuice)
		Score: top-right score card
			Width / MinHeight: card size (design pixels)
			CaptionTextSize / ScoreTextSize: caption and score text (design pixels)
			PunchScale / PunchTime: score punch on change (multiplier, seconds)
			StinkWidth / StinkHeight: Stink chip under the score (design pixels)
			StinkIconSize / StinkTextSize: Stink chip icon and label (design pixels)
		Quests: quest panel below the score card
			Width / RowHeight: panel width and one quest row height (design pixels)
		Powerups: active food power-up column at the left edge
			Size / Gap / TimerHeight: icon diameter, gap between slots and timer bar height (design pixels)
			TimerTextSize: seconds label on the timer bar (design pixels)
			Swatch / TimerSwatch: icon circle and timer bar colours (UIConfig.Swatches keys)
		Leave: small LEAVE pill at the bottom right
			Width / Height: pill size (design pixels)
		Event: Special Time banner, shown in the lobby and in runs
			Width / Height: banner size (design pixels)
			Swatch: banner colour (UIConfig.Swatches key)
			Icon: banner emoji (text)
			Format: banner text (format: map name, time left)
			TimeFormat: time left (format: minutes, seconds)
		Revive: revive offer popup when a timed run hits zero
			Width / Height: popup size (design pixels)
			Swatch: popup button colour (UIConfig.Swatches key)
			Icon: popup header emoji (text)
			Title: popup title (text)
			ButtonFormat: buy button text (format: seconds added, robux price)
			CountdownFormat: seconds left line (format: seconds)
		Result: end-of-run window
			Width: window width (design pixels)
			Icon: header emoji (text)
			RaysSize / RaysColor: sunburst behind the score (design pixels, RGB)
			RowHeight / RowIconSize: reward pill height and icon circle (design pixels)
			RowIconSwatch: icon circle colour inside a reward pill (UIConfig.Swatches key)
			ScoreTextSize / CaptionTextSize: score and caption text (design pixels)
			StinkChipHeight / StinkChipTextSize: Stink chip (design pixels)
			NewBestText / NewBestSwatch / NewBestHeight: NEW BEST stamp (text, swatch, design pixels)
			BadgeHeight / BadgesPerRow: result badge chips (design pixels, count)
			ContinueHeight: bottom CONTINUE button (design pixels)
		Reveal: full-screen pet drop reveal
			OverlayTransparency: dark overlay transparency (0 to 1)
			CardWidth / CardHeight: flip card size (design pixels)
			ShakeSeconds / FlipSeconds / FlipOvershoot: silhouette shake, flip and overshoot (seconds, multiplier)
			TapAfter: seconds after the flip before a tap closes it (seconds)
			RaysSize: rotating rays diameter behind the card (design pixels)
			Sparkles: star decorations around the card, each { X, Y, Size } (screen scale, design pixels)
			IconSize: pet icon well diameter (design pixels)
			LockedIcon: silhouette emoji (text)
			NameFormat / TraitFormat / StinkFormat / ConvertedFormat: card text (formats)
			NewTag / NewRibbonRotation: NEW ribbon text and tilt (text, degrees)
			CollectText / CollectWidth / CollectHeight / CollectSwatch: COLLECT button (text, design pixels, swatch)
		Layouts: per UIConfig layout ("PC" / "Mobile"), AnchorPoint + Position of Event, Powerups,
			Quests and Revive
		NarrowWidth: safe widths below this move the Event banner to the bottom centre (design pixels)
		Narrow: Event AnchorPoint + Position used below NarrowWidth
		Glow: highlight drawn on golden targets during a run
			FillColor / OutlineColor: highlight colours (RGB)
			FillTransparency / OutlineTransparency: highlight transparency (0 to 1)
			PulseSeconds: time of one fill pulse (seconds)
			PulseFillTransparency: most faded fill transparency during the pulse (0 to 1)
]]

return {
	Lifespan = {
		Width = 420,
		Height = 56,
		IconSize = 44,
		Icon = "⏰",
		TextSize = 30,
		Format = "%.1fs",
		Untimed = "NO TIMER",
		SwatchHigh = "Green",
		SwatchMid = "Gold",
		SwatchLow = "Red",
		MidRatio = 0.5,
		ShakeDegrees = 2.5,
		ShakeSpeed = 16,
		ShakeScale = 1.03,
	},

	Meter = {
		Width = 360,
		Height = 36,
		Swatch = "Brown",
		TrackTransparency = 0.35,
		Format = "MAP %.1f%%",
		TextSize = 20,
		PoopIcon = "💩",
		PoopTextSize = 20,
		PoopRise = 0,
		PoopMinPercent = 15,
		Ticks = { 25, 50, 75 },
		TickWidth = 3,
		TickHeightRatio = 0.62,
		TickColor = Color3.fromRGB(255, 255, 255),
		TickDoneColor = Color3.fromRGB(255, 236, 140),
		TickPopScale = 1.9,
		TickPopTime = 0.24,
		BestChip = {
			Width = 150,
			Height = 34,
			Swatch = "Gold",
			TextSize = 16,
			Format = "Best %.0f%%",
		},
		Gap = 10,
	},

	Stack = {
		LifespanToMeter = 24,
		MeterToCombo = 2,
	},

	Score = {
		Width = 260,
		MinHeight = 110,
		CaptionTextSize = 16,
		ScoreTextSize = 64,
		PunchScale = 1.25,
		PunchTime = 0.25,
		StinkWidth = 150,
		StinkHeight = 36,
		StinkIconSize = 18,
		StinkTextSize = 18,
	},

	Quests = {
		Width = 330,
		RowHeight = 56,
	},

	Powerups = {
		Size = 64,
		Gap = 8,
		TimerHeight = 22,
		TimerTextSize = 18,
		Swatch = "Purple",
		TimerSwatch = "Gold",
	},

	Leave = {
		Width = 132,
		Height = 48,
	},

	Event = {
		Width = 520,
		Height = 54,
		Swatch = "Gold",
		Icon = "🌟",
		Format = "SPECIAL TIME  %s  %s",
		TimeFormat = "%d:%02d",
	},

	Revive = {
		Width = 480,
		Height = 250,
		Swatch = "Green",
		Icon = "💖",
		Title = "OUT OF TIME!",
		ButtonFormat = "REVIVE +%ds  R$ %d",
		CountdownFormat = "%ds",
	},

	Result = {
		Width = 640,
		Icon = "🏁",
		RaysSize = 300,
		RaysColor = Color3.fromRGB(255, 236, 140),
		RowHeight = 64,
		RowIconSize = 44,
		RowIconSwatch = "Grey",
		ScoreTextSize = 64,
		CaptionTextSize = 16,
		StinkChipHeight = 36,
		StinkChipTextSize = 18,
		NewBestText = "NEW BEST!",
		NewBestSwatch = "Red",
		NewBestHeight = 40,
		BadgeHeight = 40,
		BadgesPerRow = 2,
		ContinueHeight = 84,
	},

	Reveal = {
		OverlayTransparency = 0.45,
		CardWidth = 600,
		CardHeight = 540,
		ShakeSeconds = 1.2,
		FlipSeconds = 0.35,
		FlipOvershoot = 1.06,
		TapAfter = 0.35,
		RaysSize = 900,
		Sparkles = {
			{ X = 0.26, Y = 0.28, Size = 46 },
			{ X = 0.74, Y = 0.24, Size = 38 },
			{ X = 0.2, Y = 0.62, Size = 32 },
			{ X = 0.8, Y = 0.66, Size = 42 },
		},
		IconSize = 180,
		PetIcon = "🐾",
		LockedIcon = "❔",
		NameFormat = "%s!",
		TraitFormat = "%s  •  %s",
		StinkFormat = "💩 Stink x%s",
		ConvertedFormat = "Bag full! +%d 💎 instead",
		NewTag = "NEW!",
		NewRibbonRotation = -12,
		CollectText = "COLLECT",
		CollectWidth = 360,
		CollectHeight = 72,
		CollectSwatch = "Green",
	},

	Layouts = {
		PC = {
			Event = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 210) },
			Powerups = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 28, 0, 24) },
			Quests = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 240) },
			Revive = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) },
		},
		Mobile = {
			Event = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196) },
			Powerups = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 16, 0, 12) },
			Quests = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 220) },
			Revive = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) },
		},
	},

	NarrowWidth = 1150,
	Narrow = {
		Event = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -180) },
	},

	Glow = {
		FillColor = Color3.fromRGB(255, 214, 40),
		OutlineColor = Color3.fromRGB(255, 255, 200),
		FillTransparency = 0.45,
		OutlineTransparency = 0,
		PulseSeconds = 0.6,
		PulseFillTransparency = 0.8,
	},
}
