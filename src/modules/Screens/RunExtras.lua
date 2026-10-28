--!strict

--[[
	RunExtras
	Extra HUD pieces drawn over the game: the live "map stained" meter during a run (with the
	best percent for that map), the Special Time banner with its countdown (lobby and runs), and
	the revive popup when a timed run hits zero and a revive is offered (prompts the Roblox
	purchase of the offered product).

	Props: data (DataController state), ui (useUIScale result), inRun (boolean)
	Dependencies: React, UIConfig, RunUIConfig, ConfigLookup, MonetizationConfig, Primitives, ChunkyButton,
		Bar, Window
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local RunUIConfig = require(ReplicatedStorage.Modules.Config.RunUIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Bar = require(Components.Bar)
local ChunkyButton = require(Components.ChunkyButton)
local Primitives = require(Components.Primitives)
local Window = require(Components.Window)

local e = React.createElement
local TextSizes = UIConfig.TextSizes

local SECONDS_PER_MINUTE = 60

local function useTick(active: boolean): number
	local now, setNow = React.useState(os.clock())
	React.useEffect(function()
		if not active then
			return
		end
		local running = true
		task.spawn(function()
			while running do
				task.wait(UIConfig.Animation.HudTick)
				if running then
					setNow(os.clock())
				end
			end
		end)
		return function()
			running = false
		end
	end, { active })
	return now
end

local function Meter(props: any)
	local progress = props.data.MapProgress
	local percent = if progress ~= nil then progress.Percent else 0
	local best = (props.data.BestMapProgress or {})[props.data.MapId] or 0
	local meter = RunUIConfig.Meter
	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(meter.Width, meter.Height + TextSizes.Small),
	}, {
		Bar = e(Bar, {
			ratio = percent / 100,
			size = UDim2.new(1, 0, 0, meter.Height),
			swatch = meter.Swatch,
			text = string.format(meter.Format, percent),
			textSize = TextSizes.Body,
		}),
		Best = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Color = UIConfig.Palette.TextSoft,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, TextSizes.Small),
			Text = string.format(meter.BestFormat, best),
			TextSize = TextSizes.Small,
		}),
	})
end

local function EventBanner(props: any)
	local event = props.data.SpecialEvent
	useTick(event ~= nil)
	if event == nil then
		return nil
	end
	local left = math.max(0, math.floor(event.EndsAt - Workspace:GetServerTimeNow()))
	if left <= 0 then
		return nil
	end
	local map = ConfigLookup.GetMap(event.MapId)
	local config = RunUIConfig.Event
	return e(ChunkyButton, {
		anchorPoint = props.layout.AnchorPoint,
		position = props.layout.Position,
		size = UDim2.fromOffset(config.Width, config.Height),
		swatch = config.Swatch,
		text = string.format(
			config.Format,
			if map ~= nil then map.DisplayName else event.MapId,
			string.format(config.TimeFormat, left // SECONDS_PER_MINUTE, left % SECONDS_PER_MINUTE)
		),
		textSize = TextSizes.Body,
	})
end

local function RevivePopup(props: any)
	local offer = props.data.ReviveOffer
	local now = useTick(offer ~= nil)
	if offer == nil then
		return nil
	end
	local left = math.max(0, math.ceil(offer.ExpiresAt - now))
	if left <= 0 then
		return nil
	end
	local tier = ConfigLookup.GetReviveTier(offer.Tier)
	local config = RunUIConfig.Revive
	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(config.Width, config.Height),
	}, {
		Window = e(Window, {
			height = config.Height,
			swatch = "Red",
			title = config.Title,
			width = config.Width,
		}, {
			Countdown = Primitives.text({
				Color = UIConfig.Palette.Sparkle,
				Size = UDim2.new(1, 0, 0.4, 0),
				Text = string.format(config.CountdownFormat, left),
				TextSize = TextSizes.Huge,
			}),
			Buy = e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 1),
				onActivated = function()
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, offer.ProductId)
				end,
				position = UDim2.fromScale(0.5, 1),
				size = UDim2.fromScale(0.9, 0.45),
				swatch = config.Swatch,
				text = string.format(config.ButtonFormat, if tier ~= nil then tier.PriceRobux else 0),
				textSize = TextSizes.Large,
			}),
		}),
	})
end

return function(props: any)
	local layouts = RunUIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"]
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Meter = if props.inRun then e(Meter, { data = props.data, layout = layouts.Meter }) else nil,
		Event = e(EventBanner, { data = props.data, layout = layouts.Event }),
		Revive = if props.inRun then e(RevivePopup, { data = props.data, layout = layouts.Revive }) else nil,
	})
end
