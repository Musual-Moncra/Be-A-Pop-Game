--!strict

--[[
	UIConfig
	Pure UI tokens and PC/Mobile layouts for HUD, PlayMenu and UpgradeMenu.
	No side effects; components and screens only read this table.

	Theme.Colors.Background: screen backdrop RGB (unused panels stay transparent)
	Theme.Colors.Panel: main panel background RGB
	Theme.Colors.Surface: cards, rows and inactive segments RGB
	Theme.Colors.Accent: the single highlight color RGB (primary actions, selection)
	Theme.Colors.AccentText: text/icon color drawn on Accent RGB
	Theme.Colors.Text: primary text RGB
	Theme.Colors.TextMuted: secondary text RGB
	Theme.Colors.Disabled: disabled control background RGB
	Theme.Colors.DisabledText: disabled control text RGB
	Theme.Colors.Success: positive value/accent RGB
	Theme.Colors.Danger: low-time warning RGB
	Theme.Colors.Overlay: modal dimmer RGB
	Theme.Colors.BarTrack: progress bar track RGB
	Theme.Fonts.Regular: Enum.Font for body text
	Theme.Fonts.Medium: Enum.Font for emphasized body text
	Theme.Fonts.Bold: Enum.Font for headings and buttons
	Theme.TextSizes.Title: screen title size in px
	Theme.TextSizes.Header: panel/section heading size in px
	Theme.TextSizes.CardTitle: card title size in px
	Theme.TextSizes.CardBody: card subtitle/description size in px
	Theme.TextSizes.Body: default body size in px
	Theme.TextSizes.Small: labels and metadata size in px
	Theme.TextSizes.ChipLabel: stat chip caption size in px
	Theme.TextSizes.ChipValue: stat chip value size in px
	Theme.TextSizes.Button: button label size in px
	Theme.TextSizes.Score: in-run score size in px
	Theme.TextSizes.Timer: in-run timer size in px
	Theme.TextSizes.Badge: lock/badge text size in px
	Theme.TextBounds.Min: minimum px for TextScaled labels
	Theme.TextBounds.Max: maximum px for TextScaled labels
	Theme.Radii.Small: small corner radius in px
	Theme.Radii.Medium: medium corner radius in px
	Theme.Radii.Large: panel corner radius in px
	Theme.Radii.Pill: fully rounded corner radius (scale)
	Theme.Spacing.XS: 4 px gaps and micro padding
	Theme.Spacing.S: 8 px gaps
	Theme.Spacing.M: 12 px gaps and row padding
	Theme.Spacing.L: 16 px panel padding and section gaps
	Theme.Spacing.XL: 24 px screen edge margin
	Theme.Sizes.NavButtonWidth: lobby nav button width in px
	Theme.Sizes.NavButtonHeight: lobby nav button height in px
	Theme.Sizes.NavGap: gap between lobby nav buttons in px
	Theme.Sizes.CardHeight: map card height in px
	Theme.Sizes.RowHeight: upgrade row height in px
	Theme.Sizes.SectionHeight: section caption height in px
	Theme.Sizes.DescriptionHeight: mode description height in px
	Theme.Sizes.ProgressHeight: progress bar height in px
	Theme.Sizes.BuyButtonWidth: upgrade buy button width in px
	Theme.Sizes.BuyButtonHeight: upgrade buy button height in px
	Theme.Sizes.TitleHeight: panel title height in px
	Theme.Sizes.PlayButtonHeight: primary PLAY button height in px
	Theme.Sizes.ResultChipHeight: result modal stat chip height in px
	Theme.Sizes.ScrollBarThickness: lobby panel scrollbar width in px
	Theme.Sizes.ScoreRowHeight: HUD score row height in px
	Theme.Sizes.ScoreCaptionWidth: HUD score caption width as a fraction of the panel
	Theme.Sizes.ScoreValueWidth: HUD score value width as a fraction of the panel
	Theme.Sizes.TimerHeight: HUD timer label height in px
	Theme.MobileMaxWidth: viewport width in px below which the Mobile layout is used
	Theme.ResultSeconds: seconds the run-result modal stays before auto-continue
	Theme.LowTimeRatio: timer fraction (0-1) at or below which the timer turns Danger
	Layouts.PC.HUD.CoinsChip.AnchorPoint: coins chip anchor (fraction of its size)
	Layouts.PC.HUD.CoinsChip.Position: coins chip position (scale/offset)
	Layouts.PC.HUD.CoinsChip.Size: coins chip size (scale/offset)
	Layouts.PC.HUD.CoinsChip.MaxSize: coins chip max pixel size
	Layouts.PC.HUD.CoinsChip.MinSize: coins chip min pixel size
	Layouts.PC.HUD.RunPanel.AnchorPoint: run panel anchor
	Layouts.PC.HUD.RunPanel.Position: run panel position
	Layouts.PC.HUD.RunPanel.Size: run panel size
	Layouts.PC.HUD.RunPanel.MaxSize: run panel max pixel size
	Layouts.PC.HUD.RunPanel.MinSize: run panel min pixel size
	Layouts.PC.Lobby.Nav.AnchorPoint: lobby nav frame anchor
	Layouts.PC.Lobby.Nav.Position: lobby nav frame position
	Layouts.PC.Lobby.Nav.Size: lobby nav frame size in px
	Layouts.PC.Lobby.PlayPanel.AnchorPoint: PlayMenu panel anchor
	Layouts.PC.Lobby.PlayPanel.Position: PlayMenu panel position
	Layouts.PC.Lobby.PlayPanel.Size: PlayMenu panel size
	Layouts.PC.Lobby.PlayPanel.MaxSize: PlayMenu panel max pixel size
	Layouts.PC.Lobby.PlayPanel.MinSize: PlayMenu panel min pixel size
	Layouts.PC.Lobby.UpgradePanel.AnchorPoint: UpgradeMenu panel anchor
	Layouts.PC.Lobby.UpgradePanel.Position: UpgradeMenu panel position
	Layouts.PC.Lobby.UpgradePanel.Size: UpgradeMenu panel size
	Layouts.PC.Lobby.UpgradePanel.MaxSize: UpgradeMenu panel max pixel size
	Layouts.PC.Lobby.UpgradePanel.MinSize: UpgradeMenu panel min pixel size
	Layouts.PC.Lobby.ResultCard.AnchorPoint: result modal card anchor
	Layouts.PC.Lobby.ResultCard.Position: result modal card position
	Layouts.PC.Lobby.ResultCard.Size: result modal card size
	Layouts.PC.Lobby.ResultCard.MaxSize: result modal card max pixel size
	Layouts.Mobile.HUD.CoinsChip.AnchorPoint: coins chip anchor (fraction of its size)
	Layouts.Mobile.HUD.CoinsChip.Position: coins chip position (scale/offset)
	Layouts.Mobile.HUD.CoinsChip.Size: coins chip size (scale/offset)
	Layouts.Mobile.HUD.CoinsChip.MaxSize: coins chip max pixel size
	Layouts.Mobile.HUD.CoinsChip.MinSize: coins chip min pixel size
	Layouts.Mobile.HUD.RunPanel.AnchorPoint: run panel anchor
	Layouts.Mobile.HUD.RunPanel.Position: run panel position
	Layouts.Mobile.HUD.RunPanel.Size: run panel size
	Layouts.Mobile.HUD.RunPanel.MaxSize: run panel max pixel size
	Layouts.Mobile.HUD.RunPanel.MinSize: run panel min pixel size
	Layouts.Mobile.Lobby.Nav.AnchorPoint: lobby nav frame anchor
	Layouts.Mobile.Lobby.Nav.Position: lobby nav frame position
	Layouts.Mobile.Lobby.Nav.Size: lobby nav frame size in px
	Layouts.Mobile.Lobby.PlayPanel.AnchorPoint: PlayMenu bottom-sheet anchor
	Layouts.Mobile.Lobby.PlayPanel.Position: PlayMenu bottom-sheet position
	Layouts.Mobile.Lobby.PlayPanel.Size: PlayMenu bottom-sheet size
	Layouts.Mobile.Lobby.PlayPanel.MaxSize: PlayMenu bottom-sheet max pixel size
	Layouts.Mobile.Lobby.UpgradePanel.AnchorPoint: UpgradeMenu bottom-sheet anchor
	Layouts.Mobile.Lobby.UpgradePanel.Position: UpgradeMenu bottom-sheet position
	Layouts.Mobile.Lobby.UpgradePanel.Size: UpgradeMenu bottom-sheet size
	Layouts.Mobile.Lobby.UpgradePanel.MaxSize: UpgradeMenu bottom-sheet max pixel size
	Layouts.Mobile.Lobby.ResultCard.AnchorPoint: result modal card anchor
	Layouts.Mobile.Lobby.ResultCard.Position: result modal card position
	Layouts.Mobile.Lobby.ResultCard.Size: result modal card size
	Layouts.Mobile.Lobby.ResultCard.MaxSize: result modal card max pixel size
	Layouts.Mobile.Lobby.ResultCard.MinSize: result modal card min pixel size
	Text.CoinsLabel: coins chip caption
	Text.ScoreLabel: in-run score caption
	Text.TimeFormat: timer string with seconds (string.format)
	Text.Practice: label shown instead of the timer in Practice mode
	Text.PlayTitle: PlayMenu title
	Text.PlaySubtitle: PlayMenu subheading
	Text.MapSection: map section caption
	Text.ModeSection: mode section caption
	Text.ComingSoon: disabled map badge
	Text.PlayButton: primary lobby button
	Text.UpgradesTitle: UpgradeMenu title
	Text.NavPlay: lobby nav button for PlayMenu
	Text.NavUpgrades: lobby nav button for UpgradeMenu
	Text.Maxed: buy button label at max level
	Text.PriceFormat: buy button label with cost in coins (string.format)
	Text.UpgradeDetail: upgrade level and current value line (string.format)
	UIConfig.UpgradeOrder: display order of upgrade ids in UpgradeMenu
	Text.ValueFormats.Lifespan: lifespan value format in seconds
	Text.ValueFormats.Speed: speed value format in studs/second
	Text.ValueFormats.StainSize: stain size value format in studs
	Text.UpgradeNames.Lifespan: display name for the Lifespan upgrade
	Text.UpgradeNames.Speed: display name for the Speed upgrade
	Text.UpgradeNames.StainSize: display name for the StainSize upgrade
	Text.ResultTitle: run-result modal title
	Text.Continue: result modal button
	Text.SelectionPending: hint shown while SelectRun waits for server confirmation
]]

