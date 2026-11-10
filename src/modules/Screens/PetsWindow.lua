--!strict

--[[
	PetsWindow
	Two tabs. My Pets: a rarity-coloured card grid with an equipped check and a variant tag, and
	a details panel (or a phone bottom sheet) with the big pet, Stink, stacks and EQUIP /
	EVOLVE / DELETE actions. Pet Index: map tabs, a progress bar with the exclusive pet reward
	box and a discovered / silhouette grid. The header line shows equipped slots and total
	Stink. All actions send the existing pet remotes.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, SparkleClock, Net, UIConfig, LobbyUIConfig, PetConfig, ConfigLookup,
		PetView, Bar, Chip, ChunkyButton, Format, Inset, Primitives, Tabs, Window, WindowSize
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
local Bar = require(Components.Bar)
local Burst = require(Components.Burst)
local Chip = require(Components.Chip)
local SparkleClock = require(Components.SparkleClock)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local GlowRing = require(Components.GlowRing)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Tabs = require(Components.Tabs)
local Twinkle = require(Components.Twinkle)
local useBreathe = require(Components.useBreathe)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Motion = LobbyUIConfig.Motion
local Pets = LobbyUIConfig.Pets
local Index = Pets.Index
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Gap = UIConfig.Sizes.Window.Gap
local TextSizes = UIConfig.TextSizes

local function validTab(requested: any): string?
	if type(requested) ~= "string" then
		return nil
	end
	for _, tab in Pets.Tabs do
		if tab.Id == requested then
			return requested
		end
	end
	return nil
end

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

local function equippedSet(data: any): { [string]: boolean }
	local set = {}
	for _, uid in data.Pets.Equipped or {} do
		set[uid] = true
	end
	return set
end

local function sortedOwned(data: any): { any }
	local owned = data.Pets.Pets or {}
	local equipped = equippedSet(data)
	local sorted = table.clone(owned)
	table.sort(sorted, function(a, b)
		local ea, eb = equipped[a.Uid] == true, equipped[b.Uid] == true
		if ea ~= eb then
			return ea
		end
		local pa = ConfigLookup.GetPet(a.PetId)
		local pb = ConfigLookup.GetPet(b.PetId)
		local oa = if pa ~= nil then (ConfigLookup.GetRarity(pa.Rarity) or { Order = 0 }).Order else 0
		local ob = if pb ~= nil then (ConfigLookup.GetRarity(pb.Rarity) or { Order = 0 }).Order else 0
		if oa ~= ob then
			return oa > ob
		end
		return a.Uid < b.Uid
	end)
	return sorted
end

local function mapComplete(data: any, mapId: string): boolean
	local normal = PetView.PoolForMap(mapId)
	if #normal == 0 then
		return false
	end
	for _, pet in normal do
		if not PetView.IsDiscovered(data.Pets.Index, pet.Id) then
			return false
		end
	end
	return true
end

local function rarityOrder(pet: any): number
	if pet == nil then
		return 0
	end
	local rarity = ConfigLookup.GetRarity(pet.Rarity)
	return if rarity ~= nil then rarity.Order else 0
end

local function twinkleRate(pet: any): number
	if pet == nil then
		return 0
	end
	return Motion.RarityTwinkleRates[pet.Rarity] or 0
end

local function raritySwatch(pet: any): string
	if pet == nil then
		return "Grey"
	end
	return LobbyUIConfig.RaritySwatches[pet.Rarity] or "Grey"
end

local function variantSwatch(variant: any): string
	if variant == nil or variant.Id == "Default" then
		return "Purple"
	end
	return Pets.VariantSwatches[variant.Id] or "Purple"
end

local function variantRim(variant: any): any
	if variant == nil or variant.Id == "Default" then
		return nil
	end
	local rim = Pets.VariantRims[variant.Id]
	if rim == nil then
		return nil
	end
	local stroke = e("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = rim.Color or Color3.fromRGB(255, 255, 255),
		Thickness = Shape.RimStroke,
	}, if rim.Colors ~= nil then { Gradient = e("UIGradient", { Color = Primitives.sequence(rim.Colors) }) } else nil)
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Corner = Primitives.corner(Shape.Radius),
		Stroke = stroke,
	})
