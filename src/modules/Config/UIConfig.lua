--!strict

--[[
	UIConfig
	Every look, size, text and timing of the client UI. Pure data, no functions.
	Sizes are "design pixels" on a screen ReferenceHeight pixels tall; the whole UI is scaled to the
	real screen, so a value of 100 is always the same share of the screen on every device.

	Scale (the UI scale is the smaller of safe height / ReferenceHeight and safe width / ReferenceWidth):
		ReferenceHeight / ReferenceWidth: safe-area size the design pixels are drawn for on PC (pixels)
		MobileReferenceHeight / MobileReferenceWidth: same for phones/tablets, smaller = bigger UI (pixels)
		Min / Max: smallest / largest UI scale allowed (multiplier)
		MobileMaxWidth: safe areas narrower than this, or touch-only devices, use the Mobile layout (pixels)

	Fonts:
		Display / DisplayWeight: chunky font (asset path) and weight for titles, numbers and buttons
		Body / BodyWeight: font (asset path) and weight for descriptions

	Palette (RGB colours):
		Ink: text outline and darkest outline colour
		Text: main text colour
		TextSoft: secondary text on dark panels
		PanelTop / PanelBottom: top and bottom of the window body gradient
		PanelRim: thick outer rim of windows, HUD panels and scrollbars
		Inset: dark recessed boxes inside windows (bar tracks, lists, icon wells)
		InsetStroke: outline of recessed boxes
		Shadow: drop shadow colour
		Overlay: dimmer behind open windows
		Sparkle: sparkle stars, highlighted numbers and the selection ring
		Locked: lock overlay colour

	Swatches: colour sets for buttons, cards, chips, bars and icon circles. Each has Top (gradient top),
		Bottom (gradient bottom), Lip (3D bottom edge) and Stroke (outline), all RGB.
		Names: Orange, Blue, Purple, Green, Red, Gold, Grey, Pink, Teal, Brown.

	Shape (design pixels unless noted):
		Stroke: outline thickness of buttons, cards and pills
		RimStroke: outline thickness of windows and pill rims
		TextStroke / SmallTextStroke: outline thickness around big / small text
		Lip: height of the 3D bottom edge of buttons
		ShadowOffset: how far drop shadows sit below their box
		ShadowTransparency: drop shadow transparency (0 to 1)
		Radius / WindowRadius: corner radius of buttons and cards / of windows
		InsetTransparency: transparency of recessed boxes (0 to 1)
		OverlayTransparency: transparency of the window dimmer (0 to 1)
		LockedTransparency: transparency of lock overlays (0 to 1)
		DisabledTransparency: extra transparency on disabled buttons (0 to 1)
		BadgeStarTransparency: transparency of the faint star behind the level number (0 to 1)
		IconFill: emoji size as a fraction of its round icon (0 to 1)
		GradientRotation: direction of every gradient, 90 = top to bottom (degrees)
		LineHeight: height of one line of wrapped text as a multiple of its text size (multiplier)
		ContentPadding: space between a button's edge and its label (design pixels)
		ChipPadding: space on each side of a chip's text, as a fraction of the chip height (0 to 1)
		ScrollBar: thickness of list scrollbars, kept beside the content (design pixels)

	TextSizes (design pixels): Huge (scores), Title (window titles, big buttons), Header (card names,
		currency), Large (section titles, button labels), Body, Small, Tiny (chips, bar labels),
		Icon (emoji in tiles), BigIcon (emoji on the MENU button),
		Min (smallest size a shrink-to-fit label may reach)

	Animation (seconds unless noted):
		Press: button hover/press tween time
		PressScale / HoverScale: button size while pressed / hovered (multiplier)
		HoverGrowMax / PressShrinkMax: most a button may grow on hover / shrink on press, so large
			cards in lists never spill out of them (design pixels)
		Open: window, toast and menu pop-in time
		OpenFromScale: size a window or toast starts at when it opens (multiplier)
		MenuStagger: delay between menu wheel buttons popping out
		BarTween: progress bar fill tween time
		PopupRise: how far in-run popups float up (design pixels)
		SparkleSpeed: sparkle twinkle cycles per second (cycles/second)
		HudTick: how often power-up countdowns redraw
		ToastSeconds / PopupSeconds: how long a toast / in-run popup stays on screen
		ResultAutoCloseSeconds: result window closes by itself after this, 0 = never
		ToastMaxVisible: most toasts shown at once (count)
		LowTimeRatio: timer bar turns red at or below this fraction of the run (0 to 1)
		SpringStyle / SpringDirection: easing of pop-ins and button presses (Enum.EasingStyle / Direction)
		SmoothStyle / SmoothDirection: easing of bars and popups (Enum.EasingStyle / Direction)
		TwinkleStyle / TwinkleDirection: easing of sparkles (Enum.EasingStyle / Direction)

	Sizes (design pixels unless noted):
		Hud.Width: width of the wallet column (level, coins, gems)
		Hud.BadgeSize: gold level badge diameter
		Hud.XpBarHeight: XP bar height
		Hud.PillHeight / Hud.PillIconSize: coin/gem pill height / round icon diameter
		Hud.Gap: gap between wallet rows
		Menu.ButtonSize: round MENU button diameter
		Menu.ItemSize: diameter of each wheel button
		Menu.LabelHeight: height of the label under each wheel button
		Window.HeaderHeight: height of the ribbon title
		Window.CloseSize: red close button size
		Window.Padding: space between the window edge and its content
		Window.Gap: default gap between items inside windows
		Window.HeaderWidth: ribbon width as a fraction of the window (0 to 1)
		Window.CenterShift: window moves down by this fraction of the header height (0 to 1)
		Window.CloseInset: how far the close button sits inside the corner, fraction of its size (0 to 1)
		Window.Sparkles: stars around the ribbon; X = fraction of window width, Y = fraction of header
			height from the top edge, Size = TextSizes key, Delay = fraction of a twinkle cycle
		Play.Width / Play.Height: play window size (shrinks to fit small screens)
		Play.MapColumnWidth: width of the map list (at most half the window)
		Play.MapCardHeight: height of a map card
		Play.MapIconSize: round icon diameter on map cards
		Play.ModeTileHeight: height of a mode tile
		Play.ModeIconSize: emoji size above the mode name on a mode tile
		Play.ChipHeight: height of info chips (size, rewards, rules)
		Play.PlayButtonHeight: height of the PLAY and CONTINUE buttons
		Play.ActionButtonWidth / ActionButtonHeight: size of the UNLOCK price button; map card chips match its face height
		Upgrade.Width / Upgrade.Height: upgrade window size (shrinks to fit small screens)
		Upgrade.Columns: most upgrade cards per row (count); fewer when the window is narrow
		Upgrade.MinCardWidth: narrowest an upgrade card may get before a column is dropped
		Upgrade.DescriptionLines: lines of description text each card makes room for (count)
		Upgrade.IconSize: round icon diameter on upgrade cards
		Upgrade.BuyButtonHeight: height of the price button
		Upgrade.LevelBarHeight: height of the level bar
		Stats.Width / Stats.Height: stats window size
		Stats.RowHeight: height of a stat row
		Run.ScoreWidth: width of the score panel
		Run.TimerBarHeight: timer bar height
		Run.TargetBarHeight: height of target, quest and power-up bars
		Run.QuestWidth: width of the quest panel
		Run.QuestRowHeight: height of a quest row
		Run.PowerupSize: power-up icon diameter
		Run.LeaveWidth / Run.LeaveHeight: LEAVE button size
		Result.Width: result window width; its height follows its content
		Result.BadgesPerRow: badges that fit on one row, used to size the window (count)
		Result.RowHeight: height of a reward row
		Result.BadgeHeight: height of the level-up / target / quest badges
		Toast.Width / Toast.Height / Toast.Gap: toast size and the gap between stacked toasts
		Popup.Width / Popup.Height: size of a floating in-run popup

	Layouts.PC / Layouts.Mobile: where the big pieces sit. Each entry has AnchorPoint (fraction of its
		own size) and Position (scale of the screen + design-pixel offset):
		Wallet (level and currency), MenuButton, Toasts, RunScore, RunQuests, RunPowerups, RunLeave, Popups.
		WindowMargin: gap kept between a window and the screen edge (design pixels)

	MenuItems: buttons in the menu wheel, in order. Add a row to add a button.
		Id: unique id (string)
		Label: text under the button (text)
		Icon: emoji drawn in the button (text)
		Swatch: Swatches key used for the button colour (string)
		Route: window it opens: Play, Upgrades or Stats (string)
		AngleDegrees: direction from the MENU button, 0 = straight up, negative = left (degrees)
	MenuRadius: distance from the MENU button to the wheel buttons (design pixels)

	MapVisuals: per map id, Icon (emoji) and Swatch (colour) of its map card
	ModeVisuals: per mode id, Icon (emoji) and Swatch (colour) of its mode tile
	UpgradeSwatches: card colours cycled through the upgrade cards, in order (Swatches keys)
	PowerupSwatch: colour of power-up icons in the run HUD (Swatches key)
	ToastSwatches: per toast kind (Info, Success, Error), the Swatches key used

	Layers: drawing order, higher = on top (number): Wallet, RunHud, Extras (map meter, Special Time, revive), LobbyMenu, Backdrop (full-screen
		dimmer behind open windows), Window, Result, Toasts

	Text (every word the UI shows; %s = text, %d = whole number, %.1f = one decimal):
		Icons: MenuIcon, CloseIcon, SparkleIcon, CoinIcon, GemIcon, XpIcon, LockIcon, CheckIcon (emoji/text)
		IconLabel: how an icon and a word are joined, e.g. "💰 25" (format: icon, text)
		MenuButton: label on the MENU button
		LevelFormat: level next to the badge (format: level)
		XpFormat: text on the XP bar (format: xp, xp needed)
		MaxLevel: XP bar text at max level
		PlayTitle / MapsHeader / ModesHeader / RewardHeader: play window title and section titles
		SizeChip: map size chip (format: SizeLabel)
		RewardChip: map reward chip (format: multiplier)
		LockedModeFormat: locked mode tile (format: mode name, required level)
		Owned / ComingSoon / MapLocked: map state chips
		NeedMapFirst: requirement chip when the previous map is not owned (format: map name)
		NeedLevel: requirement chip when the level is too low (format: level)
		DurationLifespan / DurationSeconds / DurationNone: mode timer chip (DurationSeconds format: seconds)
		FoodOn / FoodOff / ChefsOn / ChefsOff: mode rule chips
		QuestsChip: quest count chip (format: count)
		TargetChip: target score chip (format: points)
		NoRewards: reward line for modes that pay nothing
		RewardTotal: reward multiplier line (format: multiplier)
		RewardTarget: target bonus line (format: coins, gems)
		RewardLines: how two reward lines are joined (format: line, line)
		PlayButton / PlayLocked: PLAY button text when playable / locked
		UpgradesTitle: upgrade window title
		UpgradeLevel: level bar text (format: level, max level)
		UpgradeArrow: current and next value (format: current, next)
		UpgradeMaxValue: value text at max level (format: value)
		Max: price button text at max level
		StatsTitle: stats window title
		StatRows: rows of the stats window; Key = save Stats key, Icon = emoji, Label = text
		ScoreLabel: caption over the run score
		TimerFormat: timer bar text (format: seconds)
		Untimed: timer bar text for untimed modes
		TargetFormat / TargetDone: Challenge target bar text (TargetFormat format: score, target)
		QuestsHeader: quest panel title
		QuestProgress: quest bar text (format: progress, target)
		PowerupTimer: power-up countdown (format: seconds)
		Leave: LEAVE button text
		ResultTitle / ResultTimeUp: result window title for a normal end / for running out of time
		ResultScore / ResultCoins / ResultGems / ResultXp: result captions
		ResultLevelUp: level-up badge (format: new level)
		ResultTarget: target-reached badge
		ResultQuests: quests badge (format: count)
		ResultSoiled: soiled objects badge (format: count)
		ResultPlus: reward amount (format: amount)
		Continue: result window button
		PowerupPickedFormat: popup when food is eaten (format: food name)
		ObjectSoiledFormat: popup when an object is fully soiled (format: object name, bonus points)
		ObjectUnknown: object name used when the type is missing
		ToastInfoKind / ToastSuccessKind / ToastErrorKind: toast kind names (must match ToastSwatches keys)
		ThousandsSuffixes: suffixes for big numbers: thousand, million, billion, trillion
		CompactFormat: big-number format (format: number, suffix)
		ThousandsSeparator: character between groups of three digits
		NegativeSign: sign put in front of negative numbers
		IntegerFormat: format of whole numbers

	Defaults.Level: level shown before the save data arrives (level)
]]

