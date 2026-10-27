--!strict

--[[
	Sparkle
	Twinkling star decoration that fades in and out forever.

	Props: position, anchorPoint, size (design pixels, square), delay (seconds before it starts), zIndex

	Dependencies: React, UIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation

return function(props: any)
	local labelRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local label = labelRef.current
		local scale = scaleRef.current
		if label == nil or scale == nil then
			return
		end
		local info = TweenInfo.new(
			1 / UIConfig.Animation.SparkleSpeed / 2,
			Animation.TwinkleStyle,
			Animation.TwinkleDirection,
			-1,
			true,
			props.delay or 0
		)
		local fade = TweenService:Create(label, info, { TextTransparency = 1 })
		local shrink = TweenService:Create(scale, info, { Scale = UIConfig.Animation.PressScale })
		fade:Play()
		shrink:Play()
		return function()
			fade:Cancel()
			shrink:Cancel()
		end
	end, {})

	return e("TextLabel", {
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = Primitives.displayFont(),
		Position = props.position,
		Size = UDim2.fromOffset(props.size, props.size),
		Text = UIConfig.Text.SparkleIcon,
		TextColor3 = UIConfig.Palette.Sparkle,
		TextSize = props.size,
		ZIndex = props.zIndex,
		ref = labelRef,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
	})
end
