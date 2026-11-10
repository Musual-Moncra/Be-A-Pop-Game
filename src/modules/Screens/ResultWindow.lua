--!strict

--[[
	ResultWindow
	End-of-run window: score and coins count up together over ResultCountSeconds; the score,
	the Stink multiplier line, coin / gem / XP reward rows, badges for level up, target
	reached, quests done and objects soiled, and a CONTINUE button that clears the result.

	Props: data (DataController state with LastRun), ui (useUIScale result)
	Dependencies: React, RunService, UIConfig, DataController, PetView, Primitives, ChunkyButton, Chip, Inset,
		Window, WindowSize, Format
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local Components = ReplicatedStorage.Modules.UIComponents
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Result
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function rewardRow(order: number, icon: string, label: string, amount: number, swatchName: string)
	local swatch = Primitives.swatch(swatchName)
	return e(Inset, {
		layoutOrder = order,
		size = UDim2.new(1, 0, 0, Sizes.RowHeight),
	}, {
		Padding = Primitives.paddingXY(Gap, 0),
		Icon = Primitives.text({
			Size = UDim2.new(0, Sizes.RowHeight, 1, 0),
			Stroke = false,
			Text = icon,
			TextSize = TextSizes.Icon,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Label = Primitives.text({
			Position = UDim2.fromOffset(Sizes.RowHeight, 0),
			Size = UDim2.new(0.5, -Sizes.RowHeight, 1, 0),
			Text = label,
			TextSize = TextSizes.Large,
			XAlign = Enum.TextXAlignment.Left,
		}),
		Amount = Primitives.text({
			AnchorPoint = Vector2.new(1, 0),
			Color = swatch.Top,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),
			Text = string.format(Text.ResultPlus, Format.commas(amount)),
			TextSize = TextSizes.Header,
			XAlign = Enum.TextXAlignment.Right,
		}),
	})
end

return function(props: any)
	local summary = props.data.LastRun
	local ui = props.ui
	local displayScore, setDisplayScore = React.useState(0)
	local displayCoins, setDisplayCoins = React.useState(0)

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
			height = Sizes.BadgeHeight,
			layoutOrder = 1,
			swatch = "Gold",
			text = string.format(Text.ResultLevelUp, summary.NewLevel),
			textSize = TextSizes.Body,
		})
	end
	if summary.TargetReached then
		badges.Target = e(Chip, {
			height = Sizes.BadgeHeight,
			layoutOrder = 2,
			swatch = "Pink",
			text = Text.ResultTarget,
			textSize = TextSizes.Body,
		})
	end
	if summary.QuestsCompleted > 0 then
		badges.Quests = e(Chip, {
			height = Sizes.BadgeHeight,
			layoutOrder = 3,
			swatch = "Teal",
			text = string.format(Text.ResultQuests, summary.QuestsCompleted),
			textSize = TextSizes.Body,
		})
	end
	if summary.ObjectsSoiled > 0 then
		badges.Soiled = e(Chip, {
			height = Sizes.BadgeHeight,
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
	local badgeRows = math.ceil(badgeCount / Sizes.BadgesPerRow)
	local stink = PetView.TotalStink(props.data)
	local stinkCoins = math.floor(summary.Score * stink)
	local stinkLine = string.format(
		Text.ResultStinkFormat,
		Format.commas(summary.Score),
		Format.multiplier(stink),
		Format.commas(stinkCoins)
	)
	local footerHeight = UIConfig.Sizes.Play.PlayButtonHeight
	local contentHeight = TextSizes.Body
		+ TextSizes.Huge
		+ TextSizes.Body
		+ Shape.Stroke * 2
		+ Sizes.RowHeight * 3
		+ badgeRows * (Sizes.BadgeHeight + Shape.Stroke * 2)
		+ (Sizes.BaseRows - 1) * Gap / 2
	local width, height = WindowSize.fit(ui, Sizes.Width, contentHeight + WindowSize.chrome(footerHeight))

	return e(Window, {
		footer = e(ChunkyButton, {
			onActivated = DataController.DismissResult,
			size = UDim2.fromScale(1, 1),
			swatch = "Green",
			text = Text.Continue,
			textSize = TextSizes.Title,
		}),
		footerHeight = footerHeight,
		height = height,
		swatch = if summary.OutOfTime then "Red" else "Gold",
		title = if summary.OutOfTime then Text.ResultTimeUp else Text.ResultTitle,
		width = width,
	}, {
		Scroll = Primitives.scroll({}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2, Enum.HorizontalAlignment.Center),
			Caption = Primitives.text({
				Color = Palette.TextSoft,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, TextSizes.Body),
				Text = Text.ResultScore,
				TextSize = TextSizes.Body,
			}),
			Score = Primitives.text({
				Color = Palette.Sparkle,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, TextSizes.Huge + Shape.Stroke * 2),
				Text = Format.commas(displayScore),
				TextSize = TextSizes.Huge,
			}),
			Stink = Primitives.text({
				Color = Palette.TextSoft,
				Fit = true,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, TextSizes.Body),
				Text = stinkLine,
				TextSize = TextSizes.Body,
			}),
			Coins = rewardRow(4, Text.CoinIcon, Text.ResultCoins, displayCoins, "Gold"),
			Gems = rewardRow(5, Text.GemIcon, Text.ResultGems, summary.Gems, "Purple"),
			Xp = rewardRow(6, Text.XpIcon, Text.ResultXp, summary.Xp, "Green"),
			Badges = e("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 7,
				Size = UDim2.fromScale(1, 0),
			}, badges),
		}),
	})
end
