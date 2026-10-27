--!strict

--[[
	LobbyMenu
	The single round MENU button at the bottom centre of the lobby. Clicking it pops a fan
	of round buttons out of it (one per UIConfig.MenuItems row, springing out one after the
	other); picking one opens its window through LobbyState, clicking MENU again folds it.

	Props: ui (useUIScale result)
	Dependencies: React, UIConfig, LobbyState, Primitives, ChunkyButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation
local Sizes = UIConfig.Sizes.Menu
local TextSizes = UIConfig.TextSizes

local function MenuItem(props: any)
	local item = props.item
	local scaleRef = React.useRef(nil)
	local angle = math.rad(item.AngleDegrees)
	local offset = Vector2.new(math.sin(angle), -math.cos(angle)) * UIConfig.MenuRadius

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
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
		Size = UDim2.fromOffset(Sizes.ItemSize, Sizes.ItemSize + Sizes.LabelHeight),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Button = e(ChunkyButton, {
			icon = item.Icon,
			iconSize = Sizes.ItemSize * UIConfig.Shape.IconFill,
			onActivated = function()
				props.onPick(item.Route)
			end,
			round = true,
			size = UDim2.fromOffset(Sizes.ItemSize, Sizes.ItemSize),
			swatch = item.Swatch,
		}),
		Label = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, Sizes.ItemSize, 0, Sizes.LabelHeight),
			Text = item.Label,
			TextSize = TextSizes.Body,
		}),
	})
end

return function(props: any)
	local open, setOpen = React.useState(false)
	local layout = UIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"].MenuButton

	local function pick(route: string)
		setOpen(false)
		LobbyState.SetActive(route)
	end

	local items = {}
	if open then
		for index, item in UIConfig.MenuItems do
			items[item.Id] = e(MenuItem, {
				delay = (index - 1) * Animation.MenuStagger,
				item = item,
				onPick = pick,
			})
		end
	end

	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		BackgroundTransparency = 1,
		Position = layout.Position,
		Size = UDim2.fromOffset(Sizes.ButtonSize, Sizes.ButtonSize),
	}, {
		Items = e("Folder", nil, items),
		Menu = e(ChunkyButton, {
			icon = if open then UIConfig.Text.CloseIcon else UIConfig.Text.MenuIcon,
			iconSize = TextSizes.BigIcon,
			onActivated = function()
				setOpen(not open)
			end,
			round = true,
			size = UDim2.fromScale(1, 1),
			stacked = true,
			swatch = if open then "Red" else "Orange",
			text = UIConfig.Text.MenuButton,
			textSize = TextSizes.Body,
			zIndex = 2,
		}),
	})
end
