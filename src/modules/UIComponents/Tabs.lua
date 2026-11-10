--!strict

--[[
	Tabs
	Row of chunky tab buttons for feature windows; the selected tab keeps its colour, the others
	turn grey. Sized by LobbyUIConfig.Tabs.

	PC shortcuts: PrevTab / NextTab (KeybindConfig) step through the tabs, wrapping around, with
	key hints on the first and last tab. Pass shortcuts = false for a nested tab row.

	Props: tabs ({ Id, Label, Icon, Swatch }), selected (tab Id), onSelect(id), layoutOrder,
		shortcuts (default true)
	Dependencies: React, UIConfig, LobbyUIConfig, Primitives, ChunkyButton, Keybinds, KeyHint
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)
local Keybinds = require(ReplicatedStorage.Modules.UIComponents.Keybinds)
local KeyHint = require(ReplicatedStorage.Modules.UIComponents.KeyHint)

local e = React.createElement
local TabsConfig = LobbyUIConfig.Tabs

return function(props: any)
	local count = #props.tabs
	local shortcuts = props.shortcuts ~= false and count > 1

	local function step(direction: number)
		local current = 1
		for index, tab in props.tabs do
			if tab.Id == props.selected then
				current = index
			end
		end
		local nextIndex = (current - 1 + direction) % count + 1
		props.onSelect(props.tabs[nextIndex].Id)
	end
	Keybinds.use("PrevTab", function()
		step(-1)
	end, shortcuts)
	Keybinds.use("NextTab", function()
		step(1)
	end, shortcuts)

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
			overlay = if shortcuts and (index == 1 or index == count)
				then e(KeyHint, { action = if index == 1 then "PrevTab" else "NextTab", zIndex = 8 })
				else nil,
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
