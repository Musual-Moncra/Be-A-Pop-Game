--!strict

--[[
	EventService
	Owns the repeating Special Time event: every IntervalSeconds one random enabled map has
	boosted points and gems for DurationSeconds, and every client is told which map and when
	it ends. GetMultipliers is the read side used by scoring and run rewards.

	API:
		EventService.GetMultipliers(mapId) -> { Points: number, Gems: number }
		EventService.GetActive() -> { MapId: string, EndsAt: number }

	Dependencies: Players, EventConfig, ConfigLookup, Outbound, MessageConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EventConfig = require(ReplicatedStorage.Modules.Config.EventConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)

export type Multipliers = {
	Points: number,
	Gems: number,
}

export type Active = {
	MapId: string,
	EndsAt: number,
}

local EventService = {}

local NEUTRAL: Multipliers = { Points = 1, Gems = 1 }
local BOOSTED: Multipliers = {
	Points = EventConfig.SpecialTime.PointsMultiplier,
	Gems = EventConfig.SpecialTime.GemMultiplier,
}

local activeMapId = ""
local endsAt = 0
local nextStartAt = 0
local accumulator = 0

local function pickMap(): ConfigLookup.MapDefinition?
	local maps = ConfigLookup.GetEnabledMaps()
	if #maps == 0 then
		return nil
	end
	return maps[math.random(1, #maps)]
end

local function broadcast(mapId: string, eventEndsAt: number)
	for _, plr in Players:GetPlayers() do
		Outbound.SpecialEvent(plr, mapId, eventEndsAt)
	end
end

local function startEvent(now: number)
	local mapDef = pickMap()
	if mapDef == nil then
		nextStartAt = now + EventConfig.SpecialTime.IntervalSeconds
		return
	end

	activeMapId = mapDef.Id
	endsAt = now + EventConfig.SpecialTime.DurationSeconds
	broadcast(activeMapId, endsAt)

	local text = string.format(
		MessageConfig.SpecialTimeStart,
		mapDef.DisplayName,
		EventConfig.SpecialTime.GemMultiplier,
		EventConfig.SpecialTime.DurationSeconds
	)
	for _, plr in Players:GetPlayers() do
		Outbound.Notify(plr, "Success", text)
	end
end

local function step(now: number)
	if activeMapId ~= "" then
		if now >= endsAt then
			activeMapId = ""
			endsAt = 0
			nextStartAt = now + EventConfig.SpecialTime.IntervalSeconds
			broadcast("", 0)
		end
		return
	end
	if now >= nextStartAt then
		startEvent(now)
	end
end

function EventService.GetMultipliers(mapId: string): Multipliers
	if activeMapId ~= "" and activeMapId == mapId and Workspace:GetServerTimeNow() < endsAt then
		return BOOSTED
	end
	return NEUTRAL
end

function EventService.GetActive(): Active
	return { MapId = activeMapId, EndsAt = endsAt }
end

nextStartAt = Workspace:GetServerTimeNow() + EventConfig.SpecialTime.FirstDelaySeconds

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < EventConfig.StepInterval then
		return
	end
	accumulator = 0
	step(Workspace:GetServerTimeNow())
end)

Players.PlayerAdded:Connect(function(plr)
	if activeMapId ~= "" then
		Outbound.SpecialEvent(plr, activeMapId, endsAt)
	end
end)

return EventService
