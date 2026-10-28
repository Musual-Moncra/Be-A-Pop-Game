--!strict

--[[
	GoldenGlowController
	Client-only glow on this player's golden targets. Reads DataController GoldenTargets (paths
	like "Props/<Name>" relative to the current map model), puts a pulsing Highlight
	(RunUIConfig.Glow) on each, drops a glow when that object gets fully soiled, and clears
	everything when the list empties at run end.

	Dependencies: Workspace, ReplicatedStorage, TweenService, DataController, ConfigLookup, RunUIConfig, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
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
	local mapModel = if map ~= nil then Workspace:FindFirstChild(map.ModelName) else nil
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

Net.ObjectSoiled.OnClientEvent:Connect(function(object: Instance)
	local highlight = glows[object]
	if highlight ~= nil then
		highlight:Destroy()
		glows[object] = nil
	end
end)

return GoldenGlowController
