--!strict

--[[
	Card
	Selectable tile for maps and modes. Props: title, subtitle, badge,
	selected, disabled, onActivated, size, layoutOrder, visible.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local disabled = props.disabled == true
	local selected = props.selected == true

	local backgroundColor = Theme.Colors.Surface
	local titleColor = Theme.Colors.Text
	local subtitleColor = Theme.Colors.TextMuted

	if selected then
		backgroundColor = Theme.Colors.Accent
		titleColor = Theme.Colors.AccentText
		subtitleColor = Theme.Colors.AccentText
	elseif disabled then
		backgroundColor = Theme.Colors.Disabled
		titleColor = Theme.Colors.DisabledText
		subtitleColor = Theme.Colors.DisabledText
	end

	local children = {
		Corner = e("UICorner", { CornerRadius = Theme.Radii.Medium }),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, Theme.Spacing.S),
			PaddingLeft = UDim.new(0, Theme.Spacing.M),
			PaddingRight = UDim.new(0, Theme.Spacing.M),
			PaddingTop = UDim.new(0, Theme.Spacing.S),
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			Size = UDim2.new(1, -96, 0, 22),
			Text = props.title or "",
			TextColor3 = titleColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, {
			TextBound = e("UITextSizeConstraint", {
				MaxTextSize = Theme.TextSizes.CardTitle,
				MinTextSize = Theme.TextBounds.Min,
			}),
		}),
		Subtitle = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Regular,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -96, 0, 18),
			Text = props.subtitle or "",
			TextColor3 = subtitleColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, {
			TextBound = e("UITextSizeConstraint", {
				MaxTextSize = Theme.TextSizes.CardBody,
				MinTextSize = Theme.TextBounds.Min,
			}),
		}),
	}

	if props.badge ~= nil then
		children.Badge = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(88, 18),
			Text = props.badge,
			TextColor3 = if selected then Theme.Colors.AccentText else Theme.Colors.TextMuted,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, {
			TextBound = e("UITextSizeConstraint", {
				MaxTextSize = Theme.TextSizes.Badge,
				MinTextSize = Theme.TextBounds.Min,
			}),
		})
	end

	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		Interactable = not disabled,
		LayoutOrder = props.layoutOrder,
		Size = props.size,
		Text = "",
		Visible = props.visible ~= false,
		[ReactRoblox.Event.Activated] = if disabled then nil else props.onActivated,
	}, children)
end