local UIConfig = {}

UIConfig.Scale = {
	ReferenceHeight = 900,
	ReferenceWidth = 1400,
	MobileReferenceHeight = 640,
	MobileReferenceWidth = 1100,
	Min = 0.4,
	Max = 1.5,
	MobileMaxWidth = 900,
}

UIConfig.Fonts = {
	Display = "rbxasset://fonts/families/FredokaOne.json",
	DisplayWeight = Enum.FontWeight.Regular,
	Body = "rbxasset://fonts/families/GothamSSm.json",
	BodyWeight = Enum.FontWeight.Bold,
}

UIConfig.Palette = {
	Ink = Color3.fromRGB(16, 14, 38),
	Text = Color3.fromRGB(255, 255, 255),
	TextSoft = Color3.fromRGB(186, 194, 240),
	PanelTop = Color3.fromRGB(58, 64, 132),
	PanelBottom = Color3.fromRGB(34, 36, 84),
	PanelRim = Color3.fromRGB(112, 86, 230),
	Inset = Color3.fromRGB(20, 20, 52),
	InsetStroke = Color3.fromRGB(14, 12, 34),
	Shadow = Color3.fromRGB(8, 6, 24),
	Overlay = Color3.fromRGB(10, 8, 30),
	Sparkle = Color3.fromRGB(255, 236, 140),
	Locked = Color3.fromRGB(14, 12, 34),
}

