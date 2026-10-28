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
	Stove = { DisplayName = "Stove", PointsMultiplier = 2.5, StainsToSoil = 8, SoilBonus = 60 },
	Pot = { DisplayName = "Soup Pot", PointsMultiplier = 3, StainsToSoil = 3, SoilBonus = 40 },
	Fridge = { DisplayName = "Fridge", PointsMultiplier = 3, StainsToSoil = 10, SoilBonus = 80 },
	Island = { DisplayName = "Kitchen Island", PointsMultiplier = 2, StainsToSoil = 10, SoilBonus = 50 },
	Shelf = { DisplayName = "Pantry Shelf", PointsMultiplier = 2, StainsToSoil = 6, SoilBonus = 30 },
	Table = { DisplayName = "Table", PointsMultiplier = 2, StainsToSoil = 6, SoilBonus = 35 },
	Trash = { DisplayName = "Trash Can", PointsMultiplier = 1.5, StainsToSoil = 3, SoilBonus = 15 },
	Sink = { DisplayName = "Sink", PointsMultiplier = 2, StainsToSoil = 4, SoilBonus = 30 },
	Plant = { DisplayName = "Plant", PointsMultiplier = 2, StainsToSoil = 3, SoilBonus = 25 },
	Storefront = { DisplayName = "Shop Front", PointsMultiplier = 2, StainsToSoil = 18, SoilBonus = 140 },
	Mannequin = { DisplayName = "Mannequin", PointsMultiplier = 3, StainsToSoil = 4, SoilBonus = 70 },
	ClothesRack = { DisplayName = "Clothes Rack", PointsMultiplier = 2.5, StainsToSoil = 5, SoilBonus = 60 },
	Kiosk = { DisplayName = "Kiosk", PointsMultiplier = 3, StainsToSoil = 8, SoilBonus = 110 },
	Escalator = { DisplayName = "Escalator", PointsMultiplier = 2, StainsToSoil = 16, SoilBonus = 150 },
	Bench = { DisplayName = "Bench", PointsMultiplier = 2, StainsToSoil = 4, SoilBonus = 40 },
	Fountain = { DisplayName = "Fountain", PointsMultiplier = 5, StainsToSoil = 10, SoilBonus = 250 },
	Tree = { DisplayName = "Tree", PointsMultiplier = 2, StainsToSoil = 8, SoilBonus = 60 },
	IceCreamCart = { DisplayName = "Ice Cream Cart", PointsMultiplier = 4, StainsToSoil = 6, SoilBonus = 160 },
	Slide = { DisplayName = "Slide", PointsMultiplier = 3, StainsToSoil = 10, SoilBonus = 140 },
	Swing = { DisplayName = "Swing Set", PointsMultiplier = 3, StainsToSoil = 6, SoilBonus = 110 },
	Carousel = { DisplayName = "Carousel", PointsMultiplier = 4, StainsToSoil = 12, SoilBonus = 220 },
	Statue = { DisplayName = "Statue", PointsMultiplier = 4, StainsToSoil = 5, SoilBonus = 180 },
	Flowerbed = { DisplayName = "Flower Bed", PointsMultiplier = 2, StainsToSoil = 4, SoilBonus = 50 },
	Carpet = { DisplayName = "Red Carpet", PointsMultiplier = 1.5, StainsToSoil = 30, SoilBonus = 200 },
	Reception = { DisplayName = "Reception Desk", PointsMultiplier = 3, StainsToSoil = 14, SoilBonus = 240 },
	Pillar = { DisplayName = "Pillar", PointsMultiplier = 2.5, StainsToSoil = 8, SoilBonus = 120 },
	Bed = { DisplayName = "Bed", PointsMultiplier = 3, StainsToSoil = 8, SoilBonus = 160 },
	Sofa = { DisplayName = "Sofa", PointsMultiplier = 2.5, StainsToSoil = 8, SoilBonus = 120 },
	LuggageCart = { DisplayName = "Luggage Cart", PointsMultiplier = 4, StainsToSoil = 6, SoilBonus = 200 },
	Piano = { DisplayName = "Piano", PointsMultiplier = 5, StainsToSoil = 8, SoilBonus = 300 },
	Elevator = { DisplayName = "Elevator Doors", PointsMultiplier = 3, StainsToSoil = 10, SoilBonus = 220 },
	Crate = { DisplayName = "Fruit Crates", PointsMultiplier = 2, StainsToSoil = 4, SoilBonus = 35 },
	Microwave = { DisplayName = "Microwave", PointsMultiplier = 3, StainsToSoil = 3, SoilBonus = 45 },
	Toaster = { DisplayName = "Toaster", PointsMultiplier = 3, StainsToSoil = 2, SoilBonus = 35 },
	DogBed = { DisplayName = "Dog Bed", PointsMultiplier = 2, StainsToSoil = 5, SoilBonus = 45 },
	Clock = { DisplayName = "Wall Clock", PointsMultiplier = 4, StainsToSoil = 2, SoilBonus = 60 },
	VendingMachine = { DisplayName = "Vending Machine", PointsMultiplier = 3, StainsToSoil = 6, SoilBonus = 90 },
	Display = { DisplayName = "Shop Display", PointsMultiplier = 4, StainsToSoil = 6, SoilBonus = 130 },
	ShoppingCart = { DisplayName = "Shopping Cart", PointsMultiplier = 2.5, StainsToSoil = 3, SoilBonus = 50 },
}

return ObjectConfig
