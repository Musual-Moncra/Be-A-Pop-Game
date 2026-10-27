--!strict

--[[
	DataController
	Client store for DataSync / RunState / RunEnded / SelectionSync.
	Priority 1 so it is required before the UIs mount.
	API: DataController.Get() -> State; DataController.Changed -> Signal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

export type Upgrades = {
	Lifespan: number,
	Speed: number,
	StainSize: number,
}

export type Stats = {
	BestScore: number,
	TotalRuns: number,
}

export type LastRun = {
	Score: number,
	Coins: number,
}

export type State = {
	Coins: number,
	Gems: number,
	Upgrades: Upgrades,
	Stats: Stats,
	RunState: string,
	TimeLeft: number,
	Score: number,
	LastRun: LastRun?,
	MapId: string,
	ModeId: string,
}

local DataController = {}

DataController.Changed = Signal.new()

local function defaultState(): State
	return {
		Coins = 0,
		Gems = 0,
		Upgrades = {
			Lifespan = 0,
			Speed = 0,
			StainSize = 0,
		},
		Stats = {
			BestScore = 0,
			TotalRuns = 0,
		},
		RunState = GameConfig.RunStates.Idle,
		TimeLeft = 0,
		Score = 0,
		MapId = MapConfig.DefaultMapId,
		ModeId = ModeConfig.DefaultModeId,
	}
end

local state = defaultState()

local function publish()
	state = table.clone(state)
	DataController.Changed:Fire(state)
end

function DataController.Get(): State
	return state
end

Net.DataSync.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then
		return
	end

	state.Coins = tonumber(snapshot.Coins) or state.Coins
	state.Gems = tonumber(snapshot.Gems) or state.Gems

	if type(snapshot.Upgrades) == "table" then
		state.Upgrades = {
			Lifespan = tonumber(snapshot.Upgrades.Lifespan) or state.Upgrades.Lifespan,
			Speed = tonumber(snapshot.Upgrades.Speed) or state.Upgrades.Speed,
			StainSize = tonumber(snapshot.Upgrades.StainSize) or state.Upgrades.StainSize,
		}
	end

	if type(snapshot.Stats) == "table" then
		state.Stats = {
			BestScore = tonumber(snapshot.Stats.BestScore) or state.Stats.BestScore,
			TotalRuns = tonumber(snapshot.Stats.TotalRuns) or state.Stats.TotalRuns,
		}
	end

	publish()
end)

Net.RunState.OnClientEvent:Connect(function(runState, timeLeft, score)
	state.RunState = if type(runState) == "string" then runState else state.RunState
	local nextTimeLeft = tonumber(timeLeft) or 0
	state.TimeLeft = if nextTimeLeft < 0 then -1 else nextTimeLeft
	state.Score = tonumber(score) or 0
	publish()
end)

Net.SelectionSync.OnClientEvent:Connect(function(mapId, modeId)
	if type(mapId) == "string" then
		state.MapId = mapId
	end
	if type(modeId) == "string" then
		state.ModeId = modeId
	end
	publish()
end)

Net.RunEnded.OnClientEvent:Connect(function(score, coins)
	state.LastRun = {
		Score = tonumber(score) or 0,
		Coins = tonumber(coins) or 0,
	}
	state.RunState = GameConfig.RunStates.Idle
	state.TimeLeft = 0
	state.Score = 0
	publish()
end)

return DataController
