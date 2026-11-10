--!strict

--[[
	RainbowRim
	Animated rotating rainbow outline for a frame (UIStroke with a UIGradient). Put it as a
	child of the frame; its rotation runs on the shared SparkleClock.

	Props: thickness (design pixels), active (default true)
	Dependencies: React, UIConfig, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local SparkleClock = require(Components.SparkleClock)

local e = React.createElement
local Sparkle = UIConfig.Sparkle
local Shape = UIConfig.Shape

local function rainbowColors(): ColorSequence
	local colors = Sparkle.RainbowColors
	local keypoints = {}
	local count = #colors
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / count, color))
	end
	table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	return ColorSequence.new(keypoints)
end

return function(props: any)
	local gradientRef = React.useRef(nil)

	React.useEffect(function()
		local gradient = gradientRef.current
		if gradient == nil or props.active == false then
			return
		end
		local disconnect = SparkleClock.Subscribe(function(_dt: number, now: number)
			gradient.Rotation = (now / Sparkle.RainbowSeconds) % 1 * 360
		end)
		return function()
			disconnect()
		end
	end, { props.active })

	return e("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = props.thickness or Shape.Stroke,
	}, {
		Gradient = e("UIGradient", {
			Color = rainbowColors(),
			ref = gradientRef,
			Rotation = 0,
		}),
	})
end
