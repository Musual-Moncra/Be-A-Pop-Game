--!strict

--[[
	ConfigLookup
	Read-only helpers over the pure-data Config modules, shared by server and client.
	Config files hold numbers only; every formula that turns them into a value lives here.

	API:
		ConfigLookup.GetMap(id) -> MapDefinition?
		ConfigLookup.GetSortedMaps() -> { MapDefinition }
		ConfigLookup.GetPreviousMap(id) -> MapDefinition?
		ConfigLookup.GetMode(id) -> ModeDefinition?
		ConfigLookup.GetSortedModes() -> { ModeDefinition }
		ConfigLookup.GetUpgrade(id) -> UpgradeDefinition?
		ConfigLookup.GetSortedUpgradeIds() -> { string }
		ConfigLookup.GetUpgradeCost(id, level) -> number
		ConfigLookup.GetUpgradeValue(id, level) -> number
		ConfigLookup.FormatUpgradeValue(id, value) -> string
		ConfigLookup.GetLevelXp(level) -> number          xp needed to leave `level`
		ConfigLookup.GetPowerup(id) -> PowerupDefinition?
		ConfigLookup.GetObject(objectType) -> ObjectDefinition?
		ConfigLookup.GetQuest(id) -> QuestDefinition?
		ConfigLookup.FormatQuest(quest) -> string
		ConfigLookup.GetDailyReward(day) -> DailyRewardDefinition?
		ConfigLookup.GetDailyBoost(boostId) -> DailyBoostDefinition?
		ConfigLookup.GetPass(passKey) -> PassDefinition?
		ConfigLookup.GetDevProduct(productId) -> kind, entry
		ConfigLookup.GetReviveTier(tier) -> ReviveDefinition?
		ConfigLookup.IsReviveAvailable() -> boolean
		ConfigLookup.GetEnabledMaps() -> { MapDefinition }
		ConfigLookup.GetMapCellCount(size) -> number        stain cells covering a footprint
		ConfigLookup.GetMapProgressPercent(stained, total) -> number
		ConfigLookup.GetPotion(id) -> PotionDefinition?
		ConfigLookup.GetSortedPotionIds() -> { string }
		ConfigLookup.GetRebirthCost(rebirths) -> number
		ConfigLookup.GetRebirthMultiplier(rebirths) -> number
		ConfigLookup.GetSkin(id) -> any
		ConfigLookup.GetTrail(id) -> any
		ConfigLookup.GetCrate(id) -> any

	Dependencies: GameConfig, MapConfig, ModeConfig, UpgradeConfig, PowerupConfig, ObjectConfig,
		QuestConfig, DailyRewardConfig, MonetizationConfig, PotionConfig, RebirthConfig, CosmeticConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Modules.Config
local DailyRewardConfig = require(Config.DailyRewardConfig)
local GameConfig = require(Config.GameConfig)
local MapConfig = require(Config.MapConfig)
local ModeConfig = require(Config.ModeConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local ObjectConfig = require(Config.ObjectConfig)
local PowerupConfig = require(Config.PowerupConfig)
local QuestConfig = require(Config.QuestConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local PotionConfig = require(Config.PotionConfig)
local RebirthConfig = require(Config.RebirthConfig)
local CosmeticConfig = require(Config.CosmeticConfig)

export type MapDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	ModelName: string,
	Spawn: Vector3,
	Order: number,
	UnlockCost: number,
	RequiredLevel: number,
	RewardMultiplier: number,
	SizeLabel: string,
	Enabled: boolean,
	CompletionGems: number,
	RequirePreviousComplete: boolean,
}

export type ModeDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	Order: number,
	Duration: number,
	MaxDuration: number,
	RewardMultiplier: number,
	PowerupsEnabled: boolean,
	NpcsEnabled: boolean,
	TargetScore: number,
	TargetBonusCoins: number,
	TargetBonusGems: number,
	QuestCount: number,
	RequiredLevel: number,
}

export type UpgradeDefinition = {
	DisplayName: string,
	Description: string,
	Order: number,
	Icon: string,
	ValueFormat: string,
	Base: number,
	PerLevel: number,
	CostBase: number,
	CostGrowth: number,
	MaxLevel: number,
}

export type PowerupDefinition = {
	DisplayName: string,
	Icon: string,
	Color: Color3,
	Weight: number,
	Duration: number,
	SpeedMultiplier: number,
	StainSizeMultiplier: number,
	CharacterScale: number,
	PointsMultiplier: number,
	TimeBonus: number,
	IsComboSaver: boolean,
	IsMiniBomb: boolean,
}

export type PotionDefinition = {
	DisplayName: string,
	Icon: string,
	Duration: number,
	Multiplier: number,
	Stat: string,
	Description: string,
}

export type ObjectDefinition = {
	DisplayName: string,
	PointsMultiplier: number,
	StainsToSoil: number,
	SoilBonus: number,
}

export type QuestDefinition = {
	Id: string,
	Kind: string,
	Target: number,
	ObjectType: string,
	Description: string,
	RewardCoins: number,
	RewardGems: number,
	Weight: number,
	MinMapOrder: number,
}

local ConfigLookup = {}

local function byOrder(a: any, b: any): boolean
	return a.Order < b.Order
end

function ConfigLookup.GetMap(id: string): MapDefinition?
	for _, map in MapConfig.Maps :: { MapDefinition } do
		if map.Id == id then
			return map
		end
	end
	return nil
end

function ConfigLookup.GetSortedMaps(): { MapDefinition }
	local maps = table.clone(MapConfig.Maps :: { MapDefinition })
	table.sort(maps, byOrder)
	return maps
end

function ConfigLookup.GetPreviousMap(id: string): MapDefinition?
	local previous: MapDefinition? = nil
	for _, map in ConfigLookup.GetSortedMaps() do
		if map.Id == id then
			return previous
		end
		previous = map
	end
	return nil
end

function ConfigLookup.GetMode(id: string): ModeDefinition?
	for _, mode in ModeConfig.Modes :: { ModeDefinition } do
		if mode.Id == id then
			return mode
		end
	end
	return nil
end

function ConfigLookup.GetSortedModes(): { ModeDefinition }
	local modes = table.clone(ModeConfig.Modes :: { ModeDefinition })
	table.sort(modes, byOrder)
	return modes
end

function ConfigLookup.GetUpgrade(id: string): UpgradeDefinition?
	return (UpgradeConfig.Upgrades :: { [string]: UpgradeDefinition })[id]
end

function ConfigLookup.GetSortedUpgradeIds(): { string }
	local ids = {}
	for id in UpgradeConfig.Upgrades do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return UpgradeConfig.Upgrades[a].Order < UpgradeConfig.Upgrades[b].Order
	end)
	return ids
end

function ConfigLookup.GetUpgradeCost(id: string, level: number): number
	local upgrade = ConfigLookup.GetUpgrade(id)
	assert(upgrade, `Unknown upgrade id: {id}`)
	return math.floor(upgrade.CostBase * upgrade.CostGrowth ^ level)
end

function ConfigLookup.GetUpgradeValue(id: string, level: number): number
	local upgrade = ConfigLookup.GetUpgrade(id)
	assert(upgrade, `Unknown upgrade id: {id}`)
	return upgrade.Base + upgrade.PerLevel * level
end

function ConfigLookup.FormatUpgradeValue(id: string, value: number): string
	local upgrade = ConfigLookup.GetUpgrade(id)
	if upgrade == nil then
		return tostring(value)
	end
	local rounded = math.round(value * 100) / 100
	local text = if rounded == math.floor(rounded) then string.format("%d", rounded) else tostring(rounded)
	return (string.gsub(upgrade.ValueFormat, "%%s", text))
end

function ConfigLookup.GetLevelXp(level: number): number
	return math.floor(GameConfig.LevelXpBase * GameConfig.LevelXpGrowth ^ (math.max(level, 1) - 1))
end

function ConfigLookup.GetPowerup(id: string): PowerupDefinition?
	return (PowerupConfig.Powerups :: { [string]: PowerupDefinition })[id]
end

function ConfigLookup.GetObject(objectType: string): ObjectDefinition?
	return (ObjectConfig.Objects :: { [string]: ObjectDefinition })[objectType]
end

function ConfigLookup.GetQuest(id: string): QuestDefinition?
	for _, quest in QuestConfig.Quests :: { QuestDefinition } do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

function ConfigLookup.FormatQuest(quest: QuestDefinition): string
	return (string.gsub(quest.Description, "%%d", tostring(quest.Target)))
end

export type DailyRewardDefinition = {
	Kind: string,
	Amount: number,
	BoostId: string,
	Duration: number,
	SkinId: string,
	Label: string,
}

export type DailyBoostDefinition = {
	Multiplier: number,
	Duration: number,
}

function ConfigLookup.GetDailyReward(day: number): DailyRewardDefinition?
	return (DailyRewardConfig.Days :: { DailyRewardDefinition })[day]
end

function ConfigLookup.GetDailyBoost(boostId: string): DailyBoostDefinition?
	return (DailyRewardConfig.Boosts :: { [string]: DailyBoostDefinition })[boostId]
end

function ConfigLookup.GetPass(passKey: string): any?
	return (MonetizationConfig.Gamepasses :: any)[passKey]
end

function ConfigLookup.GetDevProduct(productId: number): (string?, any?)
	if productId == 0 then
		return nil, nil
	end

	for _, entry in MonetizationConfig.DevProducts.GemPacks do
		if entry.Id ~= 0 and entry.Id == productId then
			return "GemPack", entry
		end
	end
	for _, entry in MonetizationConfig.DevProducts.CoinPacks do
		if entry.Id ~= 0 and entry.Id == productId then
			return "CoinPack", entry
		end
	end
	for _, entry in MonetizationConfig.DevProducts.Revive do
		if entry.Id ~= 0 and entry.Id == productId then
			return "Revive", entry
		end
	end

	local stainBomb = MonetizationConfig.DevProducts.StainBomb
	if stainBomb.Id ~= 0 and stainBomb.Id == productId then
		return "StainBomb", stainBomb
	end
	local newbiePack = MonetizationConfig.DevProducts.NewbiePack
	if newbiePack.Id ~= 0 and newbiePack.Id == productId then
		return "NewbiePack", newbiePack
	end
	return nil, nil
end

function ConfigLookup.GetReviveTier(tier: number): any?
	local tiers = MonetizationConfig.DevProducts.Revive
	if #tiers == 0 then
		return nil
	end
	return tiers[math.clamp(tier, 1, #tiers)]
end

function ConfigLookup.IsReviveAvailable(): boolean
	local tier = ConfigLookup.GetReviveTier(1)
	return tier ~= nil and tier.Id ~= 0
end

function ConfigLookup.GetEnabledMaps(): { MapDefinition }
	local maps = {}
	for _, map in ConfigLookup.GetSortedMaps() do
		if map.Enabled then
			table.insert(maps, map)
		end
	end
	return maps
end

function ConfigLookup.GetMapCellCount(size: Vector3): number
	local cellSize = GameConfig.StainCellSize
	if cellSize <= 0 then
		return 0
	end
	return math.max(1, math.floor(size.X * size.Z / (cellSize * cellSize)))
end

function ConfigLookup.GetMapProgressPercent(stained: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp(stained / total * 100, 0, 100)
end

function ConfigLookup.GetPotion(id: string): PotionDefinition?
	return (PotionConfig.Potions :: { [string]: PotionDefinition })[id]
end

function ConfigLookup.GetSortedPotionIds(): { string }
	local ids = {}
	for id in PotionConfig.Potions do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end


function ConfigLookup.GetRebirthCost(rebirths: number): number
	return math.floor(RebirthConfig.BaseCost * (RebirthConfig.CostGrowth ^ rebirths))
end

function ConfigLookup.GetRebirthMultiplier(rebirths: number): number
	return 1 + (rebirths * RebirthConfig.MultiplierPerRebirth)
end

function ConfigLookup.GetSkin(id: string)
	return CosmeticConfig.Skins[id]
end

function ConfigLookup.GetTrail(id: string)
	return CosmeticConfig.Trails[id]
end

function ConfigLookup.GetCrate(id: string)
	return CosmeticConfig.Crates[id]
end

return ConfigLookup