UIConfig.Swatches = {
	Orange = {
		Top = Color3.fromRGB(255, 170, 50),
		Bottom = Color3.fromRGB(246, 106, 22),
		Lip = Color3.fromRGB(178, 62, 10),
		Stroke = Color3.fromRGB(90, 32, 8),
	},
	Blue = {
		Top = Color3.fromRGB(96, 200, 255),
		Bottom = Color3.fromRGB(40, 128, 240),
		Lip = Color3.fromRGB(22, 76, 170),
		Stroke = Color3.fromRGB(14, 40, 100),
	},
	Purple = {
		Top = Color3.fromRGB(200, 120, 255),
		Bottom = Color3.fromRGB(132, 64, 236),
		Lip = Color3.fromRGB(84, 36, 168),
		Stroke = Color3.fromRGB(46, 18, 100),
	},
	Green = {
		Top = Color3.fromRGB(150, 240, 80),
		Bottom = Color3.fromRGB(64, 192, 46),
		Lip = Color3.fromRGB(34, 128, 30),
		Stroke = Color3.fromRGB(18, 70, 16),
	},
	Red = {
		Top = Color3.fromRGB(255, 110, 110),
		Bottom = Color3.fromRGB(228, 44, 60),
		Lip = Color3.fromRGB(150, 20, 36),
		Stroke = Color3.fromRGB(84, 10, 20),
	},
	Gold = {
		Top = Color3.fromRGB(255, 232, 90),
		Bottom = Color3.fromRGB(250, 172, 24),
		Lip = Color3.fromRGB(190, 112, 10),
		Stroke = Color3.fromRGB(100, 56, 6),
	},
	Grey = {
		Top = Color3.fromRGB(176, 184, 206),
		Bottom = Color3.fromRGB(110, 118, 146),
		Lip = Color3.fromRGB(70, 76, 100),
		Stroke = Color3.fromRGB(34, 38, 56),
	},
	Pink = {
		Top = Color3.fromRGB(255, 150, 210),
		Bottom = Color3.fromRGB(236, 80, 160),
		Lip = Color3.fromRGB(164, 40, 110),
		Stroke = Color3.fromRGB(90, 16, 60),
	},
	Teal = {
		Top = Color3.fromRGB(90, 240, 210),
		Bottom = Color3.fromRGB(24, 180, 170),
		Lip = Color3.fromRGB(10, 116, 112),
		Stroke = Color3.fromRGB(6, 62, 60),
	},
	Brown = {
		Top = Color3.fromRGB(196, 132, 70),
		Bottom = Color3.fromRGB(132, 80, 36),
		Lip = Color3.fromRGB(86, 50, 20),
		Stroke = Color3.fromRGB(48, 26, 10),
	},
}

