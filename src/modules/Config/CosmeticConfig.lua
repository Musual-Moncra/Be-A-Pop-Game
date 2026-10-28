--!strict

--[[
	CosmeticConfig
	Configuration for character skins, trails, and crates. Pure data, no functions.

	Fields:
		BodyParts: list of body part names colored by equipped skins (array of strings)
		TrailTop: offset of the upper attachment for cosmetics trails (Vector3 studs)
		TrailBottom: offset of the lower attachment for cosmetics trails (Vector3 studs)
		Skins: table of skin definitions keyed by skin id (Default, DailyStreak7, Gold, Rainbow, Frozen, Ninja, Alien)
			DisplayName: player-facing skin name (text)
			Rarity: tier Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret, Darkness (text)
			Color: body parts tint color (Color3)
			Material: body parts material (Enum.Material)
			TextureId: optional texture id for body parts (string)
		Trails: table of trail definitions keyed by trail id
			DisplayName: player-facing trail name (text)
			Rarity: tier Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret, Darkness (text)
			Color: trail color sequence (ColorSequence)
			Lifetime: how long trail ribbon lasts (seconds)
			WidthScale: number sequence scaling trail width from start to end (NumberSequence)
			Texture: optional trail texture asset url (string)
			Transparency: trail transparency sequence (NumberSequence)
		Crates: table of crate definitions keyed by crate id
			DisplayName: player-facing crate name (text)
			CostType: currency used "Coins" or "Gems" (text)
			Cost: price to open (coins or gems)
			Drops: weighted drop list of { Kind = "Skin" | "Trail", Id = string, Weight = number }
		DuplicateCoinRefund: coins refunded when rolling an already owned cosmetic (coins)
]]

local CosmeticConfig = {}

CosmeticConfig.BodyParts = { "TierBottom", "TierMiddle", "TierTop", "Tip" }
CosmeticConfig.TrailTop = Vector3.new(0, 1, 0)
CosmeticConfig.TrailBottom = Vector3.new(0, -1, 0)

CosmeticConfig.Skins = {
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
}

CosmeticConfig.Trails = {
	Neon = {
		DisplayName = "Neon",
		Rarity = "Uncommon",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
		}),
		Lifetime = 0.6,
		WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Texture = "",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
	Fire = {
		DisplayName = "Fire",
		Rarity = "Rare",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0)),
		}),
		Lifetime = 0.8,
		WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.4),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Texture = "",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
	Water = {
		DisplayName = "Water",
		Rarity = "Uncommon",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 255)),
		}),
		Lifetime = 0.7,
		WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.3),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Texture = "",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
	IceCream = {
		DisplayName = "Ice Cream",
		Rarity = "Epic",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 182, 193)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 224)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 105, 30)),
		}),
		Lifetime = 0.9,
		WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Texture = "",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
}

CosmeticConfig.Crates = {
	StandardCrate = {
		DisplayName = "Standard Crate",
		CostType = "Coins",
		Cost = 5000,
		Drops = {
			{ Kind = "Skin", Id = "Frozen", Weight = 40 },
			{ Kind = "Trail", Id = "Neon", Weight = 50 },
			{ Kind = "Trail", Id = "Water", Weight = 50 },
			{ Kind = "Skin", Id = "Ninja", Weight = 20 },
			{ Kind = "Trail", Id = "Fire", Weight = 15 },
		},
	},
	PremiumCrate = {
		DisplayName = "Premium Crate",
		CostType = "Gems",
		Cost = 50,
		Drops = {
			{ Kind = "Skin", Id = "Ninja", Weight = 45 },
			{ Kind = "Trail", Id = "Fire", Weight = 40 },
			{ Kind = "Trail", Id = "IceCream", Weight = 30 },
			{ Kind = "Skin", Id = "Gold", Weight = 15 },
			{ Kind = "Skin", Id = "Rainbow", Weight = 8 },
			{ Kind = "Skin", Id = "Alien", Weight = 2 },
		},
	},
}

CosmeticConfig.DuplicateCoinRefund = 1000

return CosmeticConfig
