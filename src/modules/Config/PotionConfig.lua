--!strict

--[[
	PotionConfig
	Lobby and persistent timed boost potions consumed from inventory. Pure data, no functions.

	Fields:
		Potions: table of potion definitions keyed by potion id
			DisplayName: human-readable potion name (text)
			Icon: emoji or short icon string (text)
			Duration: active duration when consumed (seconds)
			Multiplier: boost multiplier applied to the target stat (multiplier)
			Stat: stat boosted ("Lifespan" | "Speed" | "StainSize")
			Description: description of what the potion does (text)
]]

local PotionConfig = {}

PotionConfig.Potions = {
	LifespanPotion = {
		DisplayName = "Lifespan Potion",
		Icon = "⏳",
		Duration = 600, -- 10 minutes
		Multiplier = 2,
		Stat = "Lifespan",
		Description = "x2 Lifespan duration for 10 minutes",
	},
	SpeedPotion = {
		DisplayName = "Speed Potion",
		Icon = "⚡",
		Duration = 900, -- 15 minutes
		Multiplier = 2,
		Stat = "Speed",
		Description = "x2 WalkSpeed for 15 minutes",
	},
	StinkPotion = {
		DisplayName = "Stink Potion",
		Icon = "💨",
		Duration = 900, -- 15 minutes
		Multiplier = 2,
		Stat = "StainSize",
		Description = "x2 Stain size for 15 minutes",
	},
}

return PotionConfig
