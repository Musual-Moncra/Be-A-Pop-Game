--!strict

--[[
	UpgradeWindow
	Grid of colourful upgrade cards: big icon, name, level bar, "current ➜ next" value,
	description and a green price button (grey MAX at max level, greyed out when the
	player cannot afford it). Buying sends Net.PurchaseUpgrade.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, UIConfig, ConfigLookup, Net, Primitives, ChunkyButton, Bar, Inset, Window, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Components = ReplicatedStorage.Modules.UIComponents
local Bar = require(Components.Bar)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Window = require(Components.Window)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Upgrade
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function UpgradeCard(props: any)
	local id = props.id
	local upgrade = ConfigLookup.GetUpgrade(id)
	if upgrade == nil then
		return nil
	end
	local level = props.level
	local maxed = level >= upgrade.MaxLevel
	local current = ConfigLookup.FormatUpgradeValue(id, ConfigLookup.GetUpgradeValue(id, level))
	local valueText = if maxed
		then string.format(Text.UpgradeMaxValue, current)
		else string.format(
			Text.UpgradeArrow,
			current,
			ConfigLookup.FormatUpgradeValue(id, ConfigLookup.GetUpgradeValue(id, level + 1))
		)
	local cost = if maxed then 0 else ConfigLookup.GetUpgradeCost(id, level)

	return e(ChunkyButton, {
		layoutOrder = upgrade.Order,
		swatch = props.swatch,
	}, {
		Padding = Primitives.padding(Gap * 0.75),
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2, Enum.HorizontalAlignment.Center),
		Icon = e(Inset, {
			layoutOrder = 1,
			radius = "Round",
			size = UDim2.fromOffset(Sizes.IconSize, Sizes.IconSize),
		}, {
			Emoji = Primitives.text({
				Stroke = false,
				Text = upgrade.Icon,
				TextSize = Sizes.IconSize * Shape.IconFill,
			}),
		}),
		Name = Primitives.text({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, TextSizes.Large),
			Text = upgrade.DisplayName,
			TextSize = TextSizes.Large,
		}),
		Level = e(Bar, {
			layoutOrder = 3,
			ratio = level / upgrade.MaxLevel,
			size = UDim2.new(1, 0, 0, Sizes.LevelBarHeight + Shape.Stroke * 2),
			swatch = "Gold",
			text = string.format(Text.UpgradeLevel, level, upgrade.MaxLevel),
			textSize = TextSizes.Tiny,
		}),
		Value = Primitives.text({
			Color = Palette.Sparkle,
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, TextSizes.Body),
			Text = valueText,
			TextSize = TextSizes.Body,
		}),
		Description = Primitives.text({
			Font = "Body",
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, TextSizes.Tiny * 2 + Shape.Stroke),
			StrokeSize = Shape.SmallTextStroke,
			Text = upgrade.Description,
			TextSize = TextSizes.Tiny,
			Wrapped = true,
		}),
		Buy = e(ChunkyButton, {
			enabled = not maxed and props.coins >= cost,
			layoutOrder = 6,
			onActivated = function()
				Net.PurchaseUpgrade:Fire(id)
			end,
			size = UDim2.new(1, 0, 0, Sizes.BuyButtonHeight),
			swatch = "Green",
			text = if maxed then Text.Max else string.format(Text.IconLabel, Text.CoinIcon, Format.compact(cost)),
			textSize = TextSizes.Large,
		}),
	})
end

return function(props: any)
	local data = props.data
	local ui = props.ui
	local margin = UIConfig.Layouts[if ui.mobile then "Mobile" else "PC"].WindowMargin
	local width = math.min(Sizes.Width, ui.width - margin * 2)
	local height = math.min(Sizes.Height, ui.height - margin * 2 - UIConfig.Sizes.Window.HeaderHeight / 2)

	local cards = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.new(
				1 / Sizes.Columns,
				-math.ceil(Gap * (Sizes.Columns - 1) / Sizes.Columns) - Shape.Stroke,
				0,
				Sizes.CardHeight
			),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, Shape.ShadowOffset + Shape.Stroke),
			PaddingRight = UDim.new(0, Shape.RimStroke * 3),
			PaddingTop = UDim.new(0, Shape.Stroke),
		}),
	}
	for index, id in ConfigLookup.GetSortedUpgradeIds() do
		cards[id] = e(UpgradeCard, {
			coins = data.Coins,
			id = id,
			level = data.Upgrades[id] or 0,
			swatch = UIConfig.UpgradeSwatches[(index - 1) % #UIConfig.UpgradeSwatches + 1],
		})
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = "Blue",
		title = Text.UpgradesTitle,
		width = width,
	}, {
		Scroll = e("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ScrollBarImageColor3 = Palette.PanelRim,
			ScrollBarThickness = Shape.RimStroke * 2,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 1),
		}, cards),
	})
end
