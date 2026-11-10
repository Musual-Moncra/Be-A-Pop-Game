--!strict

--[[
	GlowRing
	Soft glow drawn BEHIND a claimable thing. It sizes itself to its parent target (at most
	Sparkle.GlowExtend beyond it on each side), uses the target swatch Top as its colour, is
	rounded like the target and fades to its edge with a static gradient. Only its own UIScale
	breathes (no text inside, so it is cheap); place it before the target at a lower zIndex.

	Props: swatch (UIConfig.Swatches key of the target), color (Color3 override),
		radius (design pixels or "Round"), active (default true), zIndex,
		anchorPoint / position, period / scale (breathe override)
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
	useBreathe(scaleRef, props.scale or Sparkle.GlowScale, props.period or Sparkle.GlowPeriod, 0.37, props.active)

	local color = props.color
	if color == nil then
		color = Primitives.swatch(props.swatch or "Gold").Top
	end
	local zIndex = math.max(0, (props.zIndex or 1) - 1)
	local extend = Sparkle.GlowExtend

	return e("Frame", {
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = Sparkle.GlowTransparencyMin,
		BorderSizePixel = 0,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1 + extend * 2, 1 + extend * 2),
		Visible = props.active ~= false,
		ZIndex = zIndex,
	}, {
		Corner = Primitives.corner(props.radius or UIConfig.Shape.Radius),
		Scale = e("UIScale", { ref = scaleRef }),
		Fade = e("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, Sparkle.GlowTransparencyMax),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, Sparkle.GlowTransparencyMax),
			}),
		}),
	})
end
