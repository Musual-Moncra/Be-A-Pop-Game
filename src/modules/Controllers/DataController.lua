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
		Daily: daily streak { Day, CanClaim, SecondsUntilNext, Streak }, nil until the server sends it
		GoldenTargets: golden prop paths relative to the map model (name paths)
		Pets: owned and equipped pets { Pets, Equipped, Slots } (pet entries / uids / slots)
		LastHatch: last hatched pet { PetId, Variant, At }, At = os.clock(), nil until a hatch
		Cosmetics: { EquippedSkin, EquippedTrail, OwnedSkins, OwnedTrails } (ids / owned maps)
		LastCrate: last crate reward { CrateId, Kind, Id, IsNew, Refund }, nil until a crate opens
		Rebirths: rebirths completed (count)
		Potions: active potion expiries, potion id -> unix time it ends (unix seconds)
		PotionInventory: owned potion counts, potion id -> count (counts)
		OwnedPasses: owned gamepass key -> true (pass keys)
		ReviveOffer: open revive offer { ProductId, Tier, ExpiresAt }, ExpiresAt = os.clock(), nil = none
		MapProgress: live percent of the current run { MapId, Percent } (percent 0..100)
		BestMapProgress: best percent per map, map id -> percent (percent 0..100)
		SpecialEvent: active Special Time { MapId, EndsAt }, EndsAt = Workspace server clock, nil = none
		Leaderboards: { Daily, Weekly, AllTime }, each { { Rank, Name, Value } }
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
local DailyRewardConfig = require(ReplicatedStorage.Modules.Config.DailyRewardConfig)
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

