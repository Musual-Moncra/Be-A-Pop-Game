--!strict

--[[
	GlowRing
	Glowing outline around a claimable thing. It is exactly the size of its parent target and
	draws a soft, light-coloured ring just outside the target's edge (UIStroke), so it never
	spills over neighbouring buttons or out of scrolling lists. The ring colour is the target
	swatch Top lightened toward white, it is rounded like the target and only its transparency
	breathes, on the shared SparkleClock, while it is on screen.

	Props: swatch (UIConfig.Swatches key of the target), color (Color3 override),
		radius (design pixels or "Round"), active (default true), zIndex,
		anchorPoint / position, period (breathe override)
	Dependencies: React, UIConfig, Primitives, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local SparkleClock = require(Components.SparkleClock)

local e = React.createElement
local Sparkle = UIConfig.Sparkle
local TAU = math.pi * 2

return function(props: any)
	local strokeRef = React.useRef(nil)
	local frameRef = React.useRef(nil)
	local active = props.active ~= false
	local period = props.period or Sparkle.GlowPeriod

	React.useEffect(function()
		local stroke = strokeRef.current
		local frame = frameRef.current
		if stroke == nil or frame == nil or not active then
			return
		end
		local disconnect = SparkleClock.Subscribe(function(_dt: number, now: number)
			if SparkleClock.OnScreen(frame) then
				local wave = 0.5 + 0.5 * math.sin(now / period * TAU)
				stroke.Transparency = Sparkle.GlowTransparencyMin
					+ (Sparkle.GlowTransparencyMax - Sparkle.GlowTransparencyMin) * wave
			end
		end)
		return function()
			disconnect()
		end
	end, { active, period } :: { any })

	local base = props.color
	if base == nil then
		base = Primitives.swatch(props.swatch or "Gold").Top
	end
	local color = base:Lerp(Color3.new(1, 1, 1), Sparkle.GlowLighten)

	return e("Frame", {
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Visible = active,
		ZIndex = math.max(0, (props.zIndex or 1) - 1),
		ref = frameRef,
	}, {
		Corner = Primitives.corner(props.radius or UIConfig.Shape.Radius),
		Stroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = color,
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = Sparkle.GlowThickness,
			Transparency = Sparkle.GlowTransparencyMin,
			ref = strokeRef,
		}),
	})
end
