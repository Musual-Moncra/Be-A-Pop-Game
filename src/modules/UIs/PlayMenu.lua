--!strict

--[[
	PlayMenu
	Lobby screen: map cards, mode segmented control, description and the
	primary PLAY button, plus the post-run result modal. PC centered panel,
	Mobile bottom sheet. Wires DataController, MapConfig, ModeConfig and Net.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Button = require(ReplicatedStorage.Modules.UIComponents.Button)
local Card = require(ReplicatedStorage.Modules.UIComponents.Card)
local Modal = require(ReplicatedStorage.Modules.UIComponents.Modal)
local Panel = require(ReplicatedStorage.Modules.UIComponents.Panel)
local SegmentedControl = require(ReplicatedStorage.Modules.UIComponents.SegmentedControl)
local StatChip = require(ReplicatedStorage.Modules.UIComponents.StatChip)
local useDeviceLayout = require(ReplicatedStorage.Modules.UIComponents.useDeviceLayout)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)

local e = React.createElement
local Theme = UIConfig.Theme
local Text = UIConfig.Text

local function sectionLabel(text: string, layoutOrder: number)
	return e("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Bold,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, Theme.Sizes.SectionHeight),
		Text = text,
		TextColor3 = Theme.Colors.TextMuted,
		TextSize = Theme.TextSizes.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function App()
	local layout = useDeviceLayout()
	local lobbyLayout = UIConfig.Layouts[layout].Lobby
	local data, setData = React.useState(DataController.Get())
	local active, setActive = React.useState(LobbyState.Get())
	local selectedMapId, setSelectedMapId = React.useState(data.MapId)
	local selectedModeId, setSelectedModeId = React.useState(data.ModeId)
	local result, setResult = React.useState(data.LastRun)
	local lastResult = React.useRef(data.LastRun)

	React.useEffect(function()
		local dataConnection = DataController.Changed:Connect(setData)
		local routeConnection = LobbyState.Changed:Connect(setActive)
		return function()
			dataConnection:Disconnect()
			routeConnection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		setSelectedMapId(data.MapId)
		setSelectedModeId(data.ModeId)
	end, { data.MapId, data.ModeId })

	React.useEffect(function()
		if data.RunState == GameConfig.RunStates.Running then
			setResult(nil)
			LobbyState.SetActive(LobbyState.Routes.Play)
		end
	end, { data.RunState })

	React.useEffect(function()
		if data.LastRun ~= nil and data.LastRun ~= lastResult.current then
			lastResult.current = data.LastRun
			setResult(data.LastRun)
			LobbyState.SetActive(LobbyState.Routes.Play)
		end
	end, { data.LastRun })

	React.useEffect(function()
		if result == nil then
			return
		end
		local thread = task.delay(Theme.ResultSeconds, function()
			setResult(nil)
		end)
		return function()
			task.cancel(thread)
		end
	end, { result })

	local inRun = data.RunState == GameConfig.RunStates.Running
	local activeRoute = if result ~= nil then LobbyState.Routes.Play else active
	if inRun or activeRoute ~= LobbyState.Routes.Play then
		return nil
	end

	local maps = table.clone(MapConfig.Maps)
	table.sort(maps, function(a, b)
		return a.Order < b.Order
	end)

	local selectedMode = ModeConfig.GetMode(selectedModeId)
	local modeDescription = if selectedMode ~= nil then selectedMode.Description else ""
	local confirmed = data.MapId == selectedMapId and data.ModeId == selectedModeId
	local canPlay = confirmed and MapConfig.GetMap(selectedMapId) ~= nil and selectedMode ~= nil

	local function selectMap(id: string)
		setSelectedMapId(id)
		Net.SelectRun:Fire(id, selectedModeId)
	end

	local function selectMode(id: string)
		setSelectedModeId(id)
		Net.SelectRun:Fire(selectedMapId, id)
	end

	local mobile = layout == "Mobile"
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, if mobile then Theme.Spacing.S else Theme.Spacing.L),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.TitleHeight),
			Text = Text.PlayTitle,
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.TextSizes.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}

	local mapCards = {}
	for index, map in maps do
		local card = e(Card, {
			badge = if map.Enabled then nil else Text.ComingSoon,
			disabled = not map.Enabled,
			layoutOrder = index,
			onActivated = function()
				selectMap(map.Id)
			end,
			selected = map.Id == selectedMapId,
			size = if mobile
				then UDim2.new(0.5, -Theme.Spacing.S / 2, 1, 0)
				else UDim2.new(1, 0, 0, Theme.Sizes.CardHeight),
			subtitle = map.Id,
			title = map.DisplayName,
		})
		if mobile then
			mapCards["Map" .. index] = card
		else
			children[map.Id] = card
		end
	end

	local modeOptions = {}
	for _, mode in ModeConfig.Modes do
		table.insert(modeOptions, { Id = mode.Id, Label = mode.DisplayName })
	end

	if mobile then
		local mapRowChildren = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, Theme.Spacing.S),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for key, card in mapCards do
			mapRowChildren[key] = card
		end
		children.MapRow = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.CardHeight),
		}, mapRowChildren)
		children.Modes = e(SegmentedControl, {
			layoutOrder = 3,
			onSelect = selectMode,
			options = modeOptions,
			selectedId = selectedModeId,
			size = UDim2.new(1, 0, 0, Theme.Sizes.BuyButtonHeight),
		})
		children.Description = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Regular,
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.DescriptionHeight),
			Text = modeDescription,
			TextColor3 = Theme.Colors.TextMuted,
			TextSize = Theme.TextSizes.CardBody,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	else
		children.Subtitle = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Regular,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			Text = Text.PlaySubtitle,
			TextColor3 = Theme.Colors.TextMuted,
			TextSize = Theme.TextSizes.CardBody,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		children.MapSection = sectionLabel(Text.MapSection, 3)
		for index, map in maps do
			local card = children[map.Id]
			if card then
				children[map.Id] = e(Card, {
					badge = if map.Enabled then nil else Text.ComingSoon,
					disabled = not map.Enabled,
					layoutOrder = 10 + index,
					onActivated = function()
						selectMap(map.Id)
					end,
					selected = map.Id == selectedMapId,
					size = UDim2.new(1, 0, 0, Theme.Sizes.CardHeight),
					subtitle = map.Id,
					title = map.DisplayName,
				})
			end
		end
		children.ModeSection = sectionLabel(Text.ModeSection, 30)
		children.Modes = e(SegmentedControl, {
			layoutOrder = 31,
			onSelect = selectMode,
			options = modeOptions,
			selectedId = selectedModeId,
			size = UDim2.new(1, 0, 0, Theme.Sizes.BuyButtonHeight),
		})
		children.Description = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Regular,
			LayoutOrder = 32,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.DescriptionHeight),
			Text = modeDescription,
			TextColor3 = Theme.Colors.TextMuted,
			TextSize = Theme.TextSizes.CardBody,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end

	if not confirmed then
		children.Pending = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Medium,
			LayoutOrder = 40,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.SectionHeight),
			Text = Text.SelectionPending,
			TextColor3 = Theme.Colors.TextMuted,
			TextSize = Theme.TextSizes.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local navOptions = {
		{ Id = LobbyState.Routes.Play, Label = Text.NavPlay },
		{ Id = LobbyState.Routes.Upgrades, Label = Text.NavUpgrades },
	}

	local resultBody = {}
	if result ~= nil then
		resultBody = {
			e(StatChip, {
				label = Text.ScoreLabel,
				layoutOrder = 1,
				size = UDim2.new(1, 0, 0, Theme.Sizes.ResultChipHeight),
				value = tostring(math.floor(result.Score)),
			}),
			e(StatChip, {
				label = Text.CoinsLabel,
				layoutOrder = 2,
				size = UDim2.new(1, 0, 0, Theme.Sizes.ResultChipHeight),
				value = tostring(math.floor(result.Coins)),
				valueColor = Theme.Colors.Accent,
			}),
			e(Button, {
				layoutOrder = 3,
				onActivated = function()
					setResult(nil)
					LobbyState.SetActive(LobbyState.Routes.Play)
				end,
				size = UDim2.new(1, 0, 0, Theme.Sizes.PlayButtonHeight),
				text = Text.Continue,
			}),
		}
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Nav = e(SegmentedControl, {
			anchorPoint = lobbyLayout.Nav.AnchorPoint,
			onSelect = LobbyState.SetActive,
			options = navOptions,
			position = lobbyLayout.Nav.Position,
			selectedId = active,
			size = lobbyLayout.Nav.Size,
		}),
		Panel = e(Panel, {
			anchorPoint = lobbyLayout.PlayPanel.AnchorPoint,
			maxSize = lobbyLayout.PlayPanel.MaxSize,
			minSize = lobbyLayout.PlayPanel.MinSize,
			footer = e(Button, {
				enabled = canPlay,
				onActivated = function()
					Net.StartRun:Fire()
				end,
				size = UDim2.new(1, 0, 0, Theme.Sizes.PlayButtonHeight),
				text = Text.PlayButton,
			}),
			footerGap = Theme.Spacing.S,
			position = lobbyLayout.PlayPanel.Position,
			scroll = true,
			size = lobbyLayout.PlayPanel.Size,
		}, children),
		Result = e(Modal, {
			anchorPoint = lobbyLayout.ResultCard.AnchorPoint,
			body = resultBody,
			maxSize = lobbyLayout.ResultCard.MaxSize,
			minSize = lobbyLayout.ResultCard.MinSize,
			onDismiss = function()
				setResult(nil)
				LobbyState.SetActive(LobbyState.Routes.Play)
			end,
			position = lobbyLayout.ResultCard.Position,
			size = lobbyLayout.ResultCard.Size,
			title = Text.ResultTitle,
			visible = result ~= nil,
		}),
	})
end

return function()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayMenu"
	screenGui.DisplayOrder = 2
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(App))
end
