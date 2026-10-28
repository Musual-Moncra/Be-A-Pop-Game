--!strict

--[[
	QuestService
	Rolls the objectives for a Quests-mode run, tracks them from RunEvents and pays each
	reward the moment its objective completes. SoilType quests only roll when the map
	actually holds a prop with that ObjectType; the freed slots go to other quest kinds.

	API:
		QuestService.StartRun(plr, map, mode)
		QuestService.FinishRun(plr) -> { Completed, Coins, Gems }

	Dependencies: DataService, RunEvents, Outbound, ConfigLookup, QuestConfig, MessageConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
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

local function collectObjectTypes(mapModelName: string): { [string]: boolean }
	local types: { [string]: boolean } = {}
	local mapModel = Workspace:FindFirstChild(mapModelName)
	local props = if mapModel ~= nil then mapModel:FindFirstChild("Props") else nil
	if props == nil then
		return types
	end
	for _, descendant in props:GetDescendants() do
		local objectType = descendant:GetAttribute("ObjectType")
		if typeof(objectType) == "string" then
			types[objectType] = true
		end
	end
	return types
end

local function rollQuests(mapModelName: string, mapOrder: number, count: number): { ActiveQuest }
	local availableTypes = collectObjectTypes(mapModelName)
	local eligible: { ConfigLookup.QuestDefinition } = {}
	local fillers: { ConfigLookup.QuestDefinition } = {}

	for _, quest in QuestConfig.Quests :: { ConfigLookup.QuestDefinition } do
		if quest.MinMapOrder <= mapOrder then
			if quest.Kind ~= "SoilType" then
				table.insert(eligible, quest)
				table.insert(fillers, quest)
			elseif availableTypes[quest.ObjectType] == true then
				table.insert(eligible, quest)
			end
		end
	end

	local fillerIndex = 0
	while #eligible < count and #fillers > 0 do
		fillerIndex = (fillerIndex % #fillers) + 1
		table.insert(eligible, fillers[fillerIndex])
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
	Outbound.QuestState(plr, buildState(run))
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

	local text = ConfigLookup.FormatQuest(quest.Definition)
	Outbound.Notify(plr, "Success", string.format(MessageConfig.QuestCompleted, text))
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
	local quests = if mode.QuestCount > 0 then rollQuests(map.ModelName, map.Order, mode.QuestCount) else {}
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

	Outbound.QuestState(plr, {})

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
