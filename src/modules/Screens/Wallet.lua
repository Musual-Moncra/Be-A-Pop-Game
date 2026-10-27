--!strict

--[[
	Wallet
	Top-left HUD shown in the lobby and during runs: gold level badge with an XP bar,
	then coin and gem pills.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, UIConfig, GameConfig, ConfigLookup, Primitives, ChunkyButton, Bar, Pill, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Components = ReplicatedStorage.Modules.UIComponents
local Bar = require(Components.Bar)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Pill = require(Components.Pill)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Sizes = UIConfig.Sizes.Hud
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

return function(props: any)
	local data = props.data
	local layout = UIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"].Wallet

	local maxed = data.Level >= GameConfig.MaxLevel
	local needed = ConfigLookup.GetLevelXp(data.Level)
	local ratio = if maxed then 1 else data.Xp / math.max(needed, 1)
	local xpText = if maxed
		then Text.MaxLevel
		else string.format(Text.XpFormat, Format.compact(data.Xp), Format.compact(needed))

	local badge = Sizes.BadgeSize
	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = layout.Position,
		Size = UDim2.fromOffset(Sizes.Width, 0),
	}, {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Sizes.Gap),
		Level = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, badge),
		}, {
			XpBar = e(Bar, {
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.new(0, badge / 2, 0.5, badge / 6),
				ratio = ratio,
				size = UDim2.new(1, -badge / 2, 0, Sizes.XpBarHeight),
				swatch = "Green",
				text = xpText,
			}),
			LevelCaption = Primitives.text({
				Position = UDim2.fromOffset(badge + UIConfig.Shape.Radius / 2, 0),
				Size = UDim2.new(1, -badge, 0, badge / 2 - Sizes.XpBarHeight / 4),
				Text = string.format(Text.LevelFormat, data.Level),
				TextSize = TextSizes.Large,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Badge = e(ChunkyButton, {
				round = true,
				size = UDim2.fromOffset(badge, badge),
				swatch = "Gold",
				zIndex = 2,
			}, {
				Star = Primitives.text({
					Stroke = false,
					Text = Text.XpIcon,
					TextSize = badge * UIConfig.Shape.IconFill,
					Transparency = UIConfig.Shape.GlossTransparency,
				}),
				Number = Primitives.text({
					Text = tostring(data.Level),
					ZIndex = 2,
					TextSize = TextSizes.Header,
				}),
			}),
		}),
		Coins = e(Pill, {
			height = Sizes.PillHeight,
			icon = Text.CoinIcon,
			iconSize = Sizes.PillIconSize,
			layoutOrder = 2,
			swatch = "Gold",
			value = Format.compact(data.Coins),
			width = Sizes.Width,
		}),
		Gems = e(Pill, {
			height = Sizes.PillHeight,
			icon = Text.GemIcon,
			iconSize = Sizes.PillIconSize,
			layoutOrder = 3,
			swatch = "Purple",
			value = Format.compact(data.Gems),
			width = Sizes.Width,
		}),
	})
end
