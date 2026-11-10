--!strict

--[[
	Window
	Modal window: Ink rim around a candy panel, a glossy swatch header banner (emoji + title +
	twinkling sparkles), a round red close button on the corner, and a springy scale-open.
	The close button scales the window down before calling onClose. The full-screen dimmer is
	drawn by App.

	Props: title, icon (optional emoji), swatch (header colour, UIConfig.Swatches key),
	       width, height (design pixels), onClose (nil hides the close button),
	       children (body content), footer (element filling the bottom action bar, nil hides it),
	       footerHeight (design pixels)

	Sizing helpers live in WindowSize.
	Dependencies: React, TweenService, UIConfig, Primitives, ChunkyButton, Sparkle
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Primitives = require(Components.Primitives)
local Sparkle = require(Components.Sparkle)
local Twinkle = require(Components.Twinkle)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sparkles = UIConfig.Sparkle
local Sizes = UIConfig.Sizes.Window
local TextSizes = UIConfig.TextSizes

local function Window(props: any)
	local scaleRef = React.useRef(nil)
	local closingRef = React.useRef(false)
	local headerHeight = Sizes.HeaderHeight
	local closeSize = Sizes.CloseSize
	local bodyTop = headerHeight / 2 + Sizes.Padding
	local footerHeight = props.footerHeight or 0
	local hasFooter = props.footer ~= nil and footerHeight > 0
	local bodyBottom = Sizes.Padding + (if hasFooter then footerHeight + Sizes.Gap else 0)

	local sparkles = {}
	for index, sparkle in Sizes.Sparkles do
		sparkles["Sparkle" .. index] = e(Sparkle, {
			delay = sparkle.Delay / Animation.SparkleSpeed,
			position = UDim2.new(sparkle.X, 0, 0, headerHeight * sparkle.Y),
			size = TextSizes[sparkle.Size],
			zIndex = 5,
		})
	end

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		local step = Animation.PopInTime
		scale.Scale = Animation.PopInStart
		TweenService:Create(scale, TweenInfo.new(step * 0.35, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = Animation.PopInOver,
		}):Play()
		TweenService:Create(
			scale,
			TweenInfo.new(step * 0.25, Animation.SmoothStyle, Animation.SmoothDirection, 0, false, step * 0.35),
			{
				Scale = Animation.PopInUnder,
			}
		):Play()
		TweenService:Create(
			scale,
			TweenInfo.new(step * 0.4, Animation.SpringStyle, Animation.SpringDirection, 0, false, step * 0.6),
			{
				Scale = 1,
			}
		):Play()
	end, {})

	local function close()
		if closingRef.current then
			return
		end
		closingRef.current = true
		local scale = scaleRef.current
		if scale ~= nil then
			TweenService
				:Create(scale, TweenInfo.new(Animation.Close, Animation.SmoothStyle, Animation.SmoothDirection), {
					Scale = Animation.CloseFromScale,
				})
				:Play()
		end
		task.delay(Animation.Close, function()
			if props.onClose ~= nil then
				props.onClose()
			end
		end)
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Window = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, headerHeight * Sizes.CenterShift),
			Size = UDim2.fromOffset(props.width, props.height),
			ZIndex = 2,
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Shadow = e("Frame", {
				BackgroundColor3 = Palette.Shadow,
				BackgroundTransparency = Shape.ShadowTransparency,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, Shape.ShadowOffset * 2),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				Corner = Primitives.corner(Shape.WindowRadius),
			}),
			Rim = e("Frame", {
				Active = true,
				BackgroundColor3 = Palette.Ink,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				Corner = Primitives.corner(Shape.WindowRadius),
				Body = e("Frame", {
					BackgroundColor3 = Palette.PanelTop,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(Shape.RimStroke, Shape.RimStroke),
					Size = UDim2.new(1, -Shape.RimStroke * 2, 1, -Shape.RimStroke * 2),
				}, {
					Corner = Primitives.corner(Shape.WindowRadius - Shape.RimStroke),
					Gradient = Primitives.gradient(Palette.PanelTop, Palette.PanelBottom),
					Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
				}),
			}),
			Content = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(Sizes.Padding, bodyTop),
				Size = UDim2.new(1, -Sizes.Padding * 2, 1, -(bodyTop + bodyBottom)),
				ZIndex = 3,
			}, props.children),
			Footer = if hasFooter
				then e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, Sizes.Padding, 1, -(Sizes.Padding + footerHeight)),
					Size = UDim2.new(1, -Sizes.Padding * 2, 0, footerHeight),
					ZIndex = 3,
				}, { Content = props.footer })
				else nil,
			Header = e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 0.5),
				icon = props.icon,
				iconSize = TextSizes.Header,
				position = UDim2.fromScale(0.5, 0),
				shine = true,
				shineInterval = 5,
				size = UDim2.new(Sizes.HeaderWidth, 0, 0, headerHeight),
				stacked = false,
				swatch = props.swatch,
				text = props.title,
				textSize = TextSizes.Title,
				zIndex = 4,
			}),
			HeaderTwinkle = if props.twinkle ~= false
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(Sizes.HeaderWidth, 0, 0, headerHeight),
					ZIndex = 5,
				}, {
					Twinkle = e(Twinkle, {
						clip = true,
						color = Sparkles.TwinkleWhite,
						rate = Sparkles.HeaderTwinkleRate,
						zIndex = 6,
					}),
				})
				else nil,
			Sparkles = e("Folder", nil, sparkles),
			Close = if props.onClose ~= nil
				then e(ChunkyButton, {
					anchorPoint = Vector2.new(0.5, 0.5),
					onActivated = close,
					position = UDim2.new(1, -closeSize * Sizes.CloseInset, 0, closeSize * Sizes.CloseInset),
					radius = Shape.Radius,
					size = UDim2.fromOffset(closeSize, closeSize),
					swatch = "Red",
					text = UIConfig.Text.CloseIcon,
					textSize = TextSizes.Header,
					zIndex = 6,
				})
				else nil,
		}),
	})
end

return Window
