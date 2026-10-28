--!strict

--[[
	MapProgressService
	Tracks how much of the map a run has stained, streams the live percent to the client,
	checkpoints each player's best percent per map and pays the one-time 100% gem reward.

	A map's total target count is the number of soilable props plus the stain cells of its
	PlayArea footprint, computed once per map model and cached.

	API:
		MapProgressService.GetLive(plr) -> number            percent of the current run, 0..100
		MapProgressService.GetBest(plr, mapId) -> number     best saved percent, 0..100
		MapProgressService.GetTotal(mapId) -> number         total targets used for the percent

	Dependencies: RunService, DataService, Outbound, RunEvents, EventConfig, MessageConfig,
		ConfigLookup, GameConfig, Workspace
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RunServiceModule = require(script.Parent.RunService)
local DataService = require(script.Parent.DataService)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local EventConfig = require(ReplicatedStorage.Modules.Config.EventConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)

type Session = {
	player: Player,
	mapId: string,
	percent: number,
	saved: number,
	sent: number,
}

local MapProgressService = {}

local sessions: { [Player]: Session } = {}
local totals: { [string]: number } = {}
local accumulator = 0

local function countCells(cells: { [string]: boolean }): number
	local count = 0
	for _ in cells do
		count += 1
	end
	return count
end

local function computeTotal(mapDef: ConfigLookup.MapDefinition): number
	local model = Workspace:FindFirstChild(mapDef.ModelName)
	if model == nil then
		return 0
	end

	local total = 0
	local props = model:FindFirstChild("Props")
	if props ~= nil then
		for _, child in props:GetChildren() do
			if child:IsA("Model") then
				local objectType = child:GetAttribute("ObjectType")
				if typeof(objectType) == "string" and ConfigLookup.GetObject(objectType) ~= nil then
					total += 1
				end
			end
		end
	end

	local playArea = model:FindFirstChild("PlayArea", true)
	if playArea ~= nil and playArea:IsA("BasePart") then
		total += ConfigLookup.GetMapCellCount(playArea.Size)
	end

	return total
end

local function getTotal(mapDef: ConfigLookup.MapDefinition): number
	local cached = totals[mapDef.Id]
	if cached ~= nil then
		return cached
	end
	local total = computeTotal(mapDef)
	if total > 0 then
		totals[mapDef.Id] = total
	end
	return total
end

local function getBest(plr: Player, mapId: string): number
	local data = DataService.Get(plr)
	if data == nil or data.MapProgress == nil then
		return 0
	end
	return tonumber(data.MapProgress[mapId]) or 0
end

function MapProgressService.GetLive(plr: Player): number
	local session = sessions[plr]
	return if session ~= nil then session.percent else 0
end

function MapProgressService.GetBest(plr: Player, mapId: string): number
	return getBest(plr, mapId)
end

function MapProgressService.GetTotal(mapId: string): number
	local mapDef = ConfigLookup.GetMap(mapId)
	return if mapDef ~= nil then getTotal(mapDef) else 0
end

local function checkpoint(session: Session)
	if session.percent <= session.saved then
		return
	end
	local data = DataService.Get(session.player)
	if data == nil or data.MapProgress == nil then
		return
	end
	local best = getBest(session.player, session.mapId)
	if session.percent > best then
		data.MapProgress[session.mapId] = session.percent
		session.saved = session.percent
		DataService.MarkChanged(session.player)
	end
end

local function awardCompletion(session: Session)
	local mapDef = ConfigLookup.GetMap(session.mapId)
	if mapDef == nil or getBest(session.player, session.mapId) >= 100 then
		return
	end

	local data = DataService.Get(session.player)
	if data == nil or data.MapProgress == nil then
		return
	end

	data.MapProgress[session.mapId] = 100
	session.saved = 100
	DataService.MarkChanged(session.player)

	local gems = mapDef.CompletionGems
	if gems > 0 then
		DataService.AddGems(session.player, gems)
	end
	Outbound.Notify(
		session.player,
		"Success",
		string.format(MessageConfig.MapComplete, mapDef.DisplayName, gems)
	)
end

local function update(session: Session)
	local run = RunServiceModule.GetRun(session.player)
	if run == nil then
		return
	end

	local total = getTotal(run.mapDef)
	if total <= 0 then
		return
	end

	local stained = run.objectsSoiled + countCells(run.visitedCells)
	local percent = ConfigLookup.GetMapProgressPercent(stained, total)
	if percent <= session.percent then
		return
	end
	session.percent = percent

	if percent - session.sent >= 0.1 then
		session.sent = percent
		Outbound.MapProgress(session.player, session.mapId, percent)
	end

	if percent >= 100 then
		awardCompletion(session)
	elseif percent - session.saved >= EventConfig.MapProgress.SaveStepPercent then
		checkpoint(session)
	end
end

RunEvents.RunStarted:Connect(function(plr: Player, mapId: string)
	sessions[plr] = {
		player = plr,
		mapId = mapId,
		percent = 0,
		saved = getBest(plr, mapId),
		sent = -1,
	}
	Outbound.MapProgress(plr, mapId, 0)
end)

RunEvents.RunEnded:Connect(function(plr: Player)
	local session = sessions[plr]
	if session == nil then
		return
	end
	sessions[plr] = nil
	checkpoint(session)
end)

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < EventConfig.MapProgress.SyncInterval then
		return
	end
	accumulator = 0
	for _, session in sessions do
		update(session)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local session = sessions[plr]
	if session ~= nil then
		sessions[plr] = nil
		checkpoint(session)
	end
end)

return MapProgressService