local UIConfig = {}

UIConfig.Theme = {
	Colors = {
		Background = Color3.fromRGB(24, 22, 20),
		Panel = Color3.fromRGB(34, 31, 27),
		Surface = Color3.fromRGB(45, 41, 36),
		Accent = Color3.fromRGB(230, 166, 76),
		AccentText = Color3.fromRGB(24, 22, 20),
		Text = Color3.fromRGB(245, 239, 230),
		TextMuted = Color3.fromRGB(166, 156, 143),
		Disabled = Color3.fromRGB(58, 53, 47),
		DisabledText = Color3.fromRGB(120, 112, 102),
		Success = Color3.fromRGB(123, 201, 139),
		Danger = Color3.fromRGB(224, 108, 94),
		Overlay = Color3.fromRGB(0, 0, 0),
		BarTrack = Color3.fromRGB(58, 53, 47),
	},
	Fonts = {
		Regular = Enum.Font.Gotham,
		Medium = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
	},
	TextSizes = {
		Title = 26,
		Header = 18,
		CardTitle = 17,
		CardBody = 13,
		Body = 15,
		Small = 12,
		ChipLabel = 10,
		ChipValue = 16,
		Button = 16,
		Score = 30,
		Timer = 13,
		Badge = 11,
	},
	TextBounds = {
		Min = 10,
		Max = 28,
	},
	Radii = {
		Small = UDim.new(0, 6),
		Medium = UDim.new(0, 10),
		Large = UDim.new(0, 16),
		Pill = UDim.new(1, 0),
	},
	Spacing = {
		XS = 4,
		S = 8,
		M = 12,
		L = 16,
		XL = 24,
	},
	Sizes = {
		NavButtonWidth = 108,
		NavButtonHeight = 36,
		NavGap = 8,
		CardHeight = 64,
		RowHeight = 84,
		SectionHeight = 16,
		DescriptionHeight = 40,
		ProgressHeight = 8,
		BuyButtonWidth = 112,
		BuyButtonHeight = 40,
		TitleHeight = 30,
		PlayButtonHeight = 46,
		ResultChipHeight = 46,
		ScrollBarThickness = 4,
		ScoreRowHeight = 30,
		ScoreCaptionWidth = 0.4,
		ScoreValueWidth = 0.6,
		TimerHeight = 16,
	},
	MobileMaxWidth = 900,
	ResultSeconds = 3.5,
	LowTimeRatio = 0.25,
}