end

local function stinkText(entry: any): string
	return string.format(
		Pets.PetStinkFormat,
		Format.multiplier(PetView.Stink(entry.PetId, entry.Variant, entry.Stacks or 0))
	)
end

local function PetGridCard(props: any)
	local entry = props.entry
	local pet = props.pet
	local rarity = if pet ~= nil then ConfigLookup.GetRarity(pet.Rarity) else nil
	local rarityColor = if rarity ~= nil
		then rarity.Color
		elseif pet ~= nil then LobbyUIConfig.RarityColors[pet.Rarity]
		else Palette.Inset
	local variant = props.variant
	local variantName = if variant ~= nil and variant.Id ~= "Default" then variant.DisplayName else ""
	local rate = twinkleRate(pet)

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
		Size = UDim2.fromScale(1, 1),
	}, {
		Card = e(ChunkyButton, {
			onActivated = props.onSelect,
			overlay = if props.selected
				then e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Palette.Sparkle,
					Thickness = Shape.RimStroke,
				})
				else variantRim(props.variant),
			popDelay = props.order * UIConfig.Animation.CardStagger,
			popIn = true,
			rainbow = rarityOrder(pet) >= Motion.RainbowMinOrder,
			rarity = if pet ~= nil then pet.Rarity else nil,
			size = UDim2.fromScale(1, 1),
			swatch = raritySwatch(pet),
			zIndex = 2,
		}, {
			Icon = Primitives.text({
				Position = UDim2.new(0, 0, 0.08, 0),
				Size = UDim2.new(1, 0, 0.48, 0),
				Stroke = false,
				Text = if pet ~= nil then (pet.Icon or Pets.PetIcon) else Pets.PetIcon,
				TextSize = Pets.CardIconSize,
				ZIndex = 3,
			}),
			Name = Primitives.text({
				Fit = true,
				Position = UDim2.new(0.04, 0, 0.58, 0),
				Size = UDim2.new(0.92, 0, 0, TextSizes.Body),
				Text = if pet ~= nil then pet.DisplayName else entry.PetId,
				TextSize = TextSizes.Body,
				ZIndex = 3,
			}),
			Stink = e(Chip, {
				anchorPoint = Vector2.new(0.5, 1),
				height = 22,
				position = UDim2.new(0.5, 0, 1, -4),
				swatch = "Brown",
				text = props.stinkText,
				textSize = TextSizes.Tiny,
				zIndex = 4,
			}),
			RarityStrip = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = rarityColor,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, Shape.Lip),
				ZIndex = 3,
			}, { Corner = Primitives.corner(Shape.Lip) }),
			Equipped = if props.equipped
				then e(ChunkyButton, {
					position = UDim2.fromOffset(4, 4),
					radius = "Round",
					size = UDim2.fromOffset(26, 26),
					swatch = "Green",
					text = Pets.EquippedIcon,
					textSize = TextSizes.Small,
					zIndex = 5,
				})
				else nil,
			Variant = if variantName ~= ""
				then e(Chip, {
					anchorPoint = Vector2.new(1, 0),
					height = 22,
					position = UDim2.new(1, -4, 0, 4),
					swatch = variantSwatch(variant),
					text = variantName,
					textSize = TextSizes.Tiny,
					zIndex = 5,
				})
				else nil,
			Twinkle = if rate > 0 then e(Twinkle, { clip = true, rate = rate, zIndex = 5 }) else nil,
		}),
	})
end

