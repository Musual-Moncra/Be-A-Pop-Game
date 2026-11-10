--!strict

--[[
	PotionConfig
	Lobby and persistent timed boost potions consumed from inventory. Pure data, no functions.

	Fields:
		Potions: table of potion definitions keyed by potion id
			Id: unique potion id, saved in player data and used by the product handler (string)
			DisplayName: human-readable potion name (text)
			Icon: emoji or short icon string (text)
			Duration: active duration when consumed (seconds)
			Multiplier: boost multiplier applied to the target stat (multiplier)
			Stat: stat boosted ("Lifespan" | "Speed" | "Stink")
			Description: description of what the potion does (text)
			ProductId: developer product id that sells this potion, 0 = not uploaded yet (asset id)
			PriceRobux: planned price for the shop copy, informational only (Robux)
		Product ids must be unique across every gamepass and developer product.

	API: ConfigLookup.GetPotion(id), ConfigLookup.GetSortedPotionIds(); product purchase
		grants through PotionService.GrantPotion.
]]

return {
	Potions = {
		LifespanPotion = {
			Id = "LifespanPotion",
			DisplayName = "Rocky Poo Potion",
			Icon = "⏳",
			Duration = 600,
			Multiplier = 2,
			Stat = "Lifespan",
			Description = "x2 Lifespan duration for 10 minutes",
			ProductId = 0,
			PriceRobux = 24,
		},
		SpeedPotion = {
			Id = "SpeedPotion",
			DisplayName = "Diarrhea Potion",
			Icon = "⚡",
			Duration = 900,
			Multiplier = 2,
			Stat = "Speed",
			Description = "x2 WalkSpeed for 15 minutes",
			ProductId = 0,
			PriceRobux = 25,
		},
		StinkPotion = {
			Id = "StinkPotion",
			DisplayName = "Mala Chili",
			Icon = "💨",
			Duration = 1200,
			Multiplier = 2,
			Stat = "Stink",
			Description = "x2 Stink for 20 minutes",
			ProductId = 0,
			PriceRobux = 30,
		},
	},
}
