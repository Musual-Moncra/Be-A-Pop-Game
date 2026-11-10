--!strict

--[[
	ShopWindow
	Tabbed Robux shop and potion bag. Gems and Coins use glossy product cards with a bonus
	line, a green price button and one BEST VALUE ribbon per tab; Potions add a USE button
	beside the price; Extras hold the Newbie Pack and Stain Bomb; Passes are wide cards with
	their perk list and an OWNED stamp. Pass, pack, potion and extra buttons prompt the
	Roblox purchase dialog when its config id is set.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, MonetizationConfig, PotionConfig,
		ConfigLookup, Format, Primitives, ChunkyButton, Inset, Tabs, Window, WindowSize
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
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Tabs = require(Components.Tabs)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Shop = LobbyUIConfig.Shop
local Gap = UIConfig.Sizes.Window.Gap
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function robux(price: number): string
	return string.format(Shop.RobuxFormat, price)
end

local function promptProduct(id: number)
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
end

local function bestValue(tab: string, key: any): boolean
	local value = Shop.BestValue[tab]
	return value ~= nil and value ~= "" and value == key
end

local function ribbon(): any
	local swatch = Primitives.swatch("Red")
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = swatch.Bottom,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.81, 0.09),
		Rotation = -32,
		Size = UDim2.fromOffset(126, 24),
		ZIndex = 7,
	}, {
		Corner = Primitives.corner(6),
		Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
		Stroke = Primitives.stroke(swatch.Stroke, Shape.Stroke),
		Label = Primitives.text({
			Text = Shop.BestValueText,
			TextSize = TextSizes.Small,
			ZIndex = 8,
		}),
	})
end

local function ProductCard(props: any)
	local hasSecond = props.secondText ~= nil
	local buttonSwatch = if props.buttonEnabled == false then "Grey" else props.buttonSwatch
	local buttonWidth = if hasSecond then 0.47 else 0.86
	local buttonAnchor = if hasSecond then Vector2.new(0, 1) else Vector2.new(0.5, 1)
	local buttonX = if hasSecond
		then UDim2.new(0.07, 0, 1, -Shape.ContentPadding)
		else UDim2.new(0.5, 0, 1, -Shape.ContentPadding)

	local children: { [string]: any } = {
		Icon = Primitives.text({
			Position = UDim2.fromScale(0, 0.03),
			Size = UDim2.new(1, 0, 0.30, 0),
			Stroke = false,
			Text = props.icon,
			TextSize = TextSizes.BigIcon * 1.15,
			ZIndex = 3,
		}),
		Title = Primitives.text({
			Fit = true,
			Position = UDim2.new(0, 0, 0.35, 0),
			Size = UDim2.new(1, 0, 0, TextSizes.Title),
			Text = props.title,
			TextSize = TextSizes.Title,
			ZIndex = 3,
		}),
		Bonus = Primitives.text({
			Color = Palette.Sparkle,
			Fit = true,
			Position = UDim2.new(0, 0, 0.48, 0),
			Size = UDim2.new(1, 0, 0, TextSizes.Body),
			Text = props.bonus or "",
			TextSize = TextSizes.Body,
			ZIndex = 3,
		}),
		Info = Primitives.text({
			Color = Palette.TextSoft,
			Fit = true,
			Font = "Body",
			Position = UDim2.new(0, 0, 0.57, 0),
			Size = UDim2.new(1, 0, 0, TextSizes.Small * 1.8),
			StrokeSize = Shape.SmallTextStroke,
			Text = props.info or "",
			TextSize = TextSizes.Small,
			Wrapped = true,
			ZIndex = 3,
		}),
		Buy = e(ChunkyButton, {
			anchorPoint = buttonAnchor,
			enabled = props.buttonEnabled ~= false,
			onActivated = props.onButton,
			position = buttonX,
			shine = props.buttonEnabled ~= false,
			size = UDim2.new(buttonWidth, 0, 0, if hasSecond then 42 else 52),
			swatch = buttonSwatch,
			text = props.buttonText,
			textSize = if hasSecond then TextSizes.Small else TextSizes.Body,
			zIndex = 4,
		}),
	}
	if hasSecond then
		children.Second = e(ChunkyButton, {
			anchorPoint = Vector2.new(1, 1),
			enabled = props.secondEnabled ~= false,
			onActivated = props.onSecond,
			position = UDim2.new(0.93, 0, 1, -Shape.ContentPadding),
			shine = props.secondEnabled ~= false,
			size = UDim2.new(0.47, 0, 0, 42),
			swatch = props.secondSwatch or "Gold",
			text = props.secondText,
			textSize = TextSizes.Small,
			zIndex = 4,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
		Size = UDim2.fromOffset(Shop.CardWidth, Shop.CardHeight),
	}, {
		Card = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = props.swatch,
			zIndex = 2,
		}, children),
		Ribbon = if props.best then ribbon() else nil,
	})
end

