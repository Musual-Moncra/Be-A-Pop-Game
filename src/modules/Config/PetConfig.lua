--!strict

--[[
	PetConfig
	Eggs, pets, rarities, variants and follower visuals for the pet system. Pure data, no functions.

	Rules:
		Every hatchable pet belongs to exactly one egg through EggId. A pet with EggId = ""
		is never hatched and only arrives from a developer product or a legacy save grant.
		An egg belongs to one map through MapId, so buying an egg requires that map unlocked.
		Hatch rarity is weighted by the rarity Weight of the pets in the egg.
		Merge chain is Variants[id].NextVariant; a variant without NextVariant cannot be merged.

	Fields:
		BaseSlots: equip slots every player has before ExtraSlots gamepasses (slots)
		GrantVariant: variant used when a product or save grant names only a pet id (variant id)
		MaxMergedFrom: number of identical pets consumed by one merge (count)
		FollowFolderName: Workspace folder that holds the placeholder pet followers (string)
		FollowModelPrefix: name prefix of every follower model (string)
		FollowSpawnDelay: wait after a character spawns before followers are rebuilt (seconds)
		FollowShape: shape of the placeholder follower body (Enum.PartType)
		FollowMaterial: material of the placeholder follower body (Enum.Material)
		FollowResponsiveness: how fast AlignPosition/AlignOrientation catch up, higher = snappier (number)
		FollowMaxForce: maximum force AlignPosition may use (force)
		FollowMaxTorque: maximum torque AlignOrientation may use (torque)
		FollowOffsets: relative positions of the equipped pets around the character (studs, local space)
		Rarities: one table per rarity, keyed by rarity id
			Id: unique rarity id saved inside pet definitions (string)
			DisplayName: name shown in the UI (text)
			Order: position in the rarity list, 1 = most common (number)
			Weight: hatch weight compared to other rarities in the same egg, higher = more common (number)
			Color: colour used for the rarity label (RGB)
		Variants: one table per variant, keyed by variant id
			Id: unique variant id saved with every owned pet (string)
			DisplayName: name shown in the UI (text)
			Bonus: multiplies the pet's coin and stink multipliers (multiplier)
			Weight: hatch weight compared to the other variants, higher = more common (number)
			NextVariant: variant a merge turns this one into, missing = final variant (variant id)
			Color: follower body colour override for this variant (RGB)
		Eggs: one table per egg, keyed by egg id
			Id: unique egg id used by the hatch remote (string)
			MapId: map that must be unlocked before the egg can be bought (map id)
			DisplayName: name shown on the egg card (text)
			Price: coins paid for one hatch (coins)
			BaseSlots: equip slots advertised with this egg (slots)
			InventoryCap: most pets one player may own before hatching is blocked (count)
			Order: position in the egg list, 1 = first (number)
			Color: egg card colour (RGB)
		Pets: list of pets, one table per pet
			Id: unique pet id saved in player data (string)
			DisplayName: name shown in the UI (text)
			EggId: egg this pet hatches from, "" = never hatched (egg id)
			Rarity: rarity id from Rarities (rarity id)
			CoinMultiplier: coins earned while equipped are multiplied by this (multiplier)
			StinkMultiplier: stain score earned while equipped is multiplied by this (multiplier)
			Size: placeholder follower body width, height and depth (studs)
			Color: placeholder follower body colour (RGB)
]]

local PetConfig = {}

PetConfig.BaseSlots = 3
PetConfig.GrantVariant = "Default"
PetConfig.MaxMergedFrom = 5

PetConfig.FollowFolderName = "PetFollowers"
PetConfig.FollowModelPrefix = "Pet_"
PetConfig.FollowSpawnDelay = 0.4
PetConfig.FollowShape = Enum.PartType.Ball
PetConfig.FollowMaterial = Enum.Material.SmoothPlastic
PetConfig.FollowResponsiveness = 30
PetConfig.FollowMaxForce = 100000
PetConfig.FollowMaxTorque = 100000

