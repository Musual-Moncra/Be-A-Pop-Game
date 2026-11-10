--!strict

--[[
	PlayWindow
	The play window, with four views driven by RoomController:
		Play: one card per map; an owned map has a big PLAY button (Net.QuickPlay, one-tap solo
			run) and PLAY WITH FRIENDS, which opens the Create view for that map. ComingSoon
			maps are greyed and locked maps show their unlock state.
		Create: map cards (ComingSoon greyed, previous map must be 100% when
			RequirePreviousComplete), mode tiles, room-size selector and friends-only switch;
			the footer button sends Net.CreateRoom. Map unlock buttons keep firing Net.UnlockMap.
		Browse: Net.RoomList rows (host, map, mode, players, friends badge, JOIN), friends'
			rooms first, with an empty state. Fires Net.WatchRooms true while open, false on close.
		Room: map/mode summary, member list with level, ready and host marks, kick for the host,
			friends in this server with INVITE, READY / START, host EDIT while Waiting, LEAVE
			and the countdown from StartsAt on the server clock.
	The host's EDIT reopens the Create form and sends Net.UpdateRoom.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, UIConfig, LobbyUIConfig, RoomConfig, ConfigLookup, Net, RoomController,
		Primitives, ChunkyButton, Chip, Inset, Tabs, Window, WindowSize, Format
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local RoomConfig = require(ReplicatedStorage.Modules.Config.RoomConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RoomController = require(ReplicatedStorage.Modules.Controllers.RoomController)
local Components = ReplicatedStorage.Modules.UIComponents
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Tabs = require(Components.Tabs)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Play
local RoomSizes = UIConfig.Sizes.Room
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local Views = {
	Play = "Play",
	Create = "Create",
	Browse = "Browse",
	Room = "Room",
	Settings = "Settings",
}

local function isComingSoon(map: any): boolean
	local raw = map :: any
	return map.Enabled == false or raw.ComingSoon == true
end

local function mapStatus(data: any, map: any): (string, string?)
	if isComingSoon(map) then
		return "Soon", nil
	end
	if data.UnlockedMaps[map.Id] then
		return "Owned", nil
	end
	local previous = ConfigLookup.GetPreviousMap(map.Id)
	if previous ~= nil and not data.UnlockedMaps[previous.Id] then
		return "Blocked", string.format(Text.NeedMapFirst, previous.DisplayName)
	end
	if
		previous ~= nil
		and (map :: any).RequirePreviousComplete == true
		and (data.BestMapProgress[previous.Id] or 0) < 100
	then
		return "Blocked", string.format(Text.RequireCompleteFormat, previous.DisplayName)
	end
	if data.Level < map.RequiredLevel then
		return "Blocked", string.format(Text.NeedLevel, map.RequiredLevel)
	end
	return "Buyable", nil
end

local function sectionTitle(text: string, order: number)
	return Primitives.text({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, TextSizes.Large + Shape.Stroke * 2),
		Text = text,
		TextSize = TextSizes.Large,
		XAlign = Enum.TextXAlignment.Left,
	})
end

local function selectionRing(visible: boolean)
	if not visible then
		return nil
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-Shape.RimStroke, -Shape.RimStroke),
		Size = UDim2.new(1, Shape.RimStroke * 2, 1, Shape.RimStroke * 2 - Shape.Lip),
		ZIndex = 4,
	}, {
		Corner = Primitives.corner(Shape.Radius + Shape.RimStroke),
		Stroke = Primitives.stroke(Palette.Sparkle, Shape.RimStroke),
	})
end

local function mapIcon(mapId: string, size: number)
	local visual = UIConfig.MapVisuals[mapId] or {}
	return e(Inset, {
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.fromScale(0, 0.5),
		radius = "Round",
		size = UDim2.fromOffset(size, size),
	}, {
		Emoji = Primitives.text({
			Stroke = false,
			Text = visual.Icon or "",
			TextSize = size * Shape.IconFill,
		}),
	})
end

