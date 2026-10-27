--!strict

--[[
	DataConfig
	Server-only tunables for DataService and UpgradeService.

	Template is data schema v1. ProfileStore.Reconcile fills missing keys on
	existing profiles, so Template may only grow - never rename or remove a key.
]]

local DataConfig = {}

DataConfig.StoreName = "PlayerData_v1"

DataConfig.Template = {
	Coins = 0,
	Gems = 0,
	Upgrades = {
		Lifespan = 0,
		Speed = 0,
		StainSize = 0,
	},
	Stats = {
		BestScore = 0,
		TotalRuns = 0,
	},
}

DataConfig.PurchaseRateLimit = 0.2
DataConfig.ShutdownSaveWait = 2
DataConfig.HumanoidWaitTimeout = 5

DataConfig.LoadFailedKick = "Your data could not be loaded. Please rejoin."
DataConfig.SessionEndedKick = "Your data session ended. Please rejoin."

return DataConfig
