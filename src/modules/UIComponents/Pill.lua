--!strict

--[[
	Pill
	Glossy stat pill: light candy panel with an Ink rim, a big round icon overlapping its left
	edge, the value on the right and an optional green plus button for opening a shop.

	Props: icon (emoji), value (text), swatch (UIConfig.Swatches key for the icon),
	       width, height, iconSize, textSize, position, anchorPoint, layoutOrder,
	       onPlus (optional callback, draws the plus), plusSize (design pixels)
	Dependencies: React, UIConfig, Primitives, ChunkyButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Text = UIConfig.Text

return function(props: any)
	local height = props.height
	local iconSize = props.iconSize
	local iconInset = iconSize / 2
	local plusSize = if props.onPlus ~= nil then (props.plusSize or 40) else 0
	local rightInset = if plusSize > 0 then plusSize + Shape.Radius else Shape.Radius

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = UDim2.fromOffset(props.width, math.max(height, iconSize)),
	}, {
		Well = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Palette.PanelTop,
			BorderSizePixel = 0,
			Position = UDim2.new(0, iconInset, 0.5, 0),
			Size = UDim2.new(1, -iconInset, 0, height),
			ZIndex = 1,
		}, {
			Corner = Primitives.corner("Round"),
			Gradient = Primitives.gradient(Palette.PanelTop, Palette.PanelBottom),
			Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
			Gloss = e("Frame", {
				BackgroundColor3 = Palette.Text,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(Shape.GlossInset, Shape.GlossInset),
				Size = UDim2.new(1, -Shape.GlossInset * 2, Shape.GlossHeightRatio, -Shape.GlossInset),
				ZIndex = 2,
			}, {
				Corner = Primitives.corner("Round"),
				Fade = e("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, Shape.GlossTransparency),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, iconInset + Shape.Radius / 2),
				PaddingRight = UDim.new(0, rightInset),
			}),
			Value = Primitives.text({
				Text = props.value,
				TextSize = props.textSize or UIConfig.TextSizes.Header,
				ZIndex = 3,
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
			zIndex = 4,
		}),
		Plus = if plusSize > 0
			then e(ChunkyButton, {
				anchorPoint = Vector2.new(1, 0.5),
				onActivated = props.onPlus,
				position = UDim2.new(1, 0, 0.5, 0),
				round = true,
				size = UDim2.fromOffset(plusSize, plusSize),
				swatch = "Green",
				text = Text.PlusIcon,
				textSize = UIConfig.TextSizes.Header,
				zIndex = 5,
			})
			else nil,
	})
end
