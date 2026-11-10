--!strict

--[[
	LobbyDock
	Always-visible lobby layout: the 2-column icon grid at the left edge, the big pulsing PLAY
	button at the right with its shine sweep, and the active potion / boost timers under PLAY.
	There is no MENU fold-out any more; the PLAY button carries both onboarding names and every
	tile opens its LobbyState route.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, RunService, TweenService, UIConfig, LobbyUIConfig, LobbyState, ConfigLookup,
		PotionConfig, UpgradeConfig, MonetizationConfig, Components (IconTile, ChunkyButton, Pill,
		Primitives, Format)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local PotionConfig = require(ReplicatedStorage.Modules.Config.PotionConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Config.UpgradeConfig)
local MonetizationConfig = require(ReplicatedStorage.Modules.Config.MonetizationConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local IconTile = require(Components.IconTile)
local Pill = require(Components.Pill)
local Primitives = require(Components.Primitives)
local Twinkle = require(Components.Twinkle)
local useBreathe = require(Components.useBreathe)

local e = React.createElement
local Dock = LobbyUIConfig.Dock
local Sparkle = UIConfig.Sparkle
local Routes = LobbyState.Routes

local SECONDS_PER_MINUTE = 60

local function clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format(Dock.TimerFormat, total // SECONDS_PER_MINUTE, total % SECONDS_PER_MINUTE)
end

local function canClaimDaily(data: any): boolean
	return data.Daily ~= nil and data.Daily.CanClaim == true
end

local function canAffordUpgrade(data: any): boolean
	for id, upgrade in UpgradeConfig.Upgrades do
		local level = data.Upgrades[id] or 0
		if level < upgrade.MaxLevel and data.Coins >= ConfigLookup.GetUpgradeCost(id, level) then
			return true
		end
	end
	return false
end

local function canRebirth(data: any): boolean
	return data.Coins >= ConfigLookup.GetRebirthCost(data.Rebirths)
end

local function badgeFor(id: string, data: any): any
	if id == "Daily" and canClaimDaily(data) then
		return true
	elseif id == "Pets" and #data.PetDropQueue > 0 then
		return true
	elseif id == "Upgrades" and canAffordUpgrade(data) then
		return true
	elseif id == "Rebirth" and canRebirth(data) then
		return true
	end
	return nil
end

local function activeTimers(data: any, now: number): { any }
	local list = {}
	for _, id in ConfigLookup.GetSortedPotionIds() do
		local expiresAt = data.Potions[id] or 0
		if expiresAt > now then
			local potion = PotionConfig.Potions[id]
			table.insert(list, {
				ExpiresAt = expiresAt,
				Icon = if potion ~= nil then potion.Icon else "🧪",
				Swatch = Dock.PotionSwatch,
				Value = clock(expiresAt - now),
			})
		end
	end
	if data.CoinBoostUntil > now then
		local multiplier = MonetizationConfig.DevProducts.NewbiePack.CoinBoostMultiplier
		table.insert(list, {
			ExpiresAt = data.CoinBoostUntil,
			Icon = Dock.CoinBoostIcon,
			Swatch = Dock.CoinBoostSwatch,
			Value = string.format(Dock.BoostFormat, Format.multiplier(multiplier), clock(data.CoinBoostUntil - now)),
		})
	end
	for id, expiresAt in data.Boosts or {} do
		if type(expiresAt) == "number" and expiresAt > now then
			local boost = ConfigLookup.GetDailyBoost(id)
			local multiplier = if boost ~= nil then boost.Multiplier else 0
			table.insert(list, {
				ExpiresAt = expiresAt,
				Icon = Dock.BoostIcons[id] or "✨",
				Swatch = Dock.BoostSwatch,
				Value = if multiplier > 0
					then string.format(Dock.BoostFormat, Format.multiplier(multiplier), clock(expiresAt - now))
					else clock(expiresAt - now),
			})
		end
	end
	table.sort(list, function(a, b)
		return a.ExpiresAt < b.ExpiresAt
	end)
	while #list > Dock.TimerMax do
		table.remove(list)
	end
	return list
end

local function TimerColumn(props: any)
	local now, setNow = React.useState(os.time())
	local timers = activeTimers(props.data, now)

	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if running then
					setNow(os.time())
				end
			end
		end)
		return function()
			running = false
		end
	end, {})

	if #timers == 0 then
		return nil
	end

	local mobile = props.ui.mobile
	local width = if mobile then Dock.MobileTimerWidth else Dock.TimerWidth
	local height = if mobile then Dock.MobileTimerHeight else Dock.TimerHeight
	local iconSize = if mobile then Dock.MobileTimerIconSize else Dock.TimerIconSize
	local textSize = if mobile then Dock.MobileTimerTextSize else Dock.TimerTextSize
	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Dock.TimerGap, Enum.HorizontalAlignment.Right),
	}
	for index, timer in timers do
		children["Timer" .. index] = e(Pill, {
			height = height,
			icon = timer.Icon,
			iconSize = iconSize,
			layoutOrder = index,
			swatch = timer.Swatch,
			textSize = textSize,
			value = timer.Value,
			width = width,
		})
	end
	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(width, 0),
	}, children)
