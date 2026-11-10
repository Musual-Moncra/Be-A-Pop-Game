--!strict

--[[
	PetConfig
	Pets, rarities, variants and follower visuals for the pet system. Pure data, no functions.

	Pets drop when a run reaches 100% map stain; there are no eggs. A pet belongs to one map
	through MapId and rolls with weight 1/DropOdds inside that map's pool. Exclusive pets are
	never rolled: each launch map grants its exclusive once when the map's Pet Index is complete.
	Stink is the single player-facing multiplier:
		PetStink = Stink x variant Bonus x (1 + StackBonus x min(Stacks, StackCap))
	Pet poop adds Stacks during a run; stacks are saved on the pet entry.

	Fields:
		BaseSlots: equip slots every player has before ExtraPetSlots gamepasses (slots)
		GrantVariant: variant used when a product or save grant names only a pet id (variant id)
		MaxMergedFrom: number of identical pets consumed by one merge (count)
		InventoryCap: most pets one player may own; a drop at the cap pays FullInventoryGems (count)
		FullInventoryGems: gems paid instead of a pet when the inventory is full (gems)
		IndexGems: gems paid when a map's Pet Index is complete (gems)
		PoopInterval: seconds between two poops of one equipped pet during a run (seconds)
		PoopGemChance: chance that one pet poop pays PoopGems (0 to 1)
		PoopGems: gems paid by a successful pet poop (gems)
		StackBonus: Stink added per stack, as a share of the pet's base Stink (multiplier)
		StackCap: most stacks one pet may hold (count)
		FollowFolderName: Workspace folder that holds the pet followers (string)
		FollowModelPrefix: name prefix of every follower model (string)
		FollowSpawnDelay: wait after a character spawns before followers are rebuilt (seconds)
		FollowShape: shape of the placeholder follower body (Enum.PartType)
		FollowMaterial: material of the placeholder follower body (Enum.Material)
		FollowResponsiveness: how fast AlignPosition/AlignOrientation catch up, higher = snappier (number)
		FollowMaxForce: maximum force AlignPosition may use (force)
		FollowMaxTorque: maximum torque AlignOrientation may use (torque)
		FollowOffsets: relative positions of the equipped pets around the character, kept to the sides so they never block the camera (studs, local space)
		EyeColor: colour of the follower eyes (RGB)
		EyeSize: eye diameter as a share of the pet size (0 to 1)
		EyeSpread: sideways eye distance from the centre as a share of the pet size (0 to 1)
		EyeHeight: eye height above the centre as a share of the pet size (0 to 1)
		EyeDepth: how far forward the eyes sit as a share of the pet size (0 to 1)
		Rarities: one table per rarity, keyed by rarity id
			Id: unique rarity id saved inside pet definitions (string)
			DisplayName: name shown in the UI (text)
			Order: position in the rarity list, 1 = most common (number)
			Weight: rarity weight compared to the other rarities (number)
			Color: colour used for the rarity label (RGB)
		Variants: one table per variant, keyed by variant id
			Id: unique variant id saved with every owned pet (string)
			DisplayName: name shown in the UI (text)
			Bonus: multiplies the pet's Stink (multiplier)
			DropOdds: 1/N chance to roll this variant, 0 = never rolled, Default takes the rest (number)
			NextVariant: variant a merge turns this one into, missing = final variant (variant id)
			Color: follower body colour override for this variant (RGB)
		Pets: list of pets, one table per pet
			Id: unique pet id saved in player data (string)
			DisplayName: name shown in the UI (text)
			MapId: map whose 100% clear rolls this pet, "" = never rolled (map id)
			Rarity: rarity id from Rarities (rarity id)
			Stink: base Stink multiplier of the pet (multiplier)
			Exclusive: true = Pet Index reward, never rolled (true/false)
			DropOdds: 1/N weight inside the map pool, 0 = not rolled (number)
			Size: placeholder follower body width, height and depth (studs)
			Color: placeholder follower body colour (RGB)
			ModelName: follower model name for the art pass, "" = placeholder ball (string)
]]

