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
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.Config.CosmeticConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Burst = require(Components.Burst)
local CardGrid = require(Components.CardGrid)
local Chip = require(Components.Chip)
local Format = require(Components.Format)
local ItemCard = require(Components.ItemCard)
local Primitives = require(Components.Primitives)
local RainbowRim = require(Components.RainbowRim)
local Tabs = require(Components.Tabs)
local Twinkle = require(Components.Twinkle)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Motion = LobbyUIConfig.Motion
local Skins = LobbyUIConfig.Skins
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function PopIn(props: any)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		local animation = UIConfig.Animation
		local delay = props.delay or 0
		scale.Scale = animation.PopInStart
		TweenService:Create(
			scale,
			TweenInfo.new(animation.PopInTime * 0.35, animation.SpringStyle, animation.SpringDirection, 0, false, delay),
			{ Scale = animation.PopInOver }
		):Play()
		TweenService:Create(
			scale,
			TweenInfo.new(
				animation.PopInTime * 0.25,
				animation.SmoothStyle,
				animation.SmoothDirection,
				0,
				false,
				delay + animation.PopInTime * 0.35
			),
			{ Scale = animation.PopInUnder }
		):Play()
		TweenService:Create(
			scale,
			TweenInfo.new(
				animation.PopInTime * 0.4,
				animation.SpringStyle,
				animation.SpringDirection,
				0,
				false,
				delay + animation.PopInTime * 0.6
			),
			{ Scale = 1 }
		):Play()
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 1),
	}, {
		Corner = Primitives.corner(UIConfig.Shape.Radius),
		Scale = e("UIScale", { ref = scaleRef }),
		Rainbow = if props.rainbow then e(RainbowRim, { thickness = UIConfig.Shape.RimStroke }) else nil,
		Twinkle = if (props.twinkleRate or 0) > 0
			then e(Twinkle, { clip = true, rate = props.twinkleRate, zIndex = 10 })
			else nil,
		Content = props.children,
	})
end

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
		cards[id] = e(PopIn, {
			delay = index * UIConfig.Animation.CardStagger,
			layoutOrder = index,
		}, {
			Card = e(ItemCard, {
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
			}),
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
		local rarity = ConfigLookup.GetRarity(item.Rarity)
		local order = if rarity ~= nil then rarity.Order else 0
		cards[id] = e(PopIn, {
			delay = index * UIConfig.Animation.CardStagger,
			layoutOrder = index,
			rainbow = order >= Motion.RainbowMinOrder,
			twinkleRate = Motion.RarityTwinkleRates[item.Rarity] or 0,
		}, {
			Card = e(ItemCard, {
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
				rarity = item.Rarity,
				rarityColor = LobbyUIConfig.RarityColors[item.Rarity],
				selected = isEquipped,
				swatch = if isOwned then (LobbyUIConfig.RaritySwatches[item.Rarity] or "Purple") else "Grey",
				title = item.DisplayName,
			}),
		})
	end
	return cards, #keys
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Skins.Width, Skins.Height)
	local tab, setTab = React.useState(Skins.Tabs[1].Id)
	local data = props.data
	local burst, setBurst = React.useState(0)
	local previousCrate = React.useRef(nil)
	local headerHeight = LobbyUIConfig.Tabs.Height + Gap + TextSizes.Large + Gap

	React.useEffect(function()
		local last = data.LastCrate
		local previous = previousCrate.current
		if last ~= nil and previous ~= nil and (previous.At ~= last.At or previous.Id ~= last.Id) then
			setBurst(function(count: number)
				return count + 1
			end)
		end
		previousCrate.current = if last ~= nil then { At = last.At, Id = last.Id } else nil
	end, { data.LastCrate } :: { any })

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
		icon = Skins.Icon,
		onClose = props.onClose,
		swatch = Skins.Swatch,
		title = Skins.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Skins.Tabs }),
		Burst = e(Burst, {
			origin = UDim2.fromScale(0.5, 0.5),
			trigger = burst,
			zIndex = 20,
		}),
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