local function PetDetails(props: any)
	local entry = props.entry
	if entry == nil then
		return e(Inset, {
			radius = Shape.Radius,
			size = UDim2.fromScale(1, 1),
		}, {
			Empty = Primitives.text({
				Color = Palette.TextSoft,
				Text = Pets.DetailsEmptyText,
				TextSize = TextSizes.Large,
				Wrapped = true,
			}),
		})
	end

	local pet = ConfigLookup.GetPet(entry.PetId)
	local variant = ConfigLookup.GetVariant(entry.Variant)
	local rarity = if pet ~= nil then ConfigLookup.GetRarity(pet.Rarity) else nil
	local equipped = props.equipped
	local copies = props.copies
	local hasNext = variant ~= nil and variant.NextVariant ~= nil and variant.NextVariant ~= ""
	local canEvolve = hasNext and copies >= PetConfig.MaxMergedFrom
	local evolveText = if not hasNext
		then Pets.EvolveMaxText
		elseif canEvolve then Pets.EvolveText
		else string.format(Pets.EvolveNeedFormat, PetConfig.MaxMergedFrom)
	local stacks = math.max(0, math.floor(tonumber(entry.Stacks) or 0))
	local stackCap = PetView.StackCap()
	local stackRatio = if stackCap > 0 then math.min(1, stacks / stackCap) else 0
	local stackText = if stackCap > 0
		then string.format(Pets.StackFormat, stacks, stackCap)
		else string.format(Pets.StackOnlyFormat, stacks)
	local iconRef = React.useRef(nil)
	local panelHeight = props.height or 0

	React.useEffect(function()
		local label = iconRef.current
		if label == nil then
			return
		end
		local disconnect = SparkleClock.Subscribe(function(_dt: number, now: number)
			label.Rotation = math.sin(now * Pets.DetailSwaySpeed) * Pets.DetailSwayDegrees
		end)
		return function()
			disconnect()
		end
	end, {})

	local actionsHeight = Pets.ActionHeight * 3 + Gap * 2
	local panelSize = if panelHeight > 0 then UDim2.new(1, 0, 0, panelHeight) else UDim2.fromScale(1, 1)

	return e(Inset, {
		radius = Shape.Radius,
		size = panelSize,
	}, {
		Icon = Primitives.text({
			Position = UDim2.new(0, 0, 0, 12),
			Size = UDim2.new(1, 0, 0, Pets.DetailsIconSize),
			Stroke = false,
			Text = if pet ~= nil then (pet.Icon or Pets.PetIcon) else Pets.PetIcon,
			TextSize = Pets.DetailsIconSize,
			ZIndex = 3,
			ref = iconRef,
		}),
		Name = Primitives.text({
			Color = Palette.Text,
			Fit = true,
			Position = UDim2.new(0.06, 0, 0, Pets.DetailsIconSize + 8),
			Size = UDim2.new(0.88, 0, 0, TextSizes.Title),
			Text = if pet ~= nil then pet.DisplayName else entry.PetId,
			TextSize = TextSizes.Title,
			ZIndex = 3,
		}),
		Rarity = e(Chip, {
			anchorPoint = Vector2.new(0.5, 0),
			height = 28,
			position = UDim2.new(0.5, 0, 0, Pets.DetailsIconSize + 12 + TextSizes.Title),
			swatch = raritySwatch(pet),
			text = if rarity ~= nil then rarity.DisplayName else (if pet ~= nil then pet.Rarity else ""),
			textSize = TextSizes.Body,
			zIndex = 4,
		}),
		Stink = Primitives.text({
			Color = Palette.Sparkle,
			Fit = true,
			Position = UDim2.new(0.06, 0, 0, Pets.DetailsIconSize + 54 + TextSizes.Title),
			Size = UDim2.new(0.88, 0, 0, TextSizes.Header),
			Text = stinkText(entry),
			TextSize = TextSizes.Header,
			ZIndex = 3,
		}),
		Stacks = e(Bar, {
			Position = UDim2.new(0.06, 0, 0, Pets.DetailsIconSize + 94 + TextSizes.Title),
			ratio = stackRatio,
			size = UDim2.new(0.88, 0, 0, Pets.StackBarHeight),
			swatch = "Brown",
			text = stackText,
			textSize = TextSizes.Tiny,
		}),
		Variant = Primitives.text({
			Color = Palette.TextSoft,
			Fit = true,
			Font = "Body",
			Position = UDim2.new(0.06, 0, 0, Pets.DetailsIconSize + 118 + TextSizes.Title),
			Size = UDim2.new(0.88, 0, 0, TextSizes.Body),
			StrokeSize = Shape.SmallTextStroke,
			Text = if variant ~= nil then variant.DisplayName else entry.Variant,
			TextSize = TextSizes.Small,
			ZIndex = 3,
		}),
		Actions = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -Gap),
			Size = UDim2.new(0.88, 0, 0, actionsHeight),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
			Equip = e(ChunkyButton, {
				layoutOrder = 1,
				onActivated = function()
					if equipped then
						Net.UnequipPet:Fire(entry.Uid)
					else
						Net.EquipPet:Fire(entry.Uid)
					end
				end,
				shine = not equipped,
				size = UDim2.new(1, 0, 0, Pets.ActionHeight),
				swatch = if equipped then "Red" else "Green",
				text = if equipped then Pets.UnequipText else Pets.EquipText,
				textSize = TextSizes.Body,
			}),
			Evolve = e(ChunkyButton, {
				enabled = canEvolve,
				layoutOrder = 2,
				shine = canEvolve,
				onActivated = function()
					Net.MergePet:Fire(entry.Uid)
				end,
				size = UDim2.new(1, 0, 0, Pets.ActionHeight),
				swatch = "Purple",
				text = string.format("%s %d/%d", evolveText, copies, PetConfig.MaxMergedFrom),
				textSize = TextSizes.Small,
			}),
			Delete = e(ChunkyButton, {
				layoutOrder = 3,
				onActivated = props.onDelete,
				size = UDim2.new(1, 0, 0, Pets.ActionHeight),
				swatch = "Red",
				text = if props.confirm then Pets.DeleteConfirmText else Pets.DeleteText,
				textSize = TextSizes.Body,
			}),
		}),
	})
