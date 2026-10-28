--!strict

--[[
	RebirthWindow
	Big spinning rebirth icon over a sunburst, the current rebirth count, the coin bonus now and
	after rebirthing, the gem reward and the coin cost, and a REBIRTH button (Net.Rebirth) that
	lights up once the player can afford it.

	Props: data (DataController state), ui (useUIScale result), onClose
	Dependencies: React, Net, UIConfig, LobbyUIConfig, RebirthConfig, ConfigLookup, Format, Primitives,
		ChunkyButton, Inset, Rays, Window, WindowSize
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
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Window = require(Components.Window)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Rebirth = LobbyUIConfig.Rebirth
local Gap = UIConfig.Sizes.Window.Gap
local TextSizes = UIConfig.TextSizes
local Palette = UIConfig.Palette

local function line(order: number, text: string, color: Color3?)
	return Primitives.text({
		Color = color,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, TextSizes.Large + Gap / 2),
		Text = text,
		TextSize = TextSizes.Large,
	})
end

return function(props: any)
	local width, height = WindowSize.fit(props.ui, Rebirth.Width, Rebirth.Height)
	local data = props.data
	local rebirths = data.Rebirths or 0
	local cost = ConfigLookup.GetRebirthCost(rebirths)
	local canRebirth = (data.Coins or 0) >= cost
	local iconSize = TextSizes.Huge * 2

	return e(Window, {
		height = height,
		onClose = props.onClose,
		swatch = Rebirth.Swatch,
		title = Rebirth.Title,
		width = width,
	}, {
		Hero = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, iconSize),
		}, {
			Rays = e(Rays, { size = iconSize * LobbyUIConfig.Rays.SizeRatio, zIndex = 1 }),
			Icon = Primitives.text({
				Stroke = false,
				Text = Rebirth.Icon,
				TextSize = iconSize,
				ZIndex = 2,
			}),
		}),
		Info = e(Inset, {
			padding = Gap,
			position = UDim2.fromOffset(0, iconSize + Gap),
			size = UDim2.new(1, 0, 1, -(iconSize + Gap * 3 + TextSizes.Body + LobbyUIConfig.Daily.ClaimHeight)),
		}, {
			Layout = Primitives.list(Enum.FillDirection.Vertical, Gap / 2),
			Count = line(1, string.format(Rebirth.Lines.Count, rebirths)),
			Multiplier = line(
				2,
				string.format(
					Rebirth.Lines.Multiplier,
					Format.multiplier(ConfigLookup.GetRebirthMultiplier(rebirths)),
					Format.multiplier(ConfigLookup.GetRebirthMultiplier(rebirths + 1))
				),
				Palette.Sparkle
			),
			Gems = line(3, string.format(Rebirth.Lines.Gems, RebirthConfig.GemsPerRebirth)),
			Cost = line(4, string.format(Rebirth.Lines.Cost, Format.commas(cost))),
		}),
		Warning = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Palette.TextSoft,
			Font = "Body",
			Position = UDim2.new(0.5, 0, 1, -(LobbyUIConfig.Daily.ClaimHeight + Gap)),
			Size = UDim2.new(1, 0, 0, TextSizes.Body),
			Text = Rebirth.Warning,
			TextSize = TextSizes.Small,
		}),
		Button = e(ChunkyButton, {
			anchorPoint = Vector2.new(0.5, 1),
			enabled = canRebirth,
			onActivated = function()
				Net.Rebirth:Fire()
			end,
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.new(0.6, 0, 0, LobbyUIConfig.Daily.ClaimHeight),
			swatch = "Teal",
			text = Rebirth.Button,
			textSize = TextSizes.Header,
		}),
	})
end