local function MapCard(props: any)
	local map = props.map
	local data = props.data
	local visual = UIConfig.MapVisuals[map.Id] or {}
	local status, reason = mapStatus(data, map)
	local locked = status ~= "Owned"
	local chipHeight = Sizes.ActionButtonHeight - Shape.Lip

	local action
	if status == "Owned" then
		action = e(Chip, {
			height = chipHeight,
			swatch = "Green",
			text = string.format(Text.IconLabel, Text.CheckIcon, Text.Owned),
		})
	elseif status == "Soon" then
		action = e(Chip, { height = chipHeight, swatch = "Grey", text = Text.ComingSoon })
	elseif status == "Buyable" then
		action = e(ChunkyButton, {
			enabled = data.Coins >= map.UnlockCost,
			onActivated = function()
				Net.UnlockMap:Fire(map.Id)
			end,
			size = UDim2.fromOffset(Sizes.ActionButtonWidth, Sizes.ActionButtonHeight),
			swatch = "Green",
			text = string.format(Text.IconLabel, Text.CoinIcon, Format.compact(map.UnlockCost)),
			textSize = TextSizes.Body,
		})
	else
		action = e(Chip, {
			height = chipHeight,
			swatch = "Red",
			text = string.format(Text.IconLabel, Text.LockIcon, Text.MapLocked),
		})
	end

	local infoLeft = Sizes.MapIconSize + Gap
	local descriptionHeight = math.ceil(TextSizes.Small * Sizes.DescriptionLines * Shape.LineHeight)

	if props.quick then
		local quickInfoLeft = Sizes.QuickIconSize + Gap
		local quickAction
		if status == "Owned" then
			quickAction = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 1, 1, -Shape.Lip),
				Size = UDim2.new(1, 0, 0, Sizes.QuickButtonHeight),
			}, {
				Layout = Primitives.list(
					Enum.FillDirection.Horizontal,
					Gap / 2,
					Enum.HorizontalAlignment.Left,
					Enum.VerticalAlignment.Center
				),
				Play = e(ChunkyButton, {
					layoutOrder = 1,
					name = "OnboardingPlayButton",
					onActivated = function()
						props.onQuickPlay(map.Id)
					end,
					shine = true,
					size = UDim2.fromOffset(Sizes.QuickPlayWidth, Sizes.QuickButtonHeight),
					swatch = "Green",
					text = Text.QuickPlay,
					textSize = TextSizes.Title,
				}),
				Friends = e(ChunkyButton, {
					layoutOrder = 2,
					onActivated = function()
						props.onFriends(map.Id)
					end,
					size = UDim2.fromOffset(Sizes.QuickFriendsWidth, Sizes.QuickButtonHeight),
					swatch = "Blue",
					text = Text.PlayWithFriends,
					textSize = TextSizes.Body,
				}),
			})
		else
			quickAction = e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(0, Sizes.ActionButtonHeight),
			}, {
				Layout = Primitives.list(
					Enum.FillDirection.Horizontal,
					0,
					Enum.HorizontalAlignment.Right,
					Enum.VerticalAlignment.Top
				),
				Content = action,
			})
		end

		return e(ChunkyButton, {
			layoutOrder = map.Order,
			size = UDim2.new(1, -Shape.RimStroke * 2, 0, Sizes.QuickCardHeight),
			swatch = if status == "Soon" then "Grey" else visual.Swatch,
		}, {
			Padding = Primitives.paddingXY(Gap, Gap / 2),
			Icon = e(Inset, {
				radius = "Round",
				size = UDim2.fromOffset(Sizes.QuickIconSize, Sizes.QuickIconSize),
			}, {
				Emoji = Primitives.text({
					Stroke = false,
					Text = if status == "Soon" or (locked and status ~= "Buyable") then Text.LockIcon else visual.Icon,
					TextSize = Sizes.QuickIconSize * Shape.IconFill,
				}),
			}),
			Name = Primitives.text({
				Fit = true,
				Position = UDim2.fromOffset(quickInfoLeft, 0),
				Size = UDim2.new(1, -quickInfoLeft, 0, TextSizes.Header),
				Text = map.DisplayName,
				TextSize = TextSizes.Header,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Description = Primitives.text({
				Color = if reason ~= nil then Palette.Sparkle else Palette.Text,
				Fit = true,
				Font = "Body",
				Position = UDim2.fromOffset(quickInfoLeft, TextSizes.Header + Shape.Stroke),
				Size = UDim2.new(1, -quickInfoLeft, 0, descriptionHeight),
				StrokeSize = Shape.SmallTextStroke,
				Text = if reason ~= nil then string.format(Text.IconLabel, Text.LockIcon, reason) else map.Description,
				TextSize = TextSizes.Small,
				Wrapped = true,
				XAlign = Enum.TextXAlignment.Left,
				YAlign = Enum.TextYAlignment.Top,
			}),
			Action = quickAction,
		})
	end

	return e(ChunkyButton, {
		layoutOrder = map.Order,
		onActivated = function()
			props.onSelect(map.Id)
		end,
		overlay = selectionRing(props.selected),
		size = UDim2.new(1, -Shape.RimStroke * 2, 0, Sizes.MapCardHeight),
		swatch = if status == "Soon" then "Grey" else visual.Swatch,
	}, {
		Padding = Primitives.paddingXY(Gap, Gap / 2),
		Icon = e(Inset, {
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.fromScale(0, 0.5),
			radius = "Round",
			size = UDim2.fromOffset(Sizes.MapIconSize, Sizes.MapIconSize),
		}, {
			Emoji = Primitives.text({
				Stroke = false,
				Text = if status == "Soon" or (locked and status ~= "Buyable") then Text.LockIcon else visual.Icon,
				TextSize = Sizes.MapIconSize * Shape.IconFill,
			}),
		}),
		Name = Primitives.text({
			Fit = true,
			Position = UDim2.fromOffset(infoLeft, 0),
			Size = UDim2.new(1, -infoLeft, 0, TextSizes.Header),
			Text = map.DisplayName,
			TextSize = TextSizes.Header,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Description = Primitives.text({
			Color = if reason ~= nil then Palette.Sparkle else Palette.Text,
			Fit = true,
			Font = "Body",
			Position = UDim2.fromOffset(infoLeft, TextSizes.Header + Shape.Stroke),
			Size = UDim2.new(1, -infoLeft, 0, descriptionHeight),
			StrokeSize = Shape.SmallTextStroke,
			Text = if reason ~= nil then string.format(Text.IconLabel, Text.LockIcon, reason) else map.Description,
			TextSize = TextSizes.Small,
			Wrapped = true,
			XAlign = Enum.TextXAlignment.Left,
			YAlign = Enum.TextYAlignment.Top,
		}),
		Chips = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0, infoLeft, 1, -Shape.Lip),
			Size = UDim2.fromOffset(0, chipHeight),
			AutomaticSize = Enum.AutomaticSize.X,
		}, {
			Layout = Primitives.list(
				Enum.FillDirection.Horizontal,
				Shape.Stroke * 2,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Center
			),
			Size = e(Chip, {
				height = chipHeight,
				layoutOrder = 1,
				swatch = "Blue",
				text = string.format(Text.SizeChip, map.SizeLabel),
			}),
			Reward = e(Chip, {
				height = chipHeight,
				layoutOrder = 2,
				swatch = "Gold",
				text = string.format(Text.RewardChip, Format.multiplier(map.RewardMultiplier)),
			}),
		}),
		Action = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(0, Sizes.ActionButtonHeight),
		}, {
			Layout = Primitives.list(
				Enum.FillDirection.Horizontal,
				0,
				Enum.HorizontalAlignment.Right,
				Enum.VerticalAlignment.Top
			),
			Content = action,
		}),
	})
