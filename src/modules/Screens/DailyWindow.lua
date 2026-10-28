--!strict

--[[
	DailyWindow
	7-day login streak: one chunky tile per DailyRewardConfig.Days entry (icon, day, reward
	label), claimed days stamped, today's tile glowing with a sunburst, and a big CLAIM button
	that counts down to the next claim while waiting. Claiming fires Net.ClaimDaily; the
	server answers with DailyState + DataSync + a toast.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, DailyRewardConfig, Primitives, ChunkyButton,
		Inset, Rays, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local DailyRewardConfig = require(ReplicatedStorage.Modules.Config.DailyRewardConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Daily = LobbyUIConfig.Daily
local Gap = UIConfig.Sizes.Window.Gap
local TextSizes = UIConfig.TextSizes
local Palette = UIConfig.Palette

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_MINUTE = 60

local function clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format(
		"%02d:%02d:%02d",
		total // SECONDS_PER_HOUR,
		(total % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE,
		total % SECONDS_PER_MINUTE
	)
end

local function DayTile(props: any)
	local reward = props.reward
	local visual = Daily.KindVisuals[reward.Kind] or Daily.KindVisuals.Coins
	local today = props.isToday
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.day,
		Size = UDim2.fromScale(1, 1),
	}, {
		Rays = if today then e(Rays, { size = Daily.TileHeight * Daily.RaysRatio, zIndex = 0 }) else nil,
		Tile = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = if props.claimed then "Grey" else visual.Swatch,
			zIndex = 2,
		}, {
			Day = Primitives.text({
				Fit = true,
				Position = UDim2.fromScale(0, 0.04),
				Size = UDim2.fromScale(1, 0.2),
				Text = string.format(Daily.DayFormat, props.day),
				TextSize = TextSizes.Body,
				ZIndex = 3,
			}),
			Icon = Primitives.text({
				Position = UDim2.fromScale(0, 0.24),
				Size = UDim2.fromScale(1, 0.42),
				Stroke = false,
				Text = if props.claimed then Daily.Claimed else visual.Icon,
				TextSize = TextSizes.BigIcon,
				ZIndex = 3,
			}),
			Label = Primitives.text({
				Fit = true,
				Position = UDim2.fromScale(0.05, 0.7),
				Size = UDim2.fromScale(0.9, 0.24),
				Text = reward.Label,
				TextSize = TextSizes.Small,
				Wrapped = true,
				ZIndex = 3,
			}),
		}),
	})
end

return function(props: any)
	local ui = props.ui
	local width, height = WindowSize.fit(ui, Daily.Width, Daily.Height)
	local daily = props.data.Daily
	local remaining, setRemaining = React.useState(if daily ~= nil then daily.SecondsUntilNext else 0)

	React.useEffect(function()
		if daily == nil then
			return
		end
		setRemaining(daily.SecondsUntilNext)
		local startedAt = os.clock()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if running then
					setRemaining(math.max(0, daily.SecondsUntilNext - (os.clock() - startedAt)))
				end
			end
		end)
		return function()
			running = false
		end
	end, { daily } :: { any })

	local canClaim = daily ~= nil and (daily.CanClaim or remaining <= 0)
	local today = if daily ~= nil then daily.Day else 1
	local streak = if daily ~= nil then daily.Streak else 0

	local tiles: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Gap, Gap),
			CellSize = UDim2.new(1 / Daily.Columns, -Gap, 0, Daily.TileHeight),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for day, reward in DailyRewardConfig.Days do
		local claimed = if canClaim then day < today else day <= today
		tiles["Day" .. day] = e(DayTile, {
			claimed = claimed and streak > 0,
			day = day,
			isToday = canClaim and day == today,
			reward = reward,
		})
	end

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Daily.Swatch,
		title = Daily.Title,
		width = width,
	}, {
		Tiles = e(Inset, {
			padding = Gap,
			size = UDim2.new(1, 0, 1, -(Daily.ClaimHeight + Gap * 2 + TextSizes.Body)),
		}, tiles),
		Streak = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Palette.TextSoft,
			Position = UDim2.new(0.5, 0, 1, -(Daily.ClaimHeight + Gap)),
			Size = UDim2.new(1, 0, 0, TextSizes.Body),
			Text = string.format(Daily.StreakFormat, streak, DailyRewardConfig.StreakLength),
			TextSize = TextSizes.Body,
		}),
		Claim = e(ChunkyButton, {
			anchorPoint = Vector2.new(0.5, 1),
			enabled = canClaim,
			onActivated = function()
				Net.ClaimDaily:Fire()
			end,
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.new(0.5, 0, 0, Daily.ClaimHeight),
			swatch = "Green",
			text = if canClaim then Daily.Claim else string.format(Daily.NextFormat, clock(remaining)),
			textSize = TextSizes.Header,
		}),
	})
end