export type DailyState = {
	Day: number,
	CanClaim: boolean,
	SecondsUntilNext: number,
	Streak: number,
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

export type PetEntry = {
	Uid: string,
	PetId: string,
	Variant: string,
}

export type Pets = {
	Pets: { PetEntry },
	Equipped: { string },
	Slots: number,
}

export type LastHatch = {
	PetId: string,
	Variant: string,
	At: number,
}

export type Cosmetics = {
	EquippedSkin: string,
	EquippedTrail: string,
	OwnedSkins: { [string]: boolean },
	OwnedTrails: { [string]: boolean },
}

export type CrateResult = {
	CrateId: string,
	Kind: string,
	Id: string,
	IsNew: boolean,
	Refund: number,
}

export type ReviveOffer = {
	ProductId: number,
	Tier: number,
	ExpiresAt: number,
}

export type MapProgress = {
	MapId: string,
	Percent: number,
}

export type SpecialEvent = {
	MapId: string,
	EndsAt: number,
}

export type LeaderboardEntry = {
	Rank: number,
	Name: string,
	Value: number,
}

export type Leaderboards = {
	Daily: { LeaderboardEntry },
	Weekly: { LeaderboardEntry },
	AllTime: { LeaderboardEntry },
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
	Daily: DailyState?,
	GoldenTargets: { string },
	Pets: Pets,
	LastHatch: LastHatch?,
	Cosmetics: Cosmetics,
	LastCrate: CrateResult?,
	Rebirths: number,
	Potions: { [string]: number },
	PotionInventory: { [string]: number },
	OwnedPasses: { [string]: boolean },
	ReviveOffer: ReviveOffer?,
	MapProgress: MapProgress,
	BestMapProgress: { [string]: number },
	SpecialEvent: SpecialEvent?,
	Leaderboards: Leaderboards,
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
		Daily = nil,
		GoldenTargets = {},
		Pets = { Pets = {}, Equipped = {}, Slots = ConfigLookup.GetMaxEquippedSlots(0) },
		LastHatch = nil,
		Cosmetics = {
			EquippedSkin = "Default",
			EquippedTrail = "",
			OwnedSkins = { Default = true },
			OwnedTrails = {},
		},
		LastCrate = nil,
		Rebirths = 0,
		Potions = {},
		PotionInventory = {},
		OwnedPasses = {},
		ReviveOffer = nil,
		MapProgress = { MapId = "", Percent = 0 },
		BestMapProgress = {},
		SpecialEvent = nil,
		Leaderboards = { Daily = {}, Weekly = {}, AllTime = {} },
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

local function cleanNumberMap(source: any): { [string]: number }
	local cleaned = {}
	if type(source) ~= "table" then
		return cleaned
	end
	for id, value in source do
		if type(id) == "string" and type(value) == "number" then
			cleaned[id] = value
		end
	end
	return cleaned
end

local function cleanOwned(source: any): { [string]: boolean }
	local owned = {}
	if type(source) ~= "table" then
		return owned
	end
	for id, value in source do
		if type(id) == "string" and value == true then
			owned[id] = true
		end
	end
	return owned
end

local function cleanPetEntries(source: any): { PetEntry }
	local entries: { PetEntry } = {}
	if type(source) ~= "table" then
		return entries
	end
	for _, entry in source do
		if
			type(entry) == "table"
			and type(entry.Uid) == "string"
			and type(entry.PetId) == "string"
			and type(entry.Variant) == "string"
		then
			table.insert(entries, { Uid = entry.Uid, PetId = entry.PetId, Variant = entry.Variant })
		end
	end
	return entries
end

local function cleanUids(source: any): { string }
	local uids: { string } = {}
	if type(source) ~= "table" then
		return uids
	end
	for _, uid in source do
		if type(uid) == "string" then
			table.insert(uids, uid)
		end
	end
	return uids
end

local function cleanLeaderboardEntries(source: any): { LeaderboardEntry }
	local entries: { LeaderboardEntry } = {}
	if type(source) ~= "table" then
		return entries
	end
	for index, entry in source do
		if type(entry) == "table" and type(entry.Name) == "string" then
			table.insert(entries, {
				Rank = math.floor(tonumber(entry.Rank) or index),
				Name = entry.Name,
				Value = math.floor(tonumber(entry.Value) or 0),
			})
		end
	end
	return entries
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

	state.Rebirths = math.max(0, math.floor(tonumber(snapshot.Rebirths) or state.Rebirths))
	if type(snapshot.Potions) == "table" then
		state.Potions = cleanNumberMap(snapshot.Potions)
	end
	if type(snapshot.PotionInventory) == "table" then
		state.PotionInventory = cleanNumberMap(snapshot.PotionInventory)
	end
	if type(snapshot.MapProgress) == "table" then
		state.BestMapProgress = cleanNumberMap(snapshot.MapProgress)
	end
	if type(snapshot.OwnedSkins) == "table" or type(snapshot.OwnedTrails) == "table" then
		state.Cosmetics = {
			EquippedSkin = if type(snapshot.EquippedSkin) == "string" and snapshot.EquippedSkin ~= ""
				then snapshot.EquippedSkin
				else state.Cosmetics.EquippedSkin,
			EquippedTrail = if type(snapshot.EquippedTrail) == "string"
				then snapshot.EquippedTrail
				else state.Cosmetics.EquippedTrail,
			OwnedSkins = if type(snapshot.OwnedSkins) == "table"
				then cleanOwned(snapshot.OwnedSkins)
				else state.Cosmetics.OwnedSkins,
			OwnedTrails = if type(snapshot.OwnedTrails) == "table"
				then cleanOwned(snapshot.OwnedTrails)
				else state.Cosmetics.OwnedTrails,
		}
	end
	if type(snapshot.Pets) == "table" then
		local pets = snapshot.Pets
		state.Pets = {
			Pets = cleanPetEntries(pets.Inventory),
			Equipped = cleanUids(pets.Equipped),
			Slots = ConfigLookup.GetMaxEquippedSlots(tonumber(pets.ExtraSlots) or 0),
		}
	end

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
		state.GoldenTargets = {}
		state.Popups = {}
	end
	state.RunState = nextState
	local nextTimeLeft = tonumber(timeLeft) or 0
	state.TimeLeft = if nextTimeLeft < 0 then -1 else nextTimeLeft
	state.Score = tonumber(score) or 0
	if nextState == GameConfig.RunStates.Running and state.TimeLeft > 0 then
		state.ReviveOffer = nil
	end
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
	state.GoldenTargets = {}
	state.ReviveOffer = nil
	publish()
end)

Net.GoldenTargets.OnClientEvent:Connect(function(paths: any)
	if type(paths) ~= "table" then
		return
	end
	local cleaned: { string } = {}
	for _, path in paths do
		if type(path) == "string" and path ~= "" then
			table.insert(cleaned, path)
		end
	end
	state.GoldenTargets = cleaned
	publish()
end)

Net.Notify.OnClientEvent:Connect(function(kind: any, text: any)
	DataController.PushToast(
		if type(kind) == "string" then kind else UIConfig.Text.ToastInfoKind,
		if type(text) == "string" then text else ""
	)
end)

Net.DailyState.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local streakLength = DailyRewardConfig.StreakLength
	state.Daily = {
		Day = math.clamp(math.floor(tonumber(payload.Day) or 1), 1, streakLength),
		CanClaim = payload.CanClaim == true,
		SecondsUntilNext = math.max(0, tonumber(payload.SecondsUntilNext) or 0),
		Streak = math.clamp(math.floor(tonumber(payload.Streak) or 0), 0, streakLength),
	}
	publish()
end)

