--!strict

--[[
	UpgradeWindow
	Grid of colourful upgrade cards: big icon, name, level bar, "current ➜ next" value,
	description and a green price button (grey MAX at max level, greyed out when the
	player cannot afford it). Buying sends Net.PurchaseUpgrade.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, UIConfig, ConfigLookup, Net, Primitives, ChunkyButton, Bar, Inset, Window, WindowSize, Format
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
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Upgrade
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local descriptionHeight = math.ceil(TextSizes.Small * Sizes.DescriptionLines * Shape.LineHeight)
local barHeight = Sizes.LevelBarHeight + Shape.Stroke * 2
local cardPadding = Gap * 0.75
local cardHeight = cardPadding * 2
	+ Sizes.IconSize
	+ TextSizes.Large
	+ barHeight
	+ TextSizes.Body
	+ descriptionHeight
	+ Sizes.BuyButtonHeight
	+ (Gap / 2) * 5
	+ Shape.Lip

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
		Padding = Primitives.padding(cardPadding),
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
			Fit = true,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, TextSizes.Large),
			Text = upgrade.DisplayName,
			TextSize = TextSizes.Large,
		}),
		Level = e(Bar, {
			layoutOrder = 3,
			ratio = level / upgrade.MaxLevel,
			size = UDim2.new(1, 0, 0, barHeight),
			swatch = "Gold",
			text = string.format(Text.UpgradeLevel, level, upgrade.MaxLevel),
			textSize = TextSizes.Tiny,
		}),
		Value = Primitives.text({
			Color = Palette.Sparkle,
			Fit = true,
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, TextSizes.Body),
			Text = valueText,
			TextSize = TextSizes.Body,
		}),
		Description = Primitives.text({
			Fit = true,
			Font = "Body",
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, descriptionHeight),
			StrokeSize = Shape.SmallTextStroke,
			Text = upgrade.Description,
			TextSize = TextSizes.Small,
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
	local width, height = WindowSize.fit(ui, Sizes.Width, Sizes.Height)
	local gridWidth = width - UIConfig.Sizes.Window.Padding * 2 - Shape.ScrollBar - Shape.RimStroke * 2
	local columns = math.clamp(math.floor((gridWidth + Gap) / (Sizes.MinCardWidth + Gap)), 1, Sizes.Columns)
	local cardWidth = math.floor((gridWidth - Gap * (columns - 1)) / columns)
	local ids = ConfigLookup.GetSortedUpgradeIds()
	local rows = math.ceil(#ids / columns)
	height = math.min(height, rows * cardHeight + (rows - 1) * Gap + Shape.ShadowOffset * 2 + WindowSize.chrome())

	local cards = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.fromOffset(cardWidth, cardHeight),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, Shape.ShadowOffset + Shape.Stroke),
			PaddingLeft = UDim.new(0, Shape.RimStroke),
			PaddingRight = UDim.new(0, Shape.RimStroke),
			PaddingTop = UDim.new(0, Shape.Stroke),
		}),
	}
	for index, id in ids do
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
		Scroll = Primitives.scroll({}, cards),
	})
end