UIConfig.Shape = {
	Stroke = 3,
	RimStroke = 5,
	TextStroke = 3,
	SmallTextStroke = 2,
	Lip = 6,
	ShadowOffset = 6,
	ShadowTransparency = 0.45,
	Radius = 16,
	WindowRadius = 26,
	InsetTransparency = 0.15,
	OverlayTransparency = 0.45,
	LockedTransparency = 0.35,
	DisabledTransparency = 0.25,
	BadgeStarTransparency = 0.78,
	IconFill = 0.55,
	GradientRotation = 90,
	LineHeight = 1.25,
	ContentPadding = 10,
	ChipPadding = 0.38,
	ScrollBar = 8,
}

UIConfig.TextSizes = {
	Huge = 64,
	Title = 40,
	Header = 30,
	Large = 26,
	Body = 20,
	Small = 17,
	Tiny = 16,
	Icon = 34,
	BigIcon = 56,
	Min = 11,
}

UIConfig.Animation = {
	Press = 0.08,
	PressScale = 0.9,
	HoverScale = 1.05,
	HoverGrowMax = 8,
	PressShrinkMax = 10,
	Open = 0.22,
	OpenFromScale = 0.82,
	MenuStagger = 0.04,
	BarTween = 0.25,
	PopupRise = 60,
	SparkleSpeed = 0.7,
	HudTick = 0.1,
	ToastSeconds = 3,
	PopupSeconds = 1.8,
	ResultAutoCloseSeconds = 0,
	ToastMaxVisible = 3,
	LowTimeRatio = 0.25,
	SpringStyle = Enum.EasingStyle.Back,
	SpringDirection = Enum.EasingDirection.Out,
	SmoothStyle = Enum.EasingStyle.Quad,
	SmoothDirection = Enum.EasingDirection.Out,
	TwinkleStyle = Enum.EasingStyle.Sine,
	TwinkleDirection = Enum.EasingDirection.InOut,
}