Net.PetInventory.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	state.Pets = {
		Pets = cleanPetEntries(payload.Pets),
		Equipped = cleanUids(payload.Equipped),
		Slots = math.max(0, math.floor(tonumber(payload.Slots) or state.Pets.Slots)),
	}
	publish()
end)

Net.HatchResult.OnClientEvent:Connect(function(petId: any, variantId: any)
	if type(petId) ~= "string" or type(variantId) ~= "string" then
		return
	end
	state.LastHatch = { PetId = petId, Variant = variantId, At = os.clock() }
	publish()
end)

Net.CosmeticState.OnClientEvent:Connect(function(equippedSkin: any, equippedTrail: any, ownedSkins: any, ownedTrails: any)
	state.Cosmetics = {
		EquippedSkin = if type(equippedSkin) == "string" and equippedSkin ~= ""
			then equippedSkin
			else state.Cosmetics.EquippedSkin,
		EquippedTrail = if type(equippedTrail) == "string"
			then equippedTrail
			else state.Cosmetics.EquippedTrail,
		OwnedSkins = if type(ownedSkins) == "table" then cleanOwned(ownedSkins) else state.Cosmetics.OwnedSkins,
		OwnedTrails = if type(ownedTrails) == "table" then cleanOwned(ownedTrails) else state.Cosmetics.OwnedTrails,
	}
	publish()
end)

Net.CrateResult.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	state.LastCrate = {
		CrateId = if type(payload.CrateId) == "string" then payload.CrateId else "",
		Kind = if type(payload.Kind) == "string" then payload.Kind else "",
		Id = if type(payload.Id) == "string" then payload.Id else "",
		IsNew = payload.IsNew == true,
		Refund = math.max(0, math.floor(tonumber(payload.Refund) or 0)),
	}
	publish()
end)

Net.PassState.OnClientEvent:Connect(function(passes: any)
	if type(passes) ~= "table" then
		return
	end
	local owned = {}
	for _, passKey in passes do
		if type(passKey) == "string" and passKey ~= "" then
			owned[passKey] = true
		end
	end
	state.OwnedPasses = owned
	publish()
end)

Net.ReviveOffer.OnClientEvent:Connect(function(productId: any, tier: any, windowSeconds: any)
	local product = math.floor(tonumber(productId) or 0)
	if product <= 0 then
		return
	end
	state.ReviveOffer = {
		ProductId = product,
		Tier = math.max(1, math.floor(tonumber(tier) or 1)),
		ExpiresAt = os.clock() + math.max(0, tonumber(windowSeconds) or 0),
	}
	publish()
end)

Net.MapProgress.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	state.MapProgress = {
		MapId = if type(payload.MapId) == "string" then payload.MapId else state.MapProgress.MapId,
		Percent = math.clamp(tonumber(payload.Percent) or 0, 0, 100),
	}
	publish()
end)

Net.SpecialEvent.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local mapId = if type(payload.MapId) == "string" then payload.MapId else ""
	if mapId == "" then
		state.SpecialEvent = nil
	else
		state.SpecialEvent = { MapId = mapId, EndsAt = tonumber(payload.EndsAt) or 0 }
	end
	publish()
end)

Net.LeaderboardData.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local period = payload.Period
	local entries = cleanLeaderboardEntries(payload.Entries)
	local daily = state.Leaderboards.Daily
	local weekly = state.Leaderboards.Weekly
	local allTime = state.Leaderboards.AllTime
	if period == "Daily" then
		daily = entries
	elseif period == "Weekly" then
		weekly = entries
	elseif period == "AllTime" then
		allTime = entries
	else
		return
	end
	state.Leaderboards = { Daily = daily, Weekly = weekly, AllTime = allTime }
	publish()
end)

return DataController
