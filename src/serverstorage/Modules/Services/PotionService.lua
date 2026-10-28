--!strict

--[[
	PotionService
	Manages persistent lobby potion inventory, activation, expiries and active stat multipliers.

	API:
		PotionService.UsePotion(plr: Player, potionId: string): (boolean, string?)
		PotionService.GetActivePotions(plr: Player): { [string]: number }
		PotionService.GetMultiplier(plr: Player, stat: string): number

	Dependencies: DataService, Outbound, ConfigLookup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(ServerStorage.Modules.Services.DataService)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)

local PotionService = {}

function PotionService.GetActivePotions(plr: Player): { [string]: number }
	local data = DataService.Get(plr)
	if data == nil or data.Potions == nil then
		return {}
	end
	local now = os.time()
	local active: { [string]: number } = {}
	local dirty = false
	for id, expiresAt in data.Potions do
		if expiresAt > now then
			active[id] = expiresAt
		else
			data.Potions[id] = nil
			dirty = true
		end
	end
	if dirty then
		DataService.MarkChanged(plr)
	end
	return active
end

function PotionService.GetMultiplier(plr: Player, stat: string): number
	local data = DataService.Get(plr)
	if data == nil or data.Potions == nil then
		return 1
	end
	local now = os.time()
	local mult = 1
	for id, expiresAt in data.Potions do
		if expiresAt > now then
			local def = ConfigLookup.GetPotion(id)
			if def ~= nil and def.Stat == stat then
				mult *= def.Multiplier
			end
		end
	end
	return mult
end

function PotionService.UsePotion(plr: Player, potionId: string): (boolean, string?)
	local def = ConfigLookup.GetPotion(potionId)
	if def == nil then
		Outbound.Notify(plr, "Error", "Invalid potion.")
		return false, "InvalidPotion"
	end

	local data = DataService.Get(plr)
	if data == nil then
		return false, "NoData"
	end

	if data.PotionInventory == nil then
		data.PotionInventory = {}
	end
	if data.Potions == nil then
		data.Potions = {}
	end

	local count = data.PotionInventory[potionId] or 0
	if count <= 0 then
		Outbound.Notify(plr, "Error", "No potions of that type in inventory.")
		return false, "NoInventory"
	end

	local now = os.time()
	local currentExpiry = data.Potions[potionId] or 0
	local baseTime = if currentExpiry > now then currentExpiry else now
	local newExpiry = baseTime + def.Duration

	data.PotionInventory[potionId] = count - 1
	data.Potions[potionId] = newExpiry
	DataService.MarkChanged(plr)

	Outbound.Notify(plr, "Success", string.format("%s activated!", def.DisplayName))
	return true, nil
end

return PotionService
