--!strict

--[[
	ModeConfig
	Game modes and their rules. Pure data, no functions.

	Fields:
		DefaultModeId: mode selected for a new player and the fallback selection (mode id)
		Modes: list of modes, one table per mode
			Id: unique mode id (string)
			DisplayName: name shown on the mode button (text)
			Description: rules text shown when the mode is selected (text)
			Order: position in the mode list, 1 = first (number)
			Duration: run length; 0 = use the player's Lifespan upgrade, -1 = no timer (seconds)
			MaxDuration: hard stop for untimed runs so they cannot last forever, 0 = never (seconds)
			RewardMultiplier: multiplies coins and xp from score; 0 = this mode pays nothing (multiplier)
			PowerupsEnabled: food power-ups spawn during the run (true/false)
			NpcsEnabled: chefs patrol the map and cost you lifespan when they touch you (true/false)
			TargetScore: score to reach for the mode bonus, 0 = no target (points)
			TargetBonusCoins: coins paid once when TargetScore is reached (coins)
			TargetBonusGems: gems paid once when TargetScore is reached (gems)
			QuestCount: quests rolled at run start from QuestConfig, 0 = none (count)
			RequiredLevel: player level needed to pick this mode (level)
]]

local ModeConfig = {}

ModeConfig.DefaultModeId = "Classic"

ModeConfig.Modes = {
	{
		Id = "Classic",
		DisplayName = "Classic",
		Description = "Make a mess before your lifespan runs out. Eat food for boosts.",
		Order = 1,
		Duration = 0,
		MaxDuration = 0,
		RewardMultiplier = 1,
		PowerupsEnabled = true,
		NpcsEnabled = true,
		TargetScore = 0,
		TargetBonusCoins = 0,
		TargetBonusGems = 0,
		QuestCount = 0,
		RequiredLevel = 1,
	},
	{
		Id = "Quests",
		DisplayName = "Quests",
		Description = "Finish the run objectives for big bonus coins and gems.",
		Order = 2,
		Duration = 0,
		MaxDuration = 0,
		RewardMultiplier = 0.75,
		PowerupsEnabled = true,
		NpcsEnabled = true,
		TargetScore = 0,
		TargetBonusCoins = 0,
		TargetBonusGems = 0,
		QuestCount = 3,
		RequiredLevel = 2,
	},
	{
		Id = "Challenge",
		DisplayName = "Challenge",
		Description = "60 seconds, no power-ups. Hit the target score for a huge bonus.",
		Order = 3,
		Duration = 60,
		MaxDuration = 0,
		RewardMultiplier = 1.5,
		PowerupsEnabled = false,
		NpcsEnabled = true,
		TargetScore = 400,
		TargetBonusCoins = 500,
		TargetBonusGems = 10,
		QuestCount = 0,
		RequiredLevel = 3,
	},
	{
		Id = "Practice",
		DisplayName = "Practice",
		Description = "No timer, no chefs, no rewards. Learn to climb walls.",
		Order = 4,
		Duration = -1,
		MaxDuration = 600,
		RewardMultiplier = 0,
		PowerupsEnabled = true,
		NpcsEnabled = false,
		TargetScore = 0,
		TargetBonusCoins = 0,
		TargetBonusGems = 0,
		QuestCount = 0,
		RequiredLevel = 1,
	},
}

return ModeConfig
