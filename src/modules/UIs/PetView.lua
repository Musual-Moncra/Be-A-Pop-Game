--!strict

--[[
	PetView
	Read-only pet metadata helpers shared by the pet UI: map pool, exclusive reward pet,
	Stink with variant and stacks, drop odds, stack cap and index gems, plus the few derived
	values the screens need (total equipped Stink, discovered lookup).

	API:
		PetView.Stink(petId, variantId, stacks) -> Stink multiplier including variant and stacks
		PetView.DropOdds(pet) -> 1/N roll weight, 0 = unknown
		PetView.StackCap() -> most Stacks a pet can hold
		PetView.IndexGems() -> gems paid when a map index completes
		PetView.PoolForMap(mapId) -> non-exclusive pets droppable on that map
		PetView.ExclusivePet(mapId) -> the map's Pet Index reward pet, if any
		PetView.TotalStink(data) -> equipped Stink multiplier from the server, else recomputed
		PetView.IsDiscovered(index, petId) -> pet appears in the saved Pet Index
	Dependencies: ConfigLookup, PetConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)

local PetView = {}

local function baseStink(pet: any): number
	return tonumber(pet.Stink) or 1
end

function PetView.StackCap(): number
	return math.max(0, math.floor(PetConfig.StackCap))
end

function PetView.Stink(petId: string, variantId: string, stacks: number): number
	local pet = ConfigLookup.GetPet(petId)
	if pet == nil then
		return 1
	end
	local variant = ConfigLookup.GetVariant(variantId)
	local variantBonus = if variant ~= nil then variant.Bonus else 1
	local stackBonus = PetConfig.StackBonus
	local cap = PetView.StackCap()
	local capped = math.max(0, math.floor(stacks))
	if cap > 0 then
		capped = math.min(capped, cap)
	end
	return baseStink(pet) * variantBonus * (1 + stackBonus * capped)
end

function PetView.DropOdds(pet: any): number
	local odds = tonumber(pet.DropOdds)
	if odds == nil or odds <= 0 then
		return 0
	end
	return math.floor(odds)
end

function PetView.IndexGems(): number
	return math.max(0, math.floor(PetConfig.IndexGems))
end

function PetView.PoolForMap(mapId: string): { any }
	return ConfigLookup.GetPetsForMap(mapId)
end

function PetView.ExclusivePet(mapId: string): any
	return ConfigLookup.GetExclusivePet(mapId)
end

function PetView.TotalStink(data: any): number
	local pets = data.Pets
	if pets == nil then
		return 1
	end
	local reported = tonumber(pets.Stink)
	if reported ~= nil and reported > 0 then
		return reported
	end
	local total = 1
	for _, entry in pets.Pets or {} do
		local equipped = false
		for _, uid in pets.Equipped or {} do
			if uid == entry.Uid then
				equipped = true
				break
			end
		end
		if equipped then
			total *= PetView.Stink(entry.PetId, entry.Variant, entry.Stacks or 0)
		end
	end
	return total
end

function PetView.IsDiscovered(index: any, petId: string): boolean
	for _, entry in index or {} do
		if type(entry) == "table" and entry.PetId == petId then
			return true
		end
	end
	return false
end

return PetView
