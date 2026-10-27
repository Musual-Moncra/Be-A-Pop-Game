--!strict

--[[
	PlayWindow
	"Choose your mess" window. Left: every map as a big coloured card (icon, name, description,
	size and reward chips, and OWNED / UNLOCK price / requirement / COMING SOON). Right: mode
	tiles, the selected mode's rules as chips, the reward preview and the big PLAY button.
	Locked maps can be selected to read their unlock info; only owned maps are sent to the
	server with Net.SelectRun. PLAY sends SelectRun then StartRun and closes the window.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, UIConfig, ConfigLookup, Net, Primitives, ChunkyButton,
	              Chip, Inset, Window, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Components = ReplicatedStorage.Modules.UIComponents
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Window = require(Components.Window)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Play
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function mapStatus(data: any, map: any): (string, string?)
	if not map.Enabled then
		return "Soon", nil
	end
	if data.UnlockedMaps[map.Id] then
		return "Owned", nil
	end
	local previous = ConfigLookup.GetPreviousMap(map.Id)
	if previous ~= nil and not data.UnlockedMaps[previous.Id] then
		return "Blocked", string.format(Text.NeedMapFirst, previous.DisplayName)
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

local function MapCard(props: any)
	local map = props.map
	local data = props.data
	local visual = UIConfig.MapVisuals[map.Id] or {}
	local status, reason = mapStatus(data, map)
	local locked = status ~= "Owned"

	local action
	if status == "Owned" then
		action = e(Chip, {
			swatch = "Green",
			text = string.format(Text.IconLabel, Text.CheckIcon, Text.Owned),
			height = Sizes.ChipHeight,
		})
	elseif status == "Soon" then
		action = e(Chip, { swatch = "Grey", text = Text.ComingSoon, height = Sizes.ChipHeight })
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
			swatch = "Red",
			text = string.format(Text.IconLabel, Text.LockIcon, reason or ""),
			height = Sizes.ChipHeight,
		})
	end

	return e(ChunkyButton, {
		layoutOrder = map.Order,
		onActivated = function()
			props.onSelect(map.Id)
		end,
		overlay = selectionRing(props.selected),
		size = UDim2.new(1, -Shape.RimStroke * 2, 0, Sizes.MapCardHeight),
		swatch = visual.Swatch,
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
				Text = if locked and status ~= "Buyable" then Text.LockIcon else visual.Icon,
				TextSize = Sizes.MapIconSize * Shape.IconFill,
			}),
		}),
		Info = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(Sizes.MapIconSize + Gap, 0),
			Size = UDim2.new(1, -(Sizes.MapIconSize + Gap), 1, 0),
		}, {
			Layout = Primitives.list(
				Enum.FillDirection.Vertical,
				Shape.Stroke,
				Enum.HorizontalAlignment.Left,
				Enum.VerticalAlignment.Center
			),
			Name = Primitives.text({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, TextSizes.Header),
				Text = map.DisplayName,
				TextSize = TextSizes.Header,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Description = Primitives.text({
				Font = "Body",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, TextSizes.Small * 2 + Shape.Stroke),
				StrokeSize = Shape.SmallTextStroke,
				Text = map.Description,
				TextSize = TextSizes.Small,
				Wrapped = true,
				XAlign = Enum.TextXAlignment.Left,
			}),
			Row = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, Sizes.ActionButtonHeight),
			}, {
				Layout = Primitives.list(
					Enum.FillDirection.Horizontal,
					Shape.Stroke * 2,
					Enum.HorizontalAlignment.Left,
					Enum.VerticalAlignment.Center
				),
				Size = e(
					Chip,
					{ layoutOrder = 1, swatch = "Blue", text = string.format(Text.SizeChip, map.SizeLabel) }
				),
				Reward = e(Chip, {
					layoutOrder = 2,
					swatch = "Gold",
					text = string.format(Text.RewardChip, Format.multiplier(map.RewardMultiplier)),
				}),
				Action = e("Frame", {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					Size = UDim2.fromScale(0, 1),
				}, {
					Layout = Primitives.list(
						Enum.FillDirection.Horizontal,
						0,
						Enum.HorizontalAlignment.Left,
						Enum.VerticalAlignment.Center
					),
					Content = action,
				}),
			}),
		}),
	})
end

