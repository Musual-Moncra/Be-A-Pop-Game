--!strict

--[[
	MonetizationConfig
	Gamepasses, developer products and every reward they grant. Pure data, no functions.

	Every Id is a placeholder (0) until the asset is uploaded to the experience. A product
	whose Id is still 0 is treated as unavailable: it is never owned, offered or granted, so
	the game stays playable with no published products. Upload the asset, paste its id and
	the same code starts working. Uploaded ids must be unique across gamepasses and developer
	products, because receipts are matched by id alone.

	Fields:
		ReviveWindow: how long a timed-out run is kept alive while the revive offer is open (seconds)
		ReviveSeconds: lifespan added to the run when a revive is bought (seconds)
		StainBombRadius: soils every prop within this distance of the poop, 3x the Mini Bomb
			perk radius of 25 studs (studs)
		MagnetPickupRadius: food pickup radius while the Magnet gamepass is owned (studs)
		MaxPurchaseHistory: processed receipt ids kept per player for idempotency (count)
		PassCacheSeconds: how long a gamepass ownership answer is trusted before it is re-asked
			on another server; a local purchase updates the cache immediately (seconds)
		Messages: player-facing popup texts, %s is replaced by text, %d by a whole number
			ReviveGranted: revive applied, %d = lifespan added (text)
			StainBombUsed: stain bomb bought and nearby props soiled (text)
			NewbiePackGranted: Newbie Pack contents delivered (text)
			PassPurchased: gamepass bought, %s = gamepass display name (text)
		Gamepasses: one entry per gamepass, keyed by the pass key code uses
			Id: gamepass asset id, 0 = not uploaded yet (asset id)
			DisplayName: name shown in the shop (text)
			Description: one-line shop description (text)
			PriceRobux: planned price for the shop copy, informational only, 0 = undecided (Robux)
			Icon: emoji or short text for the shop tile (text)
			CoinMultiplier: run coins are multiplied by this while owned (multiplier)
			GemMultiplier: run gems are multiplied by this while owned (multiplier)
			ExtraPetSlots: pet slots added while owned (count)
			Vip: true when the pass is the VIP stainer cosmetic tier (boolean)
			Magnet: true when the pass widens food pickup to MagnetPickupRadius (boolean)
		DevProducts: developer products grouped by kind; kinds are the GrantProduct keys
			GemPacks: gem bundles, one entry per product
				Id: product asset id, 0 = not uploaded yet (asset id)
				DisplayName: name shown in the shop (text)
				PriceRobux: planned price for the shop copy, informational only (Robux)
				Gems: gems granted on purchase (gems)
			CoinPacks: coin bundles, one entry per product
				Id: product asset id, 0 = not uploaded yet (asset id)
				DisplayName: name shown in the shop (text)
				PriceRobux: planned price for the shop copy, informational only (Robux)
				Coins: coins granted on purchase (coins)
			Revive: revive tiers bought in order inside one run; tier 1 is the first offer
				Id: product asset id, 0 = not uploaded yet (asset id)
				DisplayName: name shown on the revive prompt (text)
				PriceRobux: planned price for the shop copy, informational only (Robux)
				Tier: 1-based offer position, the last tier repeats when bought again (tier)
			StainBomb: one-shot product, soils every prop near the player (see StainBombRadius)
				Id: product asset id, 0 = not uploaded yet (asset id)
				DisplayName: name shown in the shop (text)
				PriceRobux: planned price for the shop copy, informational only (Robux)
			NewbiePack: starter bundle, granted once per receipt
				Id: product asset id, 0 = not uploaded yet (asset id)
				DisplayName: name shown in the shop (text)
				PriceRobux: planned price for the shop copy, informational only (Robux)
				Gems: gems granted (gems)
				Coins: coins granted (coins)
				PetId: pet added to the player's granted pets, read by the pet system (pet id)
				PetMultiplier: coin multiplier the granted pet will carry once pets exist (multiplier)
				CoinBoostMultiplier: run coins are multiplied by this while the boost runs (multiplier)
				CoinBoostSeconds: how long the coin boost lasts (seconds)
]]

local MonetizationConfig = {}

