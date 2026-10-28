--!strict

--[[
	App
	Mounts the whole client UI into one full-screen ScreenGui. Everything is drawn in UIConfig
	design pixels inside a root frame that one UIScale fits to the real screen (see useUIScale).
	Every layer sits inside the measured safe area (top bar, notches); only the window backdrop
	spans the full screen so the dimmer has no gaps. Reads DataController (game state) and
	LobbyState (which window is open) and hands both to every screen in Modules.Screens.

	Started by runFramework (UIs location); returns the mount function.
	Dependencies: React, ReactRoblox, DataController, LobbyState, GameConfig, UIConfig, useUIScale, UIScaleContext,
		Screens.*
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
local UIScaleContext = require(ReplicatedStorage.Modules.UIComponents.UIScaleContext)

local Screens = ReplicatedStorage.Modules.Screens
local DailyWindow = require(Screens.DailyWindow)
local PetsWindow = require(Screens.PetsWindow)
local RebirthWindow = require(Screens.RebirthWindow)
local PlayWindow = require(Screens.PlayWindow)
local ResultWindow = require(Screens.ResultWindow)
local ShopWindow = require(Screens.ShopWindow)
local SideRail = require(Screens.SideRail)
local SkinsWindow = require(Screens.SkinsWindow)
local RunExtras = require(Screens.RunExtras)
local RunHud = require(Screens.RunHud)
local StatsWindow = require(Screens.StatsWindow)
local Toasts = require(Screens.Toasts)
local UpgradeWindow = require(Screens.UpgradeWindow)
local Wallet = require(Screens.Wallet)

local e = React.createElement
local Routes = LobbyState.Routes

local function layer(ui: any, name: string, child: any)
	if child == nil then
		return nil
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(ui.safe.Left, ui.safe.Top),
		Size = UDim2.fromOffset(ui.safeWidth, ui.safeHeight),
		ZIndex = UIConfig.Layers[name],
	}, {
		[name] = child,
	})
end

local function backdrop(onActivated: (() -> ())?)
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = UIConfig.Palette.Overlay,
		BackgroundTransparency = UIConfig.Shape.OverlayTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = UIConfig.Layers.Backdrop,
		[React.Event.Activated] = onActivated,
	})
end

local function App(props: any)
	local ui = useUIScale(props.screenGui, props.safeGui)
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
		elseif route == Routes.Daily then
			lobbyWindow = e(DailyWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Shop then
			lobbyWindow = e(ShopWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Pets then
			lobbyWindow = e(PetsWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Skins then
			lobbyWindow = e(SkinsWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Rebirth then
			lobbyWindow = e(RebirthWindow, { data = data, ui = ui, onClose = close })
		end
	end

	return e(UIScaleContext.Provider, { value = ui.scale }, {
		Root = e("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromOffset(ui.width, ui.height),
		}, {
			Scale = e("UIScale", { Scale = ui.scale }),
			Wallet = layer(ui, "Wallet", e(Wallet, { data = data, ui = ui })),
			RunHud = layer(ui, "RunHud", if inRun then e(RunHud, { data = data, ui = ui }) else nil),
			Extras = layer(ui, "Extras", e(RunExtras, { data = data, inRun = inRun, ui = ui })),
			LobbyMenu = layer(
				ui,
				"LobbyMenu",
				if not inRun and not showResult and lobbyWindow == nil then e(SideRail, { data = data, ui = ui }) else nil
			),
			Backdrop = if showResult then backdrop(nil) elseif lobbyWindow ~= nil then backdrop(close) else nil,
			Window = layer(ui, "Window", lobbyWindow),
			Result = layer(ui, "Result", if showResult then e(ResultWindow, { data = data, ui = ui }) else nil),
			Toasts = layer(ui, "Toasts", e(Toasts, { data = data, ui = ui })),
		}),
	})
end

return function()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameUI"
	screenGui.DisplayOrder = 1
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local safeGui = Instance.new("ScreenGui")
	safeGui.Name = "GameUISafeArea"
	safeGui.IgnoreGuiInset = true
	safeGui.ResetOnSpawn = false
	safeGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	safeGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(App, { screenGui = screenGui, safeGui = safeGui }))
end
