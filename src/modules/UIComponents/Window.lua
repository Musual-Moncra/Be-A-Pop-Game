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
	Dependencies: React, TweenService, UIConfig, Primitives, ChunkyButton, Sparkle, PopIn, Keybinds, KeyHint
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local PopIn = require(ReplicatedStorage.Modules.UIComponents.PopIn)
local Keybinds = require(ReplicatedStorage.Modules.UIComponents.Keybinds)
local KeyHint = require(ReplicatedStorage.Modules.UIComponents.KeyHint)
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

	local swatch = Primitives.swatch(props.swatch)
	local ribbonLip = swatch.Lip or swatch.Bottom
	local ribbonWidth = Sizes.HeaderWidth
	local ribbonWingWidth = 32
	local ribbonWingHeight = headerHeight - 14

	local sparkles = {}
	for index, sparkle in Sizes.Sparkles do
		sparkles["Sparkle" .. index] = e(Sparkle, {
			delay = sparkle.Delay / Animation.SparkleSpeed,
			position = UDim2.new(sparkle.X, 0, 0, headerHeight * sparkle.Y),
			size = TextSizes[sparkle.Size],
			zIndex = 6,
		})
	end

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		PopIn.play(scale)
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

	Keybinds.use("Close", close, props.onClose ~= nil)

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
					Gloss = e("Frame", {
						BackgroundColor3 = Palette.Text,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(Shape.GlossInset, Shape.GlossInset),
						Size = UDim2.new(1, -Shape.GlossInset * 2, 0.35, -Shape.GlossInset),
						ZIndex = 1,
					}, {
						Corner = Primitives.corner(Shape.WindowRadius - Shape.RimStroke - Shape.GlossInset),
						Fade = e("UIGradient", {
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, Shape.GlossTransparency),
								NumberSequenceKeypoint.new(1, 1),
							}),
						}),
					}),
				}),
			}),
			InnerWell = e("Frame", {
				BackgroundColor3 = Palette.Inset,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(Sizes.Padding - 4, bodyTop - 4),
				Size = UDim2.new(1, -(Sizes.Padding - 4) * 2, 1, -(bodyTop + bodyBottom - 8)),
				ZIndex = 2,
			}, {
				Corner = Primitives.corner(Shape.Radius + 4),
				Stroke = Primitives.stroke(Palette.InsetStroke, 2, 0.35),
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
			RibbonLeft = e("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = ribbonLip,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5 - ribbonWidth / 2, 14, 0, 6),
				Size = UDim2.fromOffset(ribbonWingWidth, ribbonWingHeight),
				ZIndex = 3,
			}, {
				Corner = Primitives.corner(Shape.Radius),
				Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
				Gradient = Primitives.gradient(swatch.Bottom, ribbonLip),
			}),
			RibbonRight = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = ribbonLip,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5 + ribbonWidth / 2, -14, 0, 6),
				Size = UDim2.fromOffset(ribbonWingWidth, ribbonWingHeight),
				ZIndex = 3,
			}, {
				Corner = Primitives.corner(Shape.Radius),
				Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
				Gradient = Primitives.gradient(swatch.Bottom, ribbonLip),
			}),
			Header = e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 0.5),
				icon = props.icon,
				iconSize = TextSizes.Header,
				position = UDim2.fromScale(0.5, 0),
				shine = true,
				shineInterval = 4.5,
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
					overlay = e(KeyHint, { action = "Close", zIndex = 8 }),
					position = UDim2.new(1, -closeSize * 0.28, 0, closeSize * 0.28),
					round = true,
					shine = true,
					size = UDim2.fromOffset(closeSize, closeSize),
					swatch = "Red",
					text = UIConfig.Text.CloseIcon,
					textSize = TextSizes.Header,
					zIndex = 7,
				})
				else nil,
		}),
	})
end

return Window
