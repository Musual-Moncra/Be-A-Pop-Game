--!strict

--[[
	CountUp
	Outlined number label that tick-counts to a new value over a short time and punches in
	scale when the value changes (currency, gems, score). First render shows the value at once.

	Props: value (number), textSize, color, font ("Display" | "Body"), size, position,
		anchorPoint, layoutOrder, zIndex, format (string.format with the displayed number),
		compact (true uses K/M suffixes), stroke (false hides the outline),
		flashColor (optional colour flashed on a value change; defaults to the label colour)
	Dependencies: React, RunService, TweenService, UIConfig, Primitives, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Format = require(Components.Format)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation

return function(props: any)
	local target = tonumber(props.value) or 0
	local shown, setShown = React.useState(target)
	local previous = React.useRef(target)
	local scaleRef = React.useRef(nil)
	local labelRef = React.useRef(nil)

	React.useEffect(function()
		local from = previous.current
		previous.current = target
		if from == target then
			return
		end
		local label = labelRef.current
		if label ~= nil and props.flashColor ~= nil then
			label.TextColor3 = props.flashColor
			TweenService:Create(
				label,
				TweenInfo.new(Animation.NumberPunchSeconds, Animation.SmoothStyle, Animation.SmoothDirection),
				{ TextColor3 = props.color or UIConfig.Palette.Text }
			):Play()
		end
		local punch = scaleRef.current
		if punch ~= nil then
			punch.Scale = Animation.NumberPunchScale
			TweenService:Create(
				punch,
				TweenInfo.new(Animation.NumberPunchSeconds, Animation.SpringStyle, Animation.SpringDirection),
				{ Scale = 1 }
			):Play()
		end
		local duration = Animation.CountUpSeconds
		if duration <= 0 then
			setShown(target)
			return
		end
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local progress = math.clamp((os.clock() - started) / duration, 0, 1)
			local eased = 1 - (1 - progress) * (1 - progress)
			setShown(from + (target - from) * eased)
			if progress >= 1 then
				connection:Disconnect()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { target })

	local text
	if props.compact then
		text = Format.compact(math.floor(shown))
	elseif props.format ~= nil then
		text = string.format(props.format, math.floor(shown))
	else
		text = tostring(math.floor(shown))
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		ZIndex = props.zIndex,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Label = Primitives.text({
			Color = props.color,
			Fit = true,
			Font = props.font,
			Size = UDim2.fromScale(1, 1),
			Stroke = props.stroke,
			Text = text,
			TextSize = props.textSize,
			ZIndex = props.zIndex,
			ref = labelRef,
		}),
	})
end
