--!strict

--[[
	Pill
	Currency / stat pill: dark rounded well with a coloured rim and a big round icon
	that overlaps its left edge, value text on the right (like a coin or gem counter).

	Props: icon (emoji), value (text), swatch (UIConfig.Swatches key for rim and icon),
	       width, height, iconSize, textSize, position, anchorPoint, layoutOrder

	Dependencies: React, UIConfig, Primitives, ChunkyButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape

return function(props: any)
	local swatch = Primitives.swatch(props.swatch)
	local height = props.height
	local iconSize = props.iconSize
	local iconInset = iconSize / 2
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = UDim2.fromOffset(props.width, math.max(height, iconSize)),
	}, {
		Well = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Palette.Text,
			BorderSizePixel = 0,
			Position = UDim2.new(0, iconInset, 0.5, 0),
			Size = UDim2.new(1, -iconInset, 0, height),
			ZIndex = 1,
		}, {
			Corner = Primitives.corner("Round"),
			Gradient = Primitives.gradient(Palette.PanelTop, Palette.PanelBottom),
			Stroke = Primitives.stroke(swatch.Bottom, Shape.RimStroke),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, iconInset + Shape.Radius / 2),
				PaddingRight = UDim.new(0, Shape.Radius),
			}),
			Value = Primitives.text({
				Text = props.value,
				TextSize = props.textSize or UIConfig.TextSizes.Header,
			}),
		}),
		Icon = e(ChunkyButton, {
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.fromScale(0, 0.5),
			round = true,
			size = UDim2.fromOffset(iconSize, iconSize),
			swatch = props.swatch,
			icon = props.icon,
			iconSize = iconSize * Shape.IconFill,
			zIndex = 2,
		}),
	})
end