local Theme = UIConfig.Theme
local Spacing = Theme.Spacing

UIConfig.Layouts = {
	PC = {
		HUD = {
			CoinsChip = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(Spacing.XL, 20),
				Size = UDim2.fromScale(0.14, 0.06),
				MaxSize = Vector2.new(200, 48),
				MinSize = Vector2.new(150, 40),
			},
			RunPanel = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 20),
				Size = UDim2.fromScale(0.26, 0.1),
				MaxSize = Vector2.new(360, 112),
				MinSize = Vector2.new(260, 96),
			},
		},
		Lobby = {
			Nav = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -Spacing.XL, 0, 20),
				Size = UDim2.fromOffset(
					Theme.Sizes.NavButtonWidth * 2 + Theme.Sizes.NavGap,
					Theme.Sizes.NavButtonHeight
				),
			},
			PlayPanel = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.46, 0.72),
				MaxSize = Vector2.new(640, 640),
				MinSize = Vector2.new(480, 460),
			},
			UpgradePanel = {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -Spacing.XL, 0.5, 0),
				Size = UDim2.fromScale(0.32, 0.56),
				MaxSize = Vector2.new(440, 640),
				MinSize = Vector2.new(340, 360),
			},
			ResultCard = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(380, 270),
				MaxSize = Vector2.new(380, 280),
				MinSize = Vector2.new(320, 240),
			},
		},
	},
	Mobile = {
		HUD = {
			CoinsChip = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(Spacing.M, Spacing.M),
				Size = UDim2.fromScale(0.4, 0.055),
				MaxSize = Vector2.new(180, 44),
				MinSize = Vector2.new(132, 38),
			},
			RunPanel = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, Spacing.M, 0, 64),
				Size = UDim2.fromScale(0.72, 0.11),
				MaxSize = Vector2.new(320, 92),
				MinSize = Vector2.new(220, 80),
			},
		},
		Lobby = {
			Nav = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -Spacing.M, 0, 64),
				Size = UDim2.fromOffset(
					Theme.Sizes.NavButtonWidth * 2 + Theme.Sizes.NavGap,
					Theme.Sizes.NavButtonHeight
				),
			},
			PlayPanel = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -Spacing.M),
				Size = UDim2.new(1, -Spacing.XL, 0.72, -Spacing.L),
				MaxSize = Vector2.new(640, 700),
			},
			UpgradePanel = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -Spacing.M),
				Size = UDim2.new(1, -Spacing.XL, 0.72, -Spacing.L),
				MaxSize = Vector2.new(640, 700),
			},
			ResultCard = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0.86, 0, 0, 250),
				MaxSize = Vector2.new(360, 280),
				MinSize = Vector2.new(280, 230),
			},
		},
	},
}

UIConfig.UpgradeOrder = { "Lifespan", "Speed", "StainSize" }

UIConfig.Text = {
	CoinsLabel = "COINS",
	ScoreLabel = "SCORE",
	TimeFormat = "%.1fs",
	Practice = "PRACTICE",
	PlayTitle = "PLAY",
	PlaySubtitle = "Choose a map and mode",
	MapSection = "MAP",
	ModeSection = "MODE",
	ComingSoon = "COMING SOON",
	PlayButton = "PLAY",
	UpgradesTitle = "UPGRADES",
	NavPlay = "Play",
	NavUpgrades = "Upgrades",
	Maxed = "MAX",
	PriceFormat = "%d coins",
	UpgradeDetail = "Lv %d / %d  ·  %s",
	ValueFormats = {
		Lifespan = "%.0fs",
		Speed = "%.0f",
		StainSize = "%.1f studs",
	},
	UpgradeNames = {
		Lifespan = "Lifespan",
		Speed = "Speed",
		StainSize = "StainSize",
	},
	ResultTitle = "RUN COMPLETE",
	Continue = "CONTINUE",
	SelectionPending = "Confirming selection...",
}

return UIConfig
