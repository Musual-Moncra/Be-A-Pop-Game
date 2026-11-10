--!strict

--[[
	RunJuice
	Run-only juice layers drawn over the HUD: the tilted combo meter under the map stain bar and
	the stain milestone banners (25/50/75% and the full-screen MAP CLEARED! at 100%). Motion is
	scale only (zoom entrance, scale wobble, no element rotation). Reads its state from
	JuiceController signals, so it owns nothing the RunHud already shows.

	Props: ui (useUIScale result)
	Dependencies: React, RunService, TweenService, UIConfig, RunUIConfig, JuiceConfig,
		JuiceController, Primitives, Rays, Sparkle, Twinkle
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local JuiceController = require(ReplicatedStorage.Modules.Controllers.JuiceController)
local JuiceConfig = require(ReplicatedStorage.Modules.Config.JuiceConfig)
local RunUIConfig = require(ReplicatedStorage.Modules.Config.RunUIConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Sparkle = require(Components.Sparkle)
local Twinkle = require(Components.Twinkle)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local TAU = math.pi * 2

local COMBO_PUNCH_INFO = TweenInfo.new(JuiceConfig.ComboPunchTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function comboLayout(ui: any): any
	local mode = if ui.mobile then "Mobile" else "PC"
	local timer = UIConfig.Layouts[mode].RunTimer
	local y = timer.Position.Y.Offset
		+ RunUIConfig.Lifespan.Height
		+ RunUIConfig.Stack.LifespanToMeter
		+ RunUIConfig.Meter.Height
		+ RunUIConfig.Stack.MeterToCombo
		+ JuiceConfig.ComboOffsetY
	return {
		AnchorPoint = timer.AnchorPoint,
		Position = UDim2.new(timer.Position.X.Scale, timer.Position.X.Offset, 0, y),
	}
end

local function ComboMeter(props: any)
	local ui = props.ui
	local level, setLevel = React.useState(JuiceController.GetCombo())
	local previousRef = React.useRef(level)
	local wasVisibleRef = React.useRef(false)
	local wobbleRef = React.useRef(nil)
	local punchRef = React.useRef(nil)
	local gradientRef = React.useRef(nil)
	local maxLevel = #JuiceConfig.ComboColors
	local isMax = level >= maxLevel
	local visible = level >= JuiceConfig.ComboMinLevel
	local shownLevel = math.clamp(level, 1, maxLevel)

	React.useEffect(function()
		local connection = JuiceController.ComboChanged:Connect(setLevel)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local scale = punchRef.current
		if scale == nil then
			return
		end
		if not visible then
			wasVisibleRef.current = false
			scale.Scale = 1
			return
		end
		if wasVisibleRef.current then
			return
		end
		wasVisibleRef.current = true
		scale.Scale = 0
		TweenService:Create(
			scale,
			TweenInfo.new(JuiceConfig.ComboEntranceInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = JuiceConfig.ComboEntranceScale }
		):Play()
		local thread = task.delay(JuiceConfig.ComboEntranceInTime, function()
			if scale.Parent ~= nil then
				TweenService:Create(
					scale,
					TweenInfo.new(JuiceConfig.ComboEntranceOutTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, { visible } :: { any })

	React.useEffect(function()
		local scale = punchRef.current
		local previous = previousRef.current
		previousRef.current = level
		if scale ~= nil and level > previous and previous >= JuiceConfig.ComboMinLevel then
			scale.Scale = JuiceConfig.ComboPunchScale
			TweenService:Create(scale, COMBO_PUNCH_INFO, { Scale = 1 }):Play()
		end
	end, { level } :: { any })

	React.useEffect(function()
		local scale = wobbleRef.current
		if scale == nil or not visible then
			return
		end
		local connection = RunService.Heartbeat:Connect(function()
			scale.Scale = 1 + math.sin(os.clock() * JuiceConfig.ComboWobbleSpeed * TAU) * JuiceConfig.ComboWobbleScale
		end)
		return function()
			connection:Disconnect()
			scale.Scale = 1
		end
	end, { visible } :: { any })

	React.useEffect(function()
		local gradient = gradientRef.current
		if gradient == nil or not isMax then
			return
		end
		gradient.Rotation = 0
		local tween = TweenService:Create(
			gradient,
			TweenInfo.new(
				JuiceConfig.ComboGradientRotationSeconds,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.In,
				-1
			),
			{ Rotation = 360 }
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { isMax } :: { any })

	local layout = comboLayout(ui)
	local labelChildren = {
		Stroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Palette.Ink,
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = Shape.TextStroke,
		}),
	}
	if isMax then
		labelChildren.Gradient = e("UIGradient", {
			Color = JuiceConfig.ComboMaxGradient,
			ref = gradientRef,
		})
	end

	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = layout.Position,
		Rotation = JuiceConfig.ComboTiltDegrees,
		Size = UDim2.fromOffset(JuiceConfig.ComboWidth, JuiceConfig.ComboHeight),
		Visible = visible,
	}, {
		Wobble = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Scale = e("UIScale", { ref = wobbleRef }),
			Punch = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, {
				Scale = e("UIScale", { ref = punchRef }),
				Label = e("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Primitives.displayFont(),
					Size = UDim2.fromScale(1, 1),
					Text = string.format(JuiceConfig.ComboFormat, level),
					TextColor3 = JuiceConfig.ComboColors[shownLevel],
					TextSize = JuiceConfig.ComboTextSize,
				}, labelChildren),
			}),
		}),
	})
