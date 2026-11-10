--!strict

--[[
	SkinsWindow
	Crates tab: one card per CosmeticConfig crate whose button fires Net.OpenCrate (coins or
	gems). Skins tab: every cosmetic as a rarity-striped card tinted with its colour; owned
	ones can be equipped (Net.EquipCosmetic), the equipped one is ringed, unowned ones are
	locked. Default is always owned. A banner shows the last crate result.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, CosmeticConfig, ConfigLookup, Format, Primitives,
		Tabs, ItemCard, CardGrid, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.Config.CosmeticConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local CardGrid = require(Components.CardGrid)
local Chip = require(Components.Chip)
local Format = require(Components.Format)
local ItemCard = require(Components.ItemCard)
local Tabs = require(Components.Tabs)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Skins = LobbyUIConfig.Skins
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function sortedKeys(source: { [string]: any }): { string }
	local keys = {}
	for key in source do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function crateCards(data: any): ({ [string]: any }, number)
	local cards = {}
	local keys = sortedKeys(CosmeticConfig.Crates)
	for index, id in keys do
		local crate = CosmeticConfig.Crates[id]
		local usesGems = crate.CostType == "Gems"
		local balance = if usesGems then data.Gems or 0 else data.Coins or 0
		cards[id] = e(ItemCard, {
			buttonEnabled = balance >= crate.Cost,
			buttonSwatch = if usesGems then "Purple" else "Gold",
			buttonText = string.format(
				Skins.OpenFormat,
				if usesGems then Text.GemIcon else Text.CoinIcon,
				Format.compact(crate.Cost)
			),
			icon = Skins.CrateIcon,
			info = "",
			layoutOrder = index,
			onButton = function()
				Net.OpenCrate:Fire(id)
			end,
			swatch = if usesGems then "Purple" else "Gold",
			title = crate.DisplayName,
		})
	end
	return cards, #keys
end

local function skinCards(data: any): ({ [string]: any }, number)
	local cosmetics = data.Cosmetics or {}
	local owned = cosmetics.OwnedSkins or {}
	local equippedId = cosmetics.EquippedSkin
	local cards = {}
	local keys = sortedKeys(CosmeticConfig.Skins)
	for index, id in keys do
		local item = CosmeticConfig.Skins[id]
		local isOwned = owned[id] == true or id == "Default"
		local isEquipped = equippedId == id or (id == "Default" and (equippedId or "") == "")
		local tint = if typeof(item.Color) == "Color3"
			then item.Color
			elseif typeof(item.Color) == "ColorSequence" then item.Color.Keypoints[1].Value
			else nil
		cards[id] = e(ItemCard, {
			buttonEnabled = isOwned and not isEquipped,
			buttonSwatch = if isEquipped then "Teal" else "Green",
			buttonText = if not isOwned
				then Skins.LockedText
				elseif isEquipped then Skins.EquippedText
				else Skins.EquipText,
			icon = Skins.SkinIcon,
			iconColor = tint,
			info = item.Rarity,
			layoutOrder = index,
			onButton = function()
				Net.EquipCosmetic:Fire("Skin", id)
			end,
			rarityColor = LobbyUIConfig.RarityColors[item.Rarity],
			selected = isEquipped,
			swatch = if isOwned then (LobbyUIConfig.RaritySwatches[item.Rarity] or "Purple") else "Grey",
			title = item.DisplayName,
		})
	end
	return cards, #keys
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Skins.Width, Skins.Height)
	local tab, setTab = React.useState(Skins.Tabs[1].Id)
	local data = props.data
	local headerHeight = LobbyUIConfig.Tabs.Height + Gap + TextSizes.Large + Gap

	local cards, count
	if tab == "Skins" then
		cards, count = skinCards(data)
	else
		cards, count = crateCards(data)
	end

	local banner = ""
	local last = data.LastCrate
	if last ~= nil then
		local item = if last.Kind == "Skin" then ConfigLookup.GetSkin(last.Id) else nil
		banner = string.format(Skins.LastCrateFormat, if item ~= nil then item.DisplayName else last.Id)
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Skins.Swatch,
		title = Skins.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Skins.Tabs }),
		Banner = if banner ~= ""
			then e(Chip, {
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, LobbyUIConfig.Tabs.Height + Gap),
				swatch = "Gold",
				text = banner,
				textSize = TextSizes.Body,
			})
			else nil,
		Grid = e(CardGrid, {
			cards = cards,
			count = count,
			position = UDim2.fromOffset(0, headerHeight),
			size = UDim2.new(1, 0, 1, -headerHeight),
		}),
	})
end
