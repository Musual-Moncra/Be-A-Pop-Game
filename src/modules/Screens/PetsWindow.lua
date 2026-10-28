--!strict

--[[
	PetsWindow
	Eggs tab: one card per PetConfig egg (price, map lock) whose button fires Net.HatchEgg.
	My Pets tab: every owned pet as a rarity-striped card with its coin / stink bonus, an
	EQUIP / UNEQUIP button (Net.EquipPet / Net.UnequipPet) and, when five identical pets are
	owned, a MERGE button (Net.MergePet). A banner shows the last hatch.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, ConfigLookup, PetConfig, Format, Primitives,
		Tabs, ItemCard, CardGrid, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local CardGrid = require(Components.CardGrid)
local Format = require(Components.Format)
local ItemCard = require(Components.ItemCard)
local Primitives = require(Components.Primitives)
local Tabs = require(Components.Tabs)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Pets = LobbyUIConfig.Pets
local Gap = UIConfig.Sizes.Window.Gap
local TextSizes = UIConfig.TextSizes

local function eggCards(data: any): ({ [string]: any }, number)
	local cards = {}
	local eggs = ConfigLookup.GetSortedEggs()
	for index, egg in eggs do
		local unlocked = data.UnlockedMaps ~= nil and data.UnlockedMaps[egg.MapId] == true
		local canAfford = (data.Coins or 0) >= egg.Price
		local map = ConfigLookup.GetMap(egg.MapId)
		cards[egg.Id] = e(ItemCard, {
			buttonEnabled = unlocked and canAfford,
			buttonSwatch = "Gold",
			buttonText = if unlocked then string.format(Pets.HatchFormat, Format.compact(egg.Price)) else Pets.LockedText,
			icon = Pets.EggIcon,
			iconColor = egg.Color,
			info = if map ~= nil then map.DisplayName else "",
			layoutOrder = index,
			onButton = function()
				Net.HatchEgg:Fire(egg.Id)
			end,
			swatch = "Gold",
			title = egg.DisplayName,
		})
	end
	return cards, #eggs
end

local function petCards(data: any): ({ [string]: any }, number, number, number)
	local state = data.Pets or {}
	local owned = state.Pets or {}
	local equipped = {}
	for _, uid in state.Equipped or {} do
		equipped[uid] = true
	end
	local copies: { [string]: number } = {}
	for _, entry in owned do
		local key = entry.PetId .. "/" .. entry.Variant
		copies[key] = (copies[key] or 0) + 1
	end

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
	local equippedCount = 0
	for index, entry in sorted do
		local pet = ConfigLookup.GetPet(entry.PetId)
		local variant = ConfigLookup.GetVariant(entry.Variant)
		local isEquipped = equipped[entry.Uid] == true
		if isEquipped then
			equippedCount += 1
		end
		local multipliers = ConfigLookup.GetPetMultipliers(entry.PetId, entry.Variant)
		local canMerge = (copies[entry.PetId .. "/" .. entry.Variant] or 0) >= PetConfig.MaxMergedFrom
			and variant ~= nil
			and variant.NextVariant ~= ""
		local rarityName = if pet ~= nil then pet.Rarity else ""
		cards[entry.Uid] = e(ItemCard, {
			buttonSwatch = if canMerge then "Purple" elseif isEquipped then "Red" else "Green",
			buttonText = if canMerge then Pets.MergeText elseif isEquipped then Pets.UnequipText else Pets.EquipText,
			icon = Pets.PetIcon,
			iconColor = if pet ~= nil then pet.Color else nil,
			info = string.format(
				Pets.MultiplierFormat,
				Format.multiplier(multipliers.Coins),
				Format.multiplier(multipliers.Stink)
			),
			layoutOrder = index,
			onButton = function()
				if canMerge then
					Net.MergePet:Fire(entry.Uid)
				elseif isEquipped then
					Net.UnequipPet:Fire(entry.Uid)
				else
					Net.EquipPet:Fire(entry.Uid)
				end
			end,
			rarityColor = LobbyUIConfig.RarityColors[rarityName],
			selected = isEquipped,
			swatch = "Blue",
			tag = if variant ~= nil and variant.Id ~= "Default" then variant.DisplayName else nil,
			title = if pet ~= nil then pet.DisplayName else entry.PetId,
		})
	end
	return cards, #sorted, equippedCount, state.Slots or PetConfig.BaseSlots
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Pets.Width, Pets.Height)
	local tab, setTab = React.useState(Pets.Tabs[1].Id)
	local data = props.data
	local headerHeight = LobbyUIConfig.Tabs.Height + Gap + TextSizes.Large + Gap

	local cards, count, info
	if tab == "Inventory" then
		local equippedCount, slots
		cards, count, equippedCount, slots = petCards(data)
		info = string.format(Pets.SlotsFormat, equippedCount, slots)
	else
		cards, count = eggCards(data)
		local last = data.LastHatch
		if last ~= nil then
			local pet = ConfigLookup.GetPet(last.PetId)
			local variant = ConfigLookup.GetVariant(last.Variant)
			info = string.format(
				Pets.LastHatchFormat,
				if pet ~= nil then pet.DisplayName else last.PetId,
				if variant ~= nil then variant.DisplayName else last.Variant
			)
		end
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Pets.Swatch,
		title = Pets.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Pets.Tabs }),
		Info = Primitives.text({
			Color = UIConfig.Palette.Sparkle,
			Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(1, 0, 0, TextSizes.Large),
			Text = info or "",
			TextSize = TextSizes.Large,
		}),
		Grid = e(CardGrid, {
			cards = cards,
			count = count,
			emptyText = Pets.EmptyText,
			position = UDim2.fromOffset(0, headerHeight),
			size = UDim2.new(1, 0, 1, -headerHeight),
		}),
	})
end