MonetizationConfig.ReviveWindow = 8
MonetizationConfig.ReviveSeconds = 20
MonetizationConfig.StainBombRadius = 75
MonetizationConfig.MagnetPickupRadius = 30
MonetizationConfig.MaxPurchaseHistory = 100
MonetizationConfig.PassCacheSeconds = 120

MonetizationConfig.Messages = {
	ReviveGranted = "Revived! +%ds",
	StainBombUsed = "Stain Bomb! Nearby props are wrecked!",
	NewbiePackGranted = "Newbie Pack unlocked!",
	PassPurchased = "%s activated!",
}

MonetizationConfig.Gamepasses = {
	DoubleCoins = {
		Id = 0,
		DisplayName = "x2 Coins",
		Description = "Double Poop Coins from every run.",
		PriceRobux = 299,
		Icon = "🪙",
		CoinMultiplier = 2,
		GemMultiplier = 1,
		ExtraPetSlots = 0,
		Vip = false,
		Magnet = false,
	},
	DoubleGems = {
		Id = 0,
		DisplayName = "x2 Gems",
		Description = "Double Gems from every run.",
		PriceRobux = 399,
		Icon = "💎",
		CoinMultiplier = 1,
		GemMultiplier = 2,
		ExtraPetSlots = 0,
		Vip = false,
		Magnet = false,
	},
	Magnet = {
		Id = 0,
		DisplayName = "Magnet",
		Description = "Pull in every snack around you.",
		PriceRobux = 199,
		Icon = "🧲",
		CoinMultiplier = 1,
		GemMultiplier = 1,
		ExtraPetSlots = 0,
		Vip = false,
		Magnet = true,
	},
	ExtraPetSlots = {
		Id = 0,
		DisplayName = "+3 Pet Slots",
		Description = "Bring three more pets on every run.",
		PriceRobux = 349,
		Icon = "🐾",
		CoinMultiplier = 1,
		GemMultiplier = 1,
		ExtraPetSlots = 3,
		Vip = false,
		Magnet = false,
	},
	VIP = {
		Id = 0,
		DisplayName = "VIP Stainer",
		Description = "Exclusive VIP stainer look.",
		PriceRobux = 0,
		Icon = "⭐",
		CoinMultiplier = 1,
		GemMultiplier = 1,
		ExtraPetSlots = 0,
		Vip = true,
		Magnet = false,
	},
}

MonetizationConfig.DevProducts = {
	GemPacks = {
		{ Id = 0, DisplayName = "Pocket Gems", PriceRobux = 36, Gems = 50 },
		{ Id = 0, DisplayName = "Pouch of Gems", PriceRobux = 199, Gems = 300 },
		{ Id = 0, DisplayName = "Bag of Gems", PriceRobux = 499, Gems = 800 },
		{ Id = 0, DisplayName = "Chest of Gems", PriceRobux = 1499, Gems = 2000 },
		{ Id = 0, DisplayName = "Vault of Gems", PriceRobux = 3999, Gems = 6000 },
	},
	CoinPacks = {
		{ Id = 0, DisplayName = "Handful of Coins", PriceRobux = 25, Coins = 1000 },
		{ Id = 0, DisplayName = "Bucket of Coins", PriceRobux = 99, Coins = 5000 },
		{ Id = 0, DisplayName = "Sack of Coins", PriceRobux = 349, Coins = 20000 },
		{ Id = 0, DisplayName = "Truck of Coins", PriceRobux = 1499, Coins = 100000 },
	},
	Revive = {
		{ Id = 0, DisplayName = "Revive", PriceRobux = 4, Tier = 1 },
		{ Id = 0, DisplayName = "Revive Again", PriceRobux = 9, Tier = 2 },
		{ Id = 0, DisplayName = "Last Revive", PriceRobux = 13, Tier = 3 },
	},
	StainBomb = {
		Id = 0,
		DisplayName = "Stain Bomb",
		PriceRobux = 20,
	},
	NewbiePack = {
		Id = 0,
		DisplayName = "Newbie Pack",
		PriceRobux = 89,
		Gems = 200,
		Coins = 5000,
		PetId = "GoldenPoopDoge",
		PetMultiplier = 1.5,
		CoinBoostMultiplier = 2,
		CoinBoostSeconds = 3600,
	},
}

return MonetizationConfig
