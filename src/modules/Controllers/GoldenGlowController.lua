--!strict

--[[
	GoldenGlowController
	Client-only glow on this player's golden targets. Reads DataController GoldenTargets (paths
	like "Props/<Name>" relative to the current map model), puts a pulsing Highlight
	(RunUIConfig.Glow) on each, drops a glow when that object gets fully soiled, and clears
	everything when the list empties at run end. The map copy is the live room instance with
	this MapId (RoomConfig.MapTag), not a Workspace model name, because several rooms can hold
	the same map at once.

	Dependencies: CollectionService, Players, ReplicatedStorage, TweenService, DataController,
		ConfigLookup, Net, RoomConfig, RunUIConfig
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RoomConfig = require(ReplicatedStorage.Modules.Config.RoomConfig)
local RunUIConfig = require(ReplicatedStorage.Modules.Config.RunUIConfig)

local GoldenGlowController = {}

local Glow = RunUIConfig.Glow
local glows: { [Instance]: Highlight } = {}
local shownKey = ""

local function resolve(mapModel: Instance, path: string): Instance?
	local current: Instance? = mapModel
	for segment in string.gmatch(path, "[^/]+") do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

local function clear()
	for _, highlight in glows do
		highlight:Destroy()
	end
	table.clear(glows)
end

local function addGlow(target: Instance)
	local highlight = Instance.new("Highlight")
	highlight.Name = "GoldenGlow"
	highlight.FillColor = Glow.FillColor
	highlight.OutlineColor = Glow.OutlineColor
	highlight.FillTransparency = Glow.FillTransparency
	highlight.OutlineTransparency = Glow.OutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = target
	TweenService:Create(
		highlight,
		TweenInfo.new(Glow.PulseSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ FillTransparency = Glow.PulseFillTransparency }
	):Play()
	glows[target] = highlight
end

local function liveMap(mapId: string): Model?
	local character = Players.LocalPlayer.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local origin = if hrp ~= nil then hrp.Position else nil
	local best: Model? = nil
	local bestDistance = math.huge

	for _, model in CollectionService:GetTagged(RoomConfig.MapTag) do
		if model:IsA("Model") and model:GetAttribute("MapId") == mapId then
			if origin == nil then
				return model
			end
			local distance = (model:GetPivot().Position - origin).Magnitude
			if distance < bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

local function refresh(state: any)
	local targets = state.GoldenTargets or {}
	local key = state.MapId .. "|" .. table.concat(targets, ",")
	if key == shownKey then
		return
	end
	shownKey = key
	clear()
	if #targets == 0 then
		return
	end
	local map = ConfigLookup.GetMap(state.MapId)
	local mapModel = if map ~= nil then liveMap(map.Id) else nil
	if mapModel == nil then
		return
	end
	for _, path in targets do
		local target = resolve(mapModel, path)
		if target ~= nil then
			addGlow(target)
		end
	end
end

DataController.Changed:Connect(refresh)
refresh(DataController.Get())

CollectionService:GetInstanceAddedSignal(RoomConfig.MapTag):Connect(function()
	shownKey = ""
	refresh(DataController.Get())
end)

Net.ObjectSoiled.OnClientEvent:Connect(function(object: Instance)
	local highlight = glows[object]
	if highlight ~= nil then
		highlight:Destroy()
		glows[object] = nil
	end
end)

return GoldenGlowController
