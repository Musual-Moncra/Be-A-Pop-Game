--!strict

--[[
	PetsWindow
	Two tabs. My Pets: one PetCard per owned pet with its rarity, variant, Stink value,
	Stink-stack bar, EQUIP / UNEQUIP, EVOLVE (fires Net.MergePet once five identical pets are
	owned) and DELETE (second press confirms). The header shows total Stink and used slots.
	Pet Index: one section per map with the map's pet pool; discovered pets are coloured,
	undiscovered ones show a black silhouette with "???" plus rarity and odds, and the section
	shows progress, the exclusive pet + gem reward and CLAIMED once earned. Coming-soon maps
	are greyed.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, ConfigLookup, PetConfig, PetView, Format,
		Primitives, PetCard, ChunkyButton, Inset, Tabs, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local PetCard = require(Components.PetCard)
local Primitives = require(Components.Primitives)
local Tabs = require(Components.Tabs)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Pets = LobbyUIConfig.Pets
local Card = Pets.Card
local Index = Pets.Index
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Gap = UIConfig.Sizes.Window.Gap
local TextSizes = UIConfig.TextSizes

local function isComingSoon(map: any): boolean
	local raw = map :: any
	return map.Enabled == false or raw.ComingSoon == true
end

local function copiesOf(owned: { any }): { [string]: number }
	local copies: { [string]: number } = {}
	for _, entry in owned do
		local key = entry.PetId .. "/" .. entry.Variant
		copies[key] = (copies[key] or 0) + 1
	end
	return copies
end

local function petCards(data: any, confirmUid: string?, onConfirm: (string?) -> ()): ({ [string]: any }, number)
	local state = data.Pets or {}
	local owned = state.Pets or {}
	local equipped = {}
	for _, uid in state.Equipped or {} do
		equipped[uid] = true
	end
	local copies = copiesOf(owned)
	local stackCap = PetView.StackCap()

	local sorted = table.clone(owned)
	table.sort(sorted, function(a, b)
		local ea, eb = equipped[a.Uid] == true, equipped[b.Uid] == true
		if ea ~= eb then
			return ea
		end
		local ra = ConfigLookup.GetPet(a.PetId)
		local rb = ConfigLookup.GetPet(b.PetId)
		local oa = if ra ~= nil then (ConfigLookup.GetRarity(ra.Rarity) or { Order = 0 }).Order else 0
		local ob = if rb ~= nil then (ConfigLookup.GetRarity(rb.Rarity) or { Order = 0 }).Order else 0
		if oa ~= ob then
			return oa > ob
		end
		return a.Uid < b.Uid
	end)

	local cards = {}
	for index, entry in sorted do
		local pet = ConfigLookup.GetPet(entry.PetId)
		local variant = ConfigLookup.GetVariant(entry.Variant)
		local rarity = if pet ~= nil then ConfigLookup.GetRarity(pet.Rarity) else nil
		local isEquipped = equipped[entry.Uid] == true
		local count = copies[entry.PetId .. "/" .. entry.Variant] or 0
		local hasNextVariant = variant ~= nil and variant.NextVariant ~= nil and variant.NextVariant ~= ""
		local canEvolve = hasNextVariant and count >= PetConfig.MaxMergedFrom
		local evolveText = if canEvolve
			then Pets.EvolveText
			elseif variant ~= nil and not hasNextVariant then Pets.EvolveMaxText
			else string.format(Pets.EvolveNeedFormat, PetConfig.MaxMergedFrom)
		local stacks = math.max(0, math.floor(tonumber(entry.Stacks) or 0))
		local stackRatio = if stackCap > 0 then math.min(1, stacks / stackCap) else 0
		local stackText = if stackCap > 0
			then string.format(Pets.StackFormat, stacks, stackCap)
			else string.format(Pets.StackOnlyFormat, stacks)
		local variantName = if variant ~= nil and variant.Id ~= "Default" then variant.DisplayName else ""

		cards[entry.Uid] = e(PetCard, {
			canEvolve = canEvolve,
			deleteText = if confirmUid == entry.Uid then Pets.DeleteConfirmText else Pets.DeleteText,
			equipText = if isEquipped then Pets.UnequipText else Pets.EquipText,
			equipped = isEquipped,
			evolveText = evolveText,
			layoutOrder = index,
			onDelete = function()
				if confirmUid == entry.Uid then
					Net.DeletePet:Fire(entry.Uid)
					onConfirm(nil)
				else
					onConfirm(entry.Uid)
				end
			end,
			onEquip = function()
				if isEquipped then
					Net.UnequipPet:Fire(entry.Uid)
				else
					Net.EquipPet:Fire(entry.Uid)
				end
			end,
			onEvolve = function()
				Net.MergePet:Fire(entry.Uid)
			end,
			pet = if pet ~= nil then pet else { DisplayName = entry.PetId, Color = Palette.Inset, Rarity = "" },
			rarityColor = if rarity ~= nil
				then rarity.Color
				elseif pet ~= nil then LobbyUIConfig.RarityColors[pet.Rarity]
				else nil,
			rarityName = if rarity ~= nil then rarity.DisplayName else "",
			stackRatio = stackRatio,
			stacksText = stackText,
			stinkText = string.format(
				Pets.PetStinkFormat,
				Format.multiplier(PetView.Stink(entry.PetId, entry.Variant, stacks))
			),
			variantName = variantName,
		})
	end
	return cards, #sorted
end

local function petGrid(data: any, confirmUid: string?, onConfirm: (string?) -> ()): any
	local cards, count = petCards(data, confirmUid, onConfirm)
	if count == 0 then
		return Primitives.text({
			Color = Palette.TextSoft,
			Size = UDim2.fromScale(1, 1),
			Text = Pets.EmptyText,
			TextSize = TextSizes.Large,
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
	for key, card in cards do
		children[key] = card
	end
	return Primitives.scroll({ Size = UDim2.fromScale(1, 1) }, children)
end

local function indexTile(pet: any, discovered: boolean, order: number): any
	local rarity = ConfigLookup.GetRarity(pet.Rarity)
	local odds = PetView.DropOdds(pet)
	local name = if discovered then pet.DisplayName else Index.UnknownName
	local icon = if discovered then Pets.PetIcon else Index.LockedIcon
	local rarityName = if rarity ~= nil then rarity.DisplayName else pet.Rarity
	local oddsText = if odds > 0 then string.format(Index.OddsFormat, odds) else ""

	return e(ChunkyButton, {
		layoutOrder = order,
		size = UDim2.fromOffset(Index.TileWidth, Index.TileHeight),
		swatch = if discovered then "Blue" else "Grey",
	}, {
		Content = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			Padding = Primitives.padding(Shape.ContentPadding),
			Layout = Primitives.list(Enum.FillDirection.Vertical, Shape.Stroke * 2),
			Icon = e(Inset, {
				layoutOrder = 1,
				radius = Shape.Radius,
				size = UDim2.new(1, 0, 0, Index.TileIconSize),
			}, {
				Background = e("Frame", {
					BackgroundColor3 = if discovered then pet.Color else Palette.Ink,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 1,
				}, { Corner = Primitives.corner(Shape.Radius) }),
				Label = Primitives.text({
					Stroke = false,
					Text = icon,
					TextSize = Index.TileIconSize * Shape.IconFill,
					ZIndex = 3,
				}),
			}),
			Name = Primitives.text({
				Fit = true,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, TextSizes.Body + Shape.Stroke),
				Text = name,
				TextSize = TextSizes.Body,
				ZIndex = 3,
			}),
			Rarity = Primitives.text({
				Color = if rarity ~= nil then rarity.Color else Palette.TextSoft,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, TextSizes.Small + Shape.Stroke),
				Text = rarityName,
				TextSize = TextSizes.Small,
				ZIndex = 3,
			}),
			Odds = Primitives.text({
				Color = Palette.TextSoft,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, TextSizes.Small),
				Text = oddsText,
				TextSize = TextSizes.Small,
				ZIndex = 3,
			}),
		}),
	})
