--!strict

--[[
	RunHud
	Everything shown during a run: the score panel (big score, timer bar that turns red when
	low, Challenge target bar), the quest list, active food power-ups with countdowns,
	floating popups (food eaten, object soiled, caught by a chef) and the LEAVE button.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, UIConfig, ConfigLookup, Net, Primitives, ChunkyButton, Bar, Inset, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Components = ReplicatedStorage.Modules.UIComponents
local Bar = require(Components.Bar)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Run
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function panel(props: any, children: any)
	local merged = {
		Corner = Primitives.corner(Shape.WindowRadius),
		Gradient = Primitives.gradient(Palette.PanelTop, Palette.PanelBottom),
		Stroke = Primitives.stroke(Palette.PanelRim, Shape.RimStroke),
		Padding = Primitives.padding(Gap),
	}
	for key, child in children do
		merged[key] = child
	end
	return e("Frame", {
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = props.AutomaticSize,
		BackgroundColor3 = Palette.Text,
		BorderSizePixel = 0,
		Position = props.Position,
		Size = props.Size,
	}, merged)
end

local function ScorePanel(props: any)
	local data = props.data
	local layout = props.layout
	local maxTimeRef = React.useRef(0)
	local timed = data.TimeLeft >= 0
	if timed and data.TimeLeft > maxTimeRef.current then
		maxTimeRef.current = data.TimeLeft
	end
	local ratio = if timed and maxTimeRef.current > 0 then data.TimeLeft / maxTimeRef.current else 1
	local low = timed and ratio <= Animation.LowTimeRatio

	local mode = ConfigLookup.GetMode(data.ModeId)
	local target = if mode ~= nil then mode.TargetScore else 0

	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2, Enum.HorizontalAlignment.Center),
		Caption = Primitives.text({
			Color = Palette.TextSoft,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, TextSizes.Small),
			StrokeSize = Shape.SmallTextStroke,
			Text = Text.ScoreLabel,
			TextSize = TextSizes.Small,
		}),
		Score = Primitives.text({
			Color = Palette.Sparkle,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, TextSizes.Huge),
			Text = Format.commas(data.Score),
			TextSize = TextSizes.Huge,
		}),
		Timer = e(Bar, {
			layoutOrder = 3,
			ratio = ratio,
			size = UDim2.new(1, 0, 0, Sizes.TimerBarHeight),
			swatch = if not timed then "Blue" elseif low then "Red" else "Green",
			text = if timed then string.format(Text.TimerFormat, math.max(0, data.TimeLeft)) else Text.Untimed,
		}),
	}
	if target > 0 then
		local reached = data.Score >= target
		children.Target = e(Bar, {
			layoutOrder = 4,
			ratio = data.Score / target,
			size = UDim2.new(1, 0, 0, Sizes.TargetBarHeight + Shape.Stroke * 2),
			swatch = if reached then "Green" else "Gold",
			text = if reached
				then Text.TargetDone
				else string.format(Text.TargetFormat, Format.compact(data.Score), Format.compact(target)),
			textSize = TextSizes.Tiny,
		})
	end

	return panel({
		AnchorPoint = layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = layout.Position,
		Size = UDim2.fromOffset(Sizes.ScoreWidth, 0),
	}, children)
end

local function QuestPanel(props: any)
	local quests = props.quests
	if #quests == 0 then
		return nil
	end
	local rows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
		Header = Primitives.text({
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, TextSizes.Large),
			Text = Text.QuestsHeader,
			TextSize = TextSizes.Large,
		}),
	}
	for index, quest in quests do
		rows["Quest" .. index] = e(Inset, {
			layoutOrder = index,
			padding = Gap / 2,
			size = UDim2.new(1, 0, 0, Sizes.QuestRowHeight),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Shape.Stroke),
			Label = Primitives.text({
				Color = if quest.Done then UIConfig.Swatches.Green.Top else Palette.Text,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, TextSizes.Small + Shape.Stroke),
				StrokeSize = Shape.SmallTextStroke,
				Text = if quest.Done then string.format(Text.IconLabel, Text.CheckIcon, quest.Text) else quest.Text,
				TextSize = TextSizes.Small,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Progress = e(Bar, {
				layoutOrder = 2,
				ratio = if quest.Target > 0 then quest.Progress / quest.Target else 1,
				size = UDim2.new(1, 0, 0, Sizes.TargetBarHeight),
				swatch = if quest.Done then "Green" else "Teal",
				text = string.format(
					Text.QuestProgress,
					Format.compact(math.min(quest.Progress, quest.Target)),
					Format.compact(quest.Target)
				),
				textSize = TextSizes.Tiny,
			}),
		})
	end
	return panel({
		AnchorPoint = props.layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(Sizes.QuestWidth, 0),
	}, rows)
