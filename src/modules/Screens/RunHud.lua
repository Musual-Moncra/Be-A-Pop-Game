--!strict

--[[
	RunHud
	Run HUD: the Lifespan pill (clock icon, ratio-coloured fill, red shake when low), the map
	stain bar (ticks 25/50/75, a poop icon riding the fill edge, Best chip), the score card
	with a punching count-up and Stink chip, the quest list, the active power-up column and the
	small LEAVE pill. Float popups (food, soiling, caught) stack above the HUD.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, RunService, TweenService, UIConfig, RunUIConfig, ConfigLookup, PetView,
		Net, Components (Bar, ChunkyButton, Chip, CountUp, Format, Inset, Primitives)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local RunUIConfig = require(ReplicatedStorage.Modules.Config.RunUIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Components = ReplicatedStorage.Modules.UIComponents
local Bar = require(Components.Bar)
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local CountUp = require(Components.CountUp)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes
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

local function swatchForRatio(timed: boolean, ratio: number): string
	if not timed then
		return "Blue"
	end
	if ratio > RunUIConfig.Lifespan.MidRatio then
		return RunUIConfig.Lifespan.SwatchHigh
	elseif ratio > Animation.LowTimeRatio then
		return RunUIConfig.Lifespan.SwatchMid
	end
	return RunUIConfig.Lifespan.SwatchLow
end

local function LifespanPill(props: any)
	local data = props.data
	local config = RunUIConfig.Lifespan
	local maxTimeRef = React.useRef(0)
	local frameRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)
	local timed = data.TimeLeft >= 0
	if timed and data.TimeLeft > maxTimeRef.current then
		maxTimeRef.current = data.TimeLeft
	end
	local ratio = if timed and maxTimeRef.current > 0 then data.TimeLeft / maxTimeRef.current else 1
	local low = timed and ratio <= Animation.LowTimeRatio

	React.useEffect(function()
		local frame = frameRef.current
		local scale = scaleRef.current
		if not low or frame == nil or scale == nil then
			return
		end
		local connection = RunService.Heartbeat:Connect(function()
			local wave = math.sin(os.clock() * config.ShakeSpeed)
			frame.Rotation = wave * config.ShakeDegrees
			scale.Scale = 1 + math.abs(wave) * (config.ShakeScale - 1)
		end)
		return function()
			connection:Disconnect()
			frame.Rotation = 0
			scale.Scale = 1
		end
	end, { low } :: { any })

	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(config.Width, config.Height),
		ref = frameRef,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Bar = e(Bar, {
			ratio = ratio,
			size = UDim2.fromScale(1, 1),
			swatch = swatchForRatio(timed, ratio),
		}),
		Icon = e(ChunkyButton, {
			gloss = true,
			icon = config.Icon,
			iconSize = config.IconSize * Shape.IconFill,
			position = UDim2.fromOffset(config.Height * 0.12, config.Height * 0.12),
			round = true,
			size = UDim2.fromOffset(config.IconSize, config.IconSize),
			swatch = "Gold",
			zIndex = 3,
		}),
		Time = Primitives.text({
			Color = Palette.Text,
			Position = UDim2.fromOffset(config.IconSize + config.Height * 0.3, 0),
			Size = UDim2.new(1, -(config.IconSize + config.Height * 0.5), 1, 0),
			Text = if timed then string.format(config.Format, math.max(0, data.TimeLeft)) else config.Untimed,
			TextSize = config.TextSize,
			ZIndex = 3,
		}),
	})
end