local function ModeTile(props: any)
	local mode = props.mode
	local visual = UIConfig.ModeVisuals[mode.Id] or {}
	local locked = props.level < mode.RequiredLevel
	return e(ChunkyButton, {
		layoutOrder = mode.Order,
		onActivated = function()
			props.onSelect(mode.Id)
		end,
		overlay = selectionRing(props.selected),
		swatch = if locked then "Grey" else visual.Swatch,
	}, {
		Layout = Primitives.list(
			Enum.FillDirection.Horizontal,
			Shape.Stroke * 2,
			Enum.HorizontalAlignment.Center,
			Enum.VerticalAlignment.Center
		),
		Icon = Primitives.text({
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 1,
			Size = UDim2.new(),
			Stroke = false,
			Text = if locked then Text.LockIcon else visual.Icon,
			TextSize = TextSizes.Icon,
		}),
		Name = Primitives.text({
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 2,
			Size = UDim2.new(),
			Text = if locked
				then string.format(Text.LockedModeFormat, mode.DisplayName, mode.RequiredLevel)
				else mode.DisplayName,
			TextSize = if locked then TextSizes.Body else TextSizes.Large,
		}),
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

return function(props: any)
	local data = props.data
	local ui = props.ui
	local margin = UIConfig.Layouts[if ui.mobile then "Mobile" else "PC"].WindowMargin
	local width = math.min(Sizes.Width, ui.width - margin * 2)
	local height = math.min(Sizes.Height, ui.height - margin * 2 - UIConfig.Sizes.Window.HeaderHeight / 2)

	local selectedMapId, setSelectedMapId = React.useState(data.MapId)
	local selectedModeId, setSelectedModeId = React.useState(data.ModeId)

	local map = ConfigLookup.GetMap(selectedMapId) or ConfigLookup.GetSortedMaps()[1]
	local mode = ConfigLookup.GetMode(selectedModeId) or ConfigLookup.GetSortedModes()[1]
	local mapOwned = map.Enabled and data.UnlockedMaps[map.Id] == true
	local modeOpen = data.Level >= mode.RequiredLevel
	local canPlay = mapOwned and modeOpen

	local mapCards = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap, Enum.HorizontalAlignment.Center),
		Padding = Primitives.paddingXY(Shape.RimStroke, Shape.RimStroke * 2),
	}
	for _, entry in ConfigLookup.GetSortedMaps() do
		mapCards[entry.Id] = e(MapCard, {
			data = data,
			map = entry,
			onSelect = setSelectedMapId,
			selected = entry.Id == map.Id,
		})
	end

	local modeTiles = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.new(0.5, -Gap / 2, 0, Sizes.ModeTileHeight),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local modes = ConfigLookup.GetSortedModes()
	for _, entry in modes do
		modeTiles[entry.Id] = e(ModeTile, {
			level = data.Level,
			mode = entry,
			onSelect = setSelectedModeId,
			selected = entry.Id == mode.Id,
		})
	end
	local modeRows = math.ceil(#modes / 2)

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

	local playLabel = Text.PlayButton
	if not mapOwned or not modeOpen then
		playLabel = string.format(Text.IconLabel, Text.LockIcon, Text.PlayLocked)
	end

	local function play()
		Net.SelectRun:Fire(map.Id, mode.Id)
		Net.StartRun:Fire()
		props.onClose()
	end

	local mapColumnWidth = math.min(Sizes.MapColumnWidth, width * 0.5)
	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = "Orange",
		title = Text.PlayTitle,
		width = width,
	}, {
		Maps = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, mapColumnWidth, 1, 0),
		}, {
			Title = sectionTitle(Text.MapsHeader, 1),
			List = e(Inset, {
				position = UDim2.fromOffset(0, TextSizes.Large + Gap),
				size = UDim2.new(1, 0, 1, -(TextSizes.Large + Gap)),
				clip = true,
			}, {
				Scroll = e("ScrollingFrame", {
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					ScrollBarImageColor3 = Palette.PanelRim,
					ScrollBarThickness = Shape.RimStroke * 2,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					Size = UDim2.fromScale(1, 1),
				}, mapCards),
			}),
		}),
		Side = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(mapColumnWidth + Gap, 0),
			Size = UDim2.new(1, -(mapColumnWidth + Gap), 1, 0),
		}, {
			Scroll = e("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				ScrollBarImageColor3 = Palette.PanelRim,
				ScrollBarThickness = Shape.RimStroke,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.new(1, 0, 1, -(Sizes.PlayButtonHeight + Gap)),
			}, {
				Layout = Primitives.list(Enum.FillDirection.Vertical, Gap),
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, Shape.RimStroke),
					PaddingRight = UDim.new(0, Shape.RimStroke * 2),
					PaddingTop = UDim.new(0, Shape.RimStroke),
				}),
				Title = sectionTitle(Text.ModesHeader, 1),
				Modes = e("Frame", {
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, modeRows * Sizes.ModeTileHeight + (modeRows - 1) * Gap + Shape.Lip),
				}, modeTiles),
				Info = e(Inset, {
					layoutOrder = 3,
					padding = Gap,
					automaticSize = Enum.AutomaticSize.Y,
					size = UDim2.fromScale(1, 0),
				}, {
					Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
					Description = Primitives.text({
						Font = "Body",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, TextSizes.Body * 2 + Shape.Stroke),
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
				}),
				RewardTitle = sectionTitle(Text.RewardHeader, 4),
				Reward = Primitives.text({
					Color = if mode.RewardMultiplier > 0 then Palette.Sparkle else Palette.TextSoft,
					LayoutOrder = 5,
					Size = UDim2.new(1, 0, 0, TextSizes.Body * 2 + Shape.Stroke * 2),
					Text = rewardText,
					TextSize = TextSizes.Body,
					Wrapped = true,
					XAlign = Enum.TextXAlignment.Left,
				}),
			}),
			Play = e(ChunkyButton, {
				anchorPoint = Vector2.new(0, 1),
				enabled = canPlay,
				position = UDim2.fromScale(0, 1),
				onActivated = play,
				size = UDim2.new(1, 0, 0, Sizes.PlayButtonHeight),
				swatch = "Green",
				text = playLabel,
				textSize = TextSizes.Title,
			}),
		}),
	})
end