end

local function ModeTile(props: any)
	local mode = props.mode
	local visual = UIConfig.ModeVisuals[mode.Id] or {}
	local locked = props.level < mode.RequiredLevel
	return e(ChunkyButton, {
		icon = if locked then Text.LockIcon else visual.Icon,
		iconSize = Sizes.ModeIconSize,
		layoutOrder = mode.Order,
		onActivated = function()
			props.onSelect(mode.Id)
		end,
		overlay = selectionRing(props.selected),
		stacked = true,
		swatch = if locked then "Grey" else visual.Swatch,
		text = if locked
			then string.format(Text.LockedModeFormat, mode.DisplayName, mode.RequiredLevel)
			else mode.DisplayName,
		textSize = if locked then TextSizes.Body else TextSizes.Large,
	})
end

local function modeChips(mode: any)
	local chips = {}
	local duration = if mode.Duration == 0
		then Text.DurationLifespan
		elseif mode.Duration < 0 then Text.DurationNone
		else string.format(Text.DurationSeconds, mode.Duration)
	table.insert(chips, { swatch = "Blue", text = duration })
	table.insert(chips, {
		swatch = if mode.PowerupsEnabled then "Orange" else "Grey",
		text = if mode.PowerupsEnabled then Text.FoodOn else Text.FoodOff,
	})
	table.insert(chips, {
		swatch = if mode.NpcsEnabled then "Red" else "Grey",
		text = if mode.NpcsEnabled then Text.ChefsOn else Text.ChefsOff,
	})
	if mode.QuestCount > 0 then
		table.insert(chips, { swatch = "Teal", text = string.format(Text.QuestsChip, mode.QuestCount) })
	end
	if mode.TargetScore > 0 then
		table.insert(chips, { swatch = "Pink", text = string.format(Text.TargetChip, mode.TargetScore) })
	end
	local elements: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Shape.Stroke * 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	}
	for index, chip in chips do
		elements["Chip" .. index] = e(Chip, { layoutOrder = index, swatch = chip.swatch, text = chip.text })
	end
	return elements
end

local function mapList(
	data: any,
	selectedMapId: string,
	onSelect: (string) -> (),
	quick: boolean?,
	onQuickPlay: ((string) -> ())?,
	onFriends: ((string) -> ())?
)
	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap, Enum.HorizontalAlignment.Center),
		Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke * 2),
	}
	for _, entry in ConfigLookup.GetSortedMaps() do
		children[entry.Id] = e(MapCard, {
			data = data,
			map = entry,
			onFriends = onFriends,
			onQuickPlay = onQuickPlay,
			onSelect = onSelect,
			quick = quick,
			selected = entry.Id == selectedMapId,
		})
	end
	return children
end

local function modeGrid(level: number, selectedModeId: string, onSelect: (string) -> ())
	local modes = ConfigLookup.GetSortedModes()
	local columns = Sizes.ModeColumns
	local children: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.new(1 / columns, -Gap * (columns - 1) / columns, 0, Sizes.ModeTileHeight),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, entry in modes do
		children[entry.Id] = e(ModeTile, {
			level = level,
			mode = entry,
			onSelect = onSelect,
			selected = entry.Id == selectedModeId,
		})
	end
	return children, math.ceil(#modes / columns)
end

local function viewTabs(selected: string, onSelect: (string) -> ())
	return e(Tabs, {
		onSelect = onSelect,
		selected = selected,
		tabs = {
			{ Id = Views.Play, Label = Text.PlayTab, Swatch = "Green" },
			{ Id = Views.Create, Label = Text.CreateTab, Swatch = "Orange" },
			{ Id = Views.Browse, Label = Text.BrowseTab, Swatch = "Blue" },
		},
	})
end

local function playerSelector(maxPlayers: number, onSelect: (number) -> ())
	local options: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Horizontal, Gap / 2, Enum.HorizontalAlignment.Left),
	}
	for index, count in RoomConfig.PlayerOptions do
		options["Option" .. count] = e(ChunkyButton, {
			layoutOrder = index,
			onActivated = function()
				onSelect(count)
			end,
			size = UDim2.fromOffset(RoomSizes.PlayerOptionWidth, RoomSizes.PlayerOptionHeight),
			swatch = if count == maxPlayers then "Orange" else "Grey",
			text = tostring(count),
			textSize = TextSizes.Large,
		})
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, RoomSizes.PlayerOptionHeight),
	}, options)
end

local function friendsToggle(friendsOnly: boolean, onToggle: () -> ())
	return e(ChunkyButton, {
		onActivated = onToggle,
		size = UDim2.fromOffset(RoomSizes.ToggleWidth, RoomSizes.ToggleHeight),
		swatch = if friendsOnly then "Green" else "Grey",
		text = if friendsOnly
			then string.format(Text.IconLabel, Text.CheckIcon, Text.FriendsOnly)
			else Text.FriendsOnly,
		textSize = TextSizes.Body,
	})
