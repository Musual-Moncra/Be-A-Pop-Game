--!strict

--[[
	PowerupConfig
	Food items that spawn during a run and give a temporary boost when eaten. Pure data, no functions.

	Spawning fields:
		SpawnInterval: time between two food spawns on a map while a run is active (seconds)
		MaxActivePerRun: most food items lying on the map for one player at once (count)
		ItemLifetime: food disappears if nobody eats it within this time (seconds)
		PickupRadius: how close the poop must get to eat food (studs)
		SpawnHeight: how high above the floor food floats (studs)
		SpawnRayTopInset: the spawn ray starts this far below the top of the map's PlayArea, under the ceiling (studs)
		SyncInterval: how often the active power-up list is re-sent to the player (seconds)
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
]]

local PowerupConfig = {}

PowerupConfig.SpawnInterval = 6
PowerupConfig.MaxActivePerRun = 4
PowerupConfig.ItemLifetime = 20
PowerupConfig.PickupRadius = 5
PowerupConfig.SpawnHeight = 2.5
PowerupConfig.SpawnRayTopInset = 0.5
PowerupConfig.SyncInterval = 1
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

PowerupConfig.Powerups = {
	Chili = {
		DisplayName = "Hot Chili",
		Icon = "🌶",
		Color = Color3.fromRGB(230, 50, 40),
		Weight = 30,
		Duration = 8,
		SpeedMultiplier = 1.6,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 0,
	},
	Burger = {
		DisplayName = "Mega Burger",
		Icon = "🍔",
		Color = Color3.fromRGB(214, 150, 60),
		Weight = 20,
		Duration = 10,
		SpeedMultiplier = 0.9,
		StainSizeMultiplier = 2,
		CharacterScale = 2,
		PointsMultiplier = 1,
		TimeBonus = 0,
	},
	Beans = {
		DisplayName = "Magic Beans",
		Icon = "🫘",
		Color = Color3.fromRGB(150, 90, 200),
		Weight = 20,
		Duration = 10,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 2,
		TimeBonus = 0,
	},
	Water = {
		DisplayName = "Water Bottle",
		Icon = "💧",
		Color = Color3.fromRGB(90, 180, 250),
		Weight = 15,
		Duration = 0,
		SpeedMultiplier = 1,
		StainSizeMultiplier = 1,
		CharacterScale = 1,
		PointsMultiplier = 1,
		TimeBonus = 8,
	},
	GoldenCorn = {
		DisplayName = "Golden Corn",
		Icon = "🌽",
		Color = Color3.fromRGB(255, 210, 40),
		Weight = 5,
		Duration = 6,
		SpeedMultiplier = 1.3,
		StainSizeMultiplier = 1.5,
		CharacterScale = 1.4,
		PointsMultiplier = 3,
		TimeBonus = 3,
	},
}

return PowerupConfig