end

local function indexTile(pet: any, discovered: boolean, order: number): any
	local rarity = ConfigLookup.GetRarity(pet.Rarity)
	local odds = PetView.DropOdds(pet)
	local name = if discovered then pet.DisplayName else Index.UnknownName
	local icon = if discovered then (pet.Icon or Pets.PetIcon) else Index.LockedIcon
	local rarityName = if rarity ~= nil then rarity.DisplayName else pet.Rarity
	local oddsText = if odds > 0 then string.format(Index.OddsFormat, Format.multiplier(odds)) else ""
	local swatchName = if discovered then raritySwatch(pet) else "Grey"
	local swatch = Primitives.swatch(swatchName)
	local wellColor = if not discovered
		then Palette.Ink
		elseif rarity ~= nil then rarity.Color
		else LobbyUIConfig.RarityColors[pet.Rarity] or Palette.Inset

	local rate = if discovered then twinkleRate(pet) else 0

	return e(ChunkyButton, {
		layoutOrder = order,
		popDelay = order * UIConfig.Animation.CardStagger,
		popIn = true,
		rainbow = discovered and rarityOrder(pet) >= Motion.RainbowMinOrder,
		rarity = if discovered then pet.Rarity else nil,
		swatch = swatchName,
	}, {
		Well = e("Frame", {
			BackgroundColor3 = wellColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(Index.TilePadding, Index.TilePadding),
			Size = UDim2.new(1, -Index.TilePadding * 2, 0.46, 0),
			ZIndex = 3,
		}, {
			Corner = Primitives.corner(Shape.Radius),
			Gradient = if discovered then Primitives.gradient(swatch.Top, swatch.Bottom) else nil,
			Stroke = Primitives.stroke(Palette.InsetStroke, Shape.Stroke),
			Icon = Primitives.text({
				Stroke = false,
				Text = icon,
				TextSize = Index.TileIconSize,
				ZIndex = 4,
			}),
		}),
		Name = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Fit = true,
			Position = UDim2.new(0.5, 0, 0.48, 2),
			Size = UDim2.new(0.92, 0, 0, TextSizes.Body),
			Text = name,
			TextSize = TextSizes.Body,
			ZIndex = 3,
		}),
		Rarity = e(Chip, {
			anchorPoint = Vector2.new(0.5, 1),
			height = 20,
			position = UDim2.new(0.5, 0, 1, -26),
			swatch = swatchName,
			text = rarityName,
			textSize = TextSizes.Tiny,
			zIndex = 4,
		}),
		Odds = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Palette.TextSoft,
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(0.92, 0, 0, TextSizes.Small),
			Text = oddsText,
			TextSize = TextSizes.Small,
			XAlign = Enum.TextXAlignment.Center,
			ZIndex = 3,
		}),
		Twinkle = if rate > 0 then e(Twinkle, { clip = true, rate = rate, zIndex = 5 }) else nil,
	})
