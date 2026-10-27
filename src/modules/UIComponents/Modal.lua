--!strict

--[[
	Modal
	Full-screen dimmer with a centered Panel card and optional body slots.
	Props: visible, title, body (array of elements), anchorPoint, position,
	size, maxSize, minSize, onDismiss.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Panel = require(script.Parent.Panel)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local body = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Theme.Spacing.S),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for _, child in props.body or {} do
		table.insert(body, child)
	end

	local card = e(Panel, {
		anchorPoint = props.anchorPoint,
		maxSize = props.maxSize,
		minSize = props.minSize,
		position = props.position,
		size = props.size,
	}, {
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			Size = UDim2.new(1, 0, 0, Theme.Sizes.TitleHeight),
			Text = props.title or "",
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.TextSizes.Header,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Body = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, Theme.Sizes.TitleHeight + Theme.Spacing.M),
			Size = UDim2.new(1, 0, 1, -(Theme.Sizes.TitleHeight + Theme.Spacing.M)),
		}, body),
	})

	return e("Frame", {
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = props.visible == true,
		ZIndex = 10,
	}, {
		Blocker = e("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			[ReactRoblox.Event.Activated] = props.onDismiss,
		}),
		Card = card,
	})
end
