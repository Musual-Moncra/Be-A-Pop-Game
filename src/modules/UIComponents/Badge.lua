--!strict

--[[
	Badge
	Pulsing red notification dot pinned to the top-right corner of its parent
	(LobbyUIConfig.Badge look and timing).

	Props: size (diameter, design pixels), text (optional, defaults to LobbyUIConfig.Badge.Text), zIndex
	Dependencies: React, UIConfig, LobbyUIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local BadgeConfig = LobbyUIConfig.Badge

return function(props: any)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(
				BadgeConfig.PulseSeconds,
				UIConfig.Animation.TwinkleStyle,
				UIConfig.Animation.TwinkleDirection,
				-1,
				true
			),
			{ Scale = BadgeConfig.PulseScale }
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, {})

	local swatch = Primitives.swatch(BadgeConfig.Swatch)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = swatch.Bottom,
		Position = UDim2.new(1, -props.size * 0.15, 0, props.size * 0.15),
		Size = UDim2.fromOffset(props.size, props.size),
		ZIndex = props.zIndex,
	}, {
		Corner = Primitives.corner("Round"),
		Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
		Stroke = Primitives.stroke(swatch.Stroke, UIConfig.Shape.Stroke),
		Scale = e("UIScale", { ref = scaleRef }),
		Label = Primitives.text({
			Text = props.text or BadgeConfig.Text,
			TextSize = props.size * UIConfig.Shape.IconFill,
			ZIndex = props.zIndex,
		}),
	})
end
