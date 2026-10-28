--!strict

--[[
	CardGrid
	Scrolling grid of ItemCards at LobbyUIConfig.Card size, centred, with room for card shadows.
	Shows emptyText instead when there are no cards.

	Props: cards ({ [key]: element }), count (number of cards), emptyText (text), size, position, layoutOrder
	Dependencies: React, UIConfig, LobbyUIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Card = LobbyUIConfig.Card
local Gap = UIConfig.Sizes.Window.Gap
local Shape = UIConfig.Shape

return function(props: any)
	if props.count == 0 then
		return Primitives.text({
			Color = UIConfig.Palette.TextSoft,
			LayoutOrder = props.layoutOrder,
			Position = props.position,
			Size = props.size,
			Text = props.emptyText or "",
			TextSize = UIConfig.TextSizes.Large,
		})
	end

	local children: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.fromOffset(Card.Width, Card.Height),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, Shape.ShadowOffset + Shape.RimStroke),
			PaddingLeft = UDim.new(0, Shape.RimStroke),
			PaddingRight = UDim.new(0, Shape.RimStroke),
			PaddingTop = UDim.new(0, Shape.RimStroke),
		}),
	}
	for key, card in props.cards do
		children[key] = card
	end

	return Primitives.scroll({
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
	}, children)
end
