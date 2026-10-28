--!strict

--[[
	GoldenTargetConfig
	Golden targets: random props that pay gems and extra points once fully soiled. Pure data.

	Fields:
		Chance: probability that a run has any golden targets, 0 = never, 1 = always (probability)
		MinCount: fewest golden targets picked when a run rolls them (count)
		MaxCount: most golden targets picked when a run rolls them (count)
		GemReward: gems paid for each golden target fully soiled (gems)
		PointsMultiplier: extra score for a golden target, as a multiple of the object's SoilBonus (multiplier)
]]

local GoldenTargetConfig = {}

GoldenTargetConfig.Chance = 0.5
GoldenTargetConfig.MinCount = 1
GoldenTargetConfig.MaxCount = 3
GoldenTargetConfig.GemReward = 3
GoldenTargetConfig.PointsMultiplier = 2

return GoldenTargetConfig