end

local function indexSection(map: any, data: any, order: number): any
	local comingSoon = isComingSoon(map)
	local normal = PetView.PoolForMap(map.Id)
	local exclusive = PetView.ExclusivePet(map.Id)
	local discoveredCount = 0
	for _, pet in normal do
		if PetView.IsDiscovered(data.Pets.Index, pet.Id) then
			discoveredCount += 1
		end
	end
	local total = #normal
	local complete = total > 0 and discoveredCount >= total
	local claimed = data.Pets.IndexClaimed[map.Id] == true or complete
	local gems = PetView.IndexGems()
	local visual = UIConfig.MapVisuals[map.Id] or {}

	local headerRight
	if claimed then
		headerRight = Index.ClaimedText
	elseif comingSoon then
		headerRight = Index.ComingSoonText
	else
		headerRight = string.format(Index.ProgressFormat, discoveredCount, total)
	end

	local rewardText
	if claimed then
		rewardText = Index.ClaimedText
	elseif comingSoon then
		rewardText = Index.ComingSoonText
	elseif total == 0 and exclusive == nil then
		rewardText = Index.NoPetsText
	else
		local reward = if exclusive ~= nil
			then string.format(Index.RewardFormat, exclusive.DisplayName, gems)
			else string.format(Index.RewardGemsFormat, gems)
		rewardText = Index.RewardHeader .. "  " .. reward
	end

	local tiles: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.fromOffset(Index.TileWidth, Index.TileHeight),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if not comingSoon then
		for index, pet in normal do
			tiles["Pet" .. pet.Id] = indexTile(pet, PetView.IsDiscovered(data.Pets.Index, pet.Id), index)
		end
	end
	local rows = if comingSoon then 0 else math.ceil(#normal / Index.Columns)
	local gridHeight = if rows > 0 then rows * Index.TileHeight + (rows - 1) * Gap else 0

	local header = e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, Index.HeaderHeight),
	}, {
		Name = Primitives.text({
			Color = if comingSoon then Palette.TextSoft else Palette.Text,
			Size = UDim2.new(0.6, 0, 1, 0),
			Text = string.format(UIConfig.Text.IconLabel, visual.Icon or "", map.DisplayName),
			TextSize = TextSizes.Header,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Progress = Primitives.text({
			AnchorPoint = Vector2.new(1, 0),
			Color = if claimed then Palette.Sparkle else Palette.TextSoft,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.4, 1),
			Text = headerRight,
			TextSize = TextSizes.Body,
			XAlign = Enum.TextXAlignment.Right,
		}),
	})

	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
		Header = header,
	}
	if gridHeight > 0 then
		children.Grid = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, gridHeight),
		}, tiles)
	end
	children.Reward = Primitives.text({
		Color = if claimed then Palette.Sparkle elseif comingSoon then Palette.TextSoft else Palette.Text,
		Fit = true,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Index.RewardHeight),
		Text = rewardText,
		TextSize = TextSizes.Body,
		XAlign = Enum.TextXAlignment.Left,
	})

	return e(Inset, {
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = order,
		padding = Gap,
		size = UDim2.new(1, 0, 0, 0),
	}, children)
