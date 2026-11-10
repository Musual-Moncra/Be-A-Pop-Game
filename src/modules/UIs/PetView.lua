--!strict

--[[
	PetView
	Read-only pet metadata helpers shared by the pet UI. PetConfig is being extended in
	parallel (Stink, MapId, DropOdds, Exclusive, StackCap, StackBonus, IndexGems), so every
	lookup reads the new field first and falls back to the Phase 6 shape while the branches
	are apart.

	API:
		PetView.MapId(pet) -> map id a pet drops on, "" = not droppable
		PetView.BaseStink(pet) -> base Stink multiplier of a pet
		PetView.Stink(petId, variantId, stacks) -> Stink multiplier including variant and stacks
		PetView.DropOdds(pet) -> 1/N roll weight, 0 = unknown
		PetView.IsExclusive(pet) -> true for a map's index reward pet
		PetView.StackCap() -> most Stacks a pet can hold, 0 = unknown
		PetView.IndexGems() -> gems paid when a map index completes
		PetView.PoolForMap(mapId) -> pets droppable on that map
		PetView.TotalStink(data) -> equipped Stink multiplier from the server, else recomputed
		PetView.IsDiscovered(index, petId) -> pet appears in the saved Pet Index
	Dependencies: ConfigLookup, PetConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)

local PetView = {}

function PetView.MapId(pet: any): string
	local source = pet
	if type(source.MapId) == "string" then
		return source.MapId
	end
	local egg = ConfigLookup.GetEgg(source.EggId)
	return if egg ~= nil then egg.MapId else ""
end

function PetView.BaseStink(pet: any): number
	local source = pet
	local stink = tonumber(source.Stink)
	if stink ~= nil then
		return stink
	end
	return tonumber(source.StinkMultiplier) or 1
end

function PetView.StackCap(): number
	local cap = tonumber((PetConfig :: any).StackCap)
	if cap == nil or cap <= 0 then
		return 0
	end
	return math.floor(cap)
end

function PetView.Stink(petId: string, variantId: string, stacks: number): number
	local pet = ConfigLookup.GetPet(petId)
	if pet == nil then
		return 1
	end
	local variant = ConfigLookup.GetVariant(variantId)
	local variantBonus = if variant ~= nil then variant.Bonus else 1
	local stackBonus = tonumber((PetConfig :: any).StackBonus) or 0
	local cap = PetView.StackCap()
	local capped = math.max(0, math.floor(stacks))
	if cap > 0 then
		capped = math.min(capped, cap)
	end
	return PetView.BaseStink(pet) * variantBonus * (1 + stackBonus * capped)
end

function PetView.DropOdds(pet: any): number
	local odds = tonumber(pet.DropOdds)
	if odds == nil or odds <= 0 then
		return 0
	end
	return math.floor(odds)
end

function PetView.IsExclusive(pet: any): boolean
	return pet.Exclusive == true
end

function PetView.IndexGems(): number
	local gems = tonumber((PetConfig :: any).IndexGems)
	if gems == nil then
		return 0
	end
	return math.max(0, math.floor(gems))
end

function PetView.PoolForMap(mapId: string): { any }
	local pool = {}
	for _, pet in ConfigLookup.GetSortedPets() do
		if PetView.MapId(pet) == mapId then
			table.insert(pool, pet)
		end
	end
	return pool
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
