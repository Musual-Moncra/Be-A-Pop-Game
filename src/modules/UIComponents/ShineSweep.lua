--!strict

--[[
	ShineSweep
	White diagonal bar that sweeps left to right across its parent, clipped to the parent box.
	Used on primary buttons (PLAY, BUY, COLLECT, CLAIM) to make them feel glossy and alive.

	Props: radius (design pixels or "Round"), zIndex, transparency (0 to 1), active (default true)
	Dependencies: React, TweenService, UIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette

return function(props: any)
	local barRef = React.useRef(nil)

	React.useEffect(function()
		if props.active == false then
			return
		end
		local bar = barRef.current
		if bar == nil then
			return
		end
		local running = true
		task.spawn(function()
			while running do
				bar.Position = UDim2.fromScale(-0.35, 0.5)
				task.wait(math.max(0, Animation.ShineInterval - Animation.ShineSeconds))
				if not running then
					break
				end
				TweenService:Create(bar, TweenInfo.new(Animation.ShineSeconds, Enum.EasingStyle.Linear), {
					Position = UDim2.fromScale(1.35, 0.5),
				}):Play()
				task.wait(Animation.ShineSeconds)
			end
		end)
		return function()
			running = false
		end
	end, { props.active })

	return e("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex,
	}, {
		Corner = Primitives.corner(props.radius or UIConfig.Shape.Radius),
		Bar = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.Text,
			BackgroundTransparency = props.transparency or Animation.ShineTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(-0.35, 0.5),
			Rotation = Animation.ShineRotation,
			Size = UDim2.new(Animation.ShineWidthRatio, 0, 2, 0),
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
