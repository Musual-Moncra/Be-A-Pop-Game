--!strict

--[[
	Rays
	Rotating cartoon sunburst drawn behind a highlighted button: LobbyUIConfig.Rays.Count
	thin beams through one centre, each fading out towards both ends, spinning forever.
	Built from plain Frames so it needs no image asset.

	Props: size (diameter, design pixels), position, anchorPoint, zIndex
	Dependencies: React, LobbyUIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)

local e = React.createElement
local RaysConfig = LobbyUIConfig.Rays

return function(props: any)
	local spinRef = React.useRef(nil)

	React.useEffect(function()
		local frame = spinRef.current
		if frame == nil then
			return
		end
		local tween = TweenService:Create(
			frame,
			TweenInfo.new(RaysConfig.SpinSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Rotation = 360 }
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, {})

	local beams = {}
	local halfTurn = 180 / RaysConfig.Count
	for index = 1, RaysConfig.Count do
		beams["Beam" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = RaysConfig.Color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = (index - 1) * halfTurn,
			Size = UDim2.new(1, 0, 0, RaysConfig.Thickness),
			ZIndex = props.zIndex,
		}, {
			Fade = e("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, RaysConfig.Transparency),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(props.size, props.size),
		ZIndex = props.zIndex,
		ref = spinRef,
	}, beams)
end