end

local function mapTabs(): { any }
	local tabs = {}
	for _, map in ConfigLookup.GetSortedMaps() do
		local visual = UIConfig.MapVisuals[map.Id] or {}
		local soon = isComingSoon(map)
		table.insert(tabs, {
			Icon = if soon then Index.MapComingSoonIcon else (visual.Icon or "🗺️"),
			Id = map.Id,
			Label = map.DisplayName,
			Swatch = if soon then "Grey" else (visual.Swatch or "Grey"),
		})
	end
	return tabs
end

local function RewardBox(props: any): any
	local map = props.map
	local data = props.data
	local exclusive = PetView.ExclusivePet(map.Id)
	local claimed = data.Pets.IndexClaimed[map.Id] == true
	local normal = PetView.PoolForMap(map.Id)
	local discovered = 0
	for _, pet in normal do
		if PetView.IsDiscovered(data.Pets.Index, pet.Id) then
			discovered += 1
		end
	end
	local complete = #normal > 0 and discovered >= #normal
	local earned = claimed or complete
	local claimable = complete
	local text = if exclusive ~= nil
		then string.format(Index.RewardGemsFormat, PetView.IndexGems())
		elseif isComingSoon(map) then Index.ComingSoonText
		else Index.NoPetsText
	local scaleRef = React.useRef(nil)
	useBreathe(scaleRef, Motion.BreatheRewardScale, Motion.BreatheRewardPeriod, 0.23, claimable)

	local boxWidth = props.width or Index.RewardBoxWidth
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(boxWidth, Index.RewardBoxHeight),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Glow = if claimable
			then e(GlowRing, {
				radius = Shape.Radius,
				swatch = "Gold",
				zIndex = 1,
			})
			else nil,
		Button = e(ChunkyButton, {
			overlay = if claimable
				then e("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					Corner = Primitives.corner(Shape.Radius),
					Stroke = Primitives.stroke(UIConfig.Swatches.Gold.Top, Shape.RimStroke),
				})
				else nil,
			shine = claimable,
			size = UDim2.fromScale(1, 1),
			swatch = "Gold",
			zIndex = 3,
		}, {
			Icon = Primitives.text({
				Position = UDim2.fromScale(0, 0.1),
				Size = UDim2.fromScale(0.5, 0.8),
				Stroke = false,
				Text = if exclusive ~= nil then (exclusive.Icon or Pets.PetIcon) else Index.LockedIcon,
				TextSize = TextSizes.Icon,
				ZIndex = 4,
			}),
			Label = Primitives.text({
				Fit = true,
				Position = UDim2.fromScale(0.42, 0),
				Size = UDim2.fromScale(0.54, 1),
				Text = text,
				TextSize = TextSizes.Small,
				Wrapped = true,
				ZIndex = 4,
			}),
			Stamp = if earned
				then e(Chip, {
					anchorPoint = Vector2.new(0.5, 1),
					height = 22,
					position = UDim2.new(0.5, 0, 1, -2),
					swatch = "Green",
					text = Index.ClaimedText,
					textSize = TextSizes.Tiny,
					zIndex = 5,
				})
				else nil,
			Twinkle = e(Twinkle, {
				clip = true,
				rate = Motion.RewardTwinkleRate,
				zIndex = 5,
			}),
		}),
	})
