--!strict

--[[
	RebirthService
	Handles rebirth requirements, stat resets, permanent multiplier grants, and rebirth execution.

	API:
		RebirthService.GetMultiplier(plr: Player): number
		RebirthService.Rebirth(plr: Player): boolean

	Dependencies: DataService, Outbound, ConfigLookup, MessageConfig, RebirthConfig, UpgradeConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(ServerStorage.Modules.Services.DataService)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local RebirthConfig = require(ReplicatedStorage.Modules.Config.RebirthConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Config.UpgradeConfig)

local RebirthService = {}

function RebirthService.GetMultiplier(plr: Player): number
	local data = DataService.Get(plr)
	local count = if data ~= nil and data.Rebirths ~= nil then data.Rebirths else 0
	return ConfigLookup.GetRebirthMultiplier(count)
end

function RebirthService.Rebirth(plr: Player): boolean
	local data = DataService.Get(plr)
	if data == nil then
		return false
	end

	local currentRebirths = data.Rebirths or 0
	local cost = ConfigLookup.GetRebirthCost(currentRebirths)

	if data.Coins < cost then
		Outbound.Notify(plr, "Error", MessageConfig.NotEnoughCoins)
		return false
	end

	data.Coins = 0
	data.Rebirths = currentRebirths + 1

	-- Reset upgrades
	local upgrades = data.Upgrades or {}
	for upgradeId in UpgradeConfig.Upgrades do
		upgrades[upgradeId] = 0
	end
	data.Upgrades = upgrades

	-- Optional map reset
	if RebirthConfig.ResetUnlockedMaps then
		data.UnlockedMaps = {
			Zone1 = true,
		}
	end

	-- Grant gems
	if RebirthConfig.GemsPerRebirth > 0 then
		data.Gems = (data.Gems or 0) + RebirthConfig.GemsPerRebirth
	end

	DataService.MarkChanged(plr)

	-- Re-apply base upgrade stats (e.g. speed reset to base)
	local UpgradeService = require(ServerStorage.Modules.Services.UpgradeService)
	UpgradeService.ApplyStats(plr, plr.Character)

	Outbound.Notify(plr, "Success", string.format(MessageConfig.RebirthSuccess, data.Rebirths))
	return true
end

return RebirthService
