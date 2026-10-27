--!strict

--[[
	MapService
	Owns the player's map/mode selection, unlocks maps and validates selections.
	The remotes themselves are bound in Remotes.MapRemotes.

	API:
		MapService.GetSelection(plr)                  -> { mapId: string, modeId: string }
		MapService.UnlockMap(plr, mapId)              -> boolean
		MapService.SelectRun(plr, mapId, modeId)      -> boolean

	Dependencies: DataService, Outbound, ConfigLookup, MapConfig, ModeConfig, MessageConfig, DataConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)

export type Selection = {
	mapId: string,
	modeId: string,
}

local MapService = {}

local selections: { [Player]: Selection } = {}

local function defaultSelection(): Selection
	return {
		mapId = MapConfig.DefaultMapId,
		modeId = ModeConfig.DefaultModeId,
	}
end

function MapService.GetSelection(plr: Player): Selection
	local selection = selections[plr]
	if selection == nil then
		selection = defaultSelection()
		selections[plr] = selection
	end
	return selection
end

function MapService.UnlockMap(plr: Player, mapId: string): boolean
	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil then
		Outbound.Notify(plr, "Error", MessageConfig.MapUnavailable)
		return false
	end

	local ok, reason = DataService.UnlockMap(plr, mapId)
	if ok then
		Outbound.Notify(plr, "Success", string.format(MessageConfig.MapUnlocked, mapDef.DisplayName))
		return true
	end

	if reason == "AlreadyUnlocked" then
		Outbound.Notify(plr, "Error", MessageConfig.AlreadyUnlocked)
	elseif reason == "NeedPrevious" then
		local previous = ConfigLookup.GetPreviousMap(mapId)
		local previousName = if previous ~= nil then previous.DisplayName else mapDef.DisplayName
		Outbound.Notify(plr, "Error", string.format(MessageConfig.NeedPreviousMap, previousName))
	elseif reason == "NeedLevel" then
		Outbound.Notify(plr, "Error", string.format(MessageConfig.NeedLevel, mapDef.RequiredLevel))
	elseif reason == "NotEnoughCoins" then
		Outbound.Notify(plr, "Error", MessageConfig.NotEnoughCoins)
	else
		Outbound.Notify(plr, "Error", MessageConfig.MapUnavailable)
	end
	return false
end

function MapService.SelectRun(plr: Player, mapId: string, modeId: string): boolean
	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil or not mapDef.Enabled then
		Outbound.Notify(plr, "Error", MessageConfig.MapUnavailable)
		return false
	end
	if not DataService.IsMapUnlocked(plr, mapId) then
		Outbound.Notify(plr, "Error", MessageConfig.MapLocked)
		return false
	end

	local modeDef = ConfigLookup.GetMode(modeId)
	if modeDef == nil then
		return false
	end

	local data = DataService.Get(plr)
	local level = if data ~= nil then data.Level else DataConfig.Template.Level
	if level < modeDef.RequiredLevel then
		Outbound.Notify(plr, "Error", string.format(MessageConfig.ModeLocked, modeDef.RequiredLevel))
		return false
	end

	selections[plr] = {
		mapId = mapId,
		modeId = modeId,
	}
	Outbound.SelectionSync(plr, mapId, modeId)
	return true
end

local function onPlayerAdded(plr: Player)
	local selection = MapService.GetSelection(plr)
	Outbound.SelectionSync(plr, selection.mapId, selection.modeId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(plr)
	selections[plr] = nil
end)

for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

return MapService
