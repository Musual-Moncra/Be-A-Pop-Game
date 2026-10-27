--!strict

--[[
	UpgradeMenu
	Lobby upgrade shop: one row per upgrade with level, current value,
	level progress and a buy button. PC side panel, Mobile bottom sheet.
	Reads DataController and UIConfig; purchase requests go through Net.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Config.UpgradeConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Button = require(ReplicatedStorage.Modules.UIComponents.Button)
local Panel = require(ReplicatedStorage.Modules.UIComponents.Panel)
local ProgressBar = require(ReplicatedStorage.Modules.UIComponents.ProgressBar)
local SegmentedControl = require(ReplicatedStorage.Modules.UIComponents.SegmentedControl)
local useDeviceLayout = require(ReplicatedStorage.Modules.UIComponents.useDeviceLayout)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)

local e = React.createElement
local Theme = UIConfig.Theme
local Text = UIConfig.Text

local function formatValue(id: string, value: number): string
	return string.format(Text.ValueFormats[id], value)
end

local function UpgradeRow(props: any)
	local id: string = props.id
	local data = props.data
	local upgrades = data.Upgrades :: any
	local definition = UpgradeConfig.Upgrades[id]
	local level: number = upgrades[id] or 0
	local maxed = level >= definition.MaxLevel
	local cost = if maxed then nil else UpgradeConfig.GetCost(id, level)
	local affordable = cost ~= nil and data.Coins >= cost
	local enabled = not maxed and affordable
	local buttonText = if maxed then Text.Maxed else string.format(Text.PriceFormat, cost)
	local value = UpgradeConfig.GetValue(id, level)
	local detail = string.format(Text.UpgradeDetail, level, definition.MaxLevel, formatValue(id, value))
	local textWidthOffset = -(Theme.Sizes.BuyButtonWidth + Theme.Spacing.M)

	return e("Frame", {
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, Theme.Sizes.RowHeight),
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.Radii.Medium }),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, Theme.Spacing.M),
			PaddingLeft = UDim.new(0, Theme.Spacing.M),
			PaddingRight = UDim.new(0, Theme.Spacing.M),
			PaddingTop = UDim.new(0, Theme.Spacing.M),
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			Size = UDim2.new(1, textWidthOffset, 0, 20),
			Text = Text.UpgradeNames[id] or id,
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.TextSizes.CardTitle,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Detail = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Regular,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, textWidthOffset, 0, 18),
			Text = detail,
			TextColor3 = Theme.Colors.TextMuted,
			TextSize = Theme.TextSizes.CardBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Bar = e(ProgressBar, {
			position = UDim2.fromOffset(0, 46),
			ratio = level / definition.MaxLevel,
			size = UDim2.new(1, textWidthOffset, 0, Theme.Sizes.ProgressHeight),
		}),
		Buy = e(Button, {
			anchorPoint = Vector2.new(1, 0.5),
			enabled = enabled,
			onActivated = function()
				Net.PurchaseUpgrade:Fire(id)
			end,
			position = UDim2.fromScale(1, 0.5),
			size = UDim2.fromOffset(Theme.Sizes.BuyButtonWidth, Theme.Sizes.BuyButtonHeight),
			text = buttonText,
		}),
	})
end

local function App()
	local layout = useDeviceLayout()
	local lobbyLayout = UIConfig.Layouts[layout].Lobby
	local data, setData = React.useState(DataController.Get())
	local active, setActive = React.useState(LobbyState.Get())

	React.useEffect(function()
		local dataConnection = DataController.Changed:Connect(setData)
		local routeConnection = LobbyState.Changed:Connect(setActive)
		return function()
			dataConnection:Disconnect()
			routeConnection:Disconnect()
		end
	end, {})

	local inRun = data.RunState == GameConfig.RunStates.Running
	if inRun or active ~= LobbyState.Routes.Upgrades then
		return nil
	end

	local navOptions = {
		{ Id = LobbyState.Routes.Play, Label = Text.NavPlay },
		{ Id = LobbyState.Routes.Upgrades, Label = Text.NavUpgrades },
	}
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Theme.Spacing.L),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.TitleHeight),
			Text = Text.UpgradesTitle,
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.TextSizes.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}

	for index, id in UIConfig.UpgradeOrder do
		children[id] = e(UpgradeRow, {
			data = data,
			id = id,
			layoutOrder = index + 1,
		})
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
			anchorPoint = lobbyLayout.UpgradePanel.AnchorPoint,
			maxSize = lobbyLayout.UpgradePanel.MaxSize,
			minSize = lobbyLayout.UpgradePanel.MinSize,
			position = lobbyLayout.UpgradePanel.Position,
			scroll = true,
			size = lobbyLayout.UpgradePanel.Size,
		}, children),
	})
end

return function()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UpgradeMenu"
	screenGui.DisplayOrder = 3
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(App))
end