UIConfig.Sizes = {
	Hud = {
		Width = 330,
		BadgeSize = 92,
		XpBarHeight = 34,
		PillHeight = 58,
		PillIconSize = 74,
		Gap = 14,
	},
	Menu = {
		ButtonSize = 128,
		ItemSize = 100,
		LabelHeight = 30,
	},
	Window = {
		HeaderHeight = 74,
		CloseSize = 62,
		Padding = 22,
		Gap = 16,
		HeaderWidth = 0.62,
		CenterShift = 0.25,
		CloseInset = 0.2,
		Sparkles = {
			{ X = 0.19, Y = -0.45, Size = "Large", Delay = 0 },
			{ X = 0.81, Y = 0.4, Size = "Body", Delay = 0.33 },
		},
	},
	Play = {
		Width = 1180,
		Height = 720,
		MapColumnWidth = 560,
		MapCardHeight = 150,
		MapIconSize = 96,
		ModeTileHeight = 104,
		ModeIconSize = 42,
		ChipHeight = 34,
		PlayButtonHeight = 92,
		ActionButtonWidth = 130,
		ActionButtonHeight = 44,
	},
	Upgrade = {
		Width = 1100,
		Height = 760,
		Columns = 3,
		MinCardWidth = 300,
		DescriptionLines = 2,
		IconSize = 76,
		BuyButtonHeight = 50,
		LevelBarHeight = 18,
	},
	Stats = {
		Width = 620,
		Height = 480,
		RowHeight = 62,
	},
	Run = {
		ScoreWidth = 420,
		TimerBarHeight = 30,
		TargetBarHeight = 20,
		QuestWidth = 360,
		QuestRowHeight = 62,
		PowerupSize = 84,
		LeaveWidth = 170,
		LeaveHeight = 64,
	},
	Result = {
		Width = 620,
		BadgesPerRow = 2,
		RowHeight = 64,
		BadgeHeight = 44,
	},
	Toast = {
		Width = 560,
		Height = 58,
		Gap = 10,
	},
	Popup = {
		Width = 520,
		Height = 56,
	},
}

