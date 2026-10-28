--!strict

--[[
	SideRail
	Lobby HUD in the simulator style: a grid of big square icon buttons on the left edge
	(LobbyUIConfig.Rail.Items, each opening a LobbyState route, with a pulsing badge when
	that feature has something to collect) and a big bouncing PLAY button with a spinning
	sunburst behind it at the bottom of the screen.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, UIConfig, LobbyUIConfig, LobbyState, Primitives, ChunkyButton, Rays, Badge
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local Components = ReplicatedStorage.Modules.UIComponents
local Badge = require(Components.Badge)
local ChunkyButton = require(Components.ChunkyButton)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)

local e = React.createElement
local Rail = LobbyUIConfig.Rail
local Play = LobbyUIConfig.PlayButton
local TextSizes = UIConfig.TextSizes

local function hasBadge(item: any, data: any): boolean
	if item.Route == LobbyState.Routes.Daily then
		return data.Daily ~= nil and data.Daily.CanClaim == true
	end
	return false
end

local function RailButton(props: any)
	local item = props.item
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(Rail.ButtonSize, Rail.ButtonSize + Rail.LabelHeight),
	}, {
		Button = e(ChunkyButton, {
			icon = item.Icon,
			iconSize = Rail.ButtonSize * UIConfig.Shape.IconFill,
			onActivated = function()
				LobbyState.SetActive(item.Route)
			end,
			size = UDim2.fromOffset(Rail.ButtonSize, Rail.ButtonSize),
			swatch = item.Swatch,
			overlay = if props.badge then e(Badge, { size = Rail.BadgeSize, zIndex = 3 }) else nil,
		}),
		Label = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Fit = true,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, Rail.Gap, 0, Rail.LabelHeight),
			Text = item.Label,
			TextSize = TextSizes.Body,
		}),
	})
end

local function PlayButton(props: any)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(
				LobbyUIConfig.Bounce.Seconds,
				UIConfig.Animation.TwinkleStyle,
				UIConfig.Animation.TwinkleDirection,
				-1,
				true
			),
			{ Scale = 1 + LobbyUIConfig.Bounce.Scale }
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, {})

	return e("Frame", {
		AnchorPoint = props.layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.layout.Position,
		Size = UDim2.fromOffset(Play.Width, Play.Height),
	}, {
		Rays = e(Rays, { size = Play.Width * LobbyUIConfig.Rays.SizeRatio, zIndex = 0 }),
		Holder = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Button = e(ChunkyButton, {
				icon = Play.Icon,
				iconSize = TextSizes.BigIcon,
				onActivated = function()
					LobbyState.SetActive(Play.Route)
				end,
				size = UDim2.fromScale(1, 1),
				swatch = Play.Swatch,
				text = Play.Label,
				textSize = TextSizes.Huge,
			}),
		}),
	})
end

return function(props: any)
	local layouts = LobbyUIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"]
	local columnCount = math.ceil(#Rail.Items / Rail.PerColumn)
	local perColumn = math.min(#Rail.Items, Rail.PerColumn)
	local cellHeight = Rail.ButtonSize + Rail.LabelHeight

	local buttons: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(Rail.Gap, Rail.Gap),
			CellSize = UDim2.fromOffset(Rail.ButtonSize, cellHeight),
			FillDirection = Enum.FillDirection.Vertical,
			FillDirectionMaxCells = Rail.PerColumn,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, item in Rail.Items do
		buttons[item.Id] = e(RailButton, {
			badge = hasBadge(item, props.data),
			item = item,
			layoutOrder = index,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Rail = e("Frame", {
			AnchorPoint = layouts.Rail.AnchorPoint,
			BackgroundTransparency = 1,
			Position = layouts.Rail.Position,
			Size = UDim2.fromOffset(
				columnCount * Rail.ButtonSize + (columnCount - 1) * Rail.Gap,
				perColumn * cellHeight + (perColumn - 1) * Rail.Gap
			),
		}, buttons),
		Play = e(PlayButton, { layout = layouts.PlayButton }),
	})
end
