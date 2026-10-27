--!strict

--[[
	App
	Mounts the whole client UI into one ScreenGui. Everything is drawn in UIConfig design
	pixels inside a root frame that one UIScale fits to the real screen (see useUIScale).
	Reads DataController (game state) and LobbyState (which window is open) and hands both
	to every screen in Modules.Screens.

	Started by runFramework (UIs location); returns the mount function.
	Dependencies: React, ReactRoblox, DataController, LobbyState, GameConfig, UIConfig, useUIScale, Screens.*
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local useUIScale = require(ReplicatedStorage.Modules.UIComponents.useUIScale)

local Screens = ReplicatedStorage.Modules.Screens
local LobbyMenu = require(Screens.LobbyMenu)
local PlayWindow = require(Screens.PlayWindow)
local ResultWindow = require(Screens.ResultWindow)
local RunHud = require(Screens.RunHud)
local StatsWindow = require(Screens.StatsWindow)
local Toasts = require(Screens.Toasts)
local UpgradeWindow = require(Screens.UpgradeWindow)
local Wallet = require(Screens.Wallet)

local e = React.createElement
local Routes = LobbyState.Routes

local function layer(name: string, child: any)
	if child == nil then
		return nil
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = UIConfig.Layers[name],
	}, {
		[name] = child,
	})
end

local function App(props: any)
	local ui = useUIScale(props.screenGui)
	local data, setData = React.useState(DataController.Get())
	local route, setRoute = React.useState(LobbyState.Get())

	React.useEffect(function()
		local dataConnection = DataController.Changed:Connect(setData)
		local routeConnection = LobbyState.Changed:Connect(setRoute)
		return function()
			dataConnection:Disconnect()
			routeConnection:Disconnect()
		end
	end, {})

	local inRun = data.RunState == GameConfig.RunStates.Running
	local showResult = not inRun and data.LastRun ~= nil

	React.useEffect(function()
		if inRun or showResult then
			LobbyState.SetActive(Routes.None)
		end
	end, { inRun, showResult } :: { any })

	local function close()
		LobbyState.SetActive(Routes.None)
	end

	local lobbyWindow = nil
	if not inRun and not showResult then
		if route == Routes.Play then
			lobbyWindow = e(PlayWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Upgrades then
			lobbyWindow = e(UpgradeWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Stats then
			lobbyWindow = e(StatsWindow, { data = data, ui = ui, onClose = close })
		end
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(ui.width, ui.height),
	}, {
		Scale = e("UIScale", { Scale = ui.scale }),
		Wallet = layer("Wallet", e(Wallet, { data = data, ui = ui })),
		RunHud = layer("RunHud", if inRun then e(RunHud, { data = data, ui = ui }) else nil),
		LobbyMenu = layer(
			"LobbyMenu",
			if not inRun and not showResult and lobbyWindow == nil then e(LobbyMenu, { ui = ui }) else nil
		),
		Window = layer("Window", lobbyWindow),
		Result = layer("Result", if showResult then e(ResultWindow, { data = data, ui = ui }) else nil),
		Toasts = layer("Toasts", e(Toasts, { data = data, ui = ui })),
	})
end

return function()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameUI"
	screenGui.DisplayOrder = 1
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(App, { screenGui = screenGui }))
end
