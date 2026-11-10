--!strict

--[[
	RebirthWindow
	Big spinning rebirth icon over a sunburst, the current rebirth count, the coin bonus now and
	after rebirthing, the gem reward and the coin cost as glossy rows, and a large REBIRTH
	button that lights up once the player can afford it.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, RebirthConfig, ConfigLookup, Format,
		Primitives, ChunkyButton, Inset, Rays, Window, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local RebirthConfig = require(ReplicatedStorage.Modules.Config.RebirthConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local GlowRing = require(Components.GlowRing)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Twinkle = require(Components.Twinkle)
local useBreathe = require(Components.useBreathe)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Motion = LobbyUIConfig.Motion
local Rebirth = LobbyUIConfig.Rebirth
local Gap = UIConfig.Sizes.Window.Gap
local Palette = UIConfig.Palette
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function infoRow(order: number, icon: string, text: string, color: Color3?): any
	return e(Inset, {
		layoutOrder = order,
		padding = Gap / 2,
		size = UDim2.new(1, 0, 0, Rebirth.RowHeight),
	}, {
		Icon = Primitives.text({
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(40, Rebirth.RowHeight - Gap),
			Stroke = false,
			Text = icon,
			TextSize = TextSizes.Icon,
		}),
		Label = Primitives.text({
			Color = color,
			Fit = true,
			Position = UDim2.fromOffset(48, 0),
			Size = UDim2.new(1, -48, 1, 0),
			Text = text,
			TextSize = TextSizes.Large,
			XAlign = Enum.TextXAlignment.Left,
		}),
	})
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Rebirth.Width, Rebirth.Height)
	local data = props.data
	local rebirths = data.Rebirths or 0
	local cost = ConfigLookup.GetRebirthCost(rebirths)
	local canRebirth = (data.Coins or 0) >= cost
	local rowsTop = Rebirth.HeroSize + Gap
	local buttonScale = React.useRef(nil)
	useBreathe(buttonScale, Motion.BreatheButtonScale, Motion.BreatheButtonPeriod, 0.31, canRebirth)

	local rows: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Rebirth.RowGap),
		Count = infoRow(1, Rebirth.Icon, string.format(Rebirth.Lines.Count, rebirths)),
		Multiplier = infoRow(
			2,
			Text.CoinIcon,
			string.format(
				Rebirth.Lines.Multiplier,
				Format.multiplier(ConfigLookup.GetRebirthMultiplier(rebirths)),
				Format.multiplier(ConfigLookup.GetRebirthMultiplier(rebirths + 1))
			),
			Palette.Sparkle
		),
		Gems = infoRow(3, Text.GemIcon, string.format(Rebirth.Lines.Gems, RebirthConfig.GemsPerRebirth)),
		Cost = infoRow(
			4,
			Text.CoinIcon,
			string.format(Rebirth.Lines.Cost, Format.commas(cost)),
			if canRebirth then Palette.Sparkle else UIConfig.Swatches.Red.Top
		),
	}

	return e(Window, {
		height = height,
		icon = Rebirth.Icon,
		onClose = props.onClose,
		swatch = Rebirth.Swatch,
		title = Rebirth.Title,
		width = width,
	}, {
		Hero = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Rebirth.HeroSize),
		}, {
			Rays = e(Rays, { size = Rebirth.HeroSize * LobbyUIConfig.Rays.SizeRatio, zIndex = 1 }),
			Icon = Primitives.text({
				Stroke = false,
				Text = Rebirth.Icon,
				TextSize = Rebirth.HeroSize,
				ZIndex = 2,
			}),
			Twinkle = e(Twinkle, {
				clip = true,
				rate = Motion.HeroTwinkleRate,
				zIndex = 3,
			}),
		}),
		Rows = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, rowsTop),
			Size = UDim2.new(1, 0, 1, -(rowsTop + Rebirth.ButtonHeight + Gap * 3 + TextSizes.Body)),
		}, rows),
		Warning = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Palette.TextSoft,
			Font = "Body",
			Position = UDim2.new(0.5, 0, 1, -(Rebirth.ButtonHeight + Gap * 2)),
			Size = UDim2.new(1, 0, 0, TextSizes.Body),
			Text = Rebirth.Warning,
			TextSize = TextSizes.Small,
		}),
		Button = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(Rebirth.ButtonWidth, Rebirth.ButtonHeight),
		}, {
			Scale = e("UIScale", { ref = buttonScale }),
			Glow = if canRebirth
				then e(GlowRing, {
					color = UIConfig.Swatches.Gold.Top,
					size = Rebirth.ButtonHeight * 2.4,
					zIndex = 1,
				})
				else nil,
			Button = e(ChunkyButton, {
				enabled = canRebirth,
				onActivated = function()
					Net.Rebirth:Fire()
				end,
				popIn = true,
				shine = canRebirth,
				size = UDim2.fromScale(1, 1),
				swatch = "Green",
				text = Rebirth.Button,
				textSize = TextSizes.Header,
				zIndex = 3,
			}),
		}),
	})
end
