--!strict

--[[
	Window
	Modal window: dimmed backdrop (click to close), drop shadow, purple rim around a navy
	gradient body, a glossy ribbon header that straddles the top edge with twinkling
	sparkles, and a red close button on the corner. Pops in when it mounts.

	Props: title, swatch (header colour, UIConfig.Swatches key), width, height (design pixels),
	       onClose (nil hides the close button and backdrop click), children (body content)

	Dependencies: React, UIConfig, Primitives, ChunkyButton, Sparkle
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)
local Sparkle = require(ReplicatedStorage.Modules.UIComponents.Sparkle)

local e = React.createElement
local Animation = UIConfig.Animation
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Window
local TextSizes = UIConfig.TextSizes

return function(props: any)
	local scaleRef = React.useRef(nil)
	local headerHeight = Sizes.HeaderHeight
	local closeSize = Sizes.CloseSize
	local bodyTop = headerHeight / 2 + Sizes.Padding

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
		scale.Scale = Animation.OpenFromScale
		TweenService:Create(scale, TweenInfo.new(Animation.Open, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = 1,
		}):Play()
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Backdrop = e("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Palette.Overlay,
			BackgroundTransparency = Shape.OverlayTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 1,
			[React.Event.Activated] = props.onClose,
		}),
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
				BackgroundColor3 = Palette.PanelRim,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				Corner = Primitives.corner(Shape.WindowRadius),
				Stroke = Primitives.stroke(Palette.Ink, Shape.Stroke),
				Body = e("Frame", {
					BackgroundColor3 = Palette.Text,
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
				Size = UDim2.new(1, -Sizes.Padding * 2, 1, -(bodyTop + Sizes.Padding)),
				ZIndex = 3,
			}, props.children),
			Header = e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0),
				size = UDim2.new(Sizes.HeaderWidth, 0, 0, headerHeight),
				swatch = props.swatch,
				text = props.title,
				textSize = TextSizes.Title,
				zIndex = 4,
			}),
			Sparkles = e("Folder", nil, sparkles),
			Close = if props.onClose ~= nil
				then e(ChunkyButton, {
					anchorPoint = Vector2.new(0.5, 0.5),
					onActivated = props.onClose,
					position = UDim2.new(1, -closeSize * Sizes.CloseInset, 0, closeSize * Sizes.CloseInset),
					radius = Shape.Radius,
					size = UDim2.fromOffset(closeSize, closeSize),
					swatch = "Red",
					text = UIConfig.Text.CloseIcon,
					textSize = TextSizes.Header,
					zIndex = 5,
				})
				else nil,
		}),
	})
end