end

local function CreateView(props: any)
	local data = props.data
	local ui = props.ui
	local editing = props.editing == true
	local width, height = WindowSize.fit(ui, Sizes.Width, Sizes.Height)
	local narrow = width < Sizes.NarrowWidth

	local selectedMapId, setSelectedMapId = React.useState(props.initialMapId or data.MapId)
	local selectedModeId, setSelectedModeId = React.useState(props.initialModeId or data.ModeId)
	local maxPlayers, setMaxPlayers = React.useState(props.initialMaxPlayers or RoomConfig.DefaultMaxPlayers)
	local friendsOnly, setFriendsOnly = React.useState(
		if props.initialFriendsOnly ~= nil then props.initialFriendsOnly else RoomConfig.DefaultFriendsOnly
	)

	local map = ConfigLookup.GetMap(selectedMapId) or ConfigLookup.GetSortedMaps()[1]
	local mode = ConfigLookup.GetMode(selectedModeId) or ConfigLookup.GetSortedModes()[1]
	local mapStatusNow = mapStatus(data, map)
	local mapOwned = mapStatusNow == "Owned"
	local modeOpen = data.Level >= mode.RequiredLevel
	local canPlay = mapOwned and modeOpen

	local maps = mapList(data, map.Id, setSelectedMapId)
	local modes, modeRows = modeGrid(data.Level, mode.Id, setSelectedModeId)

	local rewardText
	if mode.RewardMultiplier <= 0 then
		rewardText = Text.NoRewards
	else
		rewardText = string.format(Text.RewardTotal, Format.multiplier(map.RewardMultiplier * mode.RewardMultiplier))
		if mode.TargetScore > 0 then
			rewardText = string.format(
				Text.RewardLines,
				rewardText,
				string.format(
					Text.RewardTarget,
					Format.compact(mode.TargetBonusCoins),
					Format.compact(mode.TargetBonusGems)
				)
			)
		end
	end

	local function infoBlock(order: number)
		return e(Inset, {
			layoutOrder = order,
			padding = Gap,
			automaticSize = Enum.AutomaticSize.Y,
			size = UDim2.fromScale(1, 0),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
			Description = Primitives.text({
				Fit = true,
				Font = "Body",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, math.ceil(TextSizes.Body * Sizes.DescriptionLines * Shape.LineHeight)),
				StrokeSize = Shape.SmallTextStroke,
				Text = mode.Description,
				TextSize = TextSizes.Body,
				Wrapped = true,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Chips = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromScale(1, 0),
			}, modeChips(mode)),
		})
	end

	local function rewardBlock(order: number)
		return Primitives.text({
			Color = if mode.RewardMultiplier > 0 then Palette.Sparkle else Palette.TextSoft,
			Fit = true,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, math.ceil(TextSizes.Body * Sizes.DescriptionLines * Shape.LineHeight)),
			Text = rewardText,
			TextSize = TextSizes.Body,
			Wrapped = true,
			XAlign = Enum.TextXAlignment.Left,
		})
	end

	local function playersBlock(order: number)
		return e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, RoomSizes.PlayerOptionHeight),
		}, {
			Selector = playerSelector(maxPlayers, setMaxPlayers),
		})
	end

	local function friendsBlock(order: number)
		return e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, RoomSizes.ToggleHeight),
		}, {
			Toggle = friendsToggle(friendsOnly, function()
				setFriendsOnly(not friendsOnly)
			end),
		})
	end

	local modeBlockHeight = modeRows * Sizes.ModeTileHeight + (modeRows - 1) * Gap + Shape.Lip
	local sideChildren: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, Shape.RimStroke),
			PaddingRight = UDim.new(0, Shape.RimStroke * 2),
			PaddingTop = UDim.new(0, Shape.RimStroke),
		}),
		PlayersTitle = sectionTitle(Text.PlayersHeader, 1),
		Players = playersBlock(2),
		Friends = friendsBlock(3),
		Title = sectionTitle(Text.ModesHeader, 4),
		Modes = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, modeBlockHeight),
		}, modes),
		Info = infoBlock(6),
		RewardTitle = sectionTitle(Text.RewardHeader, 7),
		Reward = rewardBlock(8),
	}

	local bodyChildren: { [string]: any } = {}
	if narrow then
		bodyChildren.Scroll = Primitives.scroll({}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Gap),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, Shape.RimStroke),
				PaddingRight = UDim.new(0, Shape.RimStroke * 2),
				PaddingTop = UDim.new(0, Shape.RimStroke),
			}),
			MapsTitle = sectionTitle(Text.MapsHeader, 1),
			Maps = e("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 0),
			}, maps),
			ModesTitle = sectionTitle(Text.ModesHeader, 3),
			Modes = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, modeBlockHeight),
			}, modes),
			Info = infoBlock(5),
			RewardTitle = sectionTitle(Text.RewardHeader, 6),
			Reward = rewardBlock(7),
			PlayersTitle = sectionTitle(Text.PlayersHeader, 8),
			Players = playersBlock(9),
			Friends = friendsBlock(10),
		})
	else
		local mapColumnWidth = math.min(Sizes.MapColumnWidth, width * 0.5)
		bodyChildren.Maps = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, mapColumnWidth, 1, 0),
		}, {
			Title = sectionTitle(Text.MapsHeader, 1),
			List = e(Inset, {
				position = UDim2.fromOffset(0, TextSizes.Large + Gap),
				size = UDim2.new(1, 0, 1, -(TextSizes.Large + Gap)),
				clip = true,
			}, {
				Scroll = Primitives.scroll({}, maps),
			}),
		})
		bodyChildren.Side = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(mapColumnWidth + Gap, 0),
			Size = UDim2.new(1, -(mapColumnWidth + Gap), 1, 0),
		}, {
			Scroll = Primitives.scroll({}, sideChildren),
		})
	end

	local footerButtons: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Horizontal, Gap, Enum.HorizontalAlignment.Left),
	}
	if editing then
		footerButtons.Back = e(ChunkyButton, {
			layoutOrder = 1,
			onActivated = props.onCancel,
			size = UDim2.new(0.3, 0, 0, RoomSizes.ActionHeight),
			swatch = "Grey",
			text = Text.BackSettings,
			textSize = TextSizes.Large,
		})
	end
	footerButtons.Submit = e(ChunkyButton, {
		enabled = canPlay,
		layoutOrder = 2,
		name = if editing then nil else "OnboardingPlayButton",
		onActivated = function()
			if canPlay then
				props.onSubmit(map.Id, mode.Id, maxPlayers, friendsOnly)
			end
		end,
		size = if editing
			then UDim2.new(0.68, 0, 0, RoomSizes.ActionHeight)
			else UDim2.new(1, 0, 0, RoomSizes.ActionHeight),
		swatch = "Green",
		text = if editing then Text.SaveSettings else Text.CreateRoom,
		textSize = TextSizes.Title,
	})

	local content: { [string]: any } = {}
	if not editing then
		content.Tabs = viewTabs(Views.Create, props.onSelectView)
		content.Body = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(1, 0, 1, -(LobbyUIConfig.Tabs.Height + Gap)),
		}, bodyChildren)
	else
		content.Body = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, bodyChildren)
	end

	return e(Window, {
		footer = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, footerButtons),
		footerHeight = RoomSizes.ActionHeight,
		height = height,
		icon = if editing then LobbyUIConfig.Play.EditIcon else LobbyUIConfig.Play.Icon,
		onClose = props.onClose,
		swatch = "Orange",
		title = if editing then Text.RoomTitle else Text.PlayTitle,
		width = width,
	}, content)