end

local function PowerupSlots(props: any)
	local powerups = props.powerups
	local _, setTick = React.useState(0)

	React.useEffect(function()
		if #powerups == 0 then
			return
		end
		local elapsed = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= Animation.HudTick then
				elapsed = 0
				setTick(os.clock())
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { #powerups })

	if #powerups == 0 then
		return nil
	end

	local slots: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Horizontal, Gap),
	}
	local now = os.clock()
	for index, active in powerups do
		local definition = ConfigLookup.GetPowerup(active.Id)
		local left = math.max(0, active.ExpiresAt - now)
		slots[active.Id] = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.fromOffset(Sizes.PowerupSize, Sizes.PowerupSize + Sizes.TargetBarHeight + Gap / 2),
		}, {
			Icon = e(ChunkyButton, {
				icon = if definition ~= nil then definition.Icon else "",
				iconSize = Sizes.PowerupSize * Shape.IconFill,
				round = true,
				size = UDim2.fromOffset(Sizes.PowerupSize, Sizes.PowerupSize),
				swatch = UIConfig.PowerupSwatch,
			}),
			Timer = e(Bar, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				ratio = if active.Duration > 0 then left / active.Duration else 0,
				size = UDim2.new(1, 0, 0, Sizes.TargetBarHeight),
				swatch = "Gold",
				text = string.format(Text.PowerupTimer, math.ceil(left)),
				textSize = TextSizes.Tiny,
			}),
		})
	end

	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.new(),
	}, slots)
end

local function Popup(props: any)
	local labelRef = React.useRef(nil)
	local swatch = Primitives.swatch(UIConfig.ToastSwatches[props.popup.Kind])

	React.useEffect(function()
		local label = labelRef.current
		if label == nil then
			return
		end
		local start = label.Position
		local info = TweenInfo.new(Animation.PopupSeconds, Animation.SmoothStyle, Animation.SmoothDirection)
		TweenService:Create(label, info, {
			Position = start - UDim2.fromOffset(0, Animation.PopupRise),
			TextTransparency = 1,
		}):Play()
	end, {})

	return e("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Primitives.displayFont(),
		LayoutOrder = props.popup.Id,
		Size = UDim2.fromOffset(UIConfig.Sizes.Popup.Width, UIConfig.Sizes.Popup.Height),
		Text = props.popup.Text,
		TextColor3 = swatch.Top,
		TextSize = TextSizes.Header,
		ref = labelRef,
	}, {
		Stroke = e("UIStroke", {
			Color = Palette.Ink,
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = Shape.TextStroke,
		}),
	})
end

return function(props: any)
	local data = props.data
	local layouts = UIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"]

	local popups: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center),
	}
	for _, popup in data.Popups do
		popups["Popup" .. popup.Id] = e(Popup, { popup = popup })
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Score = e(ScorePanel, { data = data, layout = layouts.RunScore }),
		Quests = e(QuestPanel, { layout = layouts.RunQuests, quests = data.Quests }),
		Powerups = e(PowerupSlots, { layout = layouts.RunPowerups, powerups = data.Powerups }),
		Popups = e("Frame", {
			AnchorPoint = layouts.Popups.AnchorPoint,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = layouts.Popups.Position,
			Size = UDim2.fromOffset(UIConfig.Sizes.Popup.Width, 0),
		}, popups),
		Leave = e(ChunkyButton, {
			anchorPoint = layouts.RunLeave.AnchorPoint,
			onActivated = function()
				Net.LeaveRun:Fire()
			end,
			position = layouts.RunLeave.Position,
			size = UDim2.fromOffset(Sizes.LeaveWidth, Sizes.LeaveHeight),
			swatch = "Red",
			text = Text.Leave,
			textSize = TextSizes.Large,
		}),
	})
end
