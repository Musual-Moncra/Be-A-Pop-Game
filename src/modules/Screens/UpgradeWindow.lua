--!strict

--[[
	UpgradeWindow
	One row per upgrade: icon tile, name and level, a row of pips that fills with progress,
	the current and next stat value, and a BUY button with the coin price. A row the player
	cannot afford turns its price button red (not clickable); a maxed row shows a gold MAX
	stamp. Buying sends Net.PurchaseUpgrade.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, UIConfig, LobbyUIConfig, ConfigLookup, Net, Format, Primitives,
		ChunkyButton, Inset, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Components = ReplicatedStorage.Modules.UIComponents
local Burst = require(Components.Burst)
local ChunkyButton = require(Components.ChunkyButton)
local GlowRing = require(Components.GlowRing)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local useBreathe = require(Components.useBreathe)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Upgrade = LobbyUIConfig.Upgrade
local Motion = LobbyUIConfig.Motion
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function pips(level: number, maxLevel: number, swatch: any): { [string]: any }
	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Horizontal, Upgrade.PipGap, nil, Enum.VerticalAlignment.Center),
	}
	for index = 1, maxLevel do
		local filled = index <= level
		children["Pip" .. index] = e("Frame", {
			BackgroundColor3 = if filled then swatch.Top else Palette.Inset,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(Upgrade.PipWidth, Upgrade.PipHeight),
		}, {
			Corner = Primitives.corner(Upgrade.PipRadius),
			Gradient = if filled then Primitives.gradient(swatch.Top, swatch.Bottom) else nil,
			Stroke = if filled then nil else Primitives.stroke(Palette.InsetStroke, Shape.Stroke),
		})
	end
	return children
end

local function PopInRow(props: any)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		local animation = UIConfig.Animation
		local delay = (props.order or 1) * animation.CardStagger
		scale.Scale = animation.PopInStart
		TweenService:Create(
			scale,
			TweenInfo.new(animation.PopInTime * 0.35, animation.SpringStyle, animation.SpringDirection, 0, false, delay),
			{ Scale = animation.PopInOver }
		):Play()
		TweenService:Create(
			scale,
			TweenInfo.new(
				animation.PopInTime * 0.25,
				animation.SmoothStyle,
				animation.SmoothDirection,
				0,
				false,
				delay + animation.PopInTime * 0.35
			),
			{ Scale = animation.PopInUnder }
		):Play()
		TweenService:Create(
			scale,
			TweenInfo.new(
				animation.PopInTime * 0.4,
				animation.SpringStyle,
				animation.SpringDirection,
				0,
				false,
				delay + animation.PopInTime * 0.6
			),
			{ Scale = 1 }
		):Play()
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
		Size = UDim2.new(1, 0, 0, Upgrade.RowHeight),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Row = props.row,
	})
end

local function BreatheBuy(props: any)
	local scaleRef = React.useRef(nil)
	useBreathe(scaleRef, Motion.BreatheButtonScale, Motion.BreatheButtonPeriod, (props.order or 1) * 0.17, props.active)

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -Upgrade.RowPadding, 0.5, 0),
		Size = UDim2.fromOffset(Upgrade.BuyWidth, Upgrade.BuyHeight),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Glow = if props.active
			then e(GlowRing, {
				color = Primitives.swatch("Gold").Top,
				size = Upgrade.BuyWidth * Motion.GlowSizeRatio,
				zIndex = 1,
			})
			else nil,
		Button = e(ChunkyButton, {
			onActivated = if props.active
				then function()
					Net.PurchaseUpgrade:Fire(props.id)
				end
				else nil,
			shine = props.active,
			size = UDim2.fromScale(1, 1),
			swatch = if props.active then "Green" else "Red",
			text = string.format(Text.IconLabel, Text.CoinIcon, Format.compact(props.cost)),
			textSize = TextSizes.Large,
			zIndex = 3,
		}),
	})
end

