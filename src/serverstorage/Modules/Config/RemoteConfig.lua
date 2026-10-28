--!strict

--[[
	RemoteConfig
	Server-only limits for client -> server remotes. Pure data, no functions.

	Fields:
		RateLimits: minimum time between two accepted calls of one remote from one player, keyed by
			Net packet name; a call arriving sooner is dropped silently (seconds)
			PurchaseUpgrade: buying an upgrade
			UnlockMap: buying a map
			SelectRun: choosing map and mode
			StartRun: starting a run from the Play window
			LeaveRun: leaving a run from the HUD
			ClaimDaily: claiming the daily login reward
			Rebirth: executing a rebirth
			OpenCrate: opening a cosmetic crate
			EquipCosmetic: equipping or unequipping a skin or trail
			HatchEgg: opening one egg
			EquipPet: equipping one owned pet
			UnequipPet: unequipping one owned pet
			DeletePet: deleting one owned pet
			MergePet: merging five identical pets
		DefaultRateLimit: limit used for a remote missing from RateLimits (seconds)
		MaxStringLength: longest string argument a client may send on any remote (characters)
]]

local RemoteConfig = {}

RemoteConfig.RateLimits = {
	PurchaseUpgrade = 0.2,
	UnlockMap = 0.2,
	SelectRun = 0.1,
	StartRun = 0.5,
	LeaveRun = 0.5,
	ClaimDaily = 1,
	Rebirth = 0.5,
	OpenCrate = 0.3,
	EquipCosmetic = 0.2,
	HatchEgg = 0.5,
	EquipPet = 0.1,
	UnequipPet = 0.1,
	DeletePet = 0.2,
	MergePet = 0.5,
}

RemoteConfig.DefaultRateLimit = 0.2
RemoteConfig.MaxStringLength = 64

return RemoteConfig
