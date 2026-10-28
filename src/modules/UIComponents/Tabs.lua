--!strict

--[[
	Tabs
	Row of chunky tab buttons for feature windows; the selected tab keeps its colour, the others
	turn grey. Sized by LobbyUIConfig.Tabs.

	Props: tabs ({ Id, Label, Icon, Swatch }), selected (tab Id), onSelect(id), layoutOrder
	Dependencies: React, UIConfig, LobbyUIConfig, Primitives, ChunkyButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local TabsConfig = LobbyUIConfig.Tabs

return function(props: any)
	local count = #props.tabs
	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Horizontal, TabsConfig.Gap),
	}
	for index, tab in props.tabs do
		children[tab.Id] = e(ChunkyButton, {
			icon = tab.Icon,
			layoutOrder = index,
			onActivated = function()
				props.onSelect(tab.Id)
			end,
			size = UDim2.new(1 / count, -TabsConfig.Gap * (count - 1) / count, 1, 0),
			swatch = if tab.Id == props.selected then tab.Swatch else "Grey",
			text = tab.Label,
			textSize = UIConfig.TextSizes.Large,
		})
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.new(1, 0, 0, TabsConfig.Height),
	}, children)
end
