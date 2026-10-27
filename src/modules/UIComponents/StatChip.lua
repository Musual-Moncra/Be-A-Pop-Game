--!strict

--[[
	StatChip
	Compact surface with a muted caption and a bold value. Props: label,
	value, size, position, anchorPoint, layoutOrder, visible, minSize,
	maxSize, valueColor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.Radii.Medium }),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.Spacing.M),
			PaddingRight = UDim.new(0, Theme.Spacing.M),
			PaddingTop = UDim.new(0, Theme.Spacing.S),
			PaddingBottom = UDim.new(0, Theme.Spacing.S),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Medium,
			Size = UDim2.fromScale(0.5, 1),
			Text = props.label or "",
			TextColor3 = Theme.Colors.TextMuted,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			TextBound = e("UITextSizeConstraint", {
				MaxTextSize = Theme.TextSizes.ChipLabel,
				MinTextSize = Theme.TextBounds.Min,
			}),
		}),
		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
			Text = tostring(props.value),
			TextColor3 = props.valueColor or Theme.Colors.Text,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, {
			TextBound = e("UITextSizeConstraint", {
				MaxTextSize = Theme.TextSizes.ChipValue,
				MinTextSize = Theme.TextBounds.Min,
			}),
		}),
	}

	if props.maxSize ~= nil or props.minSize ~= nil then
		children.Constraint = e("UISizeConstraint", {
			MaxSize = props.maxSize or Vector2.new(math.huge, math.huge),
			MinSize = props.minSize or Vector2.zero,
		})
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.backgroundColor or Theme.Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		Visible = props.visible ~= false,
	}, children)
end
