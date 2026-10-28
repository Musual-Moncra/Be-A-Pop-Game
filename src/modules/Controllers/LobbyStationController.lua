--!strict

--[[
	LobbyStationController
	Client controller: turns lobby booths into interaction prompts. Every BasePart under
	Workspace.Lobby carrying a string LobbyStation attribute gets a ProximityPrompt built from
	LobbyUIConfig.Stations (action and object text) and LobbyUIConfig.StationPrompt (hold time,
	reach, key, no line of sight). Triggering a prompt opens the station's lobby route through
	LobbyState, so a booth behaves exactly like its side-rail button.
	Prompts are disabled while a run is active (DataController RunState) and re-enabled when the
	run ends. The Lobby subtree is watched, so booths streamed in after the client starts (or a
	Lobby that appears late) are picked up too, and a part already carrying a prompt is skipped.

	Public API: none (the returned function is spawned by runFramework at Priority 5).
	Dependencies: Workspace, Players, LobbyUIConfig, GameConfig, DataController, LobbyState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)

local PROMPT_NAME = "LobbyStationPrompt"

local lobbyConnection: RBXScriptConnection? = nil
local promptsEnabled = true

local function isRunActive(): boolean
	return DataController.Get().RunState == GameConfig.RunStates.Running
end

local function applyPromptsEnabled(enabled: boolean)
	promptsEnabled = enabled
	local lobby = Workspace:FindFirstChild("Lobby")
	if lobby == nil then
		return
	end
	for _, descendant in lobby:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == PROMPT_NAME then
			descendant.Enabled = enabled
		end
	end
end

local function applyRunState(runState: string)
	local shouldEnable = runState ~= GameConfig.RunStates.Running
	if shouldEnable == promptsEnabled then
		return
	end
	applyPromptsEnabled(shouldEnable)
end

local function onPromptTriggered(route: string)
	if isRunActive() then
		return
	end
	LobbyState.SetActive(route)
end

local function trackPart(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local stationKey = instance:GetAttribute("LobbyStation")
	if type(stationKey) ~= "string" then
		return
	end
	local station = LobbyUIConfig.Stations[stationKey :: string]
	if station == nil then
		return
	end
	if instance:FindFirstChild(PROMPT_NAME) ~= nil then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = station.ActionText
	prompt.ObjectText = station.ObjectText
	prompt.HoldDuration = LobbyUIConfig.StationPrompt.HoldDuration
	prompt.MaxActivationDistance = LobbyUIConfig.StationPrompt.MaxActivationDistance
	prompt.KeyboardKeyCode = LobbyUIConfig.StationPrompt.KeyCode
	prompt.RequiresLineOfSight = false
	prompt.Enabled = promptsEnabled
	prompt.Triggered:Connect(function(player)
		if player ~= Players.LocalPlayer then
			return
		end
		onPromptTriggered(station.Route)
	end)
	prompt.Parent = instance
end

local function watchLobby(lobby: Instance)
	if lobbyConnection ~= nil then
		lobbyConnection:Disconnect()
		lobbyConnection = nil
	end
	for _, descendant in lobby:GetDescendants() do
		trackPart(descendant)
	end
	lobbyConnection = lobby.DescendantAdded:Connect(trackPart)
end

local function onWorkspaceChildAdded(child: Instance)
	if child.Name == "Lobby" then
		watchLobby(child)
	end
end

return function()
	local lobby = Workspace:FindFirstChild("Lobby")
	if lobby ~= nil then
		watchLobby(lobby)
	end
	Workspace.ChildAdded:Connect(onWorkspaceChildAdded)
	DataController.Changed:Connect(function(state)
		applyRunState(state.RunState)
	end)
	applyRunState(DataController.Get().RunState)
end
