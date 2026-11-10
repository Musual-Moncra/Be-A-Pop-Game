--!strict

--[[
	ShineSweep
	White diagonal bar that sweeps left to right across its parent, clipped to the parent box.
	Used on primary buttons and tiles to make them feel glossy and alive. Every sweep runs on the
	shared SparkleClock (no thread or tween per button); the bar stays hidden between sweeps and
	nothing is written while the parent is hidden or off-screen.

	Props: radius (design pixels or "Round"), zIndex, transparency (0 to 1), active (default true),
		interval (seconds between sweeps), delay (seconds before the first sweep)
	Dependencies: React, UIConfig, Primitives, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local SparkleClock = require(Components.SparkleClock)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette

local START = -0.35
local FINISH = 1.35

return function(props: any)
	local barRef = React.useRef(nil)
	local clipRef = React.useRef(nil)

	React.useEffect(function()
		local bar = barRef.current
		local clip = clipRef.current
		if bar == nil or clip == nil or props.active == false then
			return
		end
		local interval = math.max(props.interval or Animation.ShineInterval, Animation.ShineSeconds)
		local startAt = SparkleClock.Now() + (props.delay or 0)
		local sweeping = false
		local disconnect = SparkleClock.Subscribe(function(_dt: number, now: number)
			local since = now - startAt
			local progress = if since >= 0 then (since % interval) / Animation.ShineSeconds else 2
			if progress < 1 and SparkleClock.OnScreen(clip) then
				sweeping = true
				bar.Visible = true
				bar.Position = UDim2.fromScale(START + (FINISH - START) * progress, 0.5)
			elseif sweeping then
				sweeping = false
				bar.Visible = false
			end
		end)
		return function()
			disconnect()
		end
	end, { props.active, props.interval, props.delay } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex,
		ref = clipRef,
	}, {
		Corner = Primitives.corner(props.radius or UIConfig.Shape.Radius),
		Bar = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.Text,
			BackgroundTransparency = props.transparency or Animation.ShineTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(START, 0.5),
			Rotation = Animation.ShineRotation,
			Size = UDim2.new(Animation.ShineWidthRatio, 0, 2, 0),
			Visible = false,
			ref = barRef,
			ZIndex = props.zIndex,
		}, {
			Fade = e("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, props.transparency or Animation.ShineTransparency),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
	})
end