PetConfig.FollowOffsets = {
	Vector3.new(2.4, 1.4, 2.4),
	Vector3.new(-2.4, 1.4, 2.4),
	Vector3.new(0, 2.2, 3.2),
	Vector3.new(3.2, 1.4, 0),
	Vector3.new(-3.2, 1.4, 0),
	Vector3.new(0, 2.6, -3.0),
}

PetConfig.Rarities = {
	Common = {
		Id = "Common",
		DisplayName = "Common",
		Order = 1,
		Weight = 100,
		Color = Color3.fromRGB(196, 202, 214),
	},
	Uncommon = {
		Id = "Uncommon",
		DisplayName = "Uncommon",
		Order = 2,
		Weight = 40,
		Color = Color3.fromRGB(96, 200, 120),
	},
	Rare = {
		Id = "Rare",
		DisplayName = "Rare",
		Order = 3,
		Weight = 16,
		Color = Color3.fromRGB(80, 150, 255),
	},
	Epic = {
		Id = "Epic",
		DisplayName = "Epic",
		Order = 4,
		Weight = 6,
		Color = Color3.fromRGB(170, 95, 240),
	},
	Legendary = {
		Id = "Legendary",
		DisplayName = "Legendary",
		Order = 5,
		Weight = 2,
		Color = Color3.fromRGB(255, 190, 60),
	},
	Mythical = {
		Id = "Mythical",
		DisplayName = "Mythical",
		Order = 6,
		Weight = 0.6,
		Color = Color3.fromRGB(255, 110, 170),
	},
	Secret = {
		Id = "Secret",
		DisplayName = "Secret",
		Order = 7,
		Weight = 0.15,
		Color = Color3.fromRGB(70, 235, 220),
	},
	Darkness = {
		Id = "Darkness",
		DisplayName = "Darkness",
		Order = 8,
		Weight = 0.04,
		Color = Color3.fromRGB(60, 40, 90),
	},
}

PetConfig.Variants = {
	Default = {
		Id = "Default",
		DisplayName = "Default",
		Bonus = 1,
		Weight = 88,
		NextVariant = "Golden",
		Color = Color3.fromRGB(150, 110, 70),
	},
	Golden = {
		Id = "Golden",
		DisplayName = "Golden",
		Bonus = 1.25,
		Weight = 8,
		NextVariant = "Rainbow",
		Color = Color3.fromRGB(255, 205, 60),
	},
	Rainbow = {
		Id = "Rainbow",
		DisplayName = "Rainbow",
		Bonus = 1.5,
		Weight = 3,
		Color = Color3.fromRGB(255, 120, 220),
	},
	Stinky = {
		Id = "Stinky",
		DisplayName = "Stinky",
		Bonus = 1.4,
		Weight = 1,
		Color = Color3.fromRGB(120, 160, 60),
	},
}

PetConfig.Eggs = {
	KitchenEgg = {
		Id = "KitchenEgg",
		MapId = "Zone1",
		DisplayName = "Kitchen Egg",
		Price = 500,
		BaseSlots = 3,
		InventoryCap = 100,
		Order = 1,
		Color = Color3.fromRGB(235, 220, 190),
	},
	LivingRoomEgg = {
		Id = "LivingRoomEgg",
		MapId = "Zone2",
		DisplayName = "Mall Egg",
		Price = 2500,
		BaseSlots = 3,
		InventoryCap = 100,
		Order = 2,
		Color = Color3.fromRGB(190, 205, 235),
	},
	RestaurantEgg = {
		Id = "RestaurantEgg",
		MapId = "Zone3",
		DisplayName = "Park Egg",
		Price = 15000,
		BaseSlots = 3,
		InventoryCap = 100,
		Order = 3,
		Color = Color3.fromRGB(235, 190, 170),
	},
	MallEgg = {
		Id = "MallEgg",
		MapId = "Zone4",
		DisplayName = "Hotel Egg",
		Price = 75000,
		BaseSlots = 3,
		InventoryCap = 100,
		Order = 4,
		Color = Color3.fromRGB(200, 170, 240),
	},
}

