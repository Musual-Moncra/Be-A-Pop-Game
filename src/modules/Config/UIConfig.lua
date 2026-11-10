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
		MinTouchTarget: smallest clickable control on a touch device (design pixels)

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
		GlossHeightRatio / GlossTransparency / GlossInset: button gloss top share, its transparency
			and its inset from the edge (0 to 1, 0 to 1, design pixels)
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
		HoverRotate: how far a hovered button tilts (degrees)
		HoverGrowMax / PressShrinkMax: most a button may grow on hover / shrink on press, so large
			cards in lists never spill out of them (design pixels)
		Open: window, toast and dock button pop-in time
		OpenFromScale: size a window or toast starts at when it opens (multiplier)
		Close / CloseFromScale: window close tween time and end scale (seconds, multiplier)
		OverlayFade: window dimmer fade time (seconds)
		ShineSeconds / ShineInterval: one shine sweep and the wait between sweeps (seconds)
		ShineWidthRatio / ShineTransparency / ShineRotation: sweep bar width share, opacity and tilt
		CountUpSeconds: currency count-up time (seconds)
		NumberPunchScale / NumberPunchSeconds: currency punch size and time (multiplier, seconds)
		IdleBobHeight / IdleBobSeconds: icon-tile bob height and cycle (design pixels, seconds)
		BarTween: progress bar fill tween time
		SparkleSpeed: sparkle twinkle cycles per second (cycles/second)
		HudTick: how often power-up countdowns redraw
		ToastSeconds / PopupSeconds: how long a toast / in-run popup stays on screen
		PopupMaxVisible: most in-run popups stacked on screen at once (count)
		ResultAutoCloseSeconds: result window closes by itself after this, 0 = never
		ResultCountSeconds: score and coin numbers count up over this time (seconds)
		ToastMaxVisible: most toasts shown at once (count)
		LowTimeRatio: timer bar turns red at or below this fraction of the run (0 to 1)
		SpringStyle / SpringDirection: easing of pop-ins and button presses (Enum.EasingStyle / Direction)
		SmoothStyle / SmoothDirection: easing of bars and popups (Enum.EasingStyle / Direction)
		TwinkleStyle / TwinkleDirection: easing of sparkles (Enum.EasingStyle / Direction)

	Sizes (design pixels unless noted):
		Hud.BadgeSize: level badge diameter in the lobby top bar (design pixels)
		Hud.XpRingSize / XpRingThickness / XpRingSegments: XP ring diameter, band width and segment count
		Hud.PillWidth / PillHeight / PillIconSize: coin and gem pill width, height and icon diameter
		Hud.StinkWidth / StinkHeight / StinkIconSize: Stink pill width, height and icon diameter
		Hud.PlusSize / PlusGap: green plus button size and its gap from the pill edge
		Hud.StinkSwatch: Stink pill colour (UIConfig.Swatches key)
		Hud.Gap: gap between top-bar items
		Hud.Mobile*: same fields scale for the phone top bar (sizes design pixels)
		Window.HeaderHeight: height of the ribbon title
		Window.CloseSize: red close button size
		Window.Padding: space between the window edge and its content
		Window.Gap: default gap between items inside windows
		Window.HeaderWidth: ribbon width as a fraction of the window (0 to 1)
		Window.CenterShift: window moves down by this fraction of the header height (0 to 1)
		Window.CloseInset: how far the close button sits inside the corner, fraction of its size (0 to 1)
		Window.Sparkles: stars around the ribbon; X = fraction of window width, Y = fraction of header
			height from the top edge, Size = TextSizes key, Delay = fraction of a twinkle cycle
		RarityGradients: per rarity id, Top / Mid / Bottom / Lip colours of a rarity card
		RarityEffects: per rarity id, RotateSeconds (animated gradient) / ShineSeconds / Sparkles count
		RaritySparkles: star positions on a sparkled rarity card (X, Y, Size key, Delay)
		Play.Width / Play.Height: play window size (shrinks to fit small screens)
		Play.MapColumnWidth: width of the map list (at most half the window)
		Play.MapCardHeight: height of a map card
		Play.MapIconSize: round icon diameter on map cards
		Play.ModeTileHeight: height of a mode tile
		Play.ModeIconSize: emoji size above the mode name on a mode tile
		Play.ChipHeight: height of info chips (size, rewards, rules)
		Play.PlayButtonHeight: height of the PLAY and CONTINUE buttons
		Play.QuickCardHeight / QuickIconSize: quick-play map card height and icon diameter (design pixels)
		Play.QuickButtonHeight / QuickPlayWidth / QuickFriendsWidth: quick-play card button row height
			and the widths of PLAY / PLAY WITH FRIENDS (design pixels)
		Play.ActionButtonWidth / ActionButtonHeight: size of the UNLOCK price button; map card chips match its face height
		Play.DescriptionLines: wrapped description lines a map or mode block makes room for (count)
		Play.ModeColumns: mode tiles per row (count)
		Play.NarrowWidth: windows narrower than this stack maps and modes in one scroll (design pixels)
		Room.ActionHeight: height of the CREATE / SAVE action in the window footer
		Room.RowHeight / FriendRowHeight: height of a member row / an invite friend row
		Room.BrowseRowHeight / BrowseIconSize: height of a room browser row / its map icon diameter
		Room.JoinWidth / JoinHeight: JOIN button size on a browser row
		Room.PlayerOptionWidth / PlayerOptionHeight: size of one room-size selector button
		Room.ToggleWidth / ToggleHeight: size of the friends-only switch
		Room.SummaryIconSize: map icon diameter in the room summary
		Room.PillWidth / PillHeight / PillIconSize: lobby room pill size and its icon
		Room.PillButtonWidth / PillButtonHeight: OPEN / JOIN button on a pill
		Room.PillDismissSize: dismiss button on an invite pill
		Room.FooterHeight: height of the room window footer (hint and action buttons)
		Room.KickWidth / KickHeight: KICK button size on a member row
		Room.InviteWidth / InviteHeight: INVITE button size on a friend row
		Upgrade.Width / Upgrade.Height: upgrade window size (shrinks to fit small screens)
		Upgrade.Columns: most upgrade cards per row (count); fewer when the window is narrow
		Upgrade.MinCardWidth: narrowest an upgrade card may get before a column is dropped
		Upgrade.DescriptionLines: lines of description text each card makes room for (count)
		Upgrade.IconSize: round icon diameter on upgrade cards
		Upgrade.BuyButtonHeight: height of the price button
		Upgrade.LevelBarHeight: height of the level bar
		Run.ScoreWidth: width of the score panel (top right)
		Run.TimerWidth: width of the lifespan panel (top centre)
		Run.TimerBarHeight: lifespan bar height
		Run.TargetBarHeight: height of target, quest and power-up bars
		Run.QuestWidth: width of the quest panel
		Run.QuestRowHeight: height of a quest row
		Run.LeaveWidth / Run.LeaveHeight: LEAVE button size
		Run.NarrowWidth: below this safe width the score moves to the top-right and the quest panel drops under it (design pixels)
		Run.NarrowScoreTop: top of the score panel in the narrow run layout (design pixels)
		Run.NarrowQuestTop: top of the quest panel in the narrow run layout (design pixels)
		Result.Width: result window width; its height follows its content
		Result.BadgesPerRow: badges that fit on one row, used to size the window (count)
		Result.RowHeight: height of a reward row
		Result.BadgeHeight: height of the level-up / target / quest badges
		Result.BaseRows: rows above the badges (caption, score, stink line, three rewards, badge block) (count)
		Toast.Width / Toast.Height / Toast.Gap: toast size and the gap between stacked toasts
		Popup.Width / Popup.Height / Popup.Gap: size of a floating in-run popup and the gap
			between two stacked popups (design pixels)

	Layouts.PC / Layouts.Mobile: where the big pieces sit. Each entry has AnchorPoint (fraction of its
		own size) and Position (scale of the screen + design-pixel offset):
		Wallet (the centred lobby top bar), Toasts, RunTimer, RunScore, RunQuests, RunLeave, Popups,
		RoomPills (room and invite prompts).
		WindowMargin: gap kept between a window and the screen edge (design pixels)

	MapVisuals: per map id, Icon (emoji) and Swatch (colour) of its map card
	ModeVisuals: per mode id, Icon (emoji) and Swatch (colour) of its mode tile
	UpgradeSwatches: card colours cycled through the upgrade cards, in order (Swatches keys)
	ToastSwatches: per toast kind (Info, Success, Error), the Swatches key used

	Layers: drawing order, higher = on top (number): Wallet, RunHud, Juice (combo meter, milestone banners), Extras (map meter, Special Time, revive), LobbyMenu, Backdrop (full-screen
		dimmer behind open windows), Window, Result, Toasts, Reveal (pet drop), Onboarding (tutorial hints)

	Text (every word the UI shows; %s = text, %d = whole number, %.1f = one decimal):
		Icons: CloseIcon, SparkleIcon, CoinIcon, GemIcon, XpIcon, LockIcon, CheckIcon (emoji/text)
		IconLabel: how an icon and a word are joined, e.g. "💰 25" (format: icon, text)
		LevelFormat: level next to the badge (format: level)
		XpFormat: text on the XP bar (format: xp, xp needed)
		MaxLevel: XP bar text at max level
		PlayTitle / MapsHeader / ModesHeader / RewardHeader: play window title and section titles
		SizeChip: map size chip (format: SizeLabel)
		RewardChip: map reward chip (format: multiplier)
		LockedModeFormat: locked mode tile (format: mode name, required level)
		Owned / ComingSoon / MapLocked: map state chips
		NeedMapFirst: requirement chip when the previous map is not owned (format: map name)
		RequireCompleteFormat: requirement chip when the previous map is not cleared 100%% (format: map name)
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
		PlayTab / CreateTab / BrowseTab / RoomTab: play window view tabs
		QuickPlay / PlayWithFriends: quick-play card buttons (text)
		PlayersHeader: room-size section title
		FriendsOnly: friends-only switch label
		CreateRoom / EditSettings / SaveSettings / BackSettings: room form buttons
		EmptyRooms: room browser empty state
		BrowseHostFormat / BrowseDetailsFormat / BrowsePlayersFormat: browser row lines (host, map + mode, players)		FriendsBadge: badge on a browser row whose host is a friend
		Join / JoinFull: browser JOIN button when open / full
		RoomTitle / RoomPlayersFormat: room view title and player count
		RoomPublic / RoomFriendsOnly: room privacy chip
		MembersHeader / HostMark / ReadyMark / WaitingMark: member list title and marks
		InviteHeader / NoFriends / Invite: invite list title, empty state and button
		Kick / LeaveRoom: member kick and room leave buttons
		ReadyButton / UnreadyButton / StartButton: room action buttons
		StartHint / SoloStartHint / WaitingText / CountdownFormat: room status lines (countdown format: seconds)
		RoomPillFormat / RoomPillOpen: lobby room pill (map, players, max) and open button
		InvitePillFormat / InviteToastFormat / InvitePillJoin / DismissIcon: invite prompt and toast
		UpgradesTitle: upgrade window title
		UpgradeLevel: level bar text (format: level, max level)
		UpgradeArrow: current and next value (format: current, next)
		UpgradeMaxValue: value text at max level (format: value)
		Max: price button text at max level
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
		ResultStinkFormat: score and Stink line on the result window; the coin row below it is the server total (format: score, multiplier)
		StinkIcon / StinkPillFormat / StinkChipFormat: Stink pill icon and full / short text
			(format: multiplier with two decimals)
		PlusIcon: text on the small green plus button beside coins/gems (text)
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

