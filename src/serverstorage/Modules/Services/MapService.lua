--!strict

--[[
	MapService
	Owns the player's map/mode selection, unlocks maps and validates selections.

	API:
		MapService.GetSelection(plr)                  -> { mapId: string, modeId: string }
		MapService.UnlockMap(plr, mapId)              -> boolean
		MapService.SelectRun(plr, mapId, modeId)      -> boolean

	Dependencies: DataService, ConfigLookup, MapConfig, ModeConfig, MessageConfig, Net, DataConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

export type Selection = {
	mapId: string,
	modeId: string,
}

local MapService = {}

local selections: { [Player]: Selection } = {}
local lastUnlock: { [Player]: number } = {}

local function notify(plr: Player, kind: string, text: string)
	if plr.Parent == Players then
		Net.Notify:FireClient(plr, kind, text)
	end
end

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
	if type(mapId) ~= "string" then
		return false
	end

	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil then
		notify(plr, "Error", MessageConfig.MapUnavailable)
		return false
	end

	local ok, reason = DataService.UnlockMap(plr, mapId)
	if ok then
		notify(plr, "Success", string.format(MessageConfig.MapUnlocked, mapDef.DisplayName))
		return true
	end

	if reason == "AlreadyUnlocked" then
		notify(plr, "Error", MessageConfig.AlreadyUnlocked)
	elseif reason == "NeedPrevious" then
		local previous = ConfigLookup.GetPreviousMap(mapId)
		local previousName = if previous ~= nil then previous.DisplayName else mapDef.DisplayName
		notify(plr, "Error", string.format(MessageConfig.NeedPreviousMap, previousName))
	elseif reason == "NeedLevel" then
		notify(plr, "Error", string.format(MessageConfig.NeedLevel, mapDef.RequiredLevel))
	elseif reason == "NotEnoughCoins" then
		notify(plr, "Error", MessageConfig.NotEnoughCoins)
	else
		notify(plr, "Error", MessageConfig.MapUnavailable)
	end
	return false
end

function MapService.SelectRun(plr: Player, mapId: string, modeId: string): boolean
	if type(mapId) ~= "string" or type(modeId) ~= "string" then
		return false
	end

	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil then
		notify(plr, "Error", MessageConfig.MapUnavailable)
		return false
	end
	if not mapDef.Enabled then
		notify(plr, "Error", MessageConfig.MapUnavailable)
		return false
	end
	if not DataService.IsMapUnlocked(plr, mapId) then
		notify(plr, "Error", MessageConfig.MapLocked)
		return false
	end

	local modeDef = ConfigLookup.GetMode(modeId)
	if modeDef == nil then
		return false
	end

	local data = DataService.Get(plr)
	local level = if data ~= nil then data.Level else DataConfig.Template.Level
	if level < modeDef.RequiredLevel then
		notify(plr, "Error", string.format(MessageConfig.ModeLocked, modeDef.RequiredLevel))
		return false
	end

	selections[plr] = {
		mapId = mapId,
		modeId = modeId,
	}
	Net.SelectionSync:FireClient(plr, mapId, modeId)
	return true
end

local function onPlayerAdded(plr: Player)
	local selection = MapService.GetSelection(plr)
	Net.SelectionSync:FireClient(plr, selection.mapId, selection.modeId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(plr)
	selections[plr] = nil
	lastUnlock[plr] = nil
end)

for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

Net.UnlockMap.OnServerEvent:Connect(function(plr, mapId)
	local now = os.clock()
	local last = lastUnlock[plr]
	if last ~= nil and now - last < DataConfig.PurchaseRateLimit then
		return
	end
	lastUnlock[plr] = now
	MapService.UnlockMap(plr, mapId)
end)

Net.SelectRun.OnServerEvent:Connect(function(plr, mapId, modeId)
	MapService.SelectRun(plr, mapId, modeId)
end)

return MapService
