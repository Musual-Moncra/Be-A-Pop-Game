--!strict

--[[
	DataController
	Client store for every server packet that feeds the UI. Priority 1 so it is
	required before the screens mount. Packets arriving in the same frame are folded
	into one deferred Changed fire, so the React tree re-renders once per frame at most.

	API:
		DataController.Get() -> State
		DataController.Changed -> Signal (fires with the new State)
		DataController.PushToast(kind, text) client-only notification toast
		DataController.PushPopup(kind, text) client-only in-run popup
		DataController.DismissResult() clears the last run summary
		DataController.Stained -> Signal ()            a stain step was painted
		DataController.Soiled -> Signal ()             a prop became fully soiled
		DataController.PowerupPicked -> Signal ()      a food item was eaten
		DataController.NpcCaught -> Signal ()          an NPC caught the player

	State:
		Coins: coins owned (coins)
		Gems: gems owned (gems)
		Level: player level (level)
		Xp: experience inside the current level (xp)
		Upgrades: upgrade id -> owned level (level)
		UnlockedMaps: map id -> true when owned (map ids)
		Stats: lifetime counters from the save file (counts/points)
		MapId: selected map confirmed by the server (map id)
		ModeId: selected mode confirmed by the server (mode id)
		RunState: GameConfig.RunStates value (string)
		TimeLeft: seconds left in the run, -1 = untimed (seconds)
		Score: current run score (points)
		Powerups: active powerups { Id, TimeLeft, Duration, ExpiresAt } (seconds)
		Quests: rolled quests { Id, Text, Progress, Target, Done } (counts)
		LastRun: last RunSummary, nil until a run ends (table)
		Toasts: notification toasts { Id, Kind, Text } (newest last)
		Popups: in-run popups { Id, Kind, Text } (newest last)

	RunSummary:
		Score, Coins, Gems, Xp, MapId, ModeId, ObjectsSoiled, TargetReached,
		QuestsCompleted, QuestCoins, QuestGems, BonusCoins, BonusGems,
		LeveledUp, NewLevel, OutOfTime

	Dependencies: Net, Signal, ConfigLookup, GameConfig, MapConfig, MessageConfig, ModeConfig, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

export type Stats = {
	BestScore: number,
	TotalRuns: number,
	ObjectsSoiled: number,
	PowerupsEaten: number,
	QuestsCompleted: number,
}

export type PowerupState = {
	Id: string,
	TimeLeft: number,
	Duration: number,
	ExpiresAt: number,
}

export type QuestState = {
	Id: string,
	Text: string,
	Progress: number,
	Target: number,
	Done: boolean,
}

export type RunSummary = {
	Score: number,
	Coins: number,
	Gems: number,
	Xp: number,
	MapId: string,
	ModeId: string,
	ObjectsSoiled: number,
	TargetReached: boolean,
	QuestsCompleted: number,
	QuestCoins: number,
	QuestGems: number,
	BonusCoins: number,
	BonusGems: number,
	LeveledUp: number,
	NewLevel: number,
	OutOfTime: boolean,
}

export type Toast = {
	Id: number,
	Kind: string,
	Text: string,
}

export type Popup = {
	Id: number,
	Kind: string,
	Text: string,
}

export type State = {
	Coins: number,
	Gems: number,
	Level: number,
	Xp: number,
	Upgrades: { [string]: number },
	UnlockedMaps: { [string]: boolean },
	Stats: Stats,
	MapId: string,
	ModeId: string,
	RunState: string,
	TimeLeft: number,
	Score: number,
	Powerups: { PowerupState },
	Quests: { QuestState },
	LastRun: RunSummary?,
	Toasts: { Toast },
	Popups: { Popup },
}

local DataController = {}

DataController.Changed = Signal.new()
DataController.Stained = Signal.new()
DataController.Soiled = Signal.new()
DataController.PowerupPicked = Signal.new()
DataController.NpcCaught = Signal.new()

local nextToastId = 0
local nextPopupId = 0

local function defaultStats(): Stats
	return {
		BestScore = 0,
		TotalRuns = 0,
		ObjectsSoiled = 0,
		PowerupsEaten = 0,
		QuestsCompleted = 0,
	}
end

local function defaultState(): State
	return {
		Coins = 0,
		Gems = 0,
		Level = UIConfig.Defaults.Level,
		Xp = 0,
		Upgrades = {},
		UnlockedMaps = { [MapConfig.DefaultMapId] = true },
		Stats = defaultStats(),
		MapId = MapConfig.DefaultMapId,
		ModeId = ModeConfig.DefaultModeId,
		RunState = GameConfig.RunStates.Idle,
		TimeLeft = 0,
		Score = 0,
		Powerups = {},
		Quests = {},
		LastRun = nil,
		Toasts = {},
		Popups = {},
	}
end

local state = defaultState()
local publishScheduled = false

local function flush()
	publishScheduled = false
	state = table.clone(state)
	DataController.Changed:Fire(state)
end

local function publish()
	if not publishScheduled then
		publishScheduled = true
		task.defer(flush)
	end
end

local function cleanUpgrades(source: any): { [string]: number }
	local upgrades = {}
	if type(source) ~= "table" then
		return upgrades
	end
	for id, level in source do
		if type(id) == "string" and type(level) == "number" then
			upgrades[id] = level
		end
	end
	return upgrades
end

local function cleanUnlockedMaps(source: any): { [string]: boolean }
	local maps = {}
	if type(source) ~= "table" then
		return maps
	end
	for id, owned in source do
		if type(id) == "string" and owned == true then
			maps[id] = true
		end
	end
	return maps
end

local function cleanStats(source: any): Stats
	local stats = defaultStats()
	if type(source) ~= "table" then
		return stats
	end
	stats.BestScore = tonumber(source.BestScore) or stats.BestScore
	stats.TotalRuns = tonumber(source.TotalRuns) or stats.TotalRuns
	stats.ObjectsSoiled = tonumber(source.ObjectsSoiled) or stats.ObjectsSoiled
	stats.PowerupsEaten = tonumber(source.PowerupsEaten) or stats.PowerupsEaten
	stats.QuestsCompleted = tonumber(source.QuestsCompleted) or stats.QuestsCompleted
	return stats
end

local function removeToast(id: number)
	for index, toast in state.Toasts do
		if toast.Id == id then
			table.remove(state.Toasts, index)
			publish()
			return
		end
	end
end

local function removePopup(id: number)
	for index, popup in state.Popups do
		if popup.Id == id then
			table.remove(state.Popups, index)
			publish()
			return
		end
	end
end

function DataController.Get(): State
	return state
end

function DataController.PushToast(kind: string, text: string)
	if type(text) ~= "string" or text == "" then
		return
	end
	nextToastId += 1
	local toast: Toast = {
		Id = nextToastId,
		Kind = if type(kind) == "string" then kind else UIConfig.Text.ToastInfoKind,
		Text = text,
	}
	table.insert(state.Toasts, toast)
	while #state.Toasts > UIConfig.Animation.ToastMaxVisible do
		table.remove(state.Toasts, 1)
	end
	publish()
	task.delay(UIConfig.Animation.ToastSeconds, function()
		removeToast(toast.Id)
	end)
end

function DataController.PushPopup(kind: string, text: string)
	if type(text) ~= "string" or text == "" then
		return
	end
	nextPopupId += 1
	local popup: Popup = {
		Id = nextPopupId,
		Kind = if type(kind) == "string" then kind else UIConfig.Text.ToastInfoKind,
		Text = text,
	}
	table.insert(state.Popups, popup)
	publish()
	task.delay(UIConfig.Animation.PopupSeconds, function()
		removePopup(popup.Id)
	end)
end

function DataController.DismissResult()
	if state.LastRun == nil then
		return
	end
	state.LastRun = nil
	publish()
end

Net.DataSync.OnClientEvent:Connect(function(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end

	state.Coins = tonumber(snapshot.Coins) or state.Coins
	state.Gems = tonumber(snapshot.Gems) or state.Gems
	state.Level = tonumber(snapshot.Level) or state.Level
	state.Xp = tonumber(snapshot.Xp) or state.Xp

	if type(snapshot.Upgrades) == "table" then
		state.Upgrades = cleanUpgrades(snapshot.Upgrades)
	end
	if type(snapshot.UnlockedMaps) == "table" then
		state.UnlockedMaps = cleanUnlockedMaps(snapshot.UnlockedMaps)
	end
	state.Stats = cleanStats(snapshot.Stats)

	publish()
end)

Net.SelectionSync.OnClientEvent:Connect(function(mapId: any, modeId: any)
	if type(mapId) == "string" then
		state.MapId = mapId
	end
	if type(modeId) == "string" then
		state.ModeId = modeId
	end
	publish()
end)

Net.RunState.OnClientEvent:Connect(function(runState: any, timeLeft: any, score: any)
	local nextState = if type(runState) == "string" then runState else state.RunState
	if nextState == GameConfig.RunStates.Running and state.RunState ~= GameConfig.RunStates.Running then
		state.LastRun = nil
		state.Powerups = {}
		state.Quests = {}
		state.Popups = {}
	end
	state.RunState = nextState
	local nextTimeLeft = tonumber(timeLeft) or 0
	state.TimeLeft = if nextTimeLeft < 0 then -1 else nextTimeLeft
	state.Score = tonumber(score) or 0
	publish()
end)

Net.PowerupState.OnClientEvent:Connect(function(active: any)
	if type(active) ~= "table" then
		return
	end
	local powerups: { PowerupState } = {}
	for _, entry in active do
		if type(entry) == "table" and type(entry.Id) == "string" then
			local timeLeft = tonumber(entry.TimeLeft) or 0
			table.insert(powerups, {
				Id = entry.Id,
				TimeLeft = timeLeft,
				Duration = tonumber(entry.Duration) or timeLeft,
				ExpiresAt = os.clock() + timeLeft,
			})
		end
	end
	state.Powerups = powerups
	publish()
end)

Net.PowerupPicked.OnClientEvent:Connect(function(powerupId: any)
	if type(powerupId) ~= "string" then
		return
	end
	local definition = ConfigLookup.GetPowerup(powerupId)
	local name = if definition ~= nil then definition.DisplayName else powerupId
	DataController.PushPopup(UIConfig.Text.ToastSuccessKind, string.format(UIConfig.Text.PowerupPickedFormat, name))
	DataController.PowerupPicked:Fire()
end)

Net.ObjectStained.OnClientEvent:Connect(function(_object: any, _step: any)
	DataController.Stained:Fire()
end)

Net.ObjectSoiled.OnClientEvent:Connect(function(object: any, bonus: any)
	local name = UIConfig.Text.ObjectUnknown
	if typeof(object) == "Instance" and object:IsA("Model") then
		name = object.Name
		local objectType = object:GetAttribute("ObjectType")
		if type(objectType) == "string" then
			local definition = ConfigLookup.GetObject(objectType)
			if definition ~= nil then
				name = definition.DisplayName
			end
		end
	end
	DataController.PushPopup(
		UIConfig.Text.ToastSuccessKind,
		string.format(UIConfig.Text.ObjectSoiledFormat, name, math.floor(tonumber(bonus) or 0))
	)
	DataController.Soiled:Fire()
end)

Net.NpcCaught.OnClientEvent:Connect(function(penaltySeconds: any)
	DataController.PushPopup(
		UIConfig.Text.ToastErrorKind,
		string.format(MessageConfig.NpcCaught, math.ceil(tonumber(penaltySeconds) or 0))
	)
	DataController.NpcCaught:Fire()
end)

Net.QuestState.OnClientEvent:Connect(function(quests: any)
	if type(quests) ~= "table" then
		return
	end
	local cleaned: { QuestState } = {}
	for _, entry in quests do
		if type(entry) == "table" and type(entry.Id) == "string" then
			table.insert(cleaned, {
				Id = entry.Id,
				Text = if type(entry.Text) == "string" then entry.Text else "",
				Progress = tonumber(entry.Progress) or 0,
				Target = tonumber(entry.Target) or 0,
				Done = entry.Done == true,
			})
		end
	end
	state.Quests = cleaned
	publish()
end)

Net.RunEnded.OnClientEvent:Connect(function(summary: any)
	local cleaned: RunSummary = {
		Score = 0,
		Coins = 0,
		Gems = 0,
		Xp = 0,
		MapId = state.MapId,
		ModeId = state.ModeId,
		ObjectsSoiled = 0,
		TargetReached = false,
		QuestsCompleted = 0,
		QuestCoins = 0,
		QuestGems = 0,
		BonusCoins = 0,
		BonusGems = 0,
		LeveledUp = 0,
		NewLevel = state.Level,
		OutOfTime = false,
	}

	if type(summary) == "table" then
		cleaned.Score = tonumber(summary.Score) or cleaned.Score
		cleaned.Coins = tonumber(summary.Coins) or cleaned.Coins
		cleaned.Gems = tonumber(summary.Gems) or cleaned.Gems
		cleaned.Xp = tonumber(summary.Xp) or cleaned.Xp
		cleaned.MapId = if type(summary.MapId) == "string" then summary.MapId else cleaned.MapId
		cleaned.ModeId = if type(summary.ModeId) == "string" then summary.ModeId else cleaned.ModeId
		cleaned.ObjectsSoiled = tonumber(summary.ObjectsSoiled) or cleaned.ObjectsSoiled
		cleaned.TargetReached = summary.TargetReached == true
		cleaned.QuestsCompleted = tonumber(summary.QuestsCompleted) or cleaned.QuestsCompleted
		cleaned.QuestCoins = tonumber(summary.QuestCoins) or cleaned.QuestCoins
		cleaned.QuestGems = tonumber(summary.QuestGems) or cleaned.QuestGems
		cleaned.BonusCoins = tonumber(summary.BonusCoins) or cleaned.BonusCoins
		cleaned.BonusGems = tonumber(summary.BonusGems) or cleaned.BonusGems
		cleaned.LeveledUp = tonumber(summary.LeveledUp) or cleaned.LeveledUp
		cleaned.NewLevel = tonumber(summary.NewLevel) or cleaned.NewLevel
		cleaned.OutOfTime = summary.OutOfTime == true
	end

	state.LastRun = cleaned
	state.RunState = GameConfig.RunStates.Idle
	state.TimeLeft = 0
	state.Score = 0
	state.Powerups = {}
	state.Quests = {}
	publish()
end)

Net.Notify.OnClientEvent:Connect(function(kind: any, text: any)
	DataController.PushToast(
		if type(kind) == "string" then kind else UIConfig.Text.ToastInfoKind,
		if type(text) == "string" then text else ""
	)
end)

return DataController
