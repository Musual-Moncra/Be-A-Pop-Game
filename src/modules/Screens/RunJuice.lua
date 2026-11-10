--!strict

--[[
	RunJuice
	Run-only juice layers drawn over the HUD: the tilted combo meter under the map stain bar and
	the stain milestone banners (25/50/75% and the full-screen MAP CLEARED! at 100%). Reads its
	state from JuiceController signals, so it owns nothing the RunHud already shows.

	Props: ui (useUIScale result)
	Dependencies: React, RunService, TweenService, UIConfig, RunUIConfig, JuiceConfig,
		JuiceController, Primitives, Rays, Sparkle
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

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape

local COMBO_PUNCH_INFO = TweenInfo.new(JuiceConfig.ComboPunchTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BANNER_PUNCH_INFO = TweenInfo.new(JuiceConfig.MilestonePunchTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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
	local punchRef = React.useRef(nil)
	local frameRef = React.useRef(nil)
	local gradientRef = React.useRef(nil)
	local maxLevel = #JuiceConfig.ComboColors
	local isMax = level >= maxLevel
	local shownLevel = math.clamp(level, 1, maxLevel)

	React.useEffect(function()
		local connection = JuiceController.ComboChanged:Connect(setLevel)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local scale = punchRef.current
		local previous = previousRef.current
		previousRef.current = level
		if scale ~= nil and level > previous then
			scale.Scale = JuiceConfig.ComboPunchScale
			TweenService:Create(scale, COMBO_PUNCH_INFO, { Scale = 1 }):Play()
		end
	end, { level } :: { any })

	React.useEffect(function()
		local frame = frameRef.current
		if frame == nil or level < JuiceConfig.ComboMinLevel then
			if frame ~= nil then
				frame.Rotation = JuiceConfig.ComboTiltDegrees
			end
			return
		end
		local amplitude = if isMax then JuiceConfig.ComboShakeDegrees else JuiceConfig.ComboWobbleDegrees
		local speed = if isMax then JuiceConfig.ComboShakeSpeed else JuiceConfig.ComboWobbleSpeed
		local connection = RunService.Heartbeat:Connect(function()
			frame.Rotation = JuiceConfig.ComboTiltDegrees + math.sin(os.clock() * speed) * amplitude
		end)
		return function()
			connection:Disconnect()
			frame.Rotation = JuiceConfig.ComboTiltDegrees
		end
	end, { level, isMax } :: { any })

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
		Visible = level >= JuiceConfig.ComboMinLevel,
		ref = frameRef,
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
		scale.Scale = JuiceConfig.MilestonePunchScale
		TweenService:Create(scale, BANNER_PUNCH_INFO, { Scale = 1 }):Play()
	end, { milestoneId } :: { any })

	if milestone == nil then
		return nil
	end

	if milestone.Cleared then
		local sparkles: { [string]: any } = {}
		for index, star in JuiceConfig.MilestoneClearSparkles do
			sparkles["Sparkle" .. index] = e(Sparkle, {
				delay = index * JuiceConfig.MilestoneSparkleDelay,
				position = UDim2.fromScale(star.X, star.Y),
				size = star.Size,
			})
		end
		sparkles.Rays = e(Rays, { size = JuiceConfig.MilestoneClearRaysSize })
		sparkles.Box = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(JuiceConfig.MilestoneClearWidth, JuiceConfig.MilestoneClearHeight),
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Label = Primitives.text({
				Color = JuiceConfig.MilestoneClearColor,
				Size = UDim2.fromScale(1, 1),
				Text = JuiceConfig.MilestoneClearText,
				TextSize = JuiceConfig.MilestoneClearTextSize,
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
		Scale = e("UIScale", { ref = scaleRef }),
		Label = Primitives.text({
			Color = JuiceConfig.MilestoneColor,
			Size = UDim2.fromScale(1, 1),
			Text = string.format(JuiceConfig.MilestoneFormat, milestone.Percent),
			TextSize = JuiceConfig.MilestoneTextSize,
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
