--!strict

--[[
	Badge
	Pulsing red notification dot pinned to the top-right corner of its parent
	(LobbyUIConfig.Badge look and timing).

	Props: size (diameter, design pixels; defaults to LobbyUIConfig.Badge.Size),
		text or count (optional, defaults to LobbyUIConfig.Badge.Text), zIndex
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
	local size = props.size or BadgeConfig.Size
	local label = if props.count ~= nil then tostring(props.count) else (props.text or BadgeConfig.Text)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = swatch.Bottom,
		Position = UDim2.new(1, -size * 0.15, 0, size * 0.15),
		Size = UDim2.fromOffset(size, size),
		ZIndex = props.zIndex,
	}, {
		Corner = Primitives.corner("Round"),
		Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
		Stroke = Primitives.stroke(swatch.Stroke, UIConfig.Shape.Stroke),
		Scale = e("UIScale", { ref = scaleRef }),
		Label = Primitives.text({
			Text = label,
			TextSize = size * UIConfig.Shape.IconFill,
			ZIndex = props.zIndex,
		}),
	})
end
