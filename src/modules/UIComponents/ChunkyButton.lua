--!strict

--[[
	ChunkyButton
	Cartoon button: drop shadow, dark 3D lip, gradient face with a gloss highlight,
	outlined label and a springy hover/press animation. Also used as a non-clickable
	coloured block (cards, icon circles) by leaving out onActivated.

	Props:
		swatch: UIConfig.Swatches key (string), Grey when disabled
		size, position, anchorPoint, layoutOrder, zIndex
		round: true for a circle
		text, textSize, icon, iconSize: label and emoji; icon sits left of the text,
			or above it when stacked = true
		onActivated: click handler; nil = static block (no hover/press)
		enabled: false greys the button out and ignores clicks
		children: extra content drawn on the face instead of text/icon
		overlay: element drawn above the whole button, outside its layout (selection rings)

	Dependencies: React, UIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Shape = UIConfig.Shape
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette
local TextSizes = UIConfig.TextSizes

return function(props: any)
	local enabled = props.enabled ~= false
	local clickable = props.onActivated ~= nil
	local swatch = Primitives.swatch(if enabled then props.swatch else "Grey")
	local radius = if props.round then "Round" else (props.radius or Shape.Radius)
	local scaleRef = React.useRef(nil)

	local function tweenTo(target: number, time: number)
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		TweenService:Create(scale, TweenInfo.new(time, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = target,
		}):Play()
	end

	local content = props.children
	if content == nil then
		local stacked = props.stacked == true
		local iconSize = props.iconSize or TextSizes.Icon
		local items: { [string]: any } = {
			Layout = Primitives.list(
				if stacked then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				if stacked then 0 else Shape.Stroke * 2,
				Enum.HorizontalAlignment.Center,
				Enum.VerticalAlignment.Center
			),
		}
		if props.icon ~= nil and props.icon ~= "" then
			items.Icon = Primitives.text({
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = 1,
				Size = UDim2.new(),
				Stroke = false,
				Text = props.icon,
				TextSize = iconSize,
			})
		end
		if props.text ~= nil and props.text ~= "" then
			items.Label = Primitives.text({
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = 2,
				Size = UDim2.new(),
				Text = props.text,
				TextSize = props.textSize or TextSizes.Large,
			})
		end
		content = items
	end

	local faceChildren = {
		Corner = Primitives.corner(radius),
		Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
		Gloss = e("Frame", {
			BackgroundColor3 = Palette.Text,
			BackgroundTransparency = Shape.GlossTransparency,
			BorderSizePixel = 0,
			Position = UDim2.new(0, Shape.Stroke * 2, 0, Shape.Stroke),
			Size = UDim2.new(1, -Shape.Stroke * 4, Shape.GlossHeight, 0),
		}, {
			Corner = Primitives.corner(radius),
		}),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, content),
	}

	local holderProps = {
		Active = clickable and enabled,
		AnchorPoint = props.anchorPoint,
		AutoButtonColor = if clickable then false else nil,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Selectable = clickable and enabled,
		Size = props.size,
		Text = if clickable then "" else nil,
		ZIndex = props.zIndex,
		[React.Event.Activated] = if clickable and enabled then props.onActivated else nil,
		[React.Event.MouseEnter] = if clickable and enabled
			then function()
				tweenTo(Animation.HoverScale, Animation.Press)
			end
			else nil,
		[React.Event.MouseLeave] = if clickable
			then function()
				tweenTo(1, Animation.Press)
			end
			else nil,
		[React.Event.MouseButton1Down] = if clickable and enabled
			then function()
				tweenTo(Animation.PressScale, Animation.Press)
			end
			else nil,
		[React.Event.MouseButton1Up] = if clickable and enabled
			then function()
				tweenTo(Animation.HoverScale, Animation.Press)
			end
			else nil,
	}

	return e(if clickable then "TextButton" else "Frame", holderProps, {
		Scale = e("UIScale", { ref = scaleRef }),
		Shadow = e("Frame", {
			BackgroundColor3 = Palette.Shadow,
			BackgroundTransparency = Shape.ShadowTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, Shape.ShadowOffset),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, {
			Corner = Primitives.corner(radius),
		}),
		Lip = e("Frame", {
			BackgroundColor3 = swatch.Lip,
			BackgroundTransparency = if enabled then 0 else Shape.DisabledTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			Corner = Primitives.corner(radius),
			Stroke = Primitives.stroke(swatch.Stroke, Shape.Stroke),
		}),
		Face = e("Frame", {
			BackgroundColor3 = Palette.Text,
			BackgroundTransparency = if enabled then 0 else Shape.DisabledTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -Shape.Lip),
			ZIndex = 3,
		}, faceChildren),
		Overlay = props.overlay,
	})
end
