--!strict

--[[
	ResultWindow
	End-of-run window: a Gold banner with a rotating sunburst, the score counting up, a
	Score x Stink chip, glossy Coins / Gems / XP reward pills, a NEW BEST stamp when the run
	beat the previous best, result badges and a shiny CONTINUE button.

	Props: data (DataController state with LastRun), ui (useUIScale result)
	Dependencies: React, RunService, UIConfig, RunUIConfig, DataController, PetView,
			Components (Burst, Chip, ChunkyButton, CoinFly, Format, Primitives, Rays, Twinkle, Window,
			WindowSize)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local RunUIConfig = require(ReplicatedStorage.Modules.Config.RunUIConfig)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local Components = ReplicatedStorage.Modules.UIComponents
local Burst = require(Components.Burst)
local Chip = require(Components.Chip)
local CoinFly = require(Components.CoinFly)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Twinkle = require(Components.Twinkle)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes
local Config = RunUIConfig.Result

local function rewardPill(order: number, icon: string, label: string, amount: string, swatchName: string)
	return e(ChunkyButton, {
		gloss = true,
		layoutOrder = order,
		size = UDim2.new(1, 0, 0, Config.RowHeight),
		swatch = swatchName,
	}, {
		Icon = e(ChunkyButton, {
			gloss = true,
			icon = icon,
			iconSize = Config.RowIconSize * Shape.IconFill,
			position = UDim2.fromOffset(10, (Config.RowHeight - Config.RowIconSize) / 2),
			round = true,
			size = UDim2.fromOffset(Config.RowIconSize, Config.RowIconSize),
			swatch = Config.RowIconSwatch,
			zIndex = 3,
		}),
		Label = Primitives.text({
			Color = Palette.Text,
			Position = UDim2.fromOffset(Config.RowIconSize + 22, 0),
			Size = UDim2.new(1, -(Config.RowIconSize + 22), 1, 0),
			Text = label,
			TextSize = TextSizes.Large,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}),
		Amount = Primitives.text({
			AnchorPoint = Vector2.new(1, 0),
			Color = Palette.Text,
			Position = UDim2.new(1, -16, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = string.format(Text.ResultPlus, amount),
			TextSize = TextSizes.Header,
			YAlign = Enum.TextYAlignment.Center,
			ZIndex = 3,
			XAlign = Enum.TextXAlignment.Right,
		}),
	})
end

return function(props: any)
	local summary = props.data.LastRun
	local ui = props.ui
	local displayScore, setDisplayScore = React.useState(0)
	local displayCoins, setDisplayCoins = React.useState(0)
	local bestBefore = React.useRef(props.data.Stats.BestScore)
	local newBest = summary ~= nil and summary.Score > bestBefore.current
	local coinTrigger = if summary ~= nil and summary.Coins > 0 then summary else nil
	local gemTrigger = if summary ~= nil and summary.Gems > 0 then summary else nil
	local burstTrigger = if newBest then summary else nil

	React.useEffect(function()
		setDisplayScore(0)
		setDisplayCoins(0)
		if summary == nil then
			return
		end
		local duration = UIConfig.Animation.ResultCountSeconds
		if duration <= 0 then
			setDisplayScore(summary.Score)
			setDisplayCoins(summary.Coins)
			return
		end
		local started = os.clock()
		local connection = RunService.Heartbeat:Connect(function()
			local progress = math.clamp((os.clock() - started) / duration, 0, 1)
			local eased = 1 - (1 - progress) * (1 - progress)
			setDisplayScore(math.floor(summary.Score * eased))
			setDisplayCoins(math.floor(summary.Coins * eased))
			if progress >= 1 then
				connection:Disconnect()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { summary } :: { any })

	React.useEffect(function()
		if UIConfig.Animation.ResultAutoCloseSeconds <= 0 then
			return
		end
		local thread = task.delay(UIConfig.Animation.ResultAutoCloseSeconds, DataController.DismissResult)
		return function()
			task.cancel(thread)
		end
	end, { summary })

	if summary == nil then
		return nil
	end

	local badges: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Shape.Stroke * 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	}
	if summary.LeveledUp > 0 then
		badges.Level = e(Chip, {
			height = Config.BadgeHeight,
			layoutOrder = 1,
			swatch = "Gold",
			text = string.format(Text.ResultLevelUp, summary.NewLevel),
			textSize = TextSizes.Body,
		})
	end
	if summary.TargetReached then
		badges.Target = e(Chip, {
			height = Config.BadgeHeight,
			layoutOrder = 2,
			swatch = "Pink",
			text = Text.ResultTarget,
			textSize = TextSizes.Body,
		})
	end
	if summary.QuestsCompleted > 0 then
		badges.Quests = e(Chip, {
			height = Config.BadgeHeight,
			layoutOrder = 3,
			swatch = "Teal",
			text = string.format(Text.ResultQuests, summary.QuestsCompleted),
			textSize = TextSizes.Body,
		})
	end
	if summary.ObjectsSoiled > 0 then
		badges.Soiled = e(Chip, {
			height = Config.BadgeHeight,
			layoutOrder = 4,
			swatch = "Brown",
			text = string.format(Text.ResultSoiled, summary.ObjectsSoiled),
			textSize = TextSizes.Body,
		})
	end

	local badgeCount = 0
	for key in badges do
		if key ~= "Layout" then
			badgeCount += 1
		end
	end

	local stink = PetView.TotalStink(props.data)
	local stinkLine = string.format(Text.ResultStinkFormat, Format.commas(summary.Score), Format.multiplier(stink))
	local footerHeight = Config.ContinueHeight
	local bannerHeight = Config.ScoreTextSize + Config.CaptionTextSize + Gap * 2
	local rowsHeight = Config.RowHeight * 3 + Gap
	local badgeHeight = if badgeCount > 0
		then math.ceil(badgeCount / Config.BadgesPerRow) * (Config.BadgeHeight + Shape.Stroke * 2)
		else 0
	local itemCount = if badgeCount > 0 then 4 else 3
	local contentHeight = bannerHeight + Config.StinkChipHeight + rowsHeight + badgeHeight + (itemCount - 1) * Gap / 2
	local width, height = WindowSize.fit(ui, Config.Width, contentHeight + WindowSize.chrome(footerHeight))

	local banner = e("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, bannerHeight),
	}, {
		Rays = e(Rays, {
			anchorPoint = Vector2.new(0.5, 0.5),
			color = Config.RaysColor,
			position = UDim2.fromScale(0.5, 0.45),
			size = Config.RaysSize,
			zIndex = 1,
		}),
		Caption = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Color = Palette.TextSoft,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, 0, 0, Config.CaptionTextSize + Shape.SmallTextStroke * 2),
			StrokeSize = Shape.SmallTextStroke,
			Text = Text.ResultScore,
			TextSize = Config.CaptionTextSize,
			ZIndex = 2,
		}),
		Score = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 0),
			Color = Palette.Sparkle,
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.new(1, 0, 0, Config.ScoreTextSize + Shape.TextStroke * 2),
			Text = Format.commas(displayScore),
			TextSize = Config.ScoreTextSize,
			ZIndex = 2,
		}),
		Twinkle = e(Twinkle, {
			clip = true,
			rate = if newBest then Config.NewBestTwinkleRate else Config.TwinkleRate,
			size = Config.TwinkleSize,
			zIndex = 2,
		}),
		NewBest = if newBest
			then e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.98, 0),
				Rotation = 8,
				Size = UDim2.fromOffset(1, 1),
				ZIndex = 3,
			}, {
				Label = e(Chip, {
					anchorPoint = Vector2.new(1, 0),
					height = Config.NewBestHeight,
					position = UDim2.fromScale(1, 0),
					swatch = Config.NewBestSwatch,
					text = Config.NewBestText,
					textSize = TextSizes.Body,
					zIndex = 3,
				}),
			})
			else nil,
	})

	local rows = e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Config.RowHeight * 3 + Gap),
	}, {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
		Coins = rewardPill(1, Text.CoinIcon, Text.ResultCoins, Format.commas(displayCoins), "Gold"),
		Gems = rewardPill(2, Text.GemIcon, Text.ResultGems, Format.commas(summary.Gems), "Purple"),
		Xp = rewardPill(3, Text.XpIcon, Text.ResultXp, Format.commas(summary.Xp), "Green"),
	})

	local scrollChildren: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2, Enum.HorizontalAlignment.Center),
		Banner = banner,
		Stink = e(Chip, {
			height = Config.StinkChipHeight,
			layoutOrder = 2,
			swatch = "Purple",
			text = stinkLine,
			textSize = Config.StinkChipTextSize,
		}),
		Rows = rows,
	}
	if badgeCount > 0 then
		scrollChildren.Badges = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
		}, badges)
	end

	local window = e(Window, {
		footer = e(ChunkyButton, {
			gloss = true,
			onActivated = DataController.DismissResult,
			shine = true,
			size = UDim2.fromScale(1, 1),
			swatch = "Green",
			text = Text.Continue,
			textSize = TextSizes.Title,
		}),
		footerHeight = footerHeight,
		height = height,
		icon = Config.Icon,
		swatch = if summary.OutOfTime then "Red" else "Gold",
		title = if summary.OutOfTime then Text.ResultTimeUp else Text.ResultTitle,
		width = width,
	}, {
		Scroll = Primitives.scroll({}, scrollChildren),
	})

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Window = window,
		Coins = e(CoinFly, {
			trigger = coinTrigger,
			from = Config.CoinFly.CoinsFrom,
			to = Config.CoinFly.CoinsTo,
			icon = Text.CoinIcon,
			count = Config.CoinFly.Count,
			duration = Config.CoinFly.Duration,
			zIndex = 20,
		}),
		Gems = e(CoinFly, {
			trigger = gemTrigger,
			from = Config.CoinFly.GemsFrom,
			to = Config.CoinFly.GemsTo,
			icon = Text.GemIcon,
			count = Config.CoinFly.Count,
			duration = Config.CoinFly.Duration,
			zIndex = 20,
		}),
		Burst = e(Burst, {
			trigger = burstTrigger,
			origin = Config.NewBestOrigin,
			count = Config.NewBestBurstCount,
			zIndex = 21,
		}),
	})
end