local function PassCard(props: any)
	local pass = props.pass
	local isOwned = props.owned
	local available = pass.Id ~= 0
	local perks = props.perks

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
		Size = UDim2.new(1, 0, 0, Shop.PassRowHeight),
	}, {
		Card = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = "Gold",
			zIndex = 2,
		}, {
			Icon = e(Inset, {
				position = UDim2.fromOffset(Shape.ContentPadding, (Shop.PassRowHeight - 72) / 2),
				radius = "Round",
				size = UDim2.fromOffset(72, 72),
				zIndex = 3,
			}, {
				Icon = Primitives.text({
					Stroke = false,
					Text = pass.Icon,
					TextSize = 40,
					ZIndex = 4,
				}),
			}),
			Title = Primitives.text({
				Fit = true,
				Position = UDim2.new(0, Shape.ContentPadding + 84, 0, 12),
				Size = UDim2.new(0.5, -84, 0, TextSizes.Header),
				Text = pass.DisplayName,
				TextSize = TextSizes.Header,
				XAlign = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}),
			Perks = Primitives.text({
				Color = Palette.TextSoft,
				Fit = true,
				Font = "Body",
				Position = UDim2.new(0, Shape.ContentPadding + 84, 0, 42),
				Size = UDim2.new(0.5, -84, 0, TextSizes.Body * 2),
				StrokeSize = Shape.SmallTextStroke,
				Text = perks,
				TextSize = TextSizes.Small,
				Wrapped = true,
				XAlign = Enum.TextXAlignment.Left,
				YAlign = Enum.TextYAlignment.Top,
				ZIndex = 3,
			}),
			Action = if isOwned
				then e(ChunkyButton, {
					anchorPoint = Vector2.new(1, 0.5),
					position = UDim2.new(1, -Shape.ContentPadding, 0.5, 0),
					size = UDim2.fromOffset(150, 48),
					swatch = "Gold",
					text = Shop.OwnedText,
					textSize = TextSizes.Body,
					zIndex = 3,
				})
				else e(ChunkyButton, {
					anchorPoint = Vector2.new(1, 0.5),
					enabled = available,
					onActivated = function()
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
					end,
					position = UDim2.new(1, -Shape.ContentPadding, 0.5, 0),
					shine = available,
					size = UDim2.fromOffset(150, 48),
					swatch = if available then "Green" else "Grey",
					text = if available then robux(pass.PriceRobux) else Shop.SoonText,
					textSize = TextSizes.Body,
					zIndex = 3,
				}),
		}),
		Ribbon = if props.best then ribbon() else nil,
	})
end

local function passPerks(pass: any): string
	local perks = {}
	if (pass.CoinMultiplier or 1) > 1 then
		table.insert(perks, string.format(Shop.Perks.Coins, Format.multiplier(pass.CoinMultiplier)))
	end
	if (pass.GemMultiplier or 1) > 1 then
		table.insert(perks, string.format(Shop.Perks.Gems, Format.multiplier(pass.GemMultiplier)))
	end
	if (pass.ExtraPetSlots or 0) > 0 then
		table.insert(perks, string.format(Shop.Perks.PetSlots, pass.ExtraPetSlots))
	end
	if pass.Magnet then
		table.insert(perks, Shop.Perks.Magnet)
	end
	if pass.Vip then
		table.insert(perks, Shop.Perks.Vip)
	end
	if #perks == 0 then
		return pass.Description
	end
	return pass.Description .. Shop.Perks.Separator .. table.concat(perks, Shop.Perks.Separator)
end

local function packCard(
	pack: any,
	index: number,
	icon: string,
	swatch: string,
	amountText: string,
	bonus: string,
	tab: string
): any
	local available = pack.Id ~= 0
	return e(ProductCard, {
		best = bestValue(tab, index),
		bonus = bonus,
		buttonEnabled = available,
		buttonSwatch = "Green",
		buttonText = if available then robux(pack.PriceRobux) else Shop.SoonText,
		icon = icon,
		info = pack.DisplayName,
		onButton = function()
			promptProduct(pack.Id)
		end,
		order = index,
		swatch = swatch,
		title = amountText,
	})
end