local function UpgradeRow(props: any)
	local upgrade = ConfigLookup.GetUpgrade(props.id)
	if upgrade == nil then
		return nil
	end

	local level = props.level
	local maxed = level >= upgrade.MaxLevel
	local current = ConfigLookup.FormatUpgradeValue(props.id, ConfigLookup.GetUpgradeValue(props.id, level))
	local valueText = if maxed
		then string.format(Text.UpgradeMaxValue, current)
		else string.format(
			Text.UpgradeArrow,
			current,
			ConfigLookup.FormatUpgradeValue(props.id, ConfigLookup.GetUpgradeValue(props.id, level + 1))
		)
	local cost = if maxed then 0 else ConfigLookup.GetUpgradeCost(props.id, level)
	local canAfford = props.coins >= cost
	local swatchName = props.swatch
	local swatch = Primitives.swatch(swatchName)

	local left = Upgrade.RowPadding + Upgrade.IconSize + Upgrade.RowPadding
	local right = Upgrade.RowPadding + Upgrade.BuyWidth + Upgrade.RowPadding

	local buy = if maxed
		then e(ChunkyButton, {
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -Upgrade.RowPadding, 0.5, 0),
			size = UDim2.fromOffset(Upgrade.MaxStampWidth, Upgrade.BuyHeight),
			swatch = "Gold",
			text = Text.Max,
			textSize = TextSizes.Header,
		})
		else e(BreatheBuy, {
			active = canAfford,
			cost = cost,
			id = props.id,
			order = props.order,
		})

	return e(Inset, {
		radius = Shape.Radius,
		size = UDim2.fromScale(1, 1),
	}, {
		Icon = e(ChunkyButton, {
			position = UDim2.fromOffset(Upgrade.RowPadding, math.floor((Upgrade.RowHeight - Upgrade.IconSize) / 2)),
			radius = Shape.Radius,
			size = UDim2.fromOffset(Upgrade.IconSize, Upgrade.IconSize),
			swatch = swatchName,
			zIndex = 3,
		}, {
			Icon = Primitives.text({
				Stroke = false,
				Text = upgrade.Icon,
				TextSize = Upgrade.IconSize * Shape.IconFill,
			}),
		}),
		Title = Primitives.text({
			Color = Palette.Text,
			Fit = true,
			Position = UDim2.fromOffset(left, 10),
			Size = UDim2.new(1, -(left + right), 0, TextSizes.Header),
			Text = upgrade.DisplayName,
			TextSize = TextSizes.Header,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Level = Primitives.text({
			Color = Palette.Text,
			Position = UDim2.fromOffset(left, 40),
			Size = UDim2.fromOffset(96, Upgrade.LevelTextSize + 4),
			StrokeSize = Shape.SmallTextStroke,
			Text = string.format(Upgrade.LevelFormat, level, upgrade.MaxLevel),
			TextSize = Upgrade.LevelTextSize,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Pips = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(left + 104, 40),
			Size = UDim2.new(1, -(left + right + 104), 0, Upgrade.PipHeight),
		}, pips(level, upgrade.MaxLevel, swatch)),
		Value = Primitives.text({
			Color = Palette.Sparkle,
			Fit = true,
			Position = UDim2.fromOffset(left, 62),
			Size = UDim2.new(1, -(left + right), 0, TextSizes.Body),
			Text = valueText,
			TextSize = TextSizes.Body,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Buy = buy,
	})
end

return function(props: any)
	local data = props.data
	local ui = props.ui
	local width, height = WindowSize.fit(ui, Upgrade.Width, Upgrade.Height)
	local ids = ConfigLookup.GetSortedUpgradeIds()
	local burst, setBurst = React.useState(0)
	local previousLevels = React.useRef(nil)

	React.useEffect(function()
		local total = 0
		for _, level in data.Upgrades do
			total += level
		end
		local previous = previousLevels.current
		if previous ~= nil and total > previous then
			setBurst(function(count: number)
				return count + 1
			end)
		end
		previousLevels.current = total
	end, { data.Upgrades } :: { any })

	local rows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Upgrade.RowGap),
		Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke),
	}
	for index, id in ids do
		rows[id] = e(PopInRow, {
			order = index,
			row = e(UpgradeRow, {
				coins = data.Coins,
				id = id,
				level = data.Upgrades[id] or 0,
				order = index,
				swatch = UIConfig.UpgradeSwatches[(index - 1) % #UIConfig.UpgradeSwatches + 1],
			}),
		})
	end

	return e(Window, {
		height = height,
		icon = Upgrade.Icon,
		onClose = props.onClose,
		swatch = Upgrade.Swatch,
		title = Upgrade.Title,
		width = width,
	}, {
		Rows = Primitives.scroll({ Size = UDim2.fromScale(1, 1) }, rows),
		Burst = e(Burst, {
			origin = UDim2.fromScale(0.5, 0.5),
			trigger = if burst > 0 then burst else nil,
			zIndex = 20,
		}),
	})
end
