--!strict

--[[
	ShopWindow
	Robux shop and potion bag, split by tabs: gamepasses, gem packs, coin packs and potions.
	Pass and pack cards prompt the Roblox purchase dialog (only when the id in MonetizationConfig
	is set); owned passes show OWNED. Potion cards show how many the player holds and fire
	Net.UsePotion; an active potion shows its time left.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, MonetizationConfig, PotionConfig, Format,
		Tabs, ItemCard, CardGrid, Window, WindowSize
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local MonetizationConfig = require(ReplicatedStorage.Modules.Config.MonetizationConfig)
local PotionConfig = require(ReplicatedStorage.Modules.Config.PotionConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local CardGrid = require(Components.CardGrid)
local Format = require(Components.Format)
local ItemCard = require(Components.ItemCard)
local Tabs = require(Components.Tabs)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Shop = LobbyUIConfig.Shop
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text

local SECONDS_PER_MINUTE = 60

local function robux(price: number): string
	return string.format(Shop.RobuxFormat, price)
end

local function promptProduct(id: number)
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
end

local function passCards(data: any): ({ [string]: any }, number)
	local owned = data.OwnedPasses or {}
	local cards, count = {}, 0
	local keys = {}
	for key in MonetizationConfig.Gamepasses do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return MonetizationConfig.Gamepasses[a].PriceRobux < MonetizationConfig.Gamepasses[b].PriceRobux
	end)
	for index, key in keys do
		local pass = MonetizationConfig.Gamepasses[key]
		local isOwned = owned[key] == true
		local available = pass.Id ~= 0
		count += 1
		cards[key] = e(ItemCard, {
			buttonEnabled = available and not isOwned,
			buttonSwatch = if isOwned then "Teal" else "Green",
			buttonText = if isOwned then Shop.OwnedText elseif available then robux(pass.PriceRobux) else Shop.SoonText,
			icon = pass.Icon,
			info = pass.Description,
			layoutOrder = index,
			onButton = function()
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
			end,
			swatch = "Gold",
			title = pass.DisplayName,
		})
	end
	return cards, count
end

local function packCards(packs: { any }, icon: string, swatch: string, amountKey: string): ({ [string]: any }, number)
	local cards = {}
	for index, pack in packs do
		local available = pack.Id ~= 0
		cards["Pack" .. index] = e(ItemCard, {
			buttonEnabled = available,
			buttonText = if available then robux(pack.PriceRobux) else Shop.SoonText,
			icon = icon,
			info = string.format(Text.IconLabel, icon, Format.commas(pack[amountKey] or 0)),
			layoutOrder = index,
			onButton = function()
				promptProduct(pack.Id)
			end,
			swatch = swatch,
			title = pack.DisplayName,
		})
	end
	return cards, #packs
end

local function potionCards(data: any): ({ [string]: any }, number)
	local inventory = data.PotionInventory or {}
	local active = data.Potions or {}
	local now = os.time()
	local cards, count = {}, 0
	local ids = {}
	for id in PotionConfig.Potions do
		table.insert(ids, id)
	end
	table.sort(ids)
	for index, id in ids do
		local potion = PotionConfig.Potions[id]
		local held = inventory[id] or 0
		local endsAt = active[id] or 0
		local left = endsAt - now
		count += 1
		cards[id] = e(ItemCard, {
			buttonEnabled = held > 0,
			buttonSwatch = "Teal",
			buttonText = if left > 0
				then string.format(
					Shop.ActiveFormat,
					string.format("%d:%02d", left // SECONDS_PER_MINUTE, left % SECONDS_PER_MINUTE)
				)
				else Shop.UseText,
			icon = potion.Icon,
			info = potion.Description,
			layoutOrder = index,
			onButton = function()
				Net.UsePotion:Fire(id)
			end,
			swatch = "Teal",
			tag = string.format(Shop.CountFormat, held),
			title = potion.DisplayName,
		})
	end
	return cards, count
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Shop.Width, Shop.Height)
	local tab, setTab = React.useState(Shop.Tabs[1].Id)
	local data = props.data

	local cards, count
	if tab == "Gems" then
		cards, count = packCards(MonetizationConfig.DevProducts.GemPacks, Text.GemIcon, "Purple", "Gems")
	elseif tab == "Coins" then
		cards, count = packCards(MonetizationConfig.DevProducts.CoinPacks, Text.CoinIcon, "Orange", "Coins")
	elseif tab == "Potions" then
		cards, count = potionCards(data)
	else
		cards, count = passCards(data)
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Shop.Swatch,
		title = Shop.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Shop.Tabs }),
		Grid = e(CardGrid, {
			cards = cards,
			count = count,
			position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			size = UDim2.new(1, 0, 1, -(LobbyUIConfig.Tabs.Height + Gap)),
		}),
	})
end
