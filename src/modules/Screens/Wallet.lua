--!strict

--[[
	Wallet
	Centred lobby top bar: a level badge with a radial XP ring, glossy coin and gem pills with
	a green plus that opens the shop, and the Stink chip. Hidden during runs by App.

	Props: data (DataController state), ui (useUIScale result), covered (a window/overlay hides it)
	Dependencies: React, UIConfig, UIConfig.Sparkle, GameConfig, ConfigLookup, LobbyState, PetView,
		Primitives, ChunkyButton, CountUp, Pill
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local CountUp = require(Components.CountUp)
local Pill = require(Components.Pill)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Hud = UIConfig.Sizes.Hud
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes
local Routes = LobbyState.Routes

local TAU = math.pi * 2

local function LevelBadge(props: any)
	local ratio = math.clamp(props.ratio, 0, 1)
	local ringSize = props.ringSize
	local thickness = props.thickness
	local radius = ringSize / 2 - thickness / 2
	local segments = Hud.XpRingSegments
	local fill = Primitives.swatch("Green")
	local children: { [string]: any } = {}
	for index = 1, segments do
		local angle = (index - 1) / segments * TAU
		local filled = (index - 1) / segments < ratio
		children["Segment" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if filled then fill.Mid else Palette.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius),
			Rotation = math.deg(angle) + 90,
			Size = UDim2.fromOffset(thickness, thickness * 1.5),
			ZIndex = 1,
		}, { Corner = Primitives.corner("Round") })
	end
	children.Badge = e(ChunkyButton, {
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		round = true,
		size = UDim2.fromOffset(props.badgeSize, props.badgeSize),
		swatch = "Gold",
		zIndex = 2,
	}, {
		Star = Primitives.text({
			Stroke = false,
			Text = Text.XpIcon,
			TextSize = props.badgeSize * Shape.IconFill,
			Transparency = Shape.BadgeStarTransparency,
		}),
		Number = Primitives.text({
			Text = tostring(props.level),
			TextSize = TextSizes.Header,
			ZIndex = 2,
		}),
	})
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(ringSize, ringSize),
	}, children)
end

return function(props: any)
	local data = props.data
	local mobile = props.ui.mobile
	local layout = UIConfig.Layouts[if mobile then "Mobile" else "PC"].Wallet

	local maxed = data.Level >= GameConfig.MaxLevel
	local needed = ConfigLookup.GetLevelXp(data.Level)
	local ratio = if maxed then 1 else data.Xp / math.max(needed, 1)

	local badgeSize = if mobile then Hud.MobileBadgeSize else Hud.BadgeSize
	local ringSize = if mobile then Hud.MobileRingSize else Hud.XpRingSize
	local ringThickness = if mobile then Hud.MobileRingThickness else Hud.XpRingThickness
	local pillWidth = if mobile then Hud.MobilePillWidth else Hud.PillWidth
	local pillHeight = if mobile then Hud.MobilePillHeight else Hud.PillHeight
	local pillIcon = if mobile then Hud.MobilePillIconSize else Hud.PillIconSize
	local stinkWidth = if mobile then Hud.MobileStinkWidth else Hud.StinkWidth
	local stinkHeight = if mobile then Hud.MobileStinkHeight else Hud.StinkHeight
	local stinkIcon = if mobile then Hud.MobileStinkIconSize else Hud.StinkIconSize
	local plusSize = if mobile then Hud.MobilePlusSize else Hud.PlusSize
	local gap = if mobile then Hud.MobileGap else Hud.Gap

	local twinkleActive = props.covered ~= true

	local function openShop(tab: string)
		LobbyState.SetActive(Routes.Shop, tab)
	end

	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Position = layout.Position,
	}, {
		Layout = Primitives.list(
			Enum.FillDirection.Horizontal,
			gap,
			Enum.HorizontalAlignment.Center,
			Enum.VerticalAlignment.Center
		),
		Level = LevelBadge({
			badgeSize = badgeSize,
			layoutOrder = 1,
			level = data.Level,
			ratio = ratio,
			ringSize = ringSize,
			thickness = ringThickness,
		}),
		Coins = e(Pill, {
			height = pillHeight,
			icon = Text.CoinIcon,
			iconSize = pillIcon,
			layoutOrder = 2,
			onPlus = function()
				openShop("Coins")
			end,
			plusSize = plusSize,
			shine = true,
			swatch = "Gold",
			twinkle = true,
			twinkleActive = twinkleActive,
			valueElement = e(CountUp, {
				compact = true,
				color = Palette.Text,
				flashColor = Palette.CoinFlash,
				size = UDim2.fromScale(1, 1),
				textSize = TextSizes.Header,
				value = data.Coins,
			}),
			width = pillWidth,
		}),
		Gems = e(Pill, {
			height = pillHeight,
			icon = Text.GemIcon,
			iconSize = pillIcon,
			layoutOrder = 3,
			onPlus = function()
				openShop("Gems")
			end,
			plusSize = plusSize,
			shine = true,
			swatch = "Purple",
			twinkle = true,
			twinkleActive = twinkleActive,
			valueElement = e(CountUp, {
				compact = true,
				color = Palette.Text,
				flashColor = Palette.GemFlash,
				size = UDim2.fromScale(1, 1),
				textSize = TextSizes.Header,
				value = data.Gems,
			}),
			width = pillWidth,
		}),
		Stink = e(Pill, {
			height = stinkHeight,
			icon = Text.StinkIcon,
			iconSize = stinkIcon,
			layoutOrder = 4,
			shine = true,
			swatch = Hud.StinkSwatch,
			textSize = TextSizes.Header,
			twinkle = true,
			twinkleActive = twinkleActive,
			value = string.format(Text.StinkChipFormat, PetView.TotalStink(data)),
			width = stinkWidth,
		}),
	})
end
