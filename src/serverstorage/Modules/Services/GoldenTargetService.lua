--!strict

--[[
	GoldenTargetService
	Rolls the golden props for a run, pays gems and extra points when one is fully soiled
	and publishes the list so the client can glow them. An id is the prop's name path
	relative to the map model ("Props/Counter_1"), stable for the life of the run.

	API:
		GoldenTargetService.StartRun(plr, mapModel)
		GoldenTargetService.StopRun(plr)
		GoldenTargetService.Soil(plr, objectModel, objectDef) -> extraPoints

	Dependencies: DataService, Outbound, RunEvents, ConfigLookup, GoldenTargetConfig, MessageConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local GoldenTargetConfig = require(ReplicatedStorage.Modules.Config.GoldenTargetConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local DataService = require(script.Parent.DataService)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)

type GoldenRun = {
	ids: { string },
	paths: { [Model]: string },
}

local GoldenTargetService = {}

local runs: { [Player]: GoldenRun } = {}

local function pathOf(mapModel: Model, target: Instance): string
	local parts = {}
	local current: Instance? = target
	while current ~= nil and current ~= mapModel do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, "/")
end

local function collectTargets(mapModel: Model): { Model }
	local props = mapModel:FindFirstChild("Props")
	if props == nil then
		return {}
	end
	local targets: { Model } = {}
	for _, child in props:GetChildren() do
		if child:IsA("Model") and typeof(child:GetAttribute("ObjectType")) == "string" then
			table.insert(targets, child)
		end
	end
	return targets
end

function GoldenTargetService.StartRun(plr: Player, mapModel: Model?)
	runs[plr] = nil
	if mapModel == nil then
		Outbound.GoldenTargets(plr, {})
		return
	end

	local targets = collectTargets(mapModel)
	local random = Random.new()
	if #targets == 0 or random:NextNumber() > GoldenTargetConfig.Chance then
		Outbound.GoldenTargets(plr, {})
		return
	end

	local wanted = math.clamp(random:NextInteger(GoldenTargetConfig.MinCount, GoldenTargetConfig.MaxCount), 0, #targets)
	local ids: { string } = {}
	local paths: { [Model]: string } = {}
	local pool = table.clone(targets)

	for index = 1, wanted do
		local pick = random:NextInteger(index, #pool)
		pool[index], pool[pick] = pool[pick], pool[index]
		local target = pool[index]
		local path = pathOf(mapModel, target)
		table.insert(ids, path)
		paths[target] = path
	end

	if #ids == 0 then
		Outbound.GoldenTargets(plr, {})
		return
	end

	runs[plr] = { ids = ids, paths = paths }
	Outbound.GoldenTargets(plr, ids)
end

function GoldenTargetService.StopRun(plr: Player)
	if runs[plr] == nil then
		return
	end
	runs[plr] = nil
	Outbound.GoldenTargets(plr, {})
end

function GoldenTargetService.Soil(plr: Player, objectModel: Model, objectDef: ConfigLookup.ObjectDefinition): number
	local run = runs[plr]
	if run == nil or run.paths[objectModel] == nil then
		return 0
	end
	run.paths[objectModel] = nil

	local extraPoints = math.floor(objectDef.SoilBonus * GoldenTargetConfig.PointsMultiplier)
	DataService.AddGems(plr, GoldenTargetConfig.GemReward)
	RunEvents.GoldenSoiled:Fire(plr, objectDef.DisplayName, GoldenTargetConfig.GemReward, extraPoints)
	Outbound.Notify(
		plr,
		"Success",
		string.format(MessageConfig.GoldenSoiled, objectDef.DisplayName, GoldenTargetConfig.GemReward)
	)
	return extraPoints
end

Players.PlayerRemoving:Connect(function(plr: Player)
	runs[plr] = nil
end)

return GoldenTargetService
