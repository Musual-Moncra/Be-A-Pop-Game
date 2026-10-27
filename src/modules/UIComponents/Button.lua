--!strict

--[[
	Button
	Flat text button with Primary/Secondary variants, disabled state and
	pixel-capped scaled text. Props: text, onActivated, enabled, variant,
	size, position, anchorPoint, layoutOrder, visible, textSize.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local enabled = props.enabled ~= false
	local secondary = props.variant == "Secondary"

	local backgroundColor = props.backgroundColor or (if secondary then Theme.Colors.Surface else Theme.Colors.Accent)
	local textColor = props.textColor or (if secondary then Theme.Colors.Text else Theme.Colors.AccentText)
	if not enabled then
		backgroundColor = Theme.Colors.Disabled
		textColor = Theme.Colors.DisabledText
	end

	return e("TextButton", {
		AnchorPoint = props.anchorPoint,
		AutoButtonColor = false,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = props.backgroundTransparency or 0,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Bold,
		Interactable = enabled,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		Text = props.text or "",
		TextColor3 = textColor,
		TextScaled = true,
		Visible = props.visible ~= false,
		[ReactRoblox.Event.Activated] = props.onActivated,
	}, {
		Corner = e("UICorner", { CornerRadius = props.cornerRadius or Theme.Radii.Medium }),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, Theme.Spacing.XS),
			PaddingLeft = UDim.new(0, Theme.Spacing.S),
			PaddingRight = UDim.new(0, Theme.Spacing.S),
			PaddingTop = UDim.new(0, Theme.Spacing.XS),
		}),
		TextBound = e("UITextSizeConstraint", {
			MaxTextSize = props.textSize or Theme.TextSizes.Button,
			MinTextSize = Theme.TextBounds.Min,
		}),
	})
end
