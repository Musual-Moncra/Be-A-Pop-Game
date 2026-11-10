--!strict

--[[
	DailyWindow
	Seven-day login streak: one glossy tile per DailyRewardConfig.Days entry. Claimed days are
	dimmed with a check, today's tile is gold with a pulsing ring and sunburst, future days are
	grey. Day 7 is wider and gold. A countdown chip and the streak line sit under the row and a
	large CLAIM button waits at the bottom; claiming fires Net.ClaimDaily.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, TweenService, UIConfig, LobbyUIConfig, DailyRewardConfig,
		Primitives, ChunkyButton, Chip, Inset, Rays, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local DailyRewardConfig = require(ReplicatedStorage.Modules.Config.DailyRewardConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Daily = LobbyUIConfig.Daily
local Gap = UIConfig.Sizes.Window.Gap
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local TextSizes = UIConfig.TextSizes

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
	local today = props.today
	local claimed = props.claimed
	local locked = props.locked
	local isLast = props.day == DailyRewardConfig.StreakLength
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		if not today then
			return
		end
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		scale.Scale = 1
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.70, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.05 }
		)
		tween:Play()
		return function()
			tween:Cancel()
			scale.Scale = 1
		end
	end, { today } :: { any })

	local swatch = if today
		then "Gold"
		elseif claimed or locked then "Grey"
		elseif isLast then Daily.DaySevenSwatch
		else visual.Swatch
	local icon = if claimed then Daily.Claimed elseif locked then Daily.LockedIcon else visual.Icon

	local content: { [string]: any } = {
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
			Text = icon,
			TextSize = Daily.TileIconSize,
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
	}
	if claimed then
		content.Dim = e("Frame", {
			BackgroundColor3 = Palette.Ink,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		}, { Corner = Primitives.corner(Shape.Radius) })
		content.Check = Primitives.text({
			Text = Daily.Claimed,
			TextSize = TextSizes.BigIcon,
			ZIndex = 6,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.day,
		Size = UDim2.fromOffset(props.width, Daily.TileHeight),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Rays = if today then e(Rays, { size = Daily.TileHeight * Daily.RaysRatio, zIndex = 0 }) else nil,
		Tile = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = swatch,
			zIndex = 2,
			overlay = if today
				then e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Primitives.swatch("Gold").Top,
					Thickness = Shape.RimStroke,
				})
				else nil,
		}, content),
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
	local narrow = ui.mobile or ui.safeWidth < 900

	local tiles: { [string]: any } = {}
	for day, reward in DailyRewardConfig.Days do
		local claimed = if canClaim then day < today else day <= today
		local tileWidth = Daily.TileWidth
		if not narrow and day == DailyRewardConfig.StreakLength then
			tileWidth = math.floor(Daily.TileWidth * Daily.DaySevenScale)
		end
		tiles["Day" .. day] = e(DayTile, {
			claimed = claimed and streak > 0,
			day = day,
			locked = day > today,
			reward = reward,
			today = canClaim and day == today,
			width = if narrow then 0 else tileWidth,
		})
	end

	local row
	if narrow then
		tiles.Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Daily.TileGap, Daily.TileGap),
			CellSize = UDim2.new(
				1 / Daily.PhoneColumns,
				-Daily.TileGap * (Daily.PhoneColumns - 1) / Daily.PhoneColumns,
				0,
				Daily.TileHeight
			),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local rows = math.ceil(DailyRewardConfig.StreakLength / Daily.PhoneColumns)
		row = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, rows * Daily.TileHeight + (rows - 1) * Daily.TileGap),
		}, tiles)
	else
		tiles.Layout = Primitives.list(
			Enum.FillDirection.Horizontal,
			Daily.TileGap,
			Enum.HorizontalAlignment.Center,
			Enum.VerticalAlignment.Center
		)
		row = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Daily.TileHeight),
		}, tiles)
	end

	local rowHeight = if narrow
		then math.ceil(DailyRewardConfig.StreakLength / Daily.PhoneColumns) * Daily.TileHeight + (math.ceil(
			DailyRewardConfig.StreakLength / Daily.PhoneColumns
		) - 1) * Daily.TileGap
		else Daily.TileHeight
	local chipTop = rowHeight + Gap

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Daily.Swatch,
		title = Daily.Title,
		width = width,
	}, {
		Row = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, rowHeight),
		}, { Content = row }),
		Countdown = e(Chip, {
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, chipTop),
			swatch = if canClaim then "Gold" else "Grey",
			text = if canClaim then Daily.Claim else string.format(Daily.NextFormat, clock(remaining)),
			textSize = TextSizes.Body,
		}),
		Streak = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Color = Palette.TextSoft,
			Position = UDim2.new(0.5, 0, 0, chipTop + TextSizes.Body + Gap),
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
			shine = canClaim,
			size = UDim2.new(0.6, 0, 0, Daily.ClaimHeight),
			swatch = "Green",
			text = if canClaim then Daily.Claim else string.format(Daily.NextFormat, clock(remaining)),
			textSize = TextSizes.Header,
		}),
	})
end
