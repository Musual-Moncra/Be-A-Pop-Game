--!strict

--[[
	ObjectConfig
	Scoring for map objects. Every prop Model in a map carries an ObjectType attribute that
	matches a key below; staining it is worth more than staining plain floor or walls, and once
	enough of it is stained the whole object turns poop colored and pays a bonus. Pure data.

	Fields:
		SurfacePointsMultiplier: score multiplier for floor, walls and ceiling (multiplier)
		SoiledColor: color an object turns once it is fully soiled (RGB)
		SoiledMaterial: material an object turns once it is fully soiled (Enum.Material)
		TintSteps: how many color steps an object goes through on its way to fully soiled (count)
		Objects: one table per object type, keyed by the ObjectType attribute in the map
			DisplayName: name shown in quests and the soiled popup (text)
			PointsMultiplier: score multiplier for stains on this object (multiplier)
			StainsToSoil: stain splats needed on it before it counts as fully soiled (count)
			SoilBonus: score added once when the object becomes fully soiled (points)
]]

local ObjectConfig = {}

ObjectConfig.SurfacePointsMultiplier = 1
ObjectConfig.SoiledColor = Color3.fromRGB(110, 66, 28)
ObjectConfig.SoiledMaterial = Enum.Material.Slate
ObjectConfig.TintSteps = 4

ObjectConfig.Objects = {
	Counter = { DisplayName = "Counter", PointsMultiplier = 1.5, StainsToSoil = 14, SoilBonus = 40 },
	Fridge = { DisplayName = "Fridge", PointsMultiplier = 3, StainsToSoil = 10, SoilBonus = 80 },
	Island = { DisplayName = "Kitchen Island", PointsMultiplier = 2, StainsToSoil = 10, SoilBonus = 50 },
	Shelf = { DisplayName = "Pantry Shelf", PointsMultiplier = 2, StainsToSoil = 6, SoilBonus = 30 },
	Table = { DisplayName = "Table", PointsMultiplier = 2, StainsToSoil = 6, SoilBonus = 35 },
	Trash = { DisplayName = "Trash Can", PointsMultiplier = 1.5, StainsToSoil = 3, SoilBonus = 15 },
	Sofa = { DisplayName = "Sofa", PointsMultiplier = 2.5, StainsToSoil = 12, SoilBonus = 70 },
	TV = { DisplayName = "Giant TV", PointsMultiplier = 4, StainsToSoil = 10, SoilBonus = 120 },
	Carpet = { DisplayName = "Carpet", PointsMultiplier = 1.5, StainsToSoil = 30, SoilBonus = 90 },
	Bookshelf = { DisplayName = "Bookshelf", PointsMultiplier = 2.5, StainsToSoil = 8, SoilBonus = 60 },
	Plant = { DisplayName = "House Plant", PointsMultiplier = 2, StainsToSoil = 3, SoilBonus = 25 },
	Piano = { DisplayName = "Piano", PointsMultiplier = 4, StainsToSoil = 8, SoilBonus = 150 },
	Bar = { DisplayName = "Bar Counter", PointsMultiplier = 2, StainsToSoil = 20, SoilBonus = 120 },
	Buffet = { DisplayName = "Buffet Line", PointsMultiplier = 3, StainsToSoil = 16, SoilBonus = 160 },
	Stage = { DisplayName = "Stage", PointsMultiplier = 2.5, StainsToSoil = 24, SoilBonus = 200 },
	Fountain = { DisplayName = "Fountain", PointsMultiplier = 5, StainsToSoil = 10, SoilBonus = 250 },
}

return ObjectConfig
