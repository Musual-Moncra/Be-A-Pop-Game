--!strict

--[[
	LobbyDock
	The whole lobby HUD is one bouncing round MENU button at the bottom centre. Pressing it pops
	a horizontal row of round buttons out above it (LobbyUIConfig.Dock.Items, springing out one
	after another; Big items such as PLAY are larger and sit on a spinning sunburst). Picking a
	button opens its LobbyState route and folds the row; pressing MENU again folds it too. A
	pulsing badge shows on MENU and on the item while that feature has something to collect.
	A row wider than the safe area (minus Margin) shrinks to fit.

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
local Dock = LobbyUIConfig.Dock
local Animation = UIConfig.Animation
local TextSizes = UIConfig.TextSizes

local function hasBadge(route: string, data: any): boolean
	if route == LobbyState.Routes.Daily then
		return data.Daily ~= nil and data.Daily.CanClaim == true
	end
	return false
end

local function useLoop(ref: any, goal: { [string]: any }, seconds: number)
	React.useEffect(function()
		local target = ref.current
		if target == nil then
			return
		end
		local tween = TweenService:Create(
			target,
			TweenInfo.new(seconds, Animation.TwinkleStyle, Animation.TwinkleDirection, -1, true),
			goal
		)
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, {})
end

local function itemSize(item: any): number
	return if item.Big then Dock.ItemSize * Dock.BigScale else Dock.ItemSize
end

local function DockItem(props: any)
	local item = props.item
	local size = itemSize(item)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		scale.Scale = 0
		TweenService:Create(
			scale,
			TweenInfo.new(Animation.Open, Animation.SpringStyle, Animation.SpringDirection, 0, false, props.delay),
			{ Scale = 1 }
		):Play()
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(size, size + Dock.LabelHeight),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Rays = if item.Big
			then e(Rays, {
				position = UDim2.fromOffset(size / 2, size / 2),
				size = size * LobbyUIConfig.Rays.SizeRatio,
				zIndex = 0,
			})
			else nil,
		Button = e(ChunkyButton, {
			icon = item.Icon,
			iconSize = size * UIConfig.Shape.IconFill,
			onActivated = function()
				props.onPick(item.Route)
			end,
			overlay = if props.badge then e(Badge, { size = Dock.BadgeSize, zIndex = 3 }) else nil,
			round = true,
			size = UDim2.fromOffset(size, size),
			swatch = item.Swatch,
			zIndex = 2,
		}),
		Label = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Fit = true,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, Dock.Gap, 0, Dock.LabelHeight),
			Text = item.Label,
			TextSize = TextSizes.Body,
		}),
	})
end

return function(props: any)
	local open, setOpen = React.useState(false)
	local bounceRef = React.useRef(nil)
	useLoop(bounceRef, { Scale = 1 + LobbyUIConfig.Bounce.Scale }, LobbyUIConfig.Bounce.Seconds)

	local layout = LobbyUIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"].Dock
	local anyBadge = false
	local rowWidth, rowHeight = 0, 0
	for _, item in Dock.Items do
		local size = itemSize(item)
		rowWidth += size
		rowHeight = math.max(rowHeight, size + Dock.LabelHeight)
		if hasBadge(item.Route, props.data) then
			anyBadge = true
		end
	end
	rowWidth += Dock.Gap * (#Dock.Items - 1)
	local fit = math.min(1, (props.ui.safeWidth - Dock.Margin * 2) / rowWidth)

	local function pick(route: string)
		setOpen(false)
		LobbyState.SetActive(route)
	end

	local row: { [string]: any }? = nil
	if open then
		row = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Dock.Gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			Fit = e("UIScale", { Scale = fit }),
		}
		local middle = (#Dock.Items + 1) / 2
		for index, item in Dock.Items do
			row[item.Id] = e(DockItem, {
				badge = hasBadge(item.Route, props.data),
				delay = math.abs(index - middle) * Dock.Stagger,
				item = item,
				layoutOrder = index,
				onPick = pick,
			})
		end
	end

	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = layout.Position,
		Size = UDim2.fromOffset(Dock.ButtonSize, Dock.ButtonSize),
	}, {
		Row = if row ~= nil
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0, -Dock.Lift),
				Size = UDim2.fromOffset(rowWidth, rowHeight),
			}, row)
			else nil,
		Holder = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Scale = e("UIScale", { ref = bounceRef }),
			Menu = e(ChunkyButton, {
				icon = if open then Dock.OpenIcon else Dock.Icon,
				iconSize = TextSizes.BigIcon,
				onActivated = function()
					setOpen(not open)
				end,
				overlay = if anyBadge and not open then e(Badge, { size = Dock.BadgeSize, zIndex = 3 }) else nil,
				round = true,
				size = UDim2.fromScale(1, 1),
				stacked = true,
				swatch = if open then Dock.OpenSwatch else Dock.Swatch,
				text = Dock.Label,
				textSize = TextSizes.Body,
			}),
		}),
	})
end
