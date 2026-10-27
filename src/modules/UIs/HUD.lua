--!strict

--[[
	HUD
	Always shows the coins chip; while a run is active it shows score and,
	when the mode is timed, a progress bar with the remaining seconds.
	Props: none; reads DataController and UIConfig layouts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Config.UpgradeConfig)
local Panel = require(ReplicatedStorage.Modules.UIComponents.Panel)
local ProgressBar = require(ReplicatedStorage.Modules.UIComponents.ProgressBar)
local StatChip = require(ReplicatedStorage.Modules.UIComponents.StatChip)
local useDeviceLayout = require(ReplicatedStorage.Modules.UIComponents.useDeviceLayout)

local e = React.createElement
local Theme = UIConfig.Theme
local Text = UIConfig.Text

local function App()
	local layout = useDeviceLayout()
	local hudLayout = UIConfig.Layouts[layout].HUD
	local data, setData = React.useState(DataController.Get())

	React.useEffect(function()
		local connection = DataController.Changed:Connect(setData)
		return function()
			connection:Disconnect()
		end
	end, {})

	local inRun = data.RunState == GameConfig.RunStates.Running
	local timed = data.TimeLeft >= 0
	local maxLifespan = UpgradeConfig.GetValue("Lifespan", data.Upgrades.Lifespan)
	local ratio = if timed and maxLifespan > 0 then math.clamp(data.TimeLeft / maxLifespan, 0, 1) else 0
	local lowTime = timed and ratio <= Theme.LowTimeRatio
	local timerText = if timed then string.format(Text.TimeFormat, math.max(0, data.TimeLeft)) else Text.Practice

	local runPanel = nil
	if inRun then
		runPanel = e(Panel, {
			anchorPoint = hudLayout.RunPanel.AnchorPoint,
			maxSize = hudLayout.RunPanel.MaxSize,
			minSize = hudLayout.RunPanel.MinSize,
			padding = Theme.Spacing.S,
			position = hudLayout.RunPanel.Position,
			size = hudLayout.RunPanel.Size,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, Theme.Spacing.S),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Header = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, Theme.Sizes.ScoreRowHeight),
			}, {
				Caption = e("TextLabel", {
					BackgroundTransparency = 1,
					Font = Theme.Fonts.Medium,
					Size = UDim2.fromScale(Theme.Sizes.ScoreCaptionWidth, 1),
					Text = Text.ScoreLabel,
					TextColor3 = Theme.Colors.TextMuted,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
					TextBound = e("UITextSizeConstraint", {
						MaxTextSize = Theme.TextSizes.Small,
						MinTextSize = Theme.TextBounds.Min,
					}),
				}),
				Value = e("TextLabel", {
					BackgroundTransparency = 1,
					Font = Theme.Fonts.Bold,
					Position = UDim2.fromScale(Theme.Sizes.ScoreCaptionWidth, 0),
					Size = UDim2.fromScale(Theme.Sizes.ScoreValueWidth, 1),
					Text = tostring(math.floor(data.Score)),
					TextColor3 = Theme.Colors.Text,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}, {
					TextBound = e("UITextSizeConstraint", {
						MaxTextSize = Theme.TextSizes.Score,
						MinTextSize = Theme.TextBounds.Min,
					}),
				}),
			}),
			Bar = e(ProgressBar, {
				LayoutOrder = 2,
				ratio = ratio,
				size = UDim2.new(1, 0, 0, Theme.Sizes.ProgressHeight),
				visible = timed,
			}),
			Timer = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Medium,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, Theme.Sizes.TimerHeight),
				Text = timerText,
				TextColor3 = if lowTime then Theme.Colors.Danger else Theme.Colors.TextMuted,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, {
				TextBound = e("UITextSizeConstraint", {
					MaxTextSize = Theme.TextSizes.Timer,
					MinTextSize = Theme.TextBounds.Min,
				}),
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		CoinsChip = e(StatChip, {
			anchorPoint = hudLayout.CoinsChip.AnchorPoint,
			label = Text.CoinsLabel,
			maxSize = hudLayout.CoinsChip.MaxSize,
			minSize = hudLayout.CoinsChip.MinSize,
			position = hudLayout.CoinsChip.Position,
			size = hudLayout.CoinsChip.Size,
			value = tostring(math.floor(data.Coins)),
			valueColor = Theme.Colors.Accent,
		}),
		RunPanel = runPanel,
	})
end

return function()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	screenGui.DisplayOrder = 1
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(App))
end
