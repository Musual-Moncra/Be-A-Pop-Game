--!strict

--[[
	LobbyUIConfig
	Look, layout and text of the lobby HUD (side button rail, big PLAY button), the lobby
	station prompts and the feature windows opened from them. Swatch names are
	UIConfig.Swatches keys; sizes are UIConfig design pixels. Pure data, no functions.

	Fields:
		Rail: left column of big square buttons
			ButtonSize: side of one button (design pixels)
			LabelHeight: height of the caption under a button (design pixels)
			Gap: space between two buttons (design pixels)
			PerColumn: buttons stacked in one column before the next column starts (count)
			BadgeSize: diameter of the red notification dot (design pixels)
			Items: one row per button, top to bottom
				Id: unique key (string)
				Label: caption under the button (text)
				Icon: emoji on the button face (text)
				Swatch: button colour (UIConfig.Swatches key)
				Route: LobbyState route the button opens (LobbyState.Routes key)
		PlayButton: the big PLAY button at the bottom of the screen
			Width / Height: button size (design pixels)
			Label: button text (text)
			Icon: emoji left of the text (text)
			Swatch: button colour (UIConfig.Swatches key)
			Route: LobbyState route it opens (LobbyState.Routes key)
		Rays: rotating sunburst drawn behind highlighted buttons
			Count: number of rays (count)
			Thickness: width of one ray (design pixels)
			Color: ray colour (RGB)
			Transparency: transparency at the centre of a ray (0 to 1)
			SpinSeconds: time for one full turn (seconds)
			SizeRatio: ray length as a multiple of the button size (multiplier)
		Bounce: idle bounce of highlighted buttons
			Scale: largest extra scale at the top of a bounce (multiplier)
			Seconds: length of one bounce (seconds)
		Badge: notification dot
			Text: text in the dot (text)
			Swatch: dot colour (UIConfig.Swatches key)
			PulseScale: largest scale of the pulse (multiplier)
			PulseSeconds: length of one pulse (seconds)
		Layouts: per UIConfig layout ("PC" / "Mobile"), AnchorPoint + Position of Rail and PlayButton
		Stations: lobby booths, keyed by the LobbyStation attribute on their Prompt part
			Route: LobbyState route opened by the prompt (LobbyState.Routes key)
			ActionText: prompt action text (text)
			ObjectText: prompt object text (text)
		StationPrompt: ProximityPrompt tuning for every station
			HoldDuration: hold time before it triggers (seconds)
			MaxActivationDistance: how close the player must be (studs)
			KeyCode: keyboard key (Enum.KeyCode)
		Daily: daily reward window
			Width / Height: window size (design pixels)
			Columns: day tiles per row (count)
			TileHeight: height of one day tile (design pixels)
			ClaimHeight: height of the claim button (design pixels)
			RaysRatio: size of the sunburst behind today's tile as a multiple of TileHeight (multiplier)
			Swatch: window header colour (UIConfig.Swatches key)
			KindVisuals: per reward Kind ("Coins", "Gems", "Boost", "Skin"), Icon (emoji) and Swatch
			Title: window title (text)
			DayFormat: caption on each tile (format: day number)
			Claim: claim button text (text)
			NextFormat: button text while waiting (format: hh:mm:ss)
			Claimed: stamp on claimed tiles (text)
			StreakFormat: streak line under the tiles (format: streak, streak length)
]]

local LobbyUIConfig = {}

LobbyUIConfig.Rail = {
	ButtonSize = 92,
	LabelHeight = 26,
	Gap = 12,
	PerColumn = 4,
	BadgeSize = 34,
	Items = {
		{ Id = "Shop", Label = "SHOP", Icon = "🛒", Swatch = "Gold", Route = "Shop" },
		{ Id = "Pets", Label = "PETS", Icon = "🐶", Swatch = "Blue", Route = "Pets" },
		{ Id = "Skins", Label = "SKINS", Icon = "🎨", Swatch = "Purple", Route = "Skins" },
		{ Id = "Daily", Label = "DAILY", Icon = "🎁", Swatch = "Pink", Route = "Daily" },
		{ Id = "Upgrades", Label = "UPGRADE", Icon = "⚡", Swatch = "Orange", Route = "Upgrades" },
		{ Id = "Rebirth", Label = "REBIRTH", Icon = "🌀", Swatch = "Teal", Route = "Rebirth" },
		{ Id = "Stats", Label = "STATS", Icon = "🏆", Swatch = "Grey", Route = "Stats" },
	},
}

LobbyUIConfig.PlayButton = {
	Width = 280,
	Height = 100,
	Label = "PLAY!",
	Icon = "💩",
	Swatch = "Green",
	Route = "Play",
}

LobbyUIConfig.Rays = {
	Count = 10,
	Thickness = 26,
	Color = Color3.fromRGB(255, 244, 160),
	Transparency = 0.35,
	SpinSeconds = 9,
	SizeRatio = 1.7,
}

LobbyUIConfig.Bounce = {
	Scale = 0.06,
	Seconds = 1.1,
}

LobbyUIConfig.Badge = {
	Text = "!",
	Swatch = "Red",
	PulseScale = 1.18,
	PulseSeconds = 0.7,
}

LobbyUIConfig.Layouts = {
	PC = {
		Rail = { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 28, 0.58, 0) },
		PlayButton = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34) },
	},
	Mobile = {
		Rail = { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.6, 0) },
		PlayButton = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -20) },
	},
}

LobbyUIConfig.Stations = {
	Upgrades = { Route = "Upgrades", ActionText = "Upgrade", ObjectText = "Upgrade Stand" },
	Eggs = { Route = "Pets", ActionText = "Hatch", ObjectText = "Pet Eggs" },
	Crates = { Route = "Skins", ActionText = "Open", ObjectText = "Skin Crates" },
	Daily = { Route = "Daily", ActionText = "Claim", ObjectText = "Daily Gift" },
	Rebirth = { Route = "Rebirth", ActionText = "Rebirth", ObjectText = "Golden Poop" },
}

LobbyUIConfig.StationPrompt = {
	HoldDuration = 0,
	MaxActivationDistance = 14,
	KeyCode = Enum.KeyCode.E,
}

LobbyUIConfig.Daily = {
	Width = 980,
	Height = 600,
	Columns = 4,
	TileHeight = 170,
	ClaimHeight = 80,
	RaysRatio = 1.4,
	Swatch = "Pink",
	KindVisuals = {
		Coins = { Icon = "💰", Swatch = "Gold" },
		Gems = { Icon = "💎", Swatch = "Purple" },
		Boost = { Icon = "🚀", Swatch = "Blue" },
		Skin = { Icon = "👑", Swatch = "Pink" },
	},
	Title = "DAILY GIFTS",
	DayFormat = "DAY %d",
	Claim = "CLAIM!",
	NextFormat = "NEXT IN %s",
	Claimed = "✅",
	StreakFormat = "Streak: %d / %d days",
}

return LobbyUIConfig
