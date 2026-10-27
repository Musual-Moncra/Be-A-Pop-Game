--!strict

--[[
	UpgradeConfig
	Pure upgrade data. Balance changes live here, not in services.

	Cost to go from `lvl` to `lvl + 1`: floor(CostBase * CostGrowth ^ lvl)
	Stat value at `lvl`:                 Base + PerLevel * lvl
]]

export type UpgradeDefinition = {
	Base: number,
	PerLevel: number,
	CostBase: number,
	CostGrowth: number,
	MaxLevel: number,
}

local UpgradeConfig = {}

UpgradeConfig.Upgrades = {
	Lifespan = {
		Base = 30,
		PerLevel = 3,
		CostBase = 10,
		CostGrowth = 1.5,
		MaxLevel = 20,
	},
	Speed = {
		Base = 16,
		PerLevel = 1,
		CostBase = 10,
		CostGrowth = 1.5,
		MaxLevel = 20,
	},
	StainSize = {
		Base = 4,
		PerLevel = 0.5,
		CostBase = 10,
		CostGrowth = 1.5,
		MaxLevel = 20,
	},
} :: { [string]: UpgradeDefinition }

function UpgradeConfig.GetCost(id: string, lvl: number): number
	local upgrade = UpgradeConfig.Upgrades[id]
	assert(upgrade, `Unknown upgrade id: {id}`)
	return math.floor(upgrade.CostBase * upgrade.CostGrowth ^ lvl)
end

function UpgradeConfig.GetValue(id: string, lvl: number): number
	local upgrade = UpgradeConfig.Upgrades[id]
	assert(upgrade, `Unknown upgrade id: {id}`)
	return upgrade.Base + upgrade.PerLevel * lvl
end

return UpgradeConfig