end

local function BrowseView(props: any)
	local width, height = WindowSize.fit(props.ui, Sizes.Width, Sizes.Height)
	local sorted = table.clone(props.rooms)
	table.sort(sorted, function(a, b)
		if a.HostIsFriend ~= b.HostIsFriend then
			return a.HostIsFriend
		end
		if a.Players ~= b.Players then
			return a.Players > b.Players
		end
		return a.Id < b.Id
	end)

	local rows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap, Enum.HorizontalAlignment.Center),
		Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke * 2),
	}
	for index, summary in sorted do
		local map = ConfigLookup.GetMap(summary.MapId)
		local mode = ConfigLookup.GetMode(summary.ModeId)
		local full = summary.Players >= summary.MaxPlayers
		local rightInset = RoomSizes.JoinWidth + Gap
		local chips: { [string]: any } = {
			Layout = Primitives.list(Enum.FillDirection.Horizontal, Gap / 2, Enum.HorizontalAlignment.Left),
			Players = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 1,
				swatch = if full then "Red" else "Gold",
				text = string.format(Text.BrowsePlayersFormat, summary.Players, summary.MaxPlayers),
			}),
		}
		if summary.FriendsOnly then
			chips.Privacy = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 2,
				swatch = "Teal",
				text = Text.RoomFriendsOnly,
			})
		end
		if summary.HostIsFriend then
			chips.Friends = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 3,
				swatch = "Teal",
				text = Text.FriendsBadge,
			})
		end
		rows["Room" .. summary.Id] = e(ChunkyButton, {
			layoutOrder = index,
			size = UDim2.new(1, -Shape.RimStroke * 2, 0, RoomSizes.BrowseRowHeight),
			swatch = if summary.HostIsFriend then "Teal" else "Blue",
		}, {
			Padding = Primitives.paddingXY(Gap, Gap / 2),
			Icon = mapIcon(summary.MapId, RoomSizes.BrowseIconSize),
			Host = Primitives.text({
				Fit = true,
				Position = UDim2.fromOffset(RoomSizes.BrowseIconSize + Gap, Gap / 2),
				Size = UDim2.new(1, -(RoomSizes.BrowseIconSize + Gap + rightInset), 0, TextSizes.Header),
				Text = string.format(Text.BrowseHostFormat, summary.HostName),
				TextSize = TextSizes.Header,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Details = Primitives.text({
				Fit = true,
				Font = "Body",
				Position = UDim2.fromOffset(RoomSizes.BrowseIconSize + Gap, Gap / 2 + TextSizes.Header),
				Size = UDim2.new(1, -(RoomSizes.BrowseIconSize + Gap + rightInset), 0, TextSizes.Small),
				StrokeSize = Shape.SmallTextStroke,
				Text = string.format(
					Text.BrowseDetailsFormat,
					if map ~= nil then map.DisplayName else summary.MapId,
					if mode ~= nil then mode.DisplayName else summary.ModeId
				),
				TextSize = TextSizes.Small,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Chips = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, RoomSizes.BrowseIconSize + Gap, 1, -Gap / 2),
				Size = UDim2.fromOffset(0, Sizes.ChipHeight),
			}, chips),
			Join = e(ChunkyButton, {
				anchorPoint = Vector2.new(1, 0.5),
				enabled = not full,
				onActivated = function()
					props.onJoin(summary.Id)
				end,
				position = UDim2.fromScale(1, 0.5),
				size = UDim2.fromOffset(RoomSizes.JoinWidth, RoomSizes.JoinHeight),
				swatch = "Green",
				text = if full then Text.JoinFull else Text.Join,
				textSize = TextSizes.Large,
			}),
		})
	end

	local list: any
	if #sorted == 0 then
		list = Primitives.text({
			Color = Palette.TextSoft,
			Size = UDim2.fromScale(1, 1),
			Text = Text.EmptyRooms,
			TextSize = TextSizes.Large,
			Wrapped = true,
		})
	else
		list = Primitives.scroll({}, rows)
	end

	return e(Window, {
		height = height,
		icon = LobbyUIConfig.Play.BrowseIcon,
		onClose = props.onClose,
		swatch = "Blue",
		title = Text.PlayTitle,
		width = width,
	}, {
		Tabs = viewTabs(Views.Browse, props.onSelectView),
		List = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, LobbyUIConfig.Tabs.Height + Gap),
			Size = UDim2.new(1, 0, 1, -(LobbyUIConfig.Tabs.Height + Gap)),
		}, {
			Content = list,
		}),
	})
