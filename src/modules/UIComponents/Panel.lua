--!strict

--[[
	Panel
	Flat rounded surface with standard padding and an optional size clamp.
	Props: size, position, anchorPoint, layoutOrder, visible, cornerRadius,
	maxSize, minSize, backgroundColor, backgroundTransparency, padding, scroll,
	footer, footerHeight, footerGap, children. Footer is pinned below content.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local padding = props.padding or Theme.Spacing.L
	local contentClass = if props.scroll then "ScrollingFrame" else "Frame"
	local footerHeight = props.footerHeight or Theme.Sizes.PlayButtonHeight
	local contentProps = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = if props.footer ~= nil
			then UDim2.new(1, 0, 1, -(footerHeight + (props.footerGap or Theme.Spacing.L)))
			else UDim2.fromScale(1, 1),
	}
	if props.scroll then
		contentProps.AutomaticCanvasSize = Enum.AutomaticSize.Y
		contentProps.CanvasSize = UDim2.fromScale(0, 0)
		contentProps.ScrollBarThickness = Theme.Sizes.ScrollBarThickness
		contentProps.ScrollingDirection = Enum.ScrollingDirection.Y
	end

	local children = {
		Corner = e("UICorner", { CornerRadius = props.cornerRadius or Theme.Radii.Large }),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
			PaddingTop = UDim.new(0, padding),
		}),
		Content = e(contentClass, contentProps, props.children),
	}
	if props.footer ~= nil then
		children.Footer = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, footerHeight),
		}, {
			props.footer,
		})
	end

	if props.maxSize ~= nil or props.minSize ~= nil then
		children.Constraint = e("UISizeConstraint", {
			MaxSize = props.maxSize or Vector2.new(math.huge, math.huge),
			MinSize = props.minSize or Vector2.zero,
		})
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.backgroundColor or Theme.Colors.Panel,
		BackgroundTransparency = props.backgroundTransparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		Visible = props.visible ~= false,
		ZIndex = props.zIndex,
	}, children)
end
