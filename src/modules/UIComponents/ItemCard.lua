--!strict

--[[
	ItemCard
	Chunky collectible card for shop, pet and skin grids: coloured block with a rarity strip,
	big emoji icon, title, a short info line, an optional corner tag and an action button at
	the bottom. Sized by its grid cell (fills its parent).

	Props:
		icon, title, info (text), tag (corner text, optional)
		swatch: card colour (UIConfig.Swatches key)
		rarityColor: colour of the strip under the icon (Color3, optional)
		iconColor: tint behind the icon (Color3, optional)
		buttonText, buttonSwatch, buttonEnabled (default true), onButton (nil hides the button)
		selected: true draws a sparkle ring around the card
		layoutOrder
	Dependencies: React, UIConfig, LobbyUIConfig, Primitives, ChunkyButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Card = LobbyUIConfig.Card
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local TextSizes = UIConfig.TextSizes

return function(props: any)
	local hasButton = props.onButton ~= nil
	local bottomInset = if hasButton then Card.ButtonHeight + Shape.ContentPadding else 0

	local face: { [string]: any } = {
		IconWell = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = props.iconColor or Palette.Inset,
			BackgroundTransparency = if props.iconColor ~= nil then 0 else Shape.InsetTransparency,
			Position = UDim2.new(0.5, 0, 0, Shape.ContentPadding),
			Size = UDim2.new(0.86, 0, Card.IconRatio, 0),
			ZIndex = 3,
		}, {
			Corner = Primitives.corner(Shape.Radius),
			Stroke = Primitives.stroke(Palette.InsetStroke, Shape.Stroke),
			Icon = Primitives.text({
				Stroke = false,
				Text = props.icon,
				TextSize = TextSizes.BigIcon,
				ZIndex = 4,
			}),
			Rarity = if props.rarityColor ~= nil
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = props.rarityColor,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.new(1, 0, 0, Shape.Lip),
					ZIndex = 4,
				}, { Corner = Primitives.corner(Shape.Lip) })
				else nil,
		}),
		Title = Primitives.text({
			Fit = true,
			Position = UDim2.new(0.05, 0, Card.IconRatio, Shape.ContentPadding * 1.5),
			Size = UDim2.new(0.9, 0, 0, TextSizes.Large),
			Text = props.title,
			TextSize = TextSizes.Large,
			ZIndex = 3,
		}),
		Info = Primitives.text({
			Color = Palette.Text,
			Fit = true,
			Font = "Body",
			Position = UDim2.new(0.05, 0, Card.IconRatio, Shape.ContentPadding * 2 + TextSizes.Large),
			Size = UDim2.new(0.9, 0, 1 - Card.IconRatio, -(bottomInset + Shape.ContentPadding * 3 + TextSizes.Large)),
			StrokeSize = Shape.SmallTextStroke,
			Text = props.info or "",
			TextSize = TextSizes.Small,
			Wrapped = true,
			ZIndex = 3,
		}),
		Tag = if props.tag ~= nil
			then Primitives.text({
				AnchorPoint = Vector2.new(1, 0),
				Color = Palette.Sparkle,
				Position = UDim2.new(1, -Shape.ContentPadding, 0, Shape.ContentPadding),
				Size = UDim2.fromOffset(Card.Width / 3, TextSizes.Body),
				Text = props.tag,
				TextSize = TextSizes.Body,
				XAlign = Enum.TextXAlignment.Right,
				ZIndex = 5,
			})
			else nil,
		Action = if hasButton
			then e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 1),
				enabled = props.buttonEnabled ~= false,
				onActivated = props.onButton,
				position = UDim2.new(0.5, 0, 1, -Shape.ContentPadding),
				size = UDim2.new(0.86, 0, 0, Card.ButtonHeight),
				swatch = props.buttonSwatch or "Green",
				text = props.buttonText,
				textSize = TextSizes.Body,
				zIndex = 4,
			})
			else nil,
	}

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 1),
	}, {
		Card = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = props.swatch,
			zIndex = 2,
			overlay = if props.selected
				then e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Palette.Sparkle,
					Thickness = Shape.RimStroke,
				})
				else nil,
		}, face),
	})
end
