--!strict

--[[
	RunUIConfig
	Look, layout and text of the extra run HUD pieces (map stain meter, Special Time banner,
	revive offer) and of the golden target glow. Swatch names are UIConfig.Swatches keys; sizes
	are UIConfig design pixels. Pure data, no functions.

	Fields:
		Meter: live "map stained" bar during a run
			Width / Height: bar size (design pixels)
			Swatch: fill colour (UIConfig.Swatches key)
			Format: bar text (format: percent with one decimal)
			BestFormat: caption under the bar (format: best percent)
		Event: Special Time banner, shown in the lobby and in runs
			Width / Height: banner size (design pixels)
			Swatch: banner colour (UIConfig.Swatches key)
			Format: banner text (format: map name, time left)
			TimeFormat: time left (format: minutes, seconds)
		Revive: revive offer popup when a timed run hits zero
			Width / Height: popup size (design pixels)
			Swatch: popup button colour (UIConfig.Swatches key)
			Title: popup title (text)
			ButtonFormat: buy button text (format: robux price)
			CountdownFormat: seconds left line (format: seconds)
		Layouts: per UIConfig layout ("PC" / "Mobile"), AnchorPoint + Position of Meter, Event and Revive
		Glow: highlight drawn on golden targets during a run
			FillColor / OutlineColor: highlight colours (RGB)
			FillTransparency / OutlineTransparency: highlight transparency (0 to 1)
			PulseSeconds: time of one fill pulse (seconds)
			PulseFillTransparency: most faded fill transparency during the pulse (0 to 1)
]]

local RunUIConfig = {}

RunUIConfig.Meter = {
	Width = 360,
	Height = 30,
	Swatch = "Brown",
	Format = "💩 MAP %.1f%%",
	BestFormat = "Best %.1f%%",
}

RunUIConfig.Event = {
	Width = 520,
	Height = 54,
	Swatch = "Gold",
	Format = "🌟 SPECIAL TIME: %s  %s",
	TimeFormat = "%d:%02d",
}

RunUIConfig.Revive = {
	Width = 480,
	Height = 230,
	Swatch = "Green",
	Title = "OUT OF TIME!",
	ButtonFormat = "💖 REVIVE  R$ %d",
	CountdownFormat = "%ds",
}

RunUIConfig.Layouts = {
	PC = {
		Meter = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 262) },
		Event = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 316) },
		Revive = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) },
	},
	Mobile = {
		Meter = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 236) },
		Event = { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 290) },
		Revive = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) },
	},
}

RunUIConfig.Glow = {
	FillColor = Color3.fromRGB(255, 214, 40),
	OutlineColor = Color3.fromRGB(255, 255, 200),
	FillTransparency = 0.45,
	OutlineTransparency = 0,
	PulseSeconds = 0.6,
	PulseFillTransparency = 0.8,
}

return RunUIConfig
