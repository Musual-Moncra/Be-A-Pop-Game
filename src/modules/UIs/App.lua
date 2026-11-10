--!strict

--[[
	App
	Mounts the whole client UI into one full-screen ScreenGui. Everything is drawn in UIConfig
	design pixels inside a root frame that one UIScale fits to the real screen (see useUIScale).
	Every layer sits inside the measured safe area (top bar, notches); only the window backdrop
	spans the full screen so the dimmer has no gaps. Reads DataController (game state) and
	LobbyState (which window is open) and hands both to every screen in Modules.Screens.

	Started by runFramework (UIs location); returns the mount function.
	Dependencies: React, ReactRoblox, DataController, RoomController, LobbyState, GameConfig, UIConfig,
		useUIScale, UIScaleContext, Screens.*
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local RoomController = require(ReplicatedStorage.Modules.Controllers.RoomController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local useUIScale = require(ReplicatedStorage.Modules.UIComponents.useUIScale)
local ErrorBoundary = require(ReplicatedStorage.Modules.UIComponents.ErrorBoundary)
local Keybinds = require(ReplicatedStorage.Modules.UIComponents.Keybinds)
local KeybindConfig = require(ReplicatedStorage.Modules.Config.KeybindConfig)
local UIScaleContext = require(ReplicatedStorage.Modules.UIComponents.UIScaleContext)

local Screens = ReplicatedStorage.Modules.Screens
local DailyWindow = require(Screens.DailyWindow)
local LobbyDock = require(Screens.LobbyDock)
local Onboarding = require(Screens.Onboarding)
local PetReveal = require(Screens.PetReveal)
local PetsWindow = require(Screens.PetsWindow)
local RebirthWindow = require(Screens.RebirthWindow)
local PlayWindow = require(Screens.PlayWindow)
local ResultWindow = require(Screens.ResultWindow)
local RoomPill = require(Screens.RoomPill)
local ShopWindow = require(Screens.ShopWindow)
local SkinsWindow = require(Screens.SkinsWindow)
local RunExtras = require(Screens.RunExtras)
local RunHud = require(Screens.RunHud)
local RunJuice = require(Screens.RunJuice)
local Toasts = require(Screens.Toasts)
local UpgradeWindow = require(Screens.UpgradeWindow)
local Wallet = require(Screens.Wallet)

local e = React.createElement
local Routes = LobbyState.Routes

local function closeWindow()
	LobbyState.SetActive(LobbyState.Routes.None)
end

local function toggleRoute(action: string)
	local target = KeybindConfig.Routes[action]
	if target == nil then
		return
	end
	local tab = if target.Tab ~= "" then target.Tab else nil
	if LobbyState.Get() == target.Route and LobbyState.GetTab() == tab then
		LobbyState.SetActive(LobbyState.Routes.None)
	else
		LobbyState.SetActive(target.Route, tab)
	end
end

local function useLobbyShortcuts(active: boolean)
	for action in KeybindConfig.Routes do
		Keybinds.use(action, function()
			toggleRoute(action)
		end, active)
	end
end

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
		[name] = e(ErrorBoundary, {
			name = name,
			onError = if name == "Window" then closeWindow else nil,
			resetKey = if name == "Window" then LobbyState.Get() else nil,
		}, { [name] = child }),
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
	local tab, setTab = React.useState(LobbyState.GetTab())

	React.useEffect(function()
		local dataConnection = DataController.Changed:Connect(setData)
		local routeConnection = LobbyState.Changed:Connect(function(nextRoute: string, nextTab: string?)
			setRoute(nextRoute)
			setTab(nextTab)
		end)
		return function()
			dataConnection:Disconnect()
			routeConnection:Disconnect()
		end
	end, {})

	local inRun = data.RunState == GameConfig.RunStates.Running
	local revealOpen = not inRun and #data.PetDropQueue > 0
	local showResult = not inRun and data.LastRun ~= nil and not revealOpen

	useLobbyShortcuts(not inRun and not showResult and not revealOpen)

	React.useEffect(function()
		if inRun or showResult or revealOpen then
			LobbyState.SetActive(Routes.None)
		end
	end, { inRun, showResult, revealOpen } :: { any })

	React.useEffect(function()
		local connection = RoomController.OpenRequested:Connect(function()
			LobbyState.SetActive(Routes.Play)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local function close()
		LobbyState.SetActive(Routes.None)
	end

	local lobbyWindow = nil
	if not inRun and not showResult and not revealOpen then
		if route == Routes.Play then
			lobbyWindow = e(PlayWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Upgrades then
			lobbyWindow = e(UpgradeWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Daily then
			lobbyWindow = e(DailyWindow, { data = data, ui = ui, onClose = close })
		elseif route == Routes.Shop then
			lobbyWindow = e(ShopWindow, { data = data, initialTab = tab, ui = ui, onClose = close })
		elseif route == Routes.Pets then
			lobbyWindow = e(PetsWindow, { data = data, initialTab = tab, ui = ui, onClose = close })
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
			Wallet = if not inRun
				then layer(
					ui,
					"Wallet",
					e(Wallet, {
						covered = lobbyWindow ~= nil or showResult or revealOpen,
						data = data,
						ui = ui,
					})
				)
				else nil,
			RunHud = layer(ui, "RunHud", if inRun then e(RunHud, { data = data, ui = ui }) else nil),
			Juice = layer(ui, "Juice", if inRun then e(RunJuice, { ui = ui }) else nil),
			Extras = layer(ui, "Extras", e(RunExtras, { data = data, inRun = inRun, ui = ui })),
			LobbyMenu = layer(
				ui,
				"LobbyMenu",
				if not inRun
						and not showResult
						and not revealOpen
						and lobbyWindow == nil
					then e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
					}, {
						Dock = e(LobbyDock, { data = data, ui = ui }),
						Pills = e(RoomPill, { ui = ui }),
					})
					else nil
			),
			Backdrop = if showResult then backdrop(nil) elseif lobbyWindow ~= nil then backdrop(close) else nil,
			Window = layer(ui, "Window", lobbyWindow),
			Result = layer(ui, "Result", if showResult then e(ResultWindow, { data = data, ui = ui }) else nil),
			Toasts = layer(ui, "Toasts", e(Toasts, { data = data, ui = ui })),
			Reveal = layer(
				ui,
				"Reveal",
				if revealOpen
					then e(PetReveal, {
						drop = data.PetDropQueue[1],
						key = string.format("%s:%s", tostring(data.PetDropQueue[1].At), data.PetDropQueue[1].PetId),
						ui = ui,
					})
					else nil
			),
			Onboarding = layer(ui, "Onboarding", e(Onboarding, { data = data, route = route, ui = ui })),
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