end

local function useServerNow(active: boolean): number
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	React.useEffect(function()
		if not active then
			return
		end
		setNow(Workspace:GetServerTimeNow())
		local elapsed = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= UIConfig.Animation.HudTick then
				elapsed = 0
				setNow(Workspace:GetServerTimeNow())
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { active })
	return now
end

local function useFriends(memberIds: { [number]: boolean }): { Player }
	local _, setTick = React.useState(0)
	React.useEffect(function()
		local added = Players.PlayerAdded:Connect(function()
			setTick(function(value)
				return value + 1
			end)
		end)
		local removed = Players.PlayerRemoving:Connect(function()
			setTick(function(value)
				return value + 1
			end)
		end)
		return function()
			added:Disconnect()
			removed:Disconnect()
		end
	end, {})

	local localPlayer = Players.LocalPlayer
	local friends: { Player } = {}
	for _, player in Players:GetPlayers() do
		if
			player ~= localPlayer
			and memberIds[player.UserId] ~= true
			and Players:GetFriendStatus(player) == Enum.FriendStatus.Friend
		then
			table.insert(friends, player)
		end
	end
	table.sort(friends, function(a, b)
		return a.Name < b.Name
	end)
	return friends
end

local function RoomView(props: any)
	local room = props.room
	local ui = props.ui
	local width, height = WindowSize.fit(ui, Sizes.Width, Sizes.Height)
	local localPlayer = Players.LocalPlayer
	local isHost = room.HostId == localPlayer.UserId
	local waiting = room.Status == "Waiting"
	local countdown = room.Status == "Countdown"
	local now = useServerNow(countdown)
	local secondsLeft = if countdown then math.max(0, math.ceil(room.StartsAt - now)) else 0

	local me: any = nil
	local memberIds: { [number]: boolean } = {}
	for _, member in room.Members do
		memberIds[member.UserId] = true
		if member.UserId == localPlayer.UserId then
			me = member
		end
	end

	local allReady = true
	for _, member in room.Members do
		if member.UserId ~= room.HostId and not member.Ready then
			allReady = false
		end
	end
	local canStart = isHost and waiting and (not RoomConfig.RequireAllReady or allReady)
	local friends = useFriends(memberIds)

	local map = ConfigLookup.GetMap(room.MapId)
	local mode = ConfigLookup.GetMode(room.ModeId)

	local summaryChildren: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
		MapLine = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, RoomSizes.SummaryIconSize),
		}, {
			Icon = mapIcon(room.MapId, RoomSizes.SummaryIconSize),
			Title = Primitives.text({
				Fit = true,
				Position = UDim2.fromOffset(RoomSizes.SummaryIconSize + Gap, 0),
				Size = UDim2.new(1, -(RoomSizes.SummaryIconSize + Gap), 0, TextSizes.Header),
				Text = if map ~= nil then map.DisplayName else room.MapId,
				TextSize = TextSizes.Header,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Mode = Primitives.text({
				Fit = true,
				Font = "Body",
				Position = UDim2.fromOffset(RoomSizes.SummaryIconSize + Gap, TextSizes.Header),
				Size = UDim2.new(1, -(RoomSizes.SummaryIconSize + Gap), 0, TextSizes.Body),
				StrokeSize = Shape.SmallTextStroke,
				Text = if mode ~= nil then mode.DisplayName else room.ModeId,
				TextSize = TextSizes.Body,
				XAlign = Enum.TextXAlignment.Left,
			}),
		}),
		Chips = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, Sizes.ChipHeight),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Horizontal, Gap / 2, Enum.HorizontalAlignment.Left),
			Players = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 1,
				swatch = "Gold",
				text = string.format(Text.RoomPlayersFormat, #room.Members, room.MaxPlayers),
			}),
			Privacy = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 2,
				swatch = if room.FriendsOnly then "Teal" else "Blue",
				text = if room.FriendsOnly then Text.RoomFriendsOnly else Text.RoomPublic,
			}),
			Status = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 3,
				swatch = if countdown then "Gold" elseif waiting then "Grey" else "Green",
				text = if countdown
					then string.format(Text.CountdownFormat, secondsLeft)
					elseif waiting then Text.WaitingText
					else Text.RoomTab,
			}),
		}),
	}

	local sortedMembers = table.clone(room.Members)
	table.sort(sortedMembers, function(a, b)
		if (a.UserId == room.HostId) ~= (b.UserId == room.HostId) then
			return a.UserId == room.HostId
		end
		return a.Name < b.Name
	end)
	local memberRows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
	}
	for index, member in sortedMembers do
		memberRows["Member" .. member.UserId] = e(Inset, {
			layoutOrder = index,
			size = UDim2.new(1, 0, 0, RoomSizes.RowHeight),
		}, {
			Padding = Primitives.paddingXY(Gap, 0),
			Layout = Primitives.list(
				Enum.FillDirection.Horizontal,
				Gap / 2,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Center
			),
			Name = Primitives.text({
				Fit = true,
				LayoutOrder = 1,
				Size = UDim2.new(0.38, 0, 1, 0),
				Text = member.Name,
				TextSize = TextSizes.Large,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Level = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 2,
				swatch = "Blue",
				text = string.format(Text.LevelFormat, member.Level),
			}),
			Host = if member.UserId == room.HostId
				then e(Chip, {
					height = Sizes.ChipHeight,
					layoutOrder = 3,
					swatch = "Gold",
					text = Text.HostMark,
				})
				else nil,
			Ready = e(Chip, {
				height = Sizes.ChipHeight,
				layoutOrder = 4,
				swatch = if member.Ready or member.UserId == room.HostId then "Green" else "Grey",
				text = if member.Ready or member.UserId == room.HostId then Text.ReadyMark else Text.WaitingMark,
			}),
			Kick = if isHost
					and waiting
					and member.UserId ~= localPlayer.UserId
				then e(ChunkyButton, {
					layoutOrder = 5,
					onActivated = function()
						Net.KickRoomMember:Fire(member.UserId)
					end,
					size = UDim2.fromOffset(RoomSizes.KickWidth, RoomSizes.KickHeight),
					swatch = "Red",
					text = Text.Kick,
					textSize = TextSizes.Small,
				})
				else nil,
		})
	end

	local inviteRows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
	}
	if #friends == 0 then
		inviteRows.Empty = Primitives.text({
			Color = Palette.TextSoft,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, RoomSizes.FriendRowHeight),
			Text = Text.NoFriends,
			TextSize = TextSizes.Body,
			Wrapped = true,
		})
	else
		for index, player in friends do
			inviteRows["Friend" .. player.UserId] = e(Inset, {
				layoutOrder = index,
				size = UDim2.new(1, 0, 0, RoomSizes.FriendRowHeight),
			}, {
				Padding = Primitives.paddingXY(Gap, 0),
				Layout = Primitives.list(
					Enum.FillDirection.Horizontal,
					Gap / 2,
					Enum.HorizontalAlignment.Left,
					Enum.VerticalAlignment.Center
				),
				Name = Primitives.text({
					Fit = true,
					LayoutOrder = 1,
					Size = UDim2.new(1, -(RoomSizes.InviteWidth + Gap), 1, 0),
					Text = player.DisplayName,
					TextSize = TextSizes.Body,
					XAlign = Enum.TextXAlignment.Left,
				}),
				Invite = e(ChunkyButton, {
					layoutOrder = 2,
					onActivated = function()
						Net.InviteToRoom:Fire(player.UserId)
					end,
					size = UDim2.fromOffset(RoomSizes.InviteWidth, RoomSizes.InviteHeight),
					swatch = "Teal",
					text = Text.Invite,
					textSize = TextSizes.Small,
				}),
			})
		end
	end

	local hint: string? = nil
	if isHost and waiting then
		if room.MaxPlayers == 1 then
			hint = Text.SoloStartHint
		elseif RoomConfig.RequireAllReady and not allReady then
			hint = Text.StartHint
		end
	end

	local action: any
	if waiting then
		if isHost then
			action = e(ChunkyButton, {
				enabled = canStart,
				onActivated = function()
					if canStart then
						Net.StartRoom:Fire()
					end
				end,
				size = UDim2.fromScale(1, 1),
				swatch = "Green",
				text = Text.StartButton,
				textSize = TextSizes.Large,
			})
		else
			local ready = me ~= nil and me.Ready
			action = e(ChunkyButton, {
				onActivated = function()
					Net.SetRoomReady:Fire(not ready)
				end,
				size = UDim2.fromScale(1, 1),
				swatch = if ready then "Grey" else "Green",
				text = if ready then Text.UnreadyButton else Text.ReadyButton,
				textSize = TextSizes.Large,
			})
		end
	elseif countdown then
		action = e(ChunkyButton, {
			enabled = false,
			size = UDim2.fromScale(1, 1),
			swatch = "Gold",
			text = string.format(Text.CountdownFormat, secondsLeft),
			textSize = TextSizes.Body,
		})
	else
		action = e(ChunkyButton, {
			enabled = false,
			size = UDim2.fromScale(1, 1),
			swatch = "Grey",
			text = Text.WaitingText,
			textSize = TextSizes.Body,
		})
	end

	local footerChildren: { [string]: any } = {
		Hint = if hint ~= nil
			then Primitives.text({
				Color = Palette.TextSoft,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, TextSizes.Body),
				Text = hint,
				TextSize = TextSizes.Body,
			})
			else nil,
		Leave = e(ChunkyButton, {
			anchorPoint = Vector2.new(0, 1),
			onActivated = function()
				Net.LeaveRoom:Fire()
				props.onClose()
			end,
			position = UDim2.fromScale(0, 1),
			size = UDim2.new(0.3, 0, 0, RoomSizes.JoinHeight),
			swatch = "Red",
			text = Text.LeaveRoom,
			textSize = TextSizes.Large,
		}),
		Edit = if isHost and waiting
			then e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 1),
				onActivated = props.onEdit,
				position = UDim2.fromScale(0.5, 1),
				size = UDim2.new(0.26, 0, 0, RoomSizes.JoinHeight),
				swatch = "Blue",
				text = Text.EditSettings,
				textSize = TextSizes.Large,
			})
			else nil,
		Action = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(0.32, 0, 0, RoomSizes.JoinHeight),
		}, {
			Content = action,
		}),
	}

	local content: { [string]: any } = {
		Scroll = Primitives.scroll({}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Gap),
			Summary = e(Inset, {
				layoutOrder = 1,
				padding = Gap,
				automaticSize = Enum.AutomaticSize.Y,
				size = UDim2.fromScale(1, 0),
			}, summaryChildren),
			MembersTitle = sectionTitle(Text.MembersHeader, 2),
			Members = e("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
			}, memberRows),
			InviteTitle = sectionTitle(Text.InviteHeader, 4),
			Invites = e("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 0),
			}, inviteRows),
		}),
	}

	return e(Window, {
		footer = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, footerChildren),
		footerHeight = RoomSizes.FooterHeight,
		height = height,
		icon = LobbyUIConfig.Play.RoomIcon,
		onClose = props.onClose,
		swatch = "Purple",
		title = Text.RoomTitle,
		width = width,
	}, content)
