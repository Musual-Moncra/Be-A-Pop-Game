--!strict

--[[
	SkinsWindow
	Crates tab: one card per CosmeticConfig crate whose button fires Net.OpenCrate (coins or
	gems). Skins / Trails tabs: every cosmetic as a rarity-striped card tinted with its colour;
	owned ones can be equipped (Net.EquipCosmetic), the equipped one is ringed, unowned ones are
	locked. Default is always owned; the equipped trail can be taken off. A banner shows the last crate result.

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
local Format = require(Components.Format)
local ItemCard = require(Components.ItemCard)
local Primitives = require(Components.Primitives)
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

local function cosmeticCards(kind: string, data: any): ({ [string]: any }, number)
	local cosmetics = data.Cosmetics or {}
	local source = if kind == "Skin" then CosmeticConfig.Skins else CosmeticConfig.Trails
	local owned = (if kind == "Skin" then cosmetics.OwnedSkins else cosmetics.OwnedTrails) or {}
	local equippedId = if kind == "Skin" then cosmetics.EquippedSkin else cosmetics.EquippedTrail
	local cards = {}
	local keys = sortedKeys(source)
	for index, id in keys do
		local item = source[id]
		local isOwned = owned[id] == true or (kind == "Skin" and id == "Default")
		local isEquipped = equippedId == id or (kind == "Skin" and id == "Default" and (equippedId or "") == "")
		local canUnequip = isEquipped and kind == "Trail"
		local tint = if typeof(item.Color) == "Color3"
			then item.Color
			elseif typeof(item.Color) == "ColorSequence" then item.Color.Keypoints[1].Value
			else nil
		cards[id] = e(ItemCard, {
			buttonEnabled = isOwned and (not isEquipped or canUnequip),
			buttonSwatch = if canUnequip then "Red" elseif isEquipped then "Teal" else "Green",
			buttonText = if not isOwned
				then Skins.LockedText
				elseif canUnequip then Skins.UnequipText
				elseif isEquipped then Skins.EquippedText
				else Skins.EquipText,
			icon = if kind == "Skin" then Skins.SkinIcon else Skins.TrailIcon,
			iconColor = tint,
			info = item.Rarity,
			layoutOrder = index,
			onButton = function()
				Net.EquipCosmetic:Fire(kind, if canUnequip then "" else id)
			end,
			rarityColor = LobbyUIConfig.RarityColors[item.Rarity],
			selected = isEquipped,
			swatch = if isOwned then "Purple" else "Grey",
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
		cards, count = cosmeticCards("Skin", data)
	elseif tab == "Trails" then
		cards, count = cosmeticCards("Trail", data)
	else
		cards, count = crateCards(data)
	end

	local banner = ""
	local last = data.LastCrate
	if last ~= nil then
		local item = if last.Kind == "Skin" then ConfigLookup.GetSkin(last.Id) else ConfigLookup.GetTrail(last.Id)
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
		Banner = Primitives.text({
			Color = UIConfig.Palette.Sparkle,
			Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(1, 0, 0, TextSizes.Large),
			Text = banner,
			TextSize = TextSizes.Large,
		}),
		Grid = e(CardGrid, {
			cards = cards,
			count = count,
			position = UDim2.fromOffset(0, headerHeight),
			size = UDim2.new(1, 0, 1, -headerHeight),
		}),
	})
end
