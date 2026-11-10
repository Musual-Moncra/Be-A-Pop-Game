--!strict

--[[
	MapConfig
	Playable maps, their unlock price and reward scaling. Pure data, no functions.
	Maps unlock in Order: a map can be bought only after the map before it is unlocked.
	Park is map 1 and Mall map 2; Kitchen and Grand Hotel are marked ComingSoon and disabled.
	Ids are stable for saves: only Order, unlock tuning and the flags changed.

	Fields:
		DefaultMapId: map every new player owns and the fallback selection (map id)
		Maps: list of maps, one table per map
			Id: unique map id, also the key saved in player data (string)
			DisplayName: name shown on the map card (text)
			Description: one short line shown under the name on the map card (text)
			ModelName: name of the Model in ServerStorage.Assets.Maps (string)
			Spawn: where the poop appears when a run starts (studs, world position)
			Order: position in the map list and in the unlock chain, 1 = first (number)
			UnlockCost: coins needed to unlock the map, 0 = free (coins)
			RequiredLevel: player level needed before the map can be unlocked (level)
			RewardMultiplier: multiplies coins and xp earned on this map (multiplier)
			SizeLabel: size text shown on the map card (text)
			Enabled: false hides the map as COMING SOON and blocks play (true/false)
			ComingSoon: true shows the map as COMING SOON in the UI; pair with Enabled = false (true/false)
			CompletionGems: gems paid the first time this map is stained to 100% (gems)
			RequirePreviousComplete: true means the map before it must be at 100% before this map can be unlocked (true/false)
]]

return {
	DefaultMapId = "Zone3",

	Maps = {
		{
			Id = "Zone3",
			DisplayName = "Park",
			Description = "Open-air park with a fountain, a statue, benches, trees and a golden toilet.",
			ModelName = "Park",
			Spawn = Vector3.new(1629.4, 20, -285.75),
			Order = 1,
			UnlockCost = 0,
			RequiredLevel = 1,
			RewardMultiplier = 1,
			SizeLabel = "L",
			Enabled = true,
			ComingSoon = false,
			CompletionGems = 5,
			RequirePreviousComplete = true,
		},
		{
			Id = "Zone2",
			DisplayName = "Shopping Mall",
			Description = "Neon shops, mannequins, a pink fountain and mall guards.",
			ModelName = "Zone2",
			Spawn = Vector3.new(1000, 5, 0),
			Order = 2,
			UnlockCost = 0,
			RequiredLevel = 1,
			RewardMultiplier = 2.5,
			SizeLabel = "M",
			Enabled = true,
			ComingSoon = false,
			CompletionGems = 15,
			RequirePreviousComplete = true,
		},
		{
			Id = "Zone1",
			DisplayName = "Kitchen",
			Description = "Stud-tiled kitchen with a stove, a fridge, chefs and a sneaky cat.",
			ModelName = "Zone1",
			Spawn = Vector3.new(500, 5, 0),
			Order = 3,
			UnlockCost = 0,
			RequiredLevel = 1,
			RewardMultiplier = 1,
			SizeLabel = "S",
			Enabled = false,
			ComingSoon = true,
			CompletionGems = 5,
			RequirePreviousComplete = true,
		},
		{
			Id = "Zone4",
			DisplayName = "Grand Hotel",
			Description = "Marble lobby, chandeliers, luggage carts and fancy butlers.",
			ModelName = "Zone4",
			Spawn = Vector3.new(2400, 5, 0),
			Order = 4,
			UnlockCost = 250000,
			RequiredLevel = 30,
			RewardMultiplier = 15,
			SizeLabel = "XL",
			Enabled = false,
			ComingSoon = true,
			CompletionGems = 100,
			RequirePreviousComplete = true,
		},
	},
}