local function MapMeter(props: any)
	local data = props.data
	local config = RunUIConfig.Meter
	local progress = data.MapProgress
	local percent = math.clamp(if progress ~= nil then tonumber(progress.Percent) or 0 else 0, 0, 100)
	local best = (data.BestMapProgress or {})[data.MapId] or 0
	local ratio = percent / 100
	local swatch = Primitives.swatch(config.Swatch)
	local tickRefs = React.useRef({})
	local passedRef = React.useRef(0)

	local tickChildren: { [string]: any } = {}
	local passedCount = 0
	for index, mark in config.Ticks do
		local passed = percent >= mark
		if passed then
			passedCount += 1
		end
		local tickIndex = index
		tickChildren["Tick" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if passed then config.TickDoneColor else config.TickColor,
			BorderSizePixel = 0,
			Position = UDim2.new(mark / 100, 0, 0.5, 0),
			Size = UDim2.fromOffset(config.TickWidth, config.Height * config.TickHeightRatio),
			ZIndex = 6,
		}, {
			Scale = e("UIScale", {
				ref = function(instance: any)
					tickRefs.current[tickIndex] = instance
				end,
			}),
		})
	end

	React.useEffect(function()
		local previous = passedRef.current
		passedRef.current = passedCount
		if passedCount <= previous then
			return
		end
		for index = previous + 1, passedCount do
			local scale = tickRefs.current[index]
			if scale ~= nil then
				scale.Scale = config.TickPopScale
				TweenService
					:Create(
						scale,
						TweenInfo.new(config.TickPopTime, Animation.SpringStyle, Animation.SpringDirection),
						{
							Scale = 1,
						}
					)
					:Play()
			end
		end
	end, { passedCount } :: { any })

	local fillGradient = e("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, swatch.Top),
			ColorSequenceKeypoint.new(0.5, swatch.Mid or swatch.Bottom),
			ColorSequenceKeypoint.new(1, swatch.Bottom),
		}),
		Rotation = Shape.GradientRotation,
	})

	local barChildren: { [string]: any } = {
		Track = e("Frame", {
			BackgroundColor3 = Palette.Ink,
			BackgroundTransparency = config.TrackTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, {
			Corner = Primitives.corner("Round"),
			Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
		}),
		Fill = e("Frame", {
			BackgroundColor3 = Palette.Text,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.fromScale(ratio, 1),
			Visible = ratio > 0,
			ZIndex = 2,
		}, {
			Corner = Primitives.corner("Round"),
			Gradient = fillGradient,
			Gloss = e("Frame", {
				BackgroundColor3 = Palette.Text,
				BackgroundTransparency = Shape.GlossTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(Shape.GlossInset, Shape.GlossInset),
				Size = UDim2.new(1, -Shape.GlossInset * 2, Shape.GlossHeightRatio, -Shape.GlossInset),
				ZIndex = 3,
			}, {
				Corner = Primitives.corner("Round"),
				Fade = e("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, Shape.GlossTransparency),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
		}),
		Label = Primitives.text({
			Color = Palette.Text,
			Size = UDim2.fromScale(1, 1),
			Text = string.format(config.Format, percent),
			TextSize = config.TextSize,
			ZIndex = 7,
		}),
		Rim = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		}, {
			Corner = Primitives.corner("Round"),
			Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
		}),
		Poop = if percent >= config.PoopMinPercent
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(ratio, 0, 0, -config.PoopRise),
				Size = UDim2.fromOffset(config.PoopTextSize + 2, config.PoopTextSize + 2),
				Text = config.PoopIcon,
				TextSize = config.PoopTextSize,
				ZIndex = 8,
			})
			else nil,
	}
	for key, tick in tickChildren do
		barChildren[key] = tick
	end

	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(config.Width + config.Gap + config.BestChip.Width, config.Height),
	}, {
		Bar = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(config.Width, config.Height),
		}, barChildren),
		Best = e(Chip, {
			anchorPoint = Vector2.new(1, 0.5),
			height = config.BestChip.Height,
			position = UDim2.new(1, 0, 0.5, 0),
			swatch = config.BestChip.Swatch,
			text = string.format(config.BestChip.Format, best),
			textSize = config.BestChip.TextSize,
			zIndex = 3,
		}),
	})
end

local function ScoreCard(props: any)
	local data = props.data
	local config = RunUIConfig.Score
	local mode = ConfigLookup.GetMode(data.ModeId)
	local target = if mode ~= nil then mode.TargetScore else 0

	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 3, Enum.HorizontalAlignment.Center),
		Caption = Primitives.text({
			Color = Palette.Text,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, config.CaptionTextSize + Shape.SmallTextStroke * 2),
			StrokeSize = Shape.SmallTextStroke,
			Text = Text.ScoreLabel,
			TextSize = config.CaptionTextSize,
		}),
		Score = e(CountUp, {
			compact = true,
			color = Palette.Sparkle,
			layoutOrder = 2,
			size = UDim2.new(1, 0, 0, config.ScoreTextSize + Shape.TextStroke * 2),
			textSize = config.ScoreTextSize,
			value = data.Score,
		}),
		Stink = e(ChunkyButton, {
			gloss = true,
			icon = Text.StinkIcon,
			iconSize = config.StinkIconSize,
			layoutOrder = 3,
			size = UDim2.fromOffset(config.StinkWidth, config.StinkHeight),
			swatch = "Brown",
			text = string.format(Text.StinkPillFormat, PetView.TotalStink(data)),
			textSize = config.StinkTextSize,
		}),
	}
	if target > 0 then
		local reached = data.Score >= target
		children.Target = e(Bar, {
			layoutOrder = 4,
			ratio = data.Score / target,
			size = UDim2.new(1, 0, 0, Sizes.Run.TargetBarHeight + Shape.Stroke * 2),
			swatch = if reached then "Green" else "Gold",
			text = if reached
				then Text.TargetDone
				else string.format(Text.TargetFormat, Format.compact(data.Score), Format.compact(target)),
			textSize = TextSizes.Tiny,
		})
	end

	return panel({
		AnchorPoint = props.layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(config.Width, 0),
	}, children)
end