end

local function MilestoneBanner()
	local milestone, setMilestone = React.useState(nil)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local connection = JuiceController.MilestoneShown:Connect(function(percent: number, cleared: boolean)
			setMilestone({ Id = os.clock(), Percent = percent, Cleared = cleared })
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local milestoneId = if milestone ~= nil then milestone.Id else 0
	React.useEffect(function()
		if milestone == nil then
			return
		end
		local id = milestone.Id
		local seconds = if milestone.Cleared then JuiceConfig.MilestoneClearSeconds else JuiceConfig.MilestoneSeconds
		local thread = task.delay(seconds, function()
			setMilestone(function(current: any)
				if current ~= nil and current.Id == id then
					return nil
				end
				return current
			end)
		end)
		return function()
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end
	end, { milestoneId } :: { any })

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		scale.Scale = 0
		TweenService:Create(
			scale,
			TweenInfo.new(JuiceConfig.MilestoneEntranceInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = JuiceConfig.MilestoneEntranceScale }
		):Play()
		local thread = task.delay(JuiceConfig.MilestoneEntranceInTime, function()
			if scale.Parent ~= nil then
				TweenService
					:Create(
						scale,
						TweenInfo.new(
							JuiceConfig.MilestoneEntranceOutTime,
							Enum.EasingStyle.Back,
							Enum.EasingDirection.Out
						),
						{ Scale = 1 }
					)
					:Play()
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, { milestoneId } :: { any })

	if milestone == nil then
		return nil
	end

	if milestone.Cleared then
		local sparkles: { [string]: any } = {
			Twinkle = e(Twinkle, {
				rate = JuiceConfig.MilestoneClearTwinkleRate,
				size = JuiceConfig.MilestoneTwinkleSize,
				zIndex = 2,
			}),
			Rays = e(Rays, { size = JuiceConfig.MilestoneClearRaysSize, zIndex = 1 }),
		}
		for index, star in JuiceConfig.MilestoneClearSparkles do
			sparkles["Sparkle" .. index] = e(Sparkle, {
				delay = index * JuiceConfig.MilestoneSparkleDelay,
				position = UDim2.fromScale(star.X, star.Y),
				size = star.Size,
				zIndex = 2,
			})
		end
		sparkles.Box = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(JuiceConfig.MilestoneClearWidth, JuiceConfig.MilestoneClearHeight),
			ZIndex = 3,
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Label = Primitives.text({
				Color = JuiceConfig.MilestoneClearColor,
				Size = UDim2.fromScale(1, 1),
				Text = JuiceConfig.MilestoneClearText,
				TextSize = JuiceConfig.MilestoneClearTextSize,
				ZIndex = 3,
			}),
		})
		return e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, sparkles)
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, JuiceConfig.MilestoneBannerY),
		Size = UDim2.fromOffset(JuiceConfig.MilestoneBannerWidth, JuiceConfig.MilestoneBannerHeight),
	}, {
		Twinkle = e(Twinkle, {
			rate = JuiceConfig.MilestoneTwinkleRate,
			size = JuiceConfig.MilestoneTwinkleSize,
			zIndex = 2,
		}),
		Scale = e("UIScale", { ref = scaleRef }),
		Label = Primitives.text({
			Color = JuiceConfig.MilestoneColor,
			Size = UDim2.fromScale(1, 1),
			Text = string.format(JuiceConfig.MilestoneFormat, milestone.Percent),
			TextSize = JuiceConfig.MilestoneTextSize,
			ZIndex = 3,
		}),
	})
end

return function(props: any)
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Combo = e(ComboMeter, { ui = props.ui }),
		Milestone = e(MilestoneBanner),
	})
end