UIConfig.Layouts = {
	PC = {
		Wallet = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 28, 0, 24) },
		MenuButton = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30) },
		Toasts = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24) },
		RunScore = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20) },
		RunQuests = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 24) },
		RunPowerups = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 28, 0, 330) },
		RunLeave = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28) },
		Popups = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200) },
		WindowMargin = 40,
	},
	Mobile = {
		Wallet = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 16, 0, 12) },
		MenuButton = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16) },
		Toasts = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12) },
		RunScore = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10) },
		RunQuests = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12) },
		RunPowerups = { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16) },
		RunLeave = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16) },
		Popups = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 180) },
		WindowMargin = 16,
	},
}

UIConfig.MenuItems = {
	{ Id = "Play", Label = "PLAY", Icon = "▶️", Swatch = "Green", Route = "Play", AngleDegrees = -50 },
	{ Id = "Upgrades", Label = "UPGRADES", Icon = "⚡", Swatch = "Blue", Route = "Upgrades", AngleDegrees = 0 },
	{ Id = "Stats", Label = "STATS", Icon = "🏆", Swatch = "Purple", Route = "Stats", AngleDegrees = 50 },
}

UIConfig.MenuRadius = 170

UIConfig.MapVisuals = {
	Zone1 = { Icon = "🍳", Swatch = "Orange" },
	Zone2 = { Icon = "🛍️", Swatch = "Pink" },
	Zone3 = { Icon = "🌳", Swatch = "Green" },
	Zone4 = { Icon = "🏨", Swatch = "Gold" },
}

UIConfig.ModeVisuals = {
	Classic = { Icon = "💩", Swatch = "Brown" },
	Quests = { Icon = "📜", Swatch = "Teal" },
	Challenge = { Icon = "🔥", Swatch = "Red" },
	Practice = { Icon = "🎯", Swatch = "Grey" },
}

UIConfig.UpgradeSwatches = { "Orange", "Blue", "Purple", "Teal", "Pink", "Green" }
UIConfig.PowerupSwatch = "Purple"

UIConfig.ToastSwatches = {
	Info = "Blue",
	Success = "Green",
	Error = "Red",
}

UIConfig.Layers = {
	Wallet = 1,
	RunHud = 2,
	Extras = 2,
	LobbyMenu = 3,
	Backdrop = 4,
	Window = 5,
	Result = 6,
	Toasts = 7,
}