local function potionCard(potion: any, index: number, data: any, tab: string): any
	local held = (data.PotionInventory or {})[potion.Id] or 0
	local endsAt = (data.Potions or {})[potion.Id] or 0
	local left = math.max(0, endsAt - os.time())
	local available = potion.ProductId ~= 0
	return e(ProductCard, {
		best = bestValue(tab, ""),
		bonus = string.format(Shop.PotionStatFormat, potion.Multiplier, potion.Stat),
		buttonEnabled = available,
		buttonSwatch = "Green",
		buttonText = if available then robux(potion.PriceRobux) else Shop.SoonText,
		icon = potion.Icon,
		info = potion.Description,
		onButton = function()
			promptProduct(potion.ProductId)
		end,
		onSecond = function()
			Net.UsePotion:Fire(potion.Id)
		end,
		order = index,
		secondEnabled = held > 0 and left <= 0,
		secondSwatch = "Teal",
		secondText = if left > 0
			then string.format(Shop.ActiveFormat, string.format(Shop.TimeFormat, left // 60, left % 60))
			else Shop.UseText,
		swatch = "Teal",
		title = string.format(Shop.CountFormat, held),
	})
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Shop.Width, Shop.Height)
	local tab, setTab = React.useState(Shop.Tabs[1].Id)
	local data = props.data
	local cards: { [string]: any } = {}
	local count = 0

	if tab == "Gems" then
		for index, pack in MonetizationConfig.DevProducts.GemPacks do
			count += 1
			cards["Pack" .. index] = packCard(
				pack,
				index,
				Text.GemIcon,
				"Purple",
				string.format(Text.IconLabel, Text.GemIcon, Format.compact(pack.Gems)),
				string.format(Shop.BonusFormat, pack.BonusPercent or 0),
				tab
			)
		end
	elseif tab == "Coins" then
		for index, pack in MonetizationConfig.DevProducts.CoinPacks do
			count += 1
			cards["Pack" .. index] = packCard(
				pack,
				index,
				Text.CoinIcon,
				"Orange",
				string.format(Text.IconLabel, Text.CoinIcon, Format.compact(pack.Coins)),
				Shop.CoinBonusText,
				tab
			)
		end
	elseif tab == "Potions" then
		local ids = {}
		for id in PotionConfig.Potions do
			table.insert(ids, id)
		end
		table.sort(ids)
		for index, id in ids do
			local potion = PotionConfig.Potions[id]
			count += 1
			cards[id] = potionCard(potion, index, data, tab)
		end
	elseif tab == "Extras" then
		if data.NewbiePackClaimed ~= true then
			local pack = MonetizationConfig.DevProducts.NewbiePack
			local pet = ConfigLookup.GetPet(pack.PetId)
			local petName = if pet ~= nil then pet.DisplayName else pack.PetId
			local available = pack.Id ~= 0
			count += 1
			cards.NewbiePack = e(ProductCard, {
				best = bestValue(tab, "NewbiePack"),
				bonus = petName,
				buttonEnabled = available,
				buttonSwatch = "Green",
				buttonText = if available then robux(pack.PriceRobux) else Shop.SoonText,
				icon = Shop.NewbiePackIcon,
				info = string.format(
					Shop.NewbiePackInfoFormat,
					petName,
					Format.compact(pack.Gems),
					Format.compact(pack.Coins),
					Format.multiplier(pack.CoinBoostMultiplier)
				),
				onButton = function()
					promptProduct(pack.Id)
				end,
				order = count,
				swatch = "Pink",
				title = Shop.NewbiePackText,
			})
		end
		local bomb = MonetizationConfig.DevProducts.StainBomb
		local available = bomb.Id ~= 0
		count += 1
		cards.StainBomb = e(ProductCard, {
			best = bestValue(tab, "StainBomb"),
			bonus = Shop.OneShotText,
			buttonEnabled = available,
			buttonSwatch = "Green",
			buttonText = if available then robux(bomb.PriceRobux) else Shop.SoonText,
			icon = Shop.StainBombIcon,
			info = string.format(Shop.StainBombInfoFormat, Format.multiplier(MonetizationConfig.StainBombAreaScale)),
			onButton = function()
				promptProduct(bomb.Id)
			end,
			order = count,
			swatch = "Red",
			title = bomb.DisplayName,
		})
	else
		local owned = data.OwnedPasses or {}
		local keys = {}
		for key in MonetizationConfig.Gamepasses do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return MonetizationConfig.Gamepasses[a].PriceRobux < MonetizationConfig.Gamepasses[b].PriceRobux
		end)
		for index, key in keys do
			local pass = MonetizationConfig.Gamepasses[key]
			count += 1
			cards[key] = e(PassCard, {
				best = bestValue(tab, key),
				order = index,
				owned = owned[key] == true,
				pass = pass,
				perks = passPerks(pass),
			})
		end
	end

	local content
	if tab == "Passes" then
		local rows: { [string]: any } = {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Shop.GridGap),
			Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke),
		}
		for key, card in cards do
			rows[key] = card
		end
		content = Primitives.scroll({ Size = UDim2.fromScale(1, 1) }, rows)
	else
		local gridChildren: { [string]: any } = {
			Grid = e("UIGridLayout", {
				CellPadding = UDim2.fromOffset(Shop.GridGap, Shop.GridGap),
				CellSize = UDim2.fromOffset(Shop.CardWidth, Shop.CardHeight),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke),
		}
		for key, card in cards do
			gridChildren[key] = card
		end
		content = Primitives.scroll({ Size = UDim2.fromScale(1, 1) }, gridChildren)
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Shop.Swatch,
		title = Shop.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Shop.Tabs }),
		Body = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(1, 0, 1, -(LobbyUIConfig.Tabs.Height + Gap)),
		}, { Content = content }),
	})
end
