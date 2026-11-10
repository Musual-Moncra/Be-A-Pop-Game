--!strict

--[[
	RunJuice
	Run-only juice layers drawn over the HUD: the combo meter under the Lifespan bar and the
	stain milestone banners (25/50/75% and the full-screen MAP CLEARED! at 100%). Reads its
	state from JuiceController signals, so it owns nothing the RunHud already shows.

	Props: ui (useUIScale result)
	Dependencies: React, RunService, TweenService, UIConfig, JuiceConfig, JuiceController,
		Primitives, Rays, Sparkle
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local JuiceController = require(ReplicatedStorage.Modules.Controllers.JuiceController)
local JuiceConfig = require(ReplicatedStorage.Modules.Config.JuiceConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Sparkle = require(Components.Sparkle)

local e = React.createElement

local COMBO_PUNCH_INFO = TweenInfo.new(JuiceConfig.ComboPunchTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BANNER_PUNCH_INFO = TweenInfo.new(JuiceConfig.MilestonePunchTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function comboPosition(ui: any): UDim2
	local layout = UIConfig.Layouts[if ui.mobile then "Mobile" else "PC"].RunTimer
	return UDim2.new(
		layout.Position.X.Scale,
		layout.Position.X.Offset,
		layout.Position.Y.Scale,
		layout.Position.Y.Offset
			+ UIConfig.Sizes.Window.Gap
			+ UIConfig.Sizes.Run.TimerBarHeight
			+ JuiceConfig.ComboOffsetY
	)
end

local function ComboMeter(props: any)
	local ui = props.ui
	local level, setLevel = React.useState(JuiceController.GetCombo())
	local previousRef = React.useRef(level)
	local punchRef = React.useRef(nil)
	local frameRef = React.useRef(nil)
	local maxLevel = #JuiceConfig.ComboColors

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
		if frame == nil or level < maxLevel then
			if frame ~= nil then
				frame.Rotation = 0
			end
			return
		end
		local connection = RunService.Heartbeat:Connect(function()
			frame.Rotation = math.sin(os.clock() * JuiceConfig.ComboShakeSpeed) * JuiceConfig.ComboShakeDegrees
		end)
		return function()
			connection:Disconnect()
			if frame ~= nil then
				frame.Rotation = 0
			end
		end
	end, { level } :: { any })

	local layout = UIConfig.Layouts[if ui.mobile then "Mobile" else "PC"].RunTimer
	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = comboPosition(ui),
		Rotation = 0,
		Size = UDim2.fromOffset(JuiceConfig.ComboWidth, JuiceConfig.ComboHeight),
		Visible = level >= JuiceConfig.ComboMinLevel,
		ref = frameRef,
	}, {
		Scale = e("UIScale", { ref = punchRef }),
		Label = Primitives.text({
			Color = JuiceConfig.ComboColors[math.clamp(level, 1, maxLevel)],
			Size = UDim2.fromScale(1, 1),
			Text = string.format(JuiceConfig.ComboFormat, level),
			TextSize = JuiceConfig.ComboTextSize,
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
