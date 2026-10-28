--!strict

--[[
	PowerupConfig
	Food items that spawn during a run and give a temporary boost when eaten. Pure data, no functions.

	Spawning fields:
		SpawnInterval: time between two food spawns on a map while a run is active (seconds)
		MaxActivePerRun: most food items lying on the map for one player at once (count)
		ItemLifetime: food disappears if nobody eats it within this time (seconds)
		PickupRadius: how close the poop must get to eat food, multiplied by the poop's current size (studs)
		SpawnHeight: how high above the floor food floats (studs)
		SpawnRayTopInset: the spawn ray starts this far below the top of the map's PlayArea, under the ceiling (studs)
		SyncInterval: how often the active power-up list is re-sent to the player (seconds)
		TickInterval: how often the server checks pickups, expiry and spawning for every run (seconds)
		FirstSpawnDelay: wait before the first food of a run appears (seconds)
		ItemShape: shape of the food part (Enum.PartType)
		ItemMaterial: material of the food part (Enum.Material)
		BobHeight: how far food bobs up and down (studs)
		BobSpeed: bob cycles per second (cycles/second)
		SpinSpeed: how fast food spins (degrees/second)
		ItemSize: size of the food ball (studs)
		FolderPrefix: name prefix of the per-player Workspace folder that holds food (string)
		IconSize: size of the floating emoji shown above each food (studs)
		IconHeight: how far above the food the emoji floats (studs)

	Caps:
		MaxSpeedMultiplier: maximum combined speed multiplier from all active perks (multiplier)
		MaxStainSizeMultiplier: maximum combined stain size multiplier from all active perks (multiplier)
		MaxPointsMultiplier: maximum combined points multiplier from all active perks (multiplier)
		MaxCharacterScale: maximum character scale from all active perks (multiplier)

	Bomb:
		MiniBombRadius: blast radius for Mini Bomb stain detonation (studs)

	Powerups: one table per food, keyed by powerup id
		DisplayName: name shown in the HUD and pickup popup (text)
		Icon: emoji or short text shown in the HUD (text)
		Color: color of the food item (RGB)
		Weight: spawn chance compared to the other foods, higher = more common (number)
		Duration: how long the boost lasts before the PowerupDuration upgrade (seconds, 0 = instant)
		SpeedMultiplier: walking speed is multiplied by this while active (multiplier)
		StainSizeMultiplier: stain width is multiplied by this while active (multiplier)
		CharacterScale: poop body size is multiplied by this while active (multiplier)
		PointsMultiplier: score from staining is multiplied by this while active (multiplier)
		TimeBonus: seconds added to the run timer when eaten (seconds)
		IsComboSaver: whether picking up this perk refreshes remaining duration of all active perks (boolean)
		IsMiniBomb: whether picking up this perk instantly soils all props/NPCs within MiniBombRadius (boolean)
]]

local PowerupConfig = {}

PowerupConfig.SpawnInterval = 6
PowerupConfig.MaxActivePerRun = 4
PowerupConfig.ItemLifetime = 20
PowerupConfig.PickupRadius = 5
PowerupConfig.SpawnHeight = 2.5
PowerupConfig.SpawnRayTopInset = 0.5
PowerupConfig.SyncInterval = 1
PowerupConfig.TickInterval = 0.05
PowerupConfig.FirstSpawnDelay = 3
PowerupConfig.ItemShape = Enum.PartType.Ball
PowerupConfig.ItemMaterial = Enum.Material.Neon
PowerupConfig.BobHeight = 0.6
PowerupConfig.BobSpeed = 0.8
PowerupConfig.SpinSpeed = 90
PowerupConfig.ItemSize = 2.5
PowerupConfig.FolderPrefix = "Powerups_"
PowerupConfig.IconSize = 3.5
PowerupConfig.IconHeight = 2.5

PowerupConfig.MaxSpeedMultiplier = 4
PowerupConfig.MaxStainSizeMultiplier = 4
PowerupConfig.MaxPointsMultiplier = 8
PowerupConfig.MaxCharacterScale = 3
PowerupConfig.MiniBombRadius = 25

PowerupConfig.Powerups = {
	SpeedBoost = {
		DisplayName = "Speed Boost",
		Icon = "⚡",
		Color = Color3.fromRGB(240, 200, 30),
		Weight = 25,
		Duration = 10,
		SpeedMultiplier = 2,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 0,
		IsComboSaver = false,
		IsMiniBomb = false,
	},
	TimeBonus = {
		DisplayName = "Time Bonus",
		Icon = "⏰",
		Color = Color3.fromRGB(80, 200, 240),
		Weight = 20,
		Duration = 0,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 60,
		IsComboSaver = false,
		IsMiniBomb = false,
	},
	BigSplat = {
		DisplayName = "Big Splat",
		Icon = "💥",
		Color = Color3.fromRGB(160, 60, 220),
		Weight = 20,
		Duration = 10,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 2,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 0,
		IsComboSaver = false,
		IsMiniBomb = false,
	},
	CoinRush = {
		DisplayName = "Coin Rush",
		Icon = "🪙",
		Color = Color3.fromRGB(255, 215, 0),
		Weight = 15,
		Duration = 10,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 2,
		TimeBonus = 0,
		IsComboSaver = false,
		IsMiniBomb = false,
	},
	MegaSize = {
		DisplayName = "Mega Size",
		Icon = "🐘",
		Color = Color3.fromRGB(220, 120, 40),
		Weight = 15,
		Duration = 10,
		SpeedMultiplier = 0.9,
		StainSizeMultiplier = 2,
		CharacterScale = 2,
		PointsMultiplier = 1.5,
		TimeBonus = 0,
		IsComboSaver = false,
		IsMiniBomb = false,
	},
	ComboSaver = {
		DisplayName = "Combo Saver",
		Icon = "🔄",
		Color = Color3.fromRGB(50, 220, 120),
		Weight = 10,
		Duration = 0,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 0,
		IsComboSaver = true,
		IsMiniBomb = false,
	},
	MiniBomb = {
		DisplayName = "Mini Bomb",
		Icon = "💣",
		Color = Color3.fromRGB(240, 50, 50),
		Weight = 10,
		Duration = 0,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 0,
		IsComboSaver = false,
		IsMiniBomb = true,
	},
}

return PowerupConfig
