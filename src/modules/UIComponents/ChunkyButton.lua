--!strict

--[[
	ChunkyButton
	Cartoon button: drop shadow, dark 3D lip, gradient face,
	outlined label and a springy hover/press animation. Also used as a non-clickable
	coloured block (cards, icon circles) by leaving out onActivated.

	Props:
		swatch: UIConfig.Swatches key (string), Grey when disabled
		size, position, anchorPoint, layoutOrder, zIndex
		round: true for a circle
		text, textSize, icon, iconSize: label and emoji; icon sits left of the text,
			or above it when stacked = true. Text-only and stacked labels shrink to fit the
			face (TextSizes.Min at the smallest), so a label never spills out of the button.
		onActivated: click handler; nil = static block (no hover/press)
		enabled: false greys the button out and ignores clicks
		children: extra content drawn on the face instead of text/icon
		overlay: element drawn above the whole button, outside its layout (selection rings)

	Hover grows the button by HoverScale but never by more than Animation.HoverGrowMax design
	pixels, and press shrinks it by PressScale but never by more than Animation.PressShrinkMax,
	so big cards inside clipped lists stay inside their list.

	Dependencies: React, UIConfig, Primitives, UIScaleContext
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)
local UIScaleContext = require(ReplicatedStorage.Modules.UIComponents.UIScaleContext)

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
	local rootScale = React.useContext(UIScaleContext)

	local function tweenTo(target: number, time: number)
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		TweenService:Create(scale, TweenInfo.new(time, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = target,
		}):Play()
	end

	local function designSize(): number
		local scale = scaleRef.current
		local holder = if scale ~= nil then scale.Parent else nil
		if holder == nil or not holder:IsA("GuiObject") then
			return 0
		end
		local size = holder.AbsoluteSize
		return math.max(size.X, size.Y) / (rootScale * scale.Scale)
	end

	local function hoverScale(): number
		local size = designSize()
		if size <= 0 then
			return Animation.HoverScale
		end
		return 1 + math.min(Animation.HoverScale - 1, Animation.HoverGrowMax / size)
	end

	local function pressScale(): number
		local size = designSize()
		if size <= 0 then
			return Animation.PressScale
		end
		return 1 - math.min(1 - Animation.PressScale, Animation.PressShrinkMax / size)
	end

	local content = props.children
	if content == nil then
		local hasIcon = props.icon ~= nil and props.icon ~= ""
		local hasText = props.text ~= nil and props.text ~= ""
		local stacked = props.stacked == true
		local iconSize = props.iconSize or TextSizes.Icon
		local textSize = props.textSize or TextSizes.Large
		local items: { [string]: any } = {
			Padding = Primitives.paddingXY(Shape.ContentPadding, 0),
			Layout = Primitives.list(
				if stacked then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				if stacked then 0 else Shape.Stroke * 2,
				Enum.HorizontalAlignment.Center,
				Enum.VerticalAlignment.Center
			),
		}
		if hasIcon then
			items.Icon = Primitives.text({
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = 1,
				Size = UDim2.new(),
				Stroke = false,
				Text = props.icon,
				TextSize = iconSize,
			})
		end
		if hasText and (stacked or not hasIcon) then
			local lines = #string.split(props.text, "\n")
			items.Label = Primitives.text({
				Fit = true,
				LayoutOrder = 2,
				Size = if stacked
					then UDim2.new(1, 0, 0, math.ceil(textSize * lines * Shape.LineHeight))
					else UDim2.fromScale(1, 1),
				Text = props.text,
				TextSize = textSize,
			})
		elseif hasText then
			items.Label = Primitives.text({
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = 2,
				Size = UDim2.new(),
				Text = props.text,
				TextSize = textSize,
			})
		end
		content = items
	end

	local faceChildren = {
		Corner = Primitives.corner(radius),
		Gradient = Primitives.gradient(swatch.Top, swatch.Bottom),
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
				tweenTo(hoverScale(), Animation.Press)
			end
			else nil,
		[React.Event.MouseLeave] = if clickable
			then function()
				tweenTo(1, Animation.Press)
			end
			else nil,
		[React.Event.MouseButton1Down] = if clickable and enabled
			then function()
				tweenTo(pressScale(), Animation.Press)
			end
			else nil,
		[React.Event.MouseButton1Up] = if clickable and enabled
			then function()
				tweenTo(hoverScale(), Animation.Press)
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