return {
	Scale = {
		ReferenceHeight = 900,
		ReferenceWidth = 1400,
		MobileReferenceHeight = 640,
		MobileReferenceWidth = 1100,
		Min = 0.4,
		Max = 1.5,
		MobileMaxWidth = 900,
		MinTouchTarget = 44,
	},

	Fonts = {
		Display = "rbxasset://fonts/families/FredokaOne.json",
		DisplayWeight = Enum.FontWeight.Regular,
		Body = "rbxasset://fonts/families/GothamSSm.json",
		BodyWeight = Enum.FontWeight.Bold,
	},

	Palette = {
		Ink = Color3.fromRGB(27, 20, 64),
		Text = Color3.fromRGB(255, 255, 255),
		TextSoft = Color3.fromRGB(92, 102, 150),
		PanelTop = Color3.fromRGB(255, 255, 255),
		PanelBottom = Color3.fromRGB(222, 232, 255),
		PanelRim = Color3.fromRGB(27, 20, 64),
		Inset = Color3.fromRGB(196, 210, 245),
		InsetStroke = Color3.fromRGB(150, 165, 215),
		Shadow = Color3.fromRGB(27, 20, 64),
		Overlay = Color3.fromRGB(27, 20, 64),
		Sparkle = Color3.fromRGB(255, 236, 140),
		Locked = Color3.fromRGB(27, 20, 64),
	},

	Swatches = {
		Orange = {
			Top = Color3.fromRGB(255, 200, 90),
			Mid = Color3.fromRGB(255, 150, 40),
			Bottom = Color3.fromRGB(240, 100, 20),
			Lip = Color3.fromRGB(170, 60, 10),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Blue = {
			Top = Color3.fromRGB(120, 215, 255),
			Mid = Color3.fromRGB(60, 165, 255),
			Bottom = Color3.fromRGB(35, 110, 235),
			Lip = Color3.fromRGB(20, 70, 170),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Purple = {
			Top = Color3.fromRGB(205, 150, 255),
			Mid = Color3.fromRGB(160, 95, 250),
			Bottom = Color3.fromRGB(115, 55, 220),
			Lip = Color3.fromRGB(75, 30, 160),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Green = {
			Top = Color3.fromRGB(140, 255, 90),
			Mid = Color3.fromRGB(70, 220, 60),
			Bottom = Color3.fromRGB(30, 170, 40),
			Lip = Color3.fromRGB(16, 110, 30),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Red = {
			Top = Color3.fromRGB(255, 130, 130),
			Mid = Color3.fromRGB(245, 70, 80),
			Bottom = Color3.fromRGB(200, 35, 55),
			Lip = Color3.fromRGB(140, 20, 35),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Gold = {
			Top = Color3.fromRGB(255, 240, 120),
			Mid = Color3.fromRGB(255, 205, 40),
			Bottom = Color3.fromRGB(240, 150, 15),
			Lip = Color3.fromRGB(175, 95, 5),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Grey = {
			Top = Color3.fromRGB(235, 240, 250),
			Mid = Color3.fromRGB(195, 205, 225),
			Bottom = Color3.fromRGB(150, 160, 190),
			Lip = Color3.fromRGB(105, 115, 145),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Pink = {
			Top = Color3.fromRGB(255, 160, 220),
			Mid = Color3.fromRGB(255, 100, 185),
			Bottom = Color3.fromRGB(225, 55, 150),
			Lip = Color3.fromRGB(160, 30, 105),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Teal = {
			Top = Color3.fromRGB(120, 255, 225),
			Mid = Color3.fromRGB(60, 220, 200),
			Bottom = Color3.fromRGB(30, 180, 165),
			Lip = Color3.fromRGB(15, 110, 100),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
		Brown = {
			Top = Color3.fromRGB(200, 140, 90),
			Mid = Color3.fromRGB(160, 100, 55),
			Bottom = Color3.fromRGB(120, 70, 35),
			Lip = Color3.fromRGB(80, 45, 20),
			Stroke = Color3.fromRGB(27, 20, 64),
		},
	},

	RarityGradients = {
		Common = {
			Top = Color3.fromRGB(225, 232, 245),
			Mid = Color3.fromRGB(190, 200, 222),
			Bottom = Color3.fromRGB(150, 160, 190),
			Lip = Color3.fromRGB(105, 115, 145),
		},
		Uncommon = {
			Top = Color3.fromRGB(165, 255, 150),
			Mid = Color3.fromRGB(90, 220, 90),
			Bottom = Color3.fromRGB(45, 170, 60),
			Lip = Color3.fromRGB(25, 110, 40),
		},
		Rare = {
			Top = Color3.fromRGB(150, 225, 255),
			Mid = Color3.fromRGB(80, 165, 255),
			Bottom = Color3.fromRGB(45, 105, 225),
			Lip = Color3.fromRGB(25, 65, 160),
		},
		Epic = {
			Top = Color3.fromRGB(225, 175, 255),
			Mid = Color3.fromRGB(175, 115, 250),
			Bottom = Color3.fromRGB(120, 60, 220),
			Lip = Color3.fromRGB(80, 30, 150),
		},
		Legendary = {
			Top = Color3.fromRGB(255, 250, 150),
			Mid = Color3.fromRGB(255, 210, 60),
			Bottom = Color3.fromRGB(240, 160, 20),
			Lip = Color3.fromRGB(175, 95, 5),
		},
		Mythical = {
			Top = Color3.fromRGB(255, 150, 220),
			Mid = Color3.fromRGB(255, 110, 190),
			Bottom = Color3.fromRGB(80, 230, 240),
			Lip = Color3.fromRGB(50, 150, 160),
		},
		Secret = {
			Top = Color3.fromRGB(35, 35, 45),
			Mid = Color3.fromRGB(145, 145, 160),
			Bottom = Color3.fromRGB(245, 245, 255),
			Lip = Color3.fromRGB(60, 60, 75),
		},
		Darkness = {
			Top = Color3.fromRGB(22, 12, 34),
			Mid = Color3.fromRGB(78, 45, 110),
			Bottom = Color3.fromRGB(42, 22, 72),
			Lip = Color3.fromRGB(15, 6, 28),
		},
	},

	RarityEffects = {
		Epic = { ShineSeconds = 6 },
		Legendary = { Sparkles = 3 },
		Mythical = { RotateSeconds = 6, Sparkles = 4 },
		Secret = { RotateSeconds = 6 },
		Darkness = { RotateSeconds = 6 },
	},

	RaritySparkles = {
		{ X = 0.2, Y = 0.24, Size = "Body", Delay = 0 },
		{ X = 0.78, Y = 0.18, Size = "Large", Delay = 0.3 },
		{ X = 0.5, Y = 0.5, Size = "Small", Delay = 0.55 },
		{ X = 0.3, Y = 0.72, Size = "Body", Delay = 0.8 },
	},

	Shape = {
		Stroke = 3,
		RimStroke = 4,
		TextStroke = 2.5,
		SmallTextStroke = 1.5,
		Lip = 6,
		ShadowOffset = 4,
		ShadowTransparency = 0.6,
		Radius = 16,
		WindowRadius = 22,
		InsetTransparency = 0,
		GlossHeightRatio = 0.45,
		GlossTransparency = 0.65,
		GlossInset = 3,
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
	},

	TextSizes = {
		Huge = 64,
		Title = 36,
		Header = 30,
		Large = 26,
		Body = 20,
		Small = 17,
		Tiny = 16,
		Icon = 34,
		BigIcon = 56,
		Min = 11,
	},

	Animation = {
		Press = 0.18,
		PressScale = 0.9,
		HoverScale = 1.07,
		HoverRotate = 2,
		HoverGrowMax = 8,
		PressShrinkMax = 10,
		Open = 0.32,
		OpenFromScale = 0.75,
		Close = 0.15,
		CloseFromScale = 0.85,
		OverlayFade = 0.2,
		ShineSeconds = 0.6,
		ShineInterval = 3.2,
		ShineWidthRatio = 0.18,
		ShineTransparency = 0.5,
		ShineRotation = 20,
		CountUpSeconds = 0.4,
		NumberPunchScale = 1.25,
		NumberPunchSeconds = 0.25,
		IdleBobHeight = 3,
		IdleBobSeconds = 1.6,
		BarTween = 0.25,
		SparkleSpeed = 0.7,
		HudTick = 0.1,
		ToastSeconds = 3,
		PopupSeconds = 1.8,
		PopupMaxVisible = 2,
		ResultAutoCloseSeconds = 0,
		ResultCountSeconds = 0.9,
		ToastMaxVisible = 3,
		LowTimeRatio = 0.25,
		SpringStyle = Enum.EasingStyle.Back,
		SpringDirection = Enum.EasingDirection.Out,
		SmoothStyle = Enum.EasingStyle.Quad,
		SmoothDirection = Enum.EasingDirection.Out,
		TwinkleStyle = Enum.EasingStyle.Sine,
		TwinkleDirection = Enum.EasingDirection.InOut,
	},

	Sizes = {
		Hud = {
			BadgeSize = 64,
			XpRingSize = 80,
			XpRingThickness = 6,
			XpRingSegments = 36,
			PillWidth = 220,
			PillHeight = 52,
			PillIconSize = 64,
			StinkWidth = 150,
			StinkHeight = 44,
			StinkIconSize = 52,
			PlusSize = 40,
			PlusGap = 6,
			StinkSwatch = "Brown",
			Gap = 12,
			MobileBadgeSize = 52,
			MobileRingSize = 68,
			MobileRingThickness = 5,
			MobilePillWidth = 170,
			MobilePillHeight = 44,
			MobilePillIconSize = 54,
			MobileStinkWidth = 120,
			MobileStinkHeight = 38,
			MobileStinkIconSize = 44,
			MobilePlusSize = 32,
			MobileGap = 8,
		},
		Window = {
			HeaderHeight = 64,
			CloseSize = 56,
			Padding = 22,
			Gap = 16,
			HeaderWidth = 0.64,
			CenterShift = 0.25,
			CloseInset = 0.2,
			Sparkles = {
				{ X = 0.16, Y = -0.42, Size = "Large", Delay = 0 },
				{ X = 0.84, Y = 0.36, Size = "Body", Delay = 0.33 },
				{ X = 0.5, Y = -0.55, Size = "Small", Delay = 0.66 },
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
			QuickCardHeight = 210,
			QuickIconSize = 84,
			QuickButtonHeight = 56,
			QuickPlayWidth = 170,
			QuickFriendsWidth = 300,
			ActionButtonWidth = 130,
			ActionButtonHeight = 44,
			DescriptionLines = 2,
			ModeColumns = 2,
			NarrowWidth = 1000,
		},
		Room = {
			ActionHeight = 84,
			RowHeight = 64,
			FriendRowHeight = 56,
			BrowseRowHeight = 108,
			BrowseIconSize = 72,
			JoinWidth = 140,
			JoinHeight = 64,
			PlayerOptionWidth = 64,
			PlayerOptionHeight = 52,
			ToggleWidth = 250,
			ToggleHeight = 52,
			SummaryIconSize = 64,
			PillWidth = 380,
			PillHeight = 76,
			PillIconSize = 54,
			PillButtonWidth = 96,
			PillButtonHeight = 52,
			PillDismissSize = 44,
			FooterHeight = 116,
			KickWidth = 96,
			KickHeight = 44,
			InviteWidth = 120,
			InviteHeight = 44,
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
		Run = {
			ScoreWidth = 300,
			TimerWidth = 340,
			TimerBarHeight = 44,
			TargetBarHeight = 20,
			QuestWidth = 360,
			QuestRowHeight = 62,
			LeaveWidth = 170,
			LeaveHeight = 64,
			NarrowWidth = 1150,
			NarrowScoreTop = 10,
			NarrowQuestTop = 190,
		},
		Result = {
			Width = 620,
			BadgesPerRow = 2,
			RowHeight = 64,
			BadgeHeight = 44,
			BaseRows = 7,
		},
		Toast = {
			Width = 560,
			Height = 58,
			Gap = 10,
		},
		Popup = {
			Width = 520,
			Height = 56,
			Gap = 8,
		},
	},

	Layouts = {
		PC = {
			Wallet = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12) },
			Toasts = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96) },
			RunTimer = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20) },
			RunScore = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 20) },
			RunQuests = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 200) },
			RunLeave = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28) },
			Popups = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200) },
			RoomPills = { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -28) },
			WindowMargin = 40,
		},
		Mobile = {
			Wallet = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8) },
			Toasts = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80) },
			RunTimer = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10) },
			RunScore = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 10) },
			RunQuests = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 190) },
			RunLeave = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16) },
			Popups = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 180) },
			RoomPills = { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12) },
			WindowMargin = 16,
		},
	},

	MapVisuals = {
		Zone1 = { Icon = "🍳", Swatch = "Orange" },
		Zone2 = { Icon = "🛍️", Swatch = "Pink" },
		Zone3 = { Icon = "🌳", Swatch = "Green" },
		Zone4 = { Icon = "🏨", Swatch = "Gold" },
	},

	ModeVisuals = {
		Classic = { Icon = "💩", Swatch = "Brown" },
		Quests = { Icon = "📜", Swatch = "Teal" },
		Challenge = { Icon = "🔥", Swatch = "Red" },
		Practice = { Icon = "🎯", Swatch = "Grey" },
	},

	UpgradeSwatches = { "Orange", "Blue", "Purple", "Teal", "Pink", "Green" },

	ToastSwatches = {
		Info = "Blue",
		Success = "Green",
		Error = "Red",
	},

	Layers = {
		Wallet = 1,
		RunHud = 2,
		Juice = 2,
		Extras = 2,
		LobbyMenu = 3,
		Backdrop = 4,
		Window = 5,
		Result = 6,
		Toasts = 7,
		Reveal = 8,
		Onboarding = 9,
	},

	Text = {
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
		RequireCompleteFormat = "Clear %s 100%% first",
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

		PlayTab = "PLAY",
		CreateTab = "CREATE",
		BrowseTab = "BROWSE",
		QuickPlay = "PLAY",
		PlayWithFriends = "PLAY WITH FRIENDS",
		RoomTab = "ROOM",
		PlayersHeader = "ROOM SIZE",
		FriendsOnly = "FRIENDS ONLY",
		CreateRoom = "CREATE ROOM",
		EditSettings = "EDIT",
		SaveSettings = "SAVE",
		BackSettings = "BACK",
		EmptyRooms = "No rooms open right now.\nCreate one and invite your friends!",
		BrowseHostFormat = "%s's room",
		BrowseDetailsFormat = "%s  •  %s",
		BrowsePlayersFormat = "%d/%d",
		FriendsBadge = "FRIENDS",
		Join = "JOIN",
		JoinFull = "FULL",
		RoomTitle = "YOUR ROOM",
		RoomPlayersFormat = "%d / %d",
		RoomPublic = "PUBLIC",
		RoomFriendsOnly = "FRIENDS ONLY",
		MembersHeader = "PLAYERS",
		HostMark = "HOST",
		ReadyMark = "READY",
		WaitingMark = "WAITING",
		InviteHeader = "INVITE FRIENDS",
		NoFriends = "No friends in this server to invite",
		Invite = "INVITE",
		Kick = "KICK",
		LeaveRoom = "LEAVE",
		ReadyButton = "READY",
		UnreadyButton = "UNREADY",
		StartButton = "START",
		StartHint = "Everyone must be ready",
		SoloStartHint = "You can start alone",
		WaitingText = "WAITING FOR PLAYERS",
		CountdownFormat = "STARTING IN %d",
		RoomPillFormat = "%s  %d/%d",
		RoomPillOpen = "OPEN",
		InvitePillFormat = "%s invited you",
		InviteToastFormat = "%s invited you to a room",
		InvitePillJoin = "JOIN",
		DismissIcon = "X",

		UpgradesTitle = "UPGRADES",
		UpgradeLevel = "LV %d / %d",
		UpgradeArrow = "%s  ➡️  %s",
		UpgradeMaxValue = "%s",
		Max = "MAX",

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
		ResultStinkFormat = "Score %s × Stink x%s",
		StinkIcon = "💩",
		StinkPillFormat = "x%.2f Stink",
		StinkChipFormat = "x%.2f",
		PlusIcon = "+",
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
	},

	Defaults = {
		Level = 1,
	},
}
