--!strict

--[[
	DailyRewardConfig
	Daily login streak tuning and the 7-day reward table. Pure data, no functions.

	Fields:
		StreakLength: days in one reward cycle; the day after the last wraps back to 1 (days)
		ClaimCooldown: earliest time between two accepted claims (seconds)
		StreakResetAfter: silence after the last claim that breaks the streak (seconds)
		ClaimToast: toast text after a claim, %s = the claimed day's Label (text)
		Days: one entry per cycle day, index = day number 1..StreakLength
			Kind: reward type, "Coins" | "Gems" | "Boost" | "Skin" (string)
			Amount: coins or gems granted, 0 for Boost and Skin days (coins/gems)
			BoostId: Boosts key granted when Kind is "Boost", "" otherwise (boost id)
			Duration: boost length granted by this day, 0 = the boost's default (seconds)
			SkinId: save id written to OwnedSkins when Kind is "Skin", "" otherwise (skin id)
			Label: short player-facing text for the day tile (text)
		Boosts: timed boosts the streak can grant, keyed by boost id
			Multiplier: reward multiplier DataService.GetBoostMultiplier reports while active (multiplier)
			Duration: default length of one boost (seconds)
]]

local DailyRewardConfig = {}

DailyRewardConfig.StreakLength = 7
DailyRewardConfig.ClaimCooldown = 20 * 60 * 60
DailyRewardConfig.StreakResetAfter = 48 * 60 * 60
DailyRewardConfig.ClaimToast = "%s claimed!"

DailyRewardConfig.Days = {
	{ Kind = "Coins", Amount = 100, BoostId = "", Duration = 0, SkinId = "", Label = "100 Coins" },
	{ Kind = "Coins", Amount = 250, BoostId = "", Duration = 0, SkinId = "", Label = "250 Coins" },
	{ Kind = "Gems", Amount = 5, BoostId = "", Duration = 0, SkinId = "", Label = "5 Gems" },
	{ Kind = "Boost", Amount = 0, BoostId = "Coins", Duration = 60 * 60, SkinId = "", Label = "2x Coins for 1h" },
	{ Kind = "Coins", Amount = 500, BoostId = "", Duration = 0, SkinId = "", Label = "500 Coins" },
	{ Kind = "Gems", Amount = 15, BoostId = "", Duration = 0, SkinId = "", Label = "15 Gems" },
	{ Kind = "Skin", Amount = 0, BoostId = "", Duration = 0, SkinId = "DailyStreak7", Label = "Exclusive Skin" },
}

DailyRewardConfig.Boosts = {
	Coins = {
		Multiplier = 2,
		Duration = 60 * 60,
	},
}

return DailyRewardConfig