UIConfig.Text = {
	MenuButton = "MENU",
	MenuIcon = "💩",
	CloseIcon = "X",
	SparkleIcon = "✨",
	CoinIcon = "💰",
	GemIcon = "💎",
	XpIcon = "⭐",
	LockIcon = "🔒",
	CheckIcon = "✅",
	LevelFormat = "LVL %d",
	IconLabel = "%s %s",
	XpFormat = "%s / %s XP",
	MaxLevel = "MAX LEVEL",

	PlayTitle = "CHOOSE YOUR MESS",
	MapsHeader = "MAPS",
	ModesHeader = "GAME MODE",
	RewardHeader = "REWARDS",
	SizeChip = "SIZE %s",
	RewardChip = "x%s REWARDS",
	LockedModeFormat = "%s\nLVL %d",
	Owned = "OWNED",
	ComingSoon = "COMING SOON",
	MapLocked = "LOCKED",
	NeedMapFirst = "Unlock %s first",
	NeedLevel = "Reach level %d",
	DurationLifespan = "⏰ Lifespan",
	DurationSeconds = "⏰ %ds",
	DurationNone = "⏰ No timer",
	FoodOn = "🍔 Food",
	FoodOff = "🚫 No food",
	ChefsOn = "👨‍🍳 Chefs",
	ChefsOff = "😴 No chefs",
	QuestsChip = "📜 %d quests",
	TargetChip = "🎯 %d pts",
	NoRewards = "No rewards in this mode",
	RewardTotal = "Coins & XP x%s",
	RewardTarget = "Target bonus: %s 💰  %s 💎",
	RewardLines = "%s\n%s",
	PlayButton = "PLAY!",
	PlayLocked = "LOCKED",

	UpgradesTitle = "UPGRADES",
	UpgradeLevel = "LV %d / %d",
	UpgradeArrow = "%s  ➡️  %s",
	UpgradeMaxValue = "%s",
	Max = "MAX",

	StatsTitle = "STATS",
	StatRows = {
		{ Key = "BestScore", Icon = "🏆", Label = "Best score" },
		{ Key = "TotalRuns", Icon = "🏃", Label = "Runs played" },
		{ Key = "ObjectsSoiled", Icon = "💩", Label = "Objects soiled" },
		{ Key = "PowerupsEaten", Icon = "🍔", Label = "Food eaten" },
		{ Key = "QuestsCompleted", Icon = "📜", Label = "Quests completed" },
	},

	ScoreLabel = "SCORE",
	TimerFormat = "%.1fs",
	Untimed = "NO TIMER",
	TargetFormat = "TARGET %s / %s",
	TargetDone = "TARGET REACHED!",
	QuestsHeader = "QUESTS",
	QuestProgress = "%s / %s",
	PowerupTimer = "%ds",
	Leave = "LEAVE",

	ResultTitle = "RUN COMPLETE!",
	ResultTimeUp = "TIME'S UP!",
	ResultScore = "SCORE",
	ResultCoins = "Coins",
	ResultGems = "Gems",
	ResultXp = "XP",
	ResultLevelUp = "LEVEL UP!  LVL %d",
	ResultTarget = "TARGET REACHED",
	ResultQuests = "%d QUESTS DONE",
	ResultSoiled = "%d objects soiled",
	ResultPlus = "+%s",
	Continue = "CONTINUE",

	PowerupPickedFormat = "Yum! %s",
	ObjectSoiledFormat = "%s soiled! +%d",
	ObjectUnknown = "Object",
	ToastInfoKind = "Info",
	ToastSuccessKind = "Success",
	ToastErrorKind = "Error",
	ThousandsSuffixes = { "K", "M", "B", "T" },
	CompactFormat = "%.1f%s",
	ThousandsSeparator = ",",
	NegativeSign = "-",
	IntegerFormat = "%d",
}

UIConfig.Defaults = {
	Level = 1,
}

return UIConfig
