--!strict

--[[
	SegmentedControl
	Equal-width horizontal option buttons with one active segment.
	Props: options ({Id, Label}), selectedId, onSelect, size, anchorPoint,
	position, layoutOrder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Button = require(script.Parent.Button)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local options = props.options or {}
	local count = #options
	local gap = Theme.Spacing.S
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, option in options do
		local selected = option.Id == props.selectedId
		local widthScale = 1 / count
		local widthOffset = -gap * (count - 1) / count
		children[option.Id] = e(Button, {
			backgroundColor = if selected then Theme.Colors.Accent else Theme.Colors.Surface,
			layoutOrder = index,
			onActivated = function()
				if not selected then
					props.onSelect(option.Id)
				end
			end,
			size = UDim2.new(widthScale, widthOffset, 1, 0),
			text = option.Label,
			textColor = if selected then Theme.Colors.AccentText else Theme.Colors.Text,
			textSize = Theme.TextSizes.Body,
		})
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
	}, children)
end
