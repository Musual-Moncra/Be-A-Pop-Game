--!strict

--[[
	MapConfig
	Playable maps, their unlock price and reward scaling. Pure data, no functions.
	Maps unlock in Order: a map can be bought only after the map before it is unlocked.

	Fields:
		DefaultMapId: map every new player owns and the fallback selection (map id)
		Maps: list of maps, one table per map
			Id: unique map id, also the key saved in player data (string)
			DisplayName: name shown on the map card (text)
			Description: one short line shown under the name on the map card (text)
			ModelName: name of the Model in Workspace that holds the map geometry (string)
			Spawn: where the poop appears when a run starts (studs, world position)
			Order: position in the map list and in the unlock chain, 1 = first (number)
			UnlockCost: coins needed to unlock the map, 0 = free (coins)
			RequiredLevel: player level needed before the map can be unlocked (level)
			RewardMultiplier: multiplies coins and xp earned on this map (multiplier)
			SizeLabel: size text shown on the map card (text)
			Enabled: false hides the map as COMING SOON and blocks play (true/false)
			CompletionGems: gems paid the first time this map is stained to 100% (gems)
			RequirePreviousComplete: true means the map before it must be at 100% before this map can be unlocked (true/false)
]]

local MapConfig = {}

MapConfig.DefaultMapId = "Zone1"

MapConfig.Maps = {
	{
		Id = "Zone1",
		DisplayName = "Kitchen",
		Description = "Small kitchen full of counters, a fridge and hungry chefs.",
		ModelName = "Zone1",
		Spawn = Vector3.new(500, 5, 0),
		Order = 1,
		UnlockCost = 0,
		RequiredLevel = 1,
		RewardMultiplier = 1,
		SizeLabel = "S",
		Enabled = true,
		CompletionGems = 5,
		RequirePreviousComplete = false,
	},
	{
		Id = "Zone2",
		DisplayName = "Living Room",
		Description = "Sofas, a giant TV and a carpet begging to be ruined.",
		ModelName = "Zone2",
		Spawn = Vector3.new(1000, 5, 0),
		Order = 2,
		UnlockCost = 2500,
		RequiredLevel = 5,
		RewardMultiplier = 2,
		SizeLabel = "M",
		Enabled = true,
		CompletionGems = 15,
		RequirePreviousComplete = false,
	},
	{
		Id = "Zone3",
		DisplayName = "Restaurant",
		Description = "Huge dining hall with tables, a bar and a buffet line.",
		ModelName = "Zone3",
		Spawn = Vector3.new(1600, 5, 0),
		Order = 3,
		UnlockCost = 25000,
		RequiredLevel = 15,
		RewardMultiplier = 4,
		SizeLabel = "L",
		Enabled = true,
		CompletionGems = 40,
		RequirePreviousComplete = false,
	},
	{
		Id = "Zone4",
		DisplayName = "Shopping Mall",
		Description = "Coming soon.",
		ModelName = "Zone4",
		Spawn = Vector3.new(2400, 5, 0),
		Order = 4,
		UnlockCost = 250000,
		RequiredLevel = 30,
		RewardMultiplier = 8,
		SizeLabel = "XL",
		Enabled = false,
		CompletionGems = 100,
		RequirePreviousComplete = false,
	},
}

return MapConfig