end

return function(props: any)
	local data = props.data
	local ui = props.ui
	local width, height = WindowSize.fit(ui, Pets.Width, Pets.Height)
	local tab, setTab = React.useState(validTab(props.initialTab) or Pets.Tabs[1].Id)
	local selectedUid, setSelectedUid = React.useState(nil :: string?)
	local confirmUid, setConfirmUid = React.useState(nil :: string?)
	local selectedMap, setSelectedMap = React.useState(ConfigLookup.GetSortedMaps()[1].Id)
	local narrow = ui.mobile or ui.safeWidth < 900
	local isIndex = tab == Pets.Tabs[2].Id
	local burst, setBurst = React.useState(0)
	local celebratedMaps = React.useRef({})

	React.useEffect(function()
		if not isIndex or celebratedMaps.current[selectedMap] or not mapComplete(data, selectedMap) then
			return
		end
		celebratedMaps.current[selectedMap] = true
		setBurst(function(count: number)
			return count + 1
		end)
	end, { isIndex, selectedMap, data.Pets.Index } :: { any })

	local function selectMap(id: string)
		local map = ConfigLookup.GetMap(id)
		if map == nil or isComingSoon(map) then
			return
		end
		setSelectedMap(id)
	end

	React.useEffect(function()
		setConfirmUid(nil)
		setSelectedUid(nil)
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

	local owned = sortedOwned(data)
	local equipped = equippedSet(data)
	local copies = copiesOf(data.Pets.Pets or {})
	local selected = nil
	for _, entry in owned do
		if entry.Uid == selectedUid then
			selected = entry
			break
		end
	end

	local headerLine = string.format(
		Pets.HeaderFormat,
		#(data.Pets.Equipped or {}),
		data.Pets.Slots or 0,
		string.format(Pets.StinkHeaderFormat, PetView.TotalStink(data))
	)

	local innerWidth = width - UIConfig.Sizes.Window.Padding * 2
	local body
	if isIndex then
		local tabs = mapTabs()
		local map = ConfigLookup.GetMap(selectedMap)
		local normal = PetView.PoolForMap(selectedMap)
		local discovered = 0
		for _, pet in normal do
			if PetView.IsDiscovered(data.Pets.Index, pet.Id) then
				discovered += 1
			end
		end
		local total = #normal
		local rewardBoxWidth = if narrow then 160 else Index.RewardBoxWidth
		local progressChildren: { [string]: any } = {
			Progress = e(Bar, {
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.new(0, 0, 0.5, 0),
				ratio = if total > 0 then discovered / total else 0,
				size = UDim2.new(1, -(rewardBoxWidth + Gap), 0, 30),
				swatch = "Purple",
				text = string.format(Index.ProgressFormat, discovered, total),
				textSize = TextSizes.Body,
			}),
			Reward = if map ~= nil then e(RewardBox, { data = data, map = map, width = rewardBoxWidth }) else nil,
		}

		local indexColumns = if narrow then (Index.PhoneColumns or 2) else Index.Columns
		local indexUsableWidth = innerWidth - Shape.ScrollBar - 8
		local indexTileWidth = math.floor((indexUsableWidth - Gap * (indexColumns - 1)) / indexColumns)
		local indexTileHeight =
			math.max(Index.TileHeight, math.floor(indexTileWidth * (Index.TileHeight / Index.TileWidth)))

		local gridChildren: { [string]: any } = {
			Grid = e("UIGridLayout", {
				CellPadding = UDim2.fromOffset(Gap, Gap),
				CellSize = UDim2.fromOffset(indexTileWidth, indexTileHeight),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, Shape.ShadowOffset * 2 + Gap),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
			}),
		}
		if map ~= nil and not isComingSoon(map) then
			for index, pet in normal do
				gridChildren["Pet" .. pet.Id] = indexTile(pet, PetView.IsDiscovered(data.Pets.Index, pet.Id), index)
			end
		end
		local bodyTop = LobbyUIConfig.Tabs.Height + Gap + Index.RewardBoxHeight + Gap
		body = {
			MapTabs = e(Tabs, { onSelect = selectMap, selected = selectedMap, shortcuts = false, tabs = tabs }),
			Progress = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
				Size = UDim2.new(1, 0, 0, Index.RewardBoxHeight),
			}, progressChildren),
			Grid = Primitives.scroll({
				Position = UDim2.fromOffset(0, bodyTop),
				Size = UDim2.new(1, 0, 1, -bodyTop),
			}, gridChildren),
		}
	else
		local petColumns = if narrow then Pets.PhoneColumns else Pets.Columns
		local petGridWidth = if narrow then innerWidth else (innerWidth - Pets.DetailsWidth - Pets.DetailsGap)
		local petUsableWidth = petGridWidth - Shape.ScrollBar - 8
		local petCardWidth = math.floor((petUsableWidth - Pets.CardGap * (petColumns - 1)) / petColumns)
		local petCardHeight = math.floor(petCardWidth * (Pets.CardHeight / Pets.CardWidth))

		local gridChildren: { [string]: any } = {
			Grid = e("UIGridLayout", {
				CellPadding = UDim2.fromOffset(Pets.CardGap, Pets.CardGap),
				CellSize = UDim2.fromOffset(petCardWidth, petCardHeight),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, Shape.ShadowOffset * 2 + Pets.CardGap),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
			}),
		}
		for index, entry in owned do
			local pet = ConfigLookup.GetPet(entry.PetId)
			local variant = ConfigLookup.GetVariant(entry.Variant)
			gridChildren[entry.Uid] = e(PetGridCard, {
				entry = entry,
				equipped = equipped[entry.Uid] == true,
				onSelect = function()
					setSelectedUid(entry.Uid)
				end,
				order = index,
				pet = pet,
				selected = entry.Uid == selectedUid,
				stinkText = stinkText(entry),
				variant = variant,
			})
		end
		if #owned == 0 then
			gridChildren.Empty = Primitives.text({
				Color = Palette.TextSoft,
				Text = Pets.EmptyText,
				TextSize = TextSizes.Large,
			})
		end

		local grid = Primitives.scroll({ Size = UDim2.fromScale(1, 1) }, gridChildren)
		local details = e(PetDetails, {
			confirm = confirmUid == (if selected ~= nil then selected.Uid else nil),
			copies = if selected ~= nil then copies[selected.PetId .. "/" .. selected.Variant] or 0 else 0,
			entry = selected,
			equipped = selected ~= nil and equipped[selected.Uid] == true,
			onDelete = function()
				if selected == nil then
					return
				end
				if confirmUid == selected.Uid then
					Net.DeletePet:Fire(selected.Uid)
					setConfirmUid(nil)
					setSelectedUid(nil)
				else
					setConfirmUid(selected.Uid)
				end
			end,
		})

		local bodyChildren: { [string]: any } = {}
		if narrow then
			bodyChildren.Grid = grid
			if selected ~= nil then
				bodyChildren.Backdrop = e("TextButton", {
					AutoButtonColor = false,
					BackgroundColor3 = Palette.Ink,
					BackgroundTransparency = 0.45,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = "",
					[React.Event.Activated] = function()
						setSelectedUid(nil)
					end,
					ZIndex = 5,
				})
				bodyChildren.Sheet = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = Palette.PanelTop,
					BackgroundTransparency = 0.05,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.new(1, 0, 0, Pets.SheetHeight),
					ZIndex = 6,
				}, {
					Corner = Primitives.corner(Shape.WindowRadius),
					Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
					Close = e(ChunkyButton, {
						anchorPoint = Vector2.new(1, 0),
						onActivated = function()
							setSelectedUid(nil)
						end,
						position = UDim2.new(1, -Gap, 0, Gap),
						radius = Shape.Radius,
						size = UDim2.fromOffset(Pets.SheetCloseSize, Pets.SheetCloseSize),
						swatch = "Red",
						text = UIConfig.Text.CloseIcon,
						textSize = TextSizes.Body,
						zIndex = 7,
					}),
					Scroll = Primitives.scroll({
						Position = UDim2.fromOffset(Gap, Pets.SheetCloseSize + Gap),
						Size = UDim2.new(1, -Gap * 2, 1, -(Pets.SheetCloseSize + Gap * 2)),
					}, {
						Padding = e("UIPadding", {
							PaddingBottom = UDim.new(0, Gap * 2),
							PaddingLeft = UDim.new(0, 4),
							PaddingRight = UDim.new(0, 4),
							PaddingTop = UDim.new(0, 4),
						}),
						Details = e(PetDetails, {
							confirm = confirmUid == selected.Uid,
							copies = copies[selected.PetId .. "/" .. selected.Variant] or 0,
							entry = selected,
							equipped = equipped[selected.Uid] == true,
							height = 520,
							onDelete = function()
								if confirmUid == selected.Uid then
									Net.DeletePet:Fire(selected.Uid)
									setConfirmUid(nil)
									setSelectedUid(nil)
								else
									setConfirmUid(selected.Uid)
								end
							end,
						}),
					}),
				})
			end
		else
			bodyChildren.Grid = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -(Pets.DetailsWidth + Pets.DetailsGap), 1, 0),
			}, { Content = grid })
			bodyChildren.Details = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, Pets.DetailsWidth, 1, 0),
			}, { Content = details })
		end

		local headerTop = LobbyUIConfig.Tabs.Height + Gap
		body = {
			Header = Primitives.text({
				Position = UDim2.fromOffset(0, headerTop),
				Size = UDim2.new(1, 0, 0, Pets.HeaderLineHeight),
				Text = headerLine,
				TextSize = TextSizes.Large,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Content = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, headerTop + Pets.HeaderLineHeight + Gap),
				Size = UDim2.new(1, 0, 1, -(headerTop + Pets.HeaderLineHeight + Gap)),
			}, bodyChildren),
		}
	end

	local bodyTop = if isIndex
		then LobbyUIConfig.Tabs.Height + Gap
		else LobbyUIConfig.Tabs.Height + Gap + Pets.HeaderLineHeight + Gap

	return e(Window, {
		height = height,
		icon = Pets.Icon,
		onClose = props.onClose,
		swatch = if isIndex then "Purple" else Pets.Swatch,
		title = if isIndex then Pets.Tabs[2].Label else Pets.Title,
		width = width,
	}, {
		Tabs = e(Tabs, { onSelect = setTab, selected = tab, tabs = Pets.Tabs }),
		Burst = e(Burst, {
			origin = UDim2.fromScale(0.5, 0.5),
			trigger = if burst > 0 then burst else nil,
			zIndex = 20,
		}),
		Header = body.Header,
		Body = if isIndex
			then e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, bodyTop),
				Size = UDim2.new(1, 0, 1, -bodyTop),
			}, body)
			else body.Content,
	})
end