end

local function petIndex(data: any): any
	local sections: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Index.SectionGap),
		Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke),
	}
	for index, map in ConfigLookup.GetSortedMaps() do
		sections[map.Id] = indexSection(map, data, index)
	end
	return Primitives.scroll({ Size = UDim2.fromScale(1, 1) }, sections)
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Pets.Width, Pets.Height)
	local tab, setTab = React.useState(Pets.Tabs[1].Id)
	local confirmUid, setConfirmUid = React.useState(nil :: string?)
	local data = props.data
	local headerHeight = LobbyUIConfig.Tabs.Height + Gap + TextSizes.Large + Gap

	React.useEffect(function()
		setConfirmUid(nil)
	end, { tab } :: { any })

	React.useEffect(function()
		if confirmUid == nil then
			return
		end
		local thread = task.delay(Pets.DeleteConfirmSeconds, function()
			setConfirmUid(nil)
		end)
		return function()
			task.cancel(thread)
		end
	end, { confirmUid } :: { any })

	local equippedCount = #(data.Pets.Equipped or {})
	local stinkText = string.format(Pets.StinkFormat, Format.multiplier(PetView.TotalStink(data)))
	local slotsText = string.format(Pets.SlotsFormat, equippedCount, data.Pets.Slots or 0)

	local body
	if tab == Pets.Tabs[2].Id then
		body = petIndex(data)
	else
		body = petGrid(data, confirmUid, setConfirmUid)
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Pets.Swatch,
		title = Pets.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Pets.Tabs }),
		Stink = Primitives.text({
			Color = Palette.Sparkle,
			Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(0.6, 0, 0, TextSizes.Large),
			Text = stinkText,
			TextSize = TextSizes.Large,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Slots = Primitives.text({
			AnchorPoint = Vector2.new(1, 0),
			Color = Palette.TextSoft,
			Position = UDim2.new(1, 0, 0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(0.4, 0, 0, TextSizes.Large),
			Text = slotsText,
			TextSize = TextSizes.Large,
			XAlign = Enum.TextXAlignment.Right,
		}),
		Body = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, headerHeight),
			Size = UDim2.new(1, 0, 1, -headerHeight),
		}, { Content = body }),
	})
end