end

local function PlayView(props: any)
	local width, height = WindowSize.fit(props.ui, Sizes.Width, Sizes.Height)
	local list = mapList(props.data, "", function() end, true, props.onQuickPlay, props.onFriends)
	local listWidth = math.min(Sizes.MapColumnWidth, width)
	local top = LobbyUIConfig.Tabs.Height + Gap
	return e(Window, {
		height = height,
		icon = LobbyUIConfig.Play.Icon,
		onClose = props.onClose,
		swatch = LobbyUIConfig.Play.Swatch,
		title = Text.PlayTitle,
		width = width,
	}, {
		Tabs = viewTabs(Views.Play, props.onSelectView),
		List = e(Inset, {
			anchorPoint = Vector2.new(0.5, 0),
			clip = true,
			position = UDim2.new(0.5, 0, 0, top),
			size = UDim2.new(0, listWidth, 1, -top),
		}, {
			Scroll = Primitives.scroll({}, list),
		}),
	})
end

return function(props: any)
	local roomState, setRoomState = React.useState(RoomController.Get())
	React.useEffect(function()
		local connection = RoomController.Changed:Connect(setRoomState)
		return function()
			connection:Disconnect()
		end
	end, {})

	local room = roomState.Room
	local friendsMapId, setFriendsMapId = React.useState(nil :: string?)
	local view, setView = React.useState(if room ~= nil then Views.Room else Views.Play)

	React.useEffect(function()
		if room ~= nil then
			setView(function(current)
				if
					current == Views.Play
					or current == Views.Create
					or current == Views.Browse
					or current == Views.Settings
				then
					return Views.Room
				end
				return current
			end)
		else
			setView(function(current)
				if current == Views.Room then
					return Views.Create
				end
				return current
			end)
		end
	end, { room ~= nil } :: { any })

	React.useEffect(function()
		if view ~= Views.Browse then
			return
		end
		RoomController.SetWatching(true)
		return function()
			RoomController.SetWatching(false)
		end
	end, { view })

	if room ~= nil then
		if view == Views.Settings then
			return e(CreateView, {
				data = props.data,
				editing = true,
				initialFriendsOnly = room.FriendsOnly,
				initialMapId = room.MapId,
				initialMaxPlayers = room.MaxPlayers,
				initialModeId = room.ModeId,
				key = "settings" .. room.Id,
				onCancel = function()
					setView(Views.Room)
				end,
				onClose = props.onClose,
				onSubmit = function(mapId: string, modeId: string, maxPlayers: number, friendsOnly: boolean)
					Net.UpdateRoom:Fire(mapId, modeId, maxPlayers, friendsOnly)
					setView(Views.Room)
				end,
				ui = props.ui,
			})
		end
		return e(RoomView, {
			onClose = props.onClose,
			onEdit = function()
				setView(Views.Settings)
			end,
			room = room,
			ui = props.ui,
		})
	end

	if view == Views.Browse then
		return e(BrowseView, {
			onClose = props.onClose,
			onJoin = function(roomId: number)
				RoomController.DismissInvite()
				Net.JoinRoom:Fire(roomId)
			end,
			onSelectView = setView,
			rooms = roomState.Rooms,
			ui = props.ui,
		})
	end

	if view == Views.Play then
		return e(PlayView, {
			data = props.data,
			onClose = props.onClose,
			onFriends = function(mapId: string)
				setFriendsMapId(mapId)
				setView(Views.Create)
			end,
			onQuickPlay = function(mapId: string)
				Net.QuickPlay:Fire(mapId)
			end,
			onSelectView = setView,
			ui = props.ui,
		})
	end

	return e(CreateView, {
		data = props.data,
		initialMapId = friendsMapId,
		key = "create",
		onClose = props.onClose,
		onSelectView = setView,
		onSubmit = function(mapId: string, modeId: string, maxPlayers: number, friendsOnly: boolean)
			Net.CreateRoom:Fire(mapId, modeId, maxPlayers, friendsOnly)
		end,
		ui = props.ui,
	})
end
