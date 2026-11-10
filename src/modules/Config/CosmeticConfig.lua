--!strict

--[[
	CosmeticConfig
	Configuration for character skins and crates. Pure data, no functions.

	Fields:
		BodyParts: list of character descendant names colored by equipped skins; the legacy
			Body model is used when present, otherwise the names are looked up on the character
			(array of strings)
		Skins: table of skin definitions keyed by skin id (Default, DailyStreak7, Gold, Rainbow, Frozen, Ninja, Alien)
			DisplayName: player-facing skin name (text)
			Rarity: tier Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret, Darkness (text)
			Color: body parts tint color; on textured parts it becomes SurfaceAppearance.Color
				and multiplies the ColorMap, while Default restores the original texture tint (Color3)
			Material: body parts material (Enum.Material)
			TextureId: optional texture id for body parts (string)
		Crates: table of crate definitions keyed by crate id
			DisplayName: player-facing crate name (text)
			CostType: currency used "Coins" or "Gems" (text)
			Cost: price to open (coins or gems)
			Drops: weighted drop list of { Kind = "Skin", Id = string, Weight = number }
		DuplicateCoinRefund: coins refunded when rolling an already owned cosmetic (coins)
]]

return {
	BodyParts = { "node_0" },

	Skins = {
		Default = {
			DisplayName = "Default",
			Rarity = "Common",
			Color = Color3.fromRGB(117, 76, 41),
			Material = Enum.Material.SmoothPlastic,
			TextureId = "",
		},
		DailyStreak7 = {
			DisplayName = "Royal Stinker",
			Rarity = "Mythical",
			Color = Color3.fromRGB(170, 90, 255),
			Material = Enum.Material.Neon,
			TextureId = "",
		},
		Gold = {
			DisplayName = "Gold",
			Rarity = "Legendary",
			Color = Color3.fromRGB(255, 215, 0),
			Material = Enum.Material.Metal,
			TextureId = "",
		},
		Rainbow = {
			DisplayName = "Rainbow",
			Rarity = "Mythical",
			Color = Color3.fromRGB(255, 105, 180),
			Material = Enum.Material.Neon,
			TextureId = "",
		},
		Frozen = {
			DisplayName = "Frozen",
			Rarity = "Rare",
			Color = Color3.fromRGB(165, 242, 255),
			Material = Enum.Material.Ice,
			TextureId = "",
		},
		Ninja = {
			DisplayName = "Ninja",
			Rarity = "Epic",
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Fabric,
			TextureId = "",
		},
		Alien = {
			DisplayName = "Alien",
			Rarity = "Secret",
			Color = Color3.fromRGB(57, 255, 20),
			Material = Enum.Material.Neon,
			TextureId = "",
		},
	},

	Crates = {
		StandardCrate = {
			DisplayName = "Standard Crate",
			CostType = "Coins",
			Cost = 5000,
			Drops = {
				{ Kind = "Skin", Id = "Frozen", Weight = 40 },
				{ Kind = "Skin", Id = "Ninja", Weight = 20 },
			},
		},
		PremiumCrate = {
			DisplayName = "Premium Crate",
			CostType = "Gems",
			Cost = 50,
			Drops = {
				{ Kind = "Skin", Id = "Ninja", Weight = 45 },
				{ Kind = "Skin", Id = "Gold", Weight = 15 },
				{ Kind = "Skin", Id = "Rainbow", Weight = 8 },
				{ Kind = "Skin", Id = "Alien", Weight = 2 },
			},
		},
	},

	DuplicateCoinRefund = 1000,
}
