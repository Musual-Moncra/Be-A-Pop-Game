--!strict

--[[
	DataConfig
	Server-only save data layout and data-service limits. Pure data, no functions.

	Template is the save layout. ProfileStore fills missing keys on old saves, so keys may
	only be added - never renamed or removed. Every key in Template.Upgrades must also exist
	in UpgradeConfig.Upgrades.

	Fields:
		StoreName: DataStore name the profiles are saved in (string, changing it wipes progress)
		Template: starting save data for a new player
			Coins: starting coins (coins)
			Gems: starting gems (gems)
			Level: starting level (level)
			Xp: starting experience inside the current level (xp)
			Upgrades: starting level of every upgrade (level)
			UnlockedMaps: maps owned from the start, map id = true (map ids)
			Stats.BestScore: best score ever (points)
			Stats.TotalRuns: runs played (count)
			Stats.ObjectsSoiled: objects fully soiled across all runs (count)
			Stats.PowerupsEaten: food items eaten across all runs (count)
			Stats.QuestsCompleted: quests completed across all runs (count)
			Daily.LastClaim: server unix time of the last daily claim, 0 = never claimed (unix seconds)
			Daily.Streak: days claimed in the current 7-day cycle, 1..7, 0 after a reset (days)
			Boosts: active timed boosts, boost id = unix time the boost ends (unix seconds)
			Purchases: receipt ids already granted, keeps developer product receipts idempotent
				(purchase ids, oldest first)
			GrantedPets: pet ids delivered by a developer product, read by the pet system
				(pet ids)
			CoinBoostUntil: unix time the purchased coin boost stops working, 0 = no boost
				(unix seconds)
			MapProgress: best percent reached per map, map id = 0..100 (percent)
			Potions: active potion expiries keyed by potion id (Unix timestamp)
			PotionInventory: inventory counts of owned potions keyed by potion id (count)
			Rebirths: number of rebirths completed (count)
			OwnedSkins: table of owned skin ids mapped to true ({ [string]: boolean })
			OwnedTrails: table of owned trail ids mapped to true ({ [string]: boolean })
			EquippedSkin: currently equipped skin id (string)
			EquippedTrail: currently equipped trail id (string)
			Pets.Inventory: owned pets, one { Uid, PetId, Variant } table each (pet entries)
			Pets.Equipped: uids of equipped pets, order is the follower order (pet uids)
			Pets.ExtraSlots: extra equip slots bought with gamepasses (slots)
		ShutdownSaveWait: time the server waits for saves when it shuts down (seconds)
		HumanoidWaitTimeout: how long to wait for a character's Humanoid to appear (seconds)
		LoadFailedKick: kick message when the save cannot be loaded (text)
		SessionEndedKick: kick message when the save is opened on another server (text)
]]

local DataConfig = {}

DataConfig.StoreName = "PlayerData_v1"

DataConfig.Template = {
	Coins = 0,
	Gems = 0,
	Level = 1,
	Xp = 0,
	Upgrades = {
		Lifespan = 0,
		Speed = 0,
		StainSize = 0,
		CoinBonus = 0,
		PowerupDuration = 0,
	},
	UnlockedMaps = {
		Zone1 = true,
	},
	Stats = {
		BestScore = 0,
		TotalRuns = 0,
		ObjectsSoiled = 0,
		PowerupsEaten = 0,
		QuestsCompleted = 0,
	},
	Daily = {
		LastClaim = 0,
		Streak = 0,
	},
	Boosts = {},
	Purchases = {},
	GrantedPets = {},
	CoinBoostUntil = 0,
	MapProgress = {},
	Potions = {},
	PotionInventory = {
		LifespanPotion = 1,
		SpeedPotion = 1,
		StinkPotion = 1,
	},
	Rebirths = 0,
	OwnedSkins = {
		Default = true,
	},
	OwnedTrails = {},
	EquippedSkin = "Default",
	EquippedTrail = "",
	Pets = {
		Inventory = {},
		Equipped = {},
		ExtraSlots = 0,
	},
}

DataConfig.ShutdownSaveWait = 2
DataConfig.HumanoidWaitTimeout = 5

DataConfig.LoadFailedKick = "Your data could not be loaded. Please rejoin."
DataConfig.SessionEndedKick = "Your data session ended. Please rejoin."

return DataConfig
