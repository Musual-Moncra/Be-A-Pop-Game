--!strict

--[[
	PetCard
	One owned pet: coloured pet block with its icon, name, rarity and variant, current Stink
	value, a Stink-stack bar and the EQUIP / EVOLVE / DELETE buttons. DELETE asks for a
	second press (SURE?) before firing. Sized by its grid cell.

	Props:
		pet: PetConfig entry (DisplayName, Color, Rarity)
		rarityColor: colour of the rarity strip (Color3)
		rarityName, variantName: card caption parts (text)
		stinkText, stacksText: Stink value and stacks bar label (text)
		stackRatio: stacks / cap (0 to 1)
		equipped, canEvolve: card state (true/false)
		equipText, evolveText, deleteText: button labels (text)
		onEquip, onEvolve, onDelete: button handlers
		layoutOrder
	Dependencies: React, UIConfig, LobbyUIConfig, Primitives, ChunkyButton, Bar, Inset, Chip
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Bar = require(Components.Bar)
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Pets = LobbyUIConfig.Pets
local Card = Pets.Card
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local TextSizes = UIConfig.TextSizes

local function titleHeight(): number
	return TextSizes.Large + Shape.Stroke * 2
end

local function smallHeight(): number
	return TextSizes.Small + Shape.Stroke * 2
end

return function(props: any)
	local iconHeight = Card.Height * Card.IconRatio
	local buttonWidth = 0.5

	local content: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Card.Gap),
		IconWell = e(Inset, {
			layoutOrder = 1,
			radius = Shape.Radius,
			size = UDim2.new(1, 0, 0, iconHeight),
		}, {
			Icon = Primitives.text({
				Stroke = false,
				Text = Pets.PetIcon,
				TextSize = iconHeight * Shape.IconFill,
				ZIndex = 3,
			}),
			Rarity = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = props.rarityColor or Palette.Inset,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, Shape.Lip),
				ZIndex = 4,
			}, { Corner = Primitives.corner(Shape.Lip) }),
		}),
		Title = Primitives.text({
			Fit = true,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, titleHeight()),
			Text = props.pet.DisplayName,
			TextSize = TextSizes.Large,
			ZIndex = 3,
		}),
		Trait = Primitives.text({
			Color = Palette.TextSoft,
			Fit = true,
			Font = "Body",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, smallHeight()),
			StrokeSize = Shape.SmallTextStroke,
			Text = string.format(Pets.TraitFormat, props.rarityName, props.variantName),
			TextSize = TextSizes.Small,
			ZIndex = 3,
		}),
		Stink = Primitives.text({
			Color = Palette.Sparkle,
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, smallHeight()),
			Text = props.stinkText,
			TextSize = TextSizes.Small,
			ZIndex = 3,
		}),
		Stacks = e(Bar, {
			layoutOrder = 5,
			ratio = props.stackRatio,
			size = UDim2.new(1, 0, 0, Card.StackBarHeight),
			swatch = "Brown",
			text = props.stacksText,
			textSize = TextSizes.Tiny,
			zIndex = 3,
		}),
		Buttons = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 6,
			Size = UDim2.new(1, 0, 0, Card.ButtonHeight),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Horizontal, Card.Gap),
			Equip = e(ChunkyButton, {
				enabled = true,
				layoutOrder = 1,
				onActivated = props.onEquip,
				size = UDim2.new(buttonWidth, -Card.Gap / 2, 1, 0),
				swatch = if props.equipped then "Red" else "Green",
				text = props.equipText,
				textSize = TextSizes.Small,
				zIndex = 4,
			}),
			Evolve = e(ChunkyButton, {
				enabled = props.canEvolve,
				layoutOrder = 2,
				onActivated = props.onEvolve,
				size = UDim2.new(buttonWidth, -Card.Gap / 2, 1, 0),
				swatch = "Purple",
				text = props.evolveText,
				textSize = TextSizes.Small,
				zIndex = 4,
			}),
		}),
		Delete = e(ChunkyButton, {
			layoutOrder = 7,
			onActivated = props.onDelete,
			size = UDim2.new(1, 0, 0, Card.DeleteHeight),
			swatch = "Red",
			text = props.deleteText,
			textSize = TextSizes.Small,
			zIndex = 4,
		}),
	}

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 1),
	}, {
		Card = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = if props.equipped then "Teal" else "Blue",
			zIndex = 2,
			overlay = if props.equipped
				then e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Palette.Sparkle,
					Thickness = Shape.RimStroke,
				})
				else nil,
		}, {
			Content = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				Padding = Primitives.padding(Card.Padding),
				Layout = content.Layout,
				IconWell = content.IconWell,
				Title = content.Title,
				Trait = content.Trait,
				Stink = content.Stink,
				Stacks = content.Stacks,
				Buttons = content.Buttons,
				Delete = content.Delete,
			}),
			Tag = if props.variantName ~= ""
				then e(Chip, {
					anchorPoint = Vector2.new(1, 0),
					height = Card.TagHeight,
					position = UDim2.new(1, -Shape.ContentPadding, 0, Shape.ContentPadding),
					swatch = "Purple",
					text = props.variantName,
					textSize = TextSizes.Tiny,
					zIndex = 5,
				})
				else nil,
		}),
	})
end
