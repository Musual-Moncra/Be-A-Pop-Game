--!strict

--[[
	Chip
	Small coloured tag that sizes itself to its text ("SIZE M", "x2 REWARDS", "LVL 5").

	Props: text, swatch (UIConfig.Swatches key), height, textSize, layoutOrder, position, anchorPoint, zIndex

	Dependencies: React, UIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Shape = UIConfig.Shape

return function(props: any)
	local swatch = Primitives.swatch(props.swatch)
	local height = props.height or UIConfig.Sizes.Play.ChipHeight
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UIConfig.Palette.Text,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = UDim2.fromOffset(0, height),
		ZIndex = props.zIndex,
	}, {
		Corner = Primitives.corner("Round"),
		Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
		Stroke = Primitives.stroke(swatch.Stroke, Shape.Stroke),
		Padding = Primitives.paddingXY(height * Shape.ChipPadding, 0),
		Label = Primitives.text({
			AutomaticSize = Enum.AutomaticSize.X,
			NoTruncate = true,
			Size = UDim2.fromScale(0, 1),
			StrokeSize = Shape.SmallTextStroke,
			Text = props.text,
			TextSize = props.textSize or UIConfig.TextSizes.Tiny,
		}),
	})
end
