--!strict

--[[
	GlowRing
	Soft glow drawn BEHIND a claimable thing. It sizes itself to its parent target (at most
	Sparkle.GlowExtend beyond it on each side), uses the target swatch Top as its colour,
	breathes between Sparkle.GlowTransparencyMin and Max and is rounded like the target.
	Place it before the target at a lower zIndex.

	Props: swatch (UIConfig.Swatches key of the target), color (Color3 override),
		radius (design pixels or "Round"), active (default true), zIndex,
		anchorPoint / position, period / scale (breathe override)
	Dependencies: React, UIConfig, Primitives, SparkleClock, useBreathe
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local SparkleClock = require(Components.SparkleClock)
local useBreathe = require(Components.useBreathe)

local e = React.createElement
local Sparkle = UIConfig.Sparkle

return function(props: any)
	local scaleRef = React.useRef(nil)
	local layer1 = React.useRef(nil)
	local layer2 = React.useRef(nil)
	local layer3 = React.useRef(nil)
	local layers = { layer1, layer2, layer3 }
	local period = props.period or Sparkle.GlowPeriod
	useBreathe(scaleRef, props.scale or Sparkle.GlowScale, period, 0.37, props.active)

	local color = props.color
	if color == nil then
		color = Primitives.swatch(props.swatch or "Gold").Top
	end

	React.useEffect(function()
		local disconnect = SparkleClock.Subscribe(function(_dt: number, now: number)
			local breathe = 0.5 + 0.5 * math.sin(now / period * math.pi * 2 + 0.37 * math.pi * 2)
			for index = 1, Sparkle.GlowLayers do
				local target = layers[index]
				if target ~= nil and target.current ~= nil then
					local transparency = Sparkle.GlowTransparencyMin
						+ (Sparkle.GlowTransparencyMax - Sparkle.GlowTransparencyMin) * breathe
						+ (index - 1) * Sparkle.GlowTransparencyStep
					target.current.BackgroundTransparency = math.clamp(transparency, Sparkle.GlowTransparencyMin, 0.97)
				end
			end
		end)
		return function()
			disconnect()
		end
	end, { period } :: { any })

	local zIndex = math.max(0, (props.zIndex or 1) - 1)
	local extend = Sparkle.GlowExtend
	local children: { [string]: any } = {
		Scale = e("UIScale", { ref = scaleRef }),
	}
	for index = 1, Sparkle.GlowLayers do
		children["Glow" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = Sparkle.GlowTransparencyMin + (index - 1) * Sparkle.GlowTransparencyStep,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 - (index - 1) * 0.06, 1 - (index - 1) * 0.06),
			ZIndex = zIndex,
			ref = layers[index],
		}, { Corner = Primitives.corner(props.radius or UIConfig.Shape.Radius) })
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1 + extend * 2, 1 + extend * 2),
		Visible = props.active ~= false,
		ZIndex = zIndex,
	}, children)
end
