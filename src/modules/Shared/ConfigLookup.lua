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
		ConfigLookup.GetPet(id) -> PetDefinition?
		ConfigLookup.GetSortedPets() -> { PetDefinition }
		ConfigLookup.GetPetsForEgg(eggId) -> { PetDefinition }
		ConfigLookup.GetEgg(id) -> EggDefinition?
		ConfigLookup.GetSortedEggs() -> { EggDefinition }
		ConfigLookup.GetRarity(id) -> RarityDefinition?
		ConfigLookup.GetVariant(id) -> VariantDefinition?
		ConfigLookup.GetNextVariant(variantId) -> string?
		ConfigLookup.GetEggWeight(eggId) -> number
		ConfigLookup.RollPet(eggId, roll) -> PetDefinition?
		ConfigLookup.RollVariant(roll) -> VariantDefinition?
		ConfigLookup.GetPetMultipliers(petId, variantId) -> PetMultipliers
		ConfigLookup.GetMaxEquippedSlots(extraSlots) -> number

	Dependencies: GameConfig, MapConfig, ModeConfig, UpgradeConfig, PowerupConfig, ObjectConfig, QuestConfig,
		PetConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Modules.Config
local GameConfig = require(Config.GameConfig)
local MapConfig = require(Config.MapConfig)
local ModeConfig = require(Config.ModeConfig)
local ObjectConfig = require(Config.ObjectConfig)
local PetConfig = require(Config.PetConfig)
local PowerupConfig = require(Config.PowerupConfig)
local QuestConfig = require(Config.QuestConfig)
local UpgradeConfig = require(Config.UpgradeConfig)

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

export type RarityDefinition = {
	Id: string,
	DisplayName: string,
	Order: number,
	Weight: number,
	Color: Color3,
}

export type VariantDefinition = {
	Id: string,
	DisplayName: string,
	Bonus: number,
	Weight: number,
	NextVariant: string?,
	Color: Color3,
}

export type EggDefinition = {
	Id: string,
	MapId: string,
	DisplayName: string,
	Price: number,
	BaseSlots: number,
	InventoryCap: number,
	Order: number,
	Color: Color3,
}

export type PetDefinition = {
	Id: string,
	DisplayName: string,
	EggId: string,
	Rarity: string,
	CoinMultiplier: number,
	StinkMultiplier: number,
	Size: number,
	Color: Color3,
}

export type PetMultipliers = {
	Coins: number,
	Stink: number,
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

function ConfigLookup.GetPet(id: string): PetDefinition?
	for _, pet in PetConfig.Pets :: { PetDefinition } do
		if pet.Id == id then
			return pet
		end
	end
	return nil
end

function ConfigLookup.GetSortedPets(): { PetDefinition }
	return table.clone(PetConfig.Pets :: { PetDefinition })
end

function ConfigLookup.GetPetsForEgg(eggId: string): { PetDefinition }
	local pets = {}
	for _, pet in PetConfig.Pets :: { PetDefinition } do
		if pet.EggId == eggId then
			table.insert(pets, pet)
		end
	end
	return pets
end

function ConfigLookup.GetEgg(id: string): EggDefinition?
	return (PetConfig.Eggs :: { [string]: EggDefinition })[id]
end

function ConfigLookup.GetSortedEggs(): { EggDefinition }
	local eggs = {}
	for _, egg in PetConfig.Eggs :: { [string]: EggDefinition } do
		table.insert(eggs, egg)
	end
	table.sort(eggs, byOrder)
	return eggs
end

function ConfigLookup.GetRarity(id: string): RarityDefinition?
	return (PetConfig.Rarities :: { [string]: RarityDefinition })[id]
end

function ConfigLookup.GetVariant(id: string): VariantDefinition?
	return (PetConfig.Variants :: { [string]: VariantDefinition })[id]
end

function ConfigLookup.GetNextVariant(variantId: string): string?
	local variant = ConfigLookup.GetVariant(variantId)
	if variant == nil then
		return nil
	end
	return variant.NextVariant
end

function ConfigLookup.GetEggWeight(eggId: string): number
	local total = 0
	for _, pet in ConfigLookup.GetPetsForEgg(eggId) do
		local rarity = ConfigLookup.GetRarity(pet.Rarity)
		if rarity ~= nil then
			total += rarity.Weight
		end
	end
	return total
end

function ConfigLookup.RollPet(eggId: string, roll: number): PetDefinition?
	local total = ConfigLookup.GetEggWeight(eggId)
	if total <= 0 then
		return nil
	end
	local target = math.clamp(roll, 0, 1) * total
	local cursor = 0
	local last: PetDefinition? = nil
	for _, pet in ConfigLookup.GetPetsForEgg(eggId) do
		local rarity = ConfigLookup.GetRarity(pet.Rarity)
		if rarity ~= nil then
			last = pet
			cursor += rarity.Weight
			if target < cursor then
				return pet
			end
		end
	end
	return last
end

function ConfigLookup.RollVariant(roll: number): VariantDefinition?
	local total = 0
	for _, variant in PetConfig.Variants :: { [string]: VariantDefinition } do
		total += variant.Weight
	end
	if total <= 0 then
		return nil
	end
	local target = math.clamp(roll, 0, 1) * total
	local cursor = 0
	local last: VariantDefinition? = nil
	for _, variant in PetConfig.Variants :: { [string]: VariantDefinition } do
		last = variant
		cursor += variant.Weight
		if target < cursor then
			return variant
		end
	end
	return last
end

function ConfigLookup.GetPetMultipliers(petId: string, variantId: string): PetMultipliers
	local pet = ConfigLookup.GetPet(petId)
	if pet == nil then
		return { Coins = 1, Stink = 1 }
	end
	local variant = ConfigLookup.GetVariant(variantId)
	local bonus = if variant ~= nil then variant.Bonus else 1
	return {
		Coins = pet.CoinMultiplier * bonus,
		Stink = pet.StinkMultiplier * bonus,
	}
end

function ConfigLookup.GetMaxEquippedSlots(extraSlots: number): number
	return PetConfig.BaseSlots + math.max(0, math.floor(extraSlots))
end

return ConfigLookup
