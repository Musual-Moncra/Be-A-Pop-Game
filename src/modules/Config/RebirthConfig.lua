--!strict

--[[
	RebirthConfig
	Balance tuning for the rebirth system. Pure data, no functions.

	Fields:
		BaseCost: coins required for the first rebirth (coins)
		CostGrowth: exponential scale factor per prior rebirth (multiplier)
		MultiplierPerRebirth: permanent bonus to coins and stink per rebirth (percent, 0.25 = +25%)
		GemsPerRebirth: gems awarded upon rebirth (gems)
		ResetUnlockedMaps: whether rebirth also resets unlocked maps back to Zone1 (boolean)
]]

return {
	BaseCost = 50000,

	CostGrowth = 2.5,

	MultiplierPerRebirth = 0.25,

	GemsPerRebirth = 25,

	ResetUnlockedMaps = false,
}