local function QuestPanel(props: any)
	local quests = props.quests
	if #quests == 0 then
		return nil
	end
	local config = RunUIConfig.Quests
	local rows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
		Header = Primitives.text({
			Color = Palette.Text,
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
			size = UDim2.new(1, 0, 0, config.RowHeight),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Shape.Stroke),
			Label = Primitives.text({
				Color = if quest.Done then UIConfig.Swatches.Green.Bottom else Palette.Ink,
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
				size = UDim2.new(1, 0, 0, Sizes.Run.TargetBarHeight),
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
		Size = UDim2.fromOffset(config.Width, 0),
	}, rows)
end

local function PowerupSlots(props: any)
	local powerups = props.powerups
	local config = RunUIConfig.Powerups
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
		Layout = Primitives.list(Enum.FillDirection.Vertical, config.Gap),
	}
	local now = os.clock()
	for index, active in powerups do
		local definition = ConfigLookup.GetPowerup(active.Id)
		local left = math.max(0, active.ExpiresAt - now)
		slots[active.Id] = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.fromOffset(config.Size, config.Size + config.TimerHeight + config.Gap / 2),
		}, {
			Icon = e(ChunkyButton, {
				gloss = true,
				icon = if definition ~= nil then definition.Icon else "",
				iconSize = config.Size * Shape.IconFill,
				round = true,
				size = UDim2.fromOffset(config.Size, config.Size),
				swatch = config.Swatch,
			}),
			Timer = e(Bar, {
				anchorPoint = Vector2.new(0, 1),
				position = UDim2.fromScale(0, 1),
				ratio = if active.Duration > 0 then left / active.Duration else 0,
				size = UDim2.new(1, 0, 0, config.TimerHeight),
				swatch = config.TimerSwatch,
				text = string.format(Text.PowerupTimer, math.ceil(left)),
				textSize = config.TimerTextSize,
			}),
		})
	end

	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(config.Size, 0),
	}, slots)
end

local function Popup(props: any)
	local scaleRef = React.useRef(nil)
	local swatch = Primitives.swatch(UIConfig.ToastSwatches[props.popup.Kind])
	local step = Sizes.Popup.Height + Sizes.Popup.Gap

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		scale.Scale = Animation.OpenFromScale
		TweenService:Create(scale, TweenInfo.new(Animation.Open, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = 1,
		}):Play()
	end, {})

	return e("TextLabel", {
		AnchorPoint = props.base.AnchorPoint,
		BackgroundTransparency = 1,
		FontFace = Primitives.displayFont(),
		Position = props.base.Position - UDim2.fromOffset(0, props.slot * step),
		Size = UDim2.fromOffset(Sizes.Popup.Width, Sizes.Popup.Height),
		Text = props.popup.Text,
		TextColor3 = swatch.Top,
		TextSize = TextSizes.Header,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Stroke = e("UIStroke", {
			Color = Palette.Ink,
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = Shape.TextStroke,
		}),
	})
end

return function(props: any)
	local data = props.data
	local mode = if props.ui.mobile then "Mobile" else "PC"
	local layouts = UIConfig.Layouts[mode]
	local runLayouts = RunUIConfig.Layouts[mode]
	local timerLayout = layouts.RunTimer
	local meterY = timerLayout.Position.Y.Offset + RunUIConfig.Lifespan.Height + RunUIConfig.Stack.LifespanToMeter
	local meterLayout = {
		AnchorPoint = timerLayout.AnchorPoint,
		Position = UDim2.new(timerLayout.Position.X.Scale, timerLayout.Position.X.Offset, 0, meterY),
	}

	local children: { [string]: any } = {
		Lifespan = e(LifespanPill, { data = data, layout = timerLayout }),
		Meter = e(MapMeter, { data = data, layout = meterLayout }),
		Score = e(ScoreCard, { data = data, layout = layouts.RunScore }),
		Quests = e(QuestPanel, { layout = runLayouts.Quests, quests = data.Quests }),
		Powerups = e(PowerupSlots, { layout = runLayouts.Powerups, powerups = data.Powerups }),
		Leave = e(ChunkyButton, {
			anchorPoint = layouts.RunLeave.AnchorPoint,
			gloss = true,
			onActivated = function()
				Net.LeaveRun:Fire()
			end,
			position = layouts.RunLeave.Position,
			size = UDim2.fromOffset(RunUIConfig.Leave.Width, RunUIConfig.Leave.Height),
			swatch = "Red",
			text = Text.Leave,
			textSize = TextSizes.Body,
		}),
	}
	local firstVisible = math.max(1, #data.Popups - Animation.PopupMaxVisible + 1)
	for index = firstVisible, #data.Popups do
		local popup = data.Popups[index]
		children["Popup" .. popup.Id] = e(Popup, {
			base = layouts.Popups,
			popup = popup,
			slot = #data.Popups - index,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end
