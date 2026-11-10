--!strict

--[[
	GlowRing
	Soft radial glow behind a claimable thing: three stacked rounded frames with rising
	transparency that slowly breathe. Uses the shared SparkleClock.

	Props: size (diameter, design pixels), color (Color3), active (default true),
		zIndex, anchorPoint, position, period / scale (breathe override)
	Dependencies: React, UIConfig, Primitives, useBreathe
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local useBreathe = require(Components.useBreathe)

local e = React.createElement
local Sparkle = UIConfig.Sparkle

return function(props: any)
	local scaleRef = React.useRef(nil)
	local period = props.period or Sparkle.GlowPeriod
	useBreathe(scaleRef, props.scale or Sparkle.GlowScale, period, 0.37, props.active)

	local children: { [string]: any } = {
		Scale = e("UIScale", { ref = scaleRef }),
	}
	for index, transparency in Sparkle.GlowTransparencies do
		children["Glow" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.color or UIConfig.Palette.Sparkle,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 - (index - 1) * 0.08, 1 - (index - 1) * 0.08),
			ZIndex = (props.zIndex or 1) + index,
		}, { Corner = Primitives.corner("Round") })
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(props.size or 100, props.size or 100),
		Visible = props.active ~= false,
		ZIndex = props.zIndex,
	}, children)
end
