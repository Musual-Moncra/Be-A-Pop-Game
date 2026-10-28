--!strict

--[[
	QuestConfig
	Run objectives rolled at the start of a Quests-mode run. Pure data, no functions.

	Quest kinds (Kind field):
		Score: reach Target score in one run
		SoilAny: fully soil Target objects of any type
		SoilType: fully soil Target objects whose ObjectType equals ObjectType
		Powerups: eat Target food items
		Cells: stain Target separate spots

	Fields:
		Quests: list of quests, one table per quest
			Id: unique quest id (string)
			Kind: one of the kinds above (string)
			Target: amount needed to complete the quest (count or points)
			ObjectType: object type for SoilType quests, empty otherwise (ObjectConfig key)
			Description: text shown in the HUD; %d is replaced by Target (text)
			RewardCoins: coins paid when completed (coins)
			RewardGems: gems paid when completed (gems)
			Weight: roll chance compared to other quests, higher = more common (number)
			MinMapOrder: quest only rolls on maps with at least this MapConfig Order (number)
]]

local QuestConfig = {}

QuestConfig.Quests = {
	{
		Id = "Score300",
		Kind = "Score",
		Target = 300,
		ObjectType = "",
		Description = "Reach %d score",
		RewardCoins = 150,
		RewardGems = 0,
		Weight = 30,
		MinMapOrder = 1,
	},
	{
		Id = "Score1000",
		Kind = "Score",
		Target = 1000,
		ObjectType = "",
		Description = "Reach %d score",
		RewardCoins = 500,
		RewardGems = 3,
		Weight = 15,
		MinMapOrder = 2,
	},
	{
		Id = "SoilAny3",
		Kind = "SoilAny",
		Target = 3,
		ObjectType = "",
		Description = "Soil %d objects",
		RewardCoins = 200,
		RewardGems = 1,
		Weight = 25,
		MinMapOrder = 1,
	},
	{
		Id = "SoilFridge",
		Kind = "SoilType",
		Target = 1,
		ObjectType = "Fridge",
		Description = "Soil %d fridge",
		RewardCoins = 250,
		RewardGems = 2,
		Weight = 15,
		MinMapOrder = 1,
	},
	{
		Id = "SoilMannequin",
		Kind = "SoilType",
		Target = 2,
		ObjectType = "Mannequin",
		Description = "Soil %d mannequins",
		RewardCoins = 400,
		RewardGems = 2,
		Weight = 15,
		MinMapOrder = 2,
	},
	{
		Id = "SoilBench",
		Kind = "SoilType",
		Target = 3,
		ObjectType = "Bench",
		Description = "Soil %d benches",
		RewardCoins = 600,
		RewardGems = 4,
		Weight = 15,
		MinMapOrder = 2,
	},
	{
		Id = "Eat3",
		Kind = "Powerups",
		Target = 3,
		ObjectType = "",
		Description = "Eat %d food items",
		RewardCoins = 180,
		RewardGems = 1,
		Weight = 25,
		MinMapOrder = 1,
	},
	{
		Id = "Cells150",
		Kind = "Cells",
		Target = 150,
		ObjectType = "",
		Description = "Stain %d spots",
		RewardCoins = 220,
		RewardGems = 1,
		Weight = 20,
		MinMapOrder = 1,
	},
}

return QuestConfig