end

return function(props: any)
	local dock = props.ui.mobile
			and {
				TileSize = Dock.MobileTileSize,
				TileGap = Dock.MobileTileGap,
				TileLabelHeight = Dock.MobileTileLabelHeight,
				TileLabelSize = Dock.MobileTileLabelSize,
				PlaySize = Dock.MobilePlaySize,
				PlayIconSize = Dock.MobilePlayIconSize,
				PlayTextSize = Dock.MobilePlayTextSize,
			}
		or {
			TileSize = Dock.TileSize,
			TileGap = Dock.TileGap,
			TileLabelHeight = Dock.TileLabelHeight,
			TileLabelSize = Dock.TileLabelSize,
			PlaySize = Dock.PlaySize,
			PlayIconSize = Dock.PlayIconSize,
			PlayTextSize = Dock.PlayTextSize,
		}
	local layout = LobbyUIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"]
	local gridWidth = Dock.TileColumns * dock.TileSize + (Dock.TileColumns - 1) * dock.TileGap

	local tiles: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(dock.TileGap, dock.TileGap),
			CellSize = UDim2.fromOffset(dock.TileSize, dock.TileSize + dock.TileLabelHeight),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, item in Dock.Items do
		tiles[item.Id] = e(IconTile, {
			badge = badgeFor(item.Id, props.data),
			icon = item.Icon,
			label = item.Label,
			labelHeight = dock.TileLabelHeight,
			labelTextSize = dock.TileLabelSize,
			layoutOrder = index,
			name = item.Name,
			onActivated = function()
				LobbyState.SetActive(item.Route, item.Tab)
			end,
			phase = index * 0.17,
			popDelay = index * UIConfig.Animation.CardStagger,
			popIn = true,
			size = dock.TileSize,
			swatch = item.Swatch,
			zIndex = UIConfig.Layers.LobbyMenu,
		})
	end

	local playScaleRef = React.useRef(nil)
	useBreathe(playScaleRef, Dock.PlayPulseScale, Dock.PlayPulseSeconds, 0.2, true)
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Grid = e("Frame", {
			AnchorPoint = layout.Grid.AnchorPoint,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = layout.Grid.Position,
			Size = UDim2.fromOffset(gridWidth, 0),
			ZIndex = UIConfig.Layers.LobbyMenu,
		}, tiles),
		Play = e("Frame", {
			AnchorPoint = layout.Play.AnchorPoint,
			BackgroundTransparency = 1,
			Position = layout.Play.Position,
			Size = UDim2.fromOffset(dock.PlaySize, dock.PlaySize),
			ZIndex = UIConfig.Layers.LobbyMenu,
		}, {
			Scale = e("UIScale", { ref = playScaleRef }),
			Button = e(ChunkyButton, {
				icon = Dock.PlayIcon,
				iconSize = dock.PlayIconSize,
				name = "OnboardingPlayButton",
				stacked = true,
				onActivated = function()
					LobbyState.SetActive(Routes.Play)
				end,
				overlay = e("Folder", {}, {
					OnboardingMenuButton = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
					}),
				}),
				popIn = true,
				rainbow = true,
				shine = true,
				size = UDim2.fromScale(1, 1),
				swatch = Dock.PlaySwatch,
				text = Dock.PlayLabel,
				textSize = dock.PlayTextSize,
				zIndex = UIConfig.Layers.LobbyMenu,
			}),
			Twinkle = e(Twinkle, {
				color = Sparkle.TwinkleGold,
				rate = Sparkle.PlayTwinkleRate,
				zIndex = UIConfig.Layers.LobbyMenu + 1,
			}),
		}),
		Timers = e(TimerColumn, { data = props.data, layout = layout.Timers, ui = props.ui }),
	})
end