return {
	BaseSlots = 1,
	GrantVariant = "Default",
	MaxMergedFrom = 5,
	InventoryCap = 50,
	FullInventoryGems = 25,
	IndexGems = 100,
	PoopInterval = 6,
	PoopGemChance = 0.1,
	PoopGems = 1,
	StackBonus = 0.01,
	StackCap = 100,
	FollowFolderName = "PetFollowers",
	FollowModelPrefix = "Pet_",
	FollowSpawnDelay = 0.4,
	FollowShape = Enum.PartType.Ball,
	FollowMaterial = Enum.Material.SmoothPlastic,
	FollowResponsiveness = 30,
	FollowMaxForce = 100000,
	FollowMaxTorque = 100000,

	FollowOffsets = {
		Vector3.new(3.4, 0.4, 0.6),
		Vector3.new(-3.4, 0.4, 0.6),
		Vector3.new(2.6, 0.4, -2.6),
		Vector3.new(-2.6, 0.4, -2.6),
		Vector3.new(4.8, 0.4, -0.8),
		Vector3.new(-4.8, 0.4, -0.8),
	},

	EyeColor = Color3.fromRGB(30, 24, 20),
	EyeSize = 0.22,
	EyeSpread = 0.22,
	EyeHeight = 0.15,
	EyeDepth = 0.45,

	Rarities = {
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
	},

	Variants = {
		Default = {
			Id = "Default",
			DisplayName = "Default",
			Bonus = 1,
			DropOdds = 0,
			NextVariant = "Golden",
			Color = Color3.fromRGB(150, 110, 70),
		},
		Golden = {
			Id = "Golden",
			DisplayName = "Golden",
			Bonus = 1.5,
			DropOdds = 8,
			NextVariant = "Rainbow",
			Color = Color3.fromRGB(255, 205, 60),
		},
		Rainbow = {
			Id = "Rainbow",
			DisplayName = "Rainbow",
			Bonus = 2.25,
			DropOdds = 60,
			NextVariant = "Stinky",
			Color = Color3.fromRGB(255, 120, 220),
		},
		Stinky = {
			Id = "Stinky",
			DisplayName = "Stinky",
			Bonus = 3.5,
			DropOdds = 400,
			Color = Color3.fromRGB(120, 160, 60),
		},
	},

	Pets = {
		{
			Id = "Snail",
			DisplayName = "Snail",
			MapId = "Zone3",
			Rarity = "Common",
			Stink = 1.1,
			Exclusive = false,
			DropOdds = 2,
			Size = 1.1,
			Color = Color3.fromRGB(176, 150, 118),
			ModelName = "",
		},
		{
			Id = "Parrot",
			DisplayName = "Parrot",
			MapId = "Zone3",
			Rarity = "Uncommon",
			Stink = 1.2,
			Exclusive = false,
			DropOdds = 4,
			Size = 1.3,
			Color = Color3.fromRGB(84, 190, 110),
			ModelName = "",
		},
		{
			Id = "Bulldog",
			DisplayName = "Bulldog",
			MapId = "Zone3",
			Rarity = "Uncommon",
			Stink = 1.2,
			Exclusive = false,
			DropOdds = 4,
			Size = 1.5,
			Color = Color3.fromRGB(170, 160, 150),
			ModelName = "",
		},
		{
			Id = "Raccoon",
			DisplayName = "Raccoon",
			MapId = "Zone3",
			Rarity = "Uncommon",
			Stink = 1.2,
			Exclusive = false,
			DropOdds = 5,
			Size = 1.3,
			Color = Color3.fromRGB(120, 125, 135),
			ModelName = "",
		},
		{
			Id = "Pelican",
			DisplayName = "Pelican",
			MapId = "Zone3",
			Rarity = "Rare",
			Stink = 1.35,
			Exclusive = false,
			DropOdds = 6.5,
			Size = 1.6,
			Color = Color3.fromRGB(238, 238, 228),
			ModelName = "",
		},
		{
			Id = "HomelessGuy",
			DisplayName = "Homeless Guy",
			MapId = "Zone3",
			Rarity = "Epic",
			Stink = 1.6,
			Exclusive = false,
			DropOdds = 12,
			Size = 1.7,
			Color = Color3.fromRGB(110, 88, 64),
			ModelName = "",
		},
		{
			Id = "ParkKing",
			DisplayName = "Park King",
			MapId = "Zone3",
			Rarity = "Legendary",
			Stink = 2.2,
			Exclusive = true,
			DropOdds = 0,
			Size = 2,
			Color = Color3.fromRGB(255, 190, 60),
			ModelName = "",
		},
		{
			Id = "PersianCat",
			DisplayName = "Persian Cat",
			MapId = "Zone2",
			Rarity = "Common",
			Stink = 1.25,
			Exclusive = false,
			DropOdds = 3,
			Size = 1.2,
			Color = Color3.fromRGB(236, 228, 214),
			ModelName = "",
		},
		{
			Id = "CyberDog",
			DisplayName = "Cyber Dog",
			MapId = "Zone2",
			Rarity = "Uncommon",
			Stink = 1.4,
			Exclusive = false,
			DropOdds = 4,
			Size = 1.4,
			Color = Color3.fromRGB(80, 220, 230),
			ModelName = "",
		},
		{
			Id = "LivingTeddyBear",
			DisplayName = "Living Teddy Bear",
			MapId = "Zone2",
			Rarity = "Uncommon",
			Stink = 1.4,
			Exclusive = false,
			DropOdds = 5,
			Size = 1.5,
			Color = Color3.fromRGB(168, 120, 78),
			ModelName = "",
		},
		{
			Id = "PuppyHotdog",
			DisplayName = "Puppy Hotdog",
			MapId = "Zone2",
			Rarity = "Rare",
			Stink = 1.6,
			Exclusive = false,
			DropOdds = 7,
			Size = 1.5,
			Color = Color3.fromRGB(214, 120, 80),
			ModelName = "",
		},
		{
			Id = "GummyBear",
			DisplayName = "Gummy Bear",
			MapId = "Zone2",
			Rarity = "Epic",
			Stink = 1.9,
			Exclusive = false,
			DropOdds = 12,
			Size = 1.7,
			Color = Color3.fromRGB(255, 120, 190),
			ModelName = "",
		},
		{
			Id = "MallCop",
			DisplayName = "Mall Cop",
			MapId = "Zone2",
			Rarity = "Epic",
			Stink = 1.9,
			Exclusive = false,
			DropOdds = 15,
			Size = 1.8,
			Color = Color3.fromRGB(64, 84, 140),
			ModelName = "",
		},
		{
			Id = "MallMonarch",
			DisplayName = "Mall Monarch",
			MapId = "Zone2",
			Rarity = "Legendary",
			Stink = 2.8,
			Exclusive = true,
			DropOdds = 0,
			Size = 2,
			Color = Color3.fromRGB(255, 210, 90),
			ModelName = "",
		},
		{
			Id = "GoldenPoopDoge",
			DisplayName = "Golden Poop Doge",
			MapId = "",
			Rarity = "Legendary",
			Stink = 1.5,
			Exclusive = false,
			DropOdds = 0,
			Size = 1.8,
			Color = Color3.fromRGB(255, 205, 60),
			ModelName = "",
		},
	},
}