PetConfig.Pets = {
	{
		Id = "Crumb",
		DisplayName = "Crumb",
		EggId = "KitchenEgg",
		Rarity = "Common",
		CoinMultiplier = 1.05,
		StinkMultiplier = 1.03,
		Size = 1.1,
		Color = Color3.fromRGB(190, 160, 120),
	},
	{
		Id = "DishSponge",
		DisplayName = "Dish Sponge",
		EggId = "KitchenEgg",
		Rarity = "Common",
		CoinMultiplier = 1.06,
		StinkMultiplier = 1.02,
		Size = 1.3,
		Color = Color3.fromRGB(255, 220, 90),
	},
	{
		Id = "ButterButt",
		DisplayName = "Butter Butt",
		EggId = "KitchenEgg",
		Rarity = "Uncommon",
		CoinMultiplier = 1.12,
		StinkMultiplier = 1.07,
		Size = 1.2,
		Color = Color3.fromRGB(255, 245, 160),
	},
	{
		Id = "GreaseGoblin",
		DisplayName = "Grease Goblin",
		EggId = "KitchenEgg",
		Rarity = "Rare",
		CoinMultiplier = 1.22,
		StinkMultiplier = 1.14,
		Size = 1.4,
		Color = Color3.fromRGB(120, 130, 90),
	},
	{
		Id = "FridgeFury",
		DisplayName = "Fridge Fury",
		EggId = "KitchenEgg",
		Rarity = "Epic",
		CoinMultiplier = 1.38,
		StinkMultiplier = 1.28,
		Size = 1.6,
		Color = Color3.fromRGB(210, 235, 245),
	},
	{
		Id = "KitchenKing",
		DisplayName = "Kitchen King",
		EggId = "KitchenEgg",
		Rarity = "Legendary",
		CoinMultiplier = 1.55,
		StinkMultiplier = 1.45,
		Size = 1.9,
		Color = Color3.fromRGB(255, 170, 70),
	},
	{
		Id = "DustBunny",
		DisplayName = "Dust Bunny",
		EggId = "LivingRoomEgg",
		Rarity = "Common",
		CoinMultiplier = 1.08,
		StinkMultiplier = 1.04,
		Size = 1.1,
		Color = Color3.fromRGB(180, 175, 165),
	},
	{
		Id = "SockSnake",
		DisplayName = "Sock Snake",
		EggId = "LivingRoomEgg",
		Rarity = "Common",
		CoinMultiplier = 1.09,
		StinkMultiplier = 1.05,
		Size = 1.2,
		Color = Color3.fromRGB(225, 225, 235),
	},
	{
		Id = "CouchPotato",
		DisplayName = "Couch Potato",
		EggId = "LivingRoomEgg",
		Rarity = "Uncommon",
		CoinMultiplier = 1.15,
		StinkMultiplier = 1.1,
		Size = 1.5,
		Color = Color3.fromRGB(200, 150, 95),
	},
	{
		Id = "LampLicker",
		DisplayName = "Lamp Licker",
		EggId = "LivingRoomEgg",
		Rarity = "Rare",
		CoinMultiplier = 1.26,
		StinkMultiplier = 1.18,
		Size = 1.3,
		Color = Color3.fromRGB(255, 235, 150),
	},
	{
		Id = "TvToad",
		DisplayName = "TV Toad",
		EggId = "LivingRoomEgg",
		Rarity = "Epic",
		CoinMultiplier = 1.42,
		StinkMultiplier = 1.3,
		Size = 1.5,
		Color = Color3.fromRGB(90, 200, 180),
	},
	{
		Id = "SofaLord",
		DisplayName = "Sofa Lord",
		EggId = "LivingRoomEgg",
		Rarity = "Legendary",
		CoinMultiplier = 1.6,
		StinkMultiplier = 1.48,
		Size = 2,
		Color = Color3.fromRGB(150, 110, 220),
	},
	{
		Id = "MenuMuncher",
		DisplayName = "Menu Muncher",
		EggId = "RestaurantEgg",
		Rarity = "Common",
		CoinMultiplier = 1.12,
		StinkMultiplier = 1.06,
		Size = 1.1,
		Color = Color3.fromRGB(245, 240, 225),
	},
	{
		Id = "NapkinNibbler",
		DisplayName = "Napkin Nibbler",
		EggId = "RestaurantEgg",
		Rarity = "Common",
		CoinMultiplier = 1.13,
		StinkMultiplier = 1.07,
		Size = 1.2,
		Color = Color3.fromRGB(250, 250, 250),
	},
	{
		Id = "PepperPooper",
		DisplayName = "Pepper Pooper",
		EggId = "RestaurantEgg",
		Rarity = "Uncommon",
		CoinMultiplier = 1.2,
		StinkMultiplier = 1.14,
		Size = 1.3,
		Color = Color3.fromRGB(200, 70, 70),
	},
	{
		Id = "BuffetBeast",
		DisplayName = "Buffet Beast",
		EggId = "RestaurantEgg",
		Rarity = "Rare",
		CoinMultiplier = 1.32,
		StinkMultiplier = 1.22,
		Size = 1.7,
		Color = Color3.fromRGB(230, 160, 90),
	},
	{
		Id = "ChefCurse",
		DisplayName = "Chef's Curse",
		EggId = "RestaurantEgg",
		Rarity = "Mythical",
		CoinMultiplier = 1.85,
		StinkMultiplier = 1.7,
		Size = 1.8,
		Color = Color3.fromRGB(255, 90, 130),
	},
	{
		Id = "RestaurantRoyalty",
		DisplayName = "Restaurant Royalty",
		EggId = "RestaurantEgg",
		Rarity = "Legendary",
		CoinMultiplier = 1.7,
		StinkMultiplier = 1.55,
		Size = 2,
		Color = Color3.fromRGB(255, 205, 80),
	},
	{
		Id = "MallRat",
		DisplayName = "Mall Rat",
		EggId = "MallEgg",
		Rarity = "Rare",
		CoinMultiplier = 1.4,
		StinkMultiplier = 1.25,
		Size = 1.3,
		Color = Color3.fromRGB(140, 140, 150),
	},
	{
		Id = "EscalatorEel",
		DisplayName = "Escalator Eel",
		EggId = "MallEgg",
		Rarity = "Rare",
		CoinMultiplier = 1.42,
		StinkMultiplier = 1.27,
		Size = 1.4,
		Color = Color3.fromRGB(110, 190, 200),
	},
	{
		Id = "MannequinMenace",
		DisplayName = "Mannequin Menace",
		EggId = "MallEgg",
		Rarity = "Epic",
		CoinMultiplier = 1.6,
		StinkMultiplier = 1.4,
		Size = 1.6,
		Color = Color3.fromRGB(235, 225, 215),
	},
	{
		Id = "SaleShark",
		DisplayName = "Sale Shark",
		EggId = "MallEgg",
		Rarity = "Legendary",
		CoinMultiplier = 1.8,
		StinkMultiplier = 1.6,
		Size = 1.8,
		Color = Color3.fromRGB(120, 175, 235),
	},
	{
		Id = "DepartmentDemon",
		DisplayName = "Department Demon",
		EggId = "MallEgg",
		Rarity = "Secret",
		CoinMultiplier = 2.2,
		StinkMultiplier = 1.9,
		Size = 2.1,
		Color = Color3.fromRGB(70, 235, 220),
	},
	{
		Id = "VoidVendor",
		DisplayName = "Void Vendor",
		EggId = "MallEgg",
		Rarity = "Darkness",
		CoinMultiplier = 2.6,
		StinkMultiplier = 2.3,
		Size = 2.3,
		Color = Color3.fromRGB(55, 35, 80),
	},
	{
		Id = "GoldenPoopDoge",
		DisplayName = "Golden Poop Doge",
		EggId = "",
		Rarity = "Legendary",
		CoinMultiplier = 1.5,
		StinkMultiplier = 1.5,
		Size = 1.8,
		Color = Color3.fromRGB(255, 205, 60),
	},
}

return PetConfig
