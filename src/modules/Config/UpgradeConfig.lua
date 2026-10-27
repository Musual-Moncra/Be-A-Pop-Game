--!strict

--[[
	UpgradeConfig
	Permanent upgrades bought with coins. Pure data, no functions.

	How the numbers are used:
		Price to go from level L to level L + 1 = CostBase * CostGrowth ^ L, rounded down (coins)
		Stat value at level L                   = Base + PerLevel * L

	Fields:
		Upgrades: one table per upgrade, keyed by upgrade id (the id is saved in player data)
			DisplayName: name shown on the upgrade card (text)
			Description: what the upgrade does, shown on the upgrade card (text)
			Order: position in the upgrade list, 1 = first (number)
			Icon: emoji or short text drawn as the card icon (text)
			ValueFormat: how the stat is printed, %s is replaced by the number (text)
			Base: stat value at level 0 (unit depends on upgrade, see below)
			PerLevel: stat gained per level (same unit as Base)
			CostBase: price of the first level (coins)
			CostGrowth: each level costs this many times more than the previous (multiplier)
			MaxLevel: highest level that can be bought (level)

	Units per upgrade:
		Lifespan: run length in Classic and Quests (seconds)
		Speed: walking speed (studs/second)
		StainSize: width of one stain splat (studs)
		CoinBonus: extra coins on every reward (percent, 10 = +10%)
		PowerupDuration: how long eaten food lasts (multiplier on PowerupConfig Duration)
]]

local UpgradeConfig = {}

UpgradeConfig.Upgrades = {
	Lifespan = {
		DisplayName = "Lifespan",
		Description = "Stay fresh longer before you dry up.",
		Order = 1,
		Icon = "⏰",
		ValueFormat = "%ss",
		Base = 30,
		PerLevel = 3,
		CostBase = 25,
		CostGrowth = 1.45,
		MaxLevel = 25,
	},
	Speed = {
		DisplayName = "Speed",
		Description = "Slide across floors and walls faster.",
		Order = 2,
		Icon = "👟",
		ValueFormat = "%s studs/s",
		Base = 16,
		PerLevel = 1,
		CostBase = 25,
		CostGrowth = 1.5,
		MaxLevel = 20,
	},
	StainSize = {
		DisplayName = "Stain Size",
		Description = "Every splat covers a bigger area.",
		Order = 3,
		Icon = "💩",
		ValueFormat = "%s studs",
		Base = 4,
		PerLevel = 0.5,
		CostBase = 40,
		CostGrowth = 1.55,
		MaxLevel = 20,
	},
	CoinBonus = {
		DisplayName = "Golden Poop",
		Description = "Earn extra coins from every run.",
		Order = 4,
		Icon = "💰",
		ValueFormat = "+%s%",
		Base = 0,
		PerLevel = 10,
		CostBase = 100,
		CostGrowth = 1.7,
		MaxLevel = 15,
	},
	PowerupDuration = {
		DisplayName = "Big Appetite",
		Description = "Food boosts last longer.",
		Order = 5,
		Icon = "🍔",
		ValueFormat = "x%s",
		Base = 1,
		PerLevel = 0.1,
		CostBase = 75,
		CostGrowth = 1.6,
		MaxLevel = 10,
	},
}

return UpgradeConfig
