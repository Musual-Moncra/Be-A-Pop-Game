--!strict

--[[
	QuestService
	Rolls the objectives for a Quests-mode run, tracks them from RunEvents and pays each
	reward the moment its objective completes.

	API:
		QuestService.StartRun(plr, map, mode)
		QuestService.FinishRun(plr) -> { Completed, Coins, Gems }

	Dependencies: DataService, RunEvents, ConfigLookup, QuestConfig, MessageConfig, Net
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local QuestConfig = require(ReplicatedStorage.Modules.Config.QuestConfig)

export type ActiveQuest = {
	Id: string,
	Kind: string,
	ObjectType: string,
	Target: number,
	Progress: number,
	Done: boolean,
	Definition: ConfigLookup.QuestDefinition,
}

export type QuestRun = {
	quests: { ActiveQuest },
	completed: number,
	coins: number,
	gems: number,
}

export type FinishResult = {
	Completed: number,
	Coins: number,
	Gems: number,
}

local QuestService = {}

local runs: { [Player]: QuestRun } = {}

local function rollQuests(mapOrder: number, count: number): { ActiveQuest }
	local eligible: { ConfigLookup.QuestDefinition } = {}
	for _, quest in QuestConfig.Quests :: { ConfigLookup.QuestDefinition } do
		if quest.MinMapOrder <= mapOrder then
			table.insert(eligible, quest)
		end
	end

	local random = Random.new()
	local remaining = table.clone(eligible)
	local rolled: { ActiveQuest } = {}
	local wanted = math.min(count, #remaining)

	for _ = 1, wanted do
		local totalWeight = 0
		for _, quest in remaining do
			totalWeight += quest.Weight
		end

		local chosenIndex = 1
		if totalWeight > 0 then
			local pick = random:NextNumber() * totalWeight
			local accumulated = 0
			for index, quest in remaining do
				accumulated += quest.Weight
				if pick <= accumulated then
					chosenIndex = index
					break
				end
			end
		end

		local definition = table.remove(remaining, chosenIndex)
		table.insert(rolled, {
			Id = definition.Id,
			Kind = definition.Kind,
			ObjectType = definition.ObjectType,
			Target = definition.Target,
			Progress = 0,
			Done = false,
			Definition = definition,
		})
	end

	return rolled
end

local function buildState(run: QuestRun): { any }
	local state = {}
	for _, quest in run.quests do
		table.insert(state, {
			Id = quest.Id,
			Text = ConfigLookup.FormatQuest(quest.Definition),
			Progress = quest.Progress,
			Target = quest.Target,
			Done = quest.Done,
		})
	end
	return state
end

local function publish(plr: Player, run: QuestRun)
	if plr.Parent == Players then
		Net.QuestState:FireClient(plr, buildState(run))
	end
end

local function completeQuest(plr: Player, run: QuestRun, quest: ActiveQuest)
	quest.Done = true
	quest.Progress = quest.Target
	run.completed += 1
	run.coins += quest.Definition.RewardCoins
	run.gems += quest.Definition.RewardGems

	if quest.Definition.RewardCoins > 0 then
		DataService.AddCoins(plr, quest.Definition.RewardCoins)
	end
	if quest.Definition.RewardGems > 0 then
		DataService.AddGems(plr, quest.Definition.RewardGems)
	end
	DataService.IncrementStat(plr, "QuestsCompleted", 1)

	if plr.Parent == Players then
		local text = ConfigLookup.FormatQuest(quest.Definition)
		Net.Notify:FireClient(plr, "Success", string.format(MessageConfig.QuestCompleted, text))
	end
end

local function applyProgress(plr: Player, run: QuestRun, quest: ActiveQuest, amount: number): boolean
	if quest.Done or amount <= 0 then
		return false
	end
	quest.Progress += amount
	if quest.Progress >= quest.Target then
		completeQuest(plr, run, quest)
	end
	return true
end

function QuestService.StartRun(plr: Player, map: ConfigLookup.MapDefinition, mode: ConfigLookup.ModeDefinition)
	local quests = if mode.QuestCount > 0 then rollQuests(map.Order, mode.QuestCount) else {}
	local run: QuestRun = {
		quests = quests,
		completed = 0,
		coins = 0,
		gems = 0,
	}
	runs[plr] = run
	publish(plr, run)
end

function QuestService.FinishRun(plr: Player): FinishResult
	local run = runs[plr]
	runs[plr] = nil

	if plr.Parent == Players then
		Net.QuestState:FireClient(plr, {})
	end

	if run == nil then
		return { Completed = 0, Coins = 0, Gems = 0 }
	end

	return {
		Completed = run.completed,
		Coins = run.coins,
		Gems = run.gems,
	}
end

RunEvents.Stained:Connect(function(plr: Player, points: number, _objectType: string?)
	local run = runs[plr]
	if run == nil then
		return
	end

	local changed = false
	for _, quest in run.quests do
		if quest.Kind == "Score" then
			changed = applyProgress(plr, run, quest, points) or changed
		elseif quest.Kind == "Cells" then
			changed = applyProgress(plr, run, quest, 1) or changed
		end
	end
	if changed then
		publish(plr, run)
	end
end)

RunEvents.ObjectSoiled:Connect(function(plr: Player, objectType: string, bonusPoints: number)
	local run = runs[plr]
	if run == nil then
		return
	end

	local changed = false
	for _, quest in run.quests do
		if quest.Kind == "Score" then
			changed = applyProgress(plr, run, quest, bonusPoints) or changed
		elseif quest.Kind == "SoilAny" or (quest.Kind == "SoilType" and quest.ObjectType == objectType) then
			changed = applyProgress(plr, run, quest, 1) or changed
		end
	end
	if changed then
		publish(plr, run)
	end
end)

RunEvents.PowerupEaten:Connect(function(plr: Player, _powerupId: string)
	local run = runs[plr]
	if run == nil then
		return
	end

	local changed = false
	for _, quest in run.quests do
		if quest.Kind == "Powerups" then
			changed = applyProgress(plr, run, quest, 1) or changed
		end
	end
	if changed then
		publish(plr, run)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	runs[plr] = nil
end)

return QuestService
