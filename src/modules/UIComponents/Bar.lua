--!strict

--[[
	Bar
	Chunky progress bar: recessed track, glossy gradient fill that tweens to its new
	value, and an outlined label drawn on top.

	Props: ratio (0 to 1), swatch (UIConfig.Swatches key), text, textSize,
	       size, position, anchorPoint, layoutOrder, zIndex

	Dependencies: React, UIConfig, Primitives, Inset
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Inset = require(ReplicatedStorage.Modules.UIComponents.Inset)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape

return function(props: any)
	local ratio = math.clamp(props.ratio or 0, 0, 1)
	local swatch = Primitives.swatch(props.swatch)
	local fillRef = React.useRef(nil)

	React.useEffect(function()
		local fill = fillRef.current
		if fill == nil then
			return
		end
		TweenService
			:Create(fill, TweenInfo.new(Animation.BarTween, Animation.SmoothStyle, Animation.SmoothDirection), {
				Size = UDim2.fromScale(ratio, 1),
			})
			:Play()
	end, { ratio })

	return e(Inset, {
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		position = props.position,
		radius = "Round",
		size = props.size,
		zIndex = props.zIndex,
	}, {
		Fill = e("Frame", {
			BackgroundColor3 = Palette.Text,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(ratio, 1),
			Visible = ratio > 0,
			ref = fillRef,
		}, {
			Corner = Primitives.corner("Round"),
			Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
			Gloss = e("Frame", {
				BackgroundColor3 = Palette.Text,
				BackgroundTransparency = Shape.GlossTransparency,
				BorderSizePixel = 0,
				Position = UDim2.new(0, Shape.Stroke * 2, 0, Shape.Stroke),
				Size = UDim2.new(1, -Shape.Stroke * 4, Shape.GlossHeight, 0),
			}, {
				Corner = Primitives.corner("Round"),
			}),
		}),
		Label = if props.text ~= nil
			then Primitives.text({
				StrokeSize = Shape.SmallTextStroke,
				Text = props.text,
				TextSize = props.textSize or UIConfig.TextSizes.Small,
				ZIndex = 2,
			})
			else nil,
	})
end
