--!strict

--[[
	StatsWindow
	Lifetime stats from the save file, one recessed row per UIConfig.Text.StatRows entry
	(icon, label, value).

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, UIConfig, Primitives, Inset, Window, WindowSize, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Palette = UIConfig.Palette
local Sizes = UIConfig.Sizes.Stats
local Gap = UIConfig.Sizes.Window.Gap
local TextSizes = UIConfig.TextSizes

return function(props: any)
	local ui = props.ui
	local width, height = WindowSize.fit(ui, Sizes.Width, Sizes.Height)

	local rows = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
	}
	for index, row in UIConfig.Text.StatRows do
		local value = props.data.Stats[row.Key] or 0
		rows[row.Key] = e(Inset, {
			layoutOrder = index,
			size = UDim2.new(1, 0, 0, Sizes.RowHeight),
		}, {
			Padding = Primitives.paddingXY(Gap, 0),
			Icon = Primitives.text({
				Size = UDim2.new(0, Sizes.RowHeight, 1, 0),
				Stroke = false,
				Text = row.Icon,
				TextSize = TextSizes.Icon,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Label = Primitives.text({
				Position = UDim2.fromOffset(Sizes.RowHeight, 0),
				Size = UDim2.new(0.6, -Sizes.RowHeight, 1, 0),
				Text = row.Label,
				TextSize = TextSizes.Body,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Value = Primitives.text({
				AnchorPoint = Vector2.new(1, 0),
				Color = Palette.Sparkle,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.4, 1),
				Text = Format.commas(value),
				TextSize = TextSizes.Large,
				XAlign = Enum.TextXAlignment.Right,
			}),
		})
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = "Purple",
		title = UIConfig.Text.StatsTitle,
		width = width,
	}, {
		Scroll = Primitives.scroll({}, rows),
	})
end
