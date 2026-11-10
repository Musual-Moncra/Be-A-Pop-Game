--!strict

--[[
	IconTile
	Big glossy lobby tile: emoji on a candy button, a display label underneath, an optional
	red notification badge at the top-right and a gentle idle bob on the emoji.

	Props:
		icon, label (text), swatch (UIConfig.Swatches key)
		size, labelHeight, labelTextSize (design pixels)
		badge: true draws the default badge, a string sets its text (nil = none)
		name: optional instance name (onboarding targets)
		onActivated, layoutOrder, position, anchorPoint, zIndex, phase (bob offset 0..1)
	Dependencies: React, RunService, UIConfig, LobbyUIConfig, Primitives, ChunkyButton, Badge
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Badge = require(Components.Badge)
local ChunkyButton = require(Components.ChunkyButton)
local GlowRing = require(Components.GlowRing)
local Primitives = require(Components.Primitives)
local useBreathe = require(Components.useBreathe)

local e = React.createElement
local Animation = UIConfig.Animation
local TextSizes = UIConfig.TextSizes
local BadgeConfig = LobbyUIConfig.Badge
local Sparkle = UIConfig.Sparkle

return function(props: any)
	local size = props.size or 84
	local labelHeight = props.labelHeight or 24
	local emojiRef = React.useRef(nil)
	local breatheRef = React.useRef(nil)
	local hasBadge = props.badge ~= nil and props.badge ~= false
	useBreathe(breatheRef, 1.06, 1, props.phase, hasBadge)

	React.useEffect(function()
		local emoji = emojiRef.current
		if emoji == nil then
			return
		end
		local phase = (props.phase or 0) * math.pi * 2
		local connection = RunService.Heartbeat:Connect(function()
			local offset = math.sin(os.clock() * math.pi * 2 / Animation.IdleBobSeconds + phase)
			emoji.Position = UDim2.new(0, 0, 0, offset * Animation.IdleBobHeight)
		end)
		return function()
			connection:Disconnect()
		end
	end, { props.phase })

	local badge
	if props.badge ~= nil and props.badge ~= false then
		badge = e(Badge, {
			size = BadgeConfig.Size,
			text = if type(props.badge) == "string" then props.badge else nil,
			zIndex = (props.zIndex or 1) + 3,
		})
	end

	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = UDim2.fromOffset(size, size + labelHeight),
		ZIndex = props.zIndex,
	}, {
		Glow = if hasBadge
			then e(GlowRing, {
				active = props.active ~= false,
				anchorPoint = Vector2.new(0.5, 0.5),
				color = UIConfig.Palette.Sparkle,
				position = UDim2.fromOffset(size / 2, size / 2),
				size = size * 1.35,
				zIndex = (props.zIndex or 1) - 1,
			})
			else nil,
		Tile = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
			ZIndex = props.zIndex,
		}, {
			Scale = e("UIScale", { ref = breatheRef }),
			Button = e(ChunkyButton, {
				gloss = true,
				name = props.name,
				onActivated = props.onActivated,
				overlay = badge,
				popDelay = props.popDelay,
				popIn = props.popIn,
				shine = true,
				shineDelay = (props.phase or 0) * 5,
				shineInterval = Sparkle.TileShineMin + math.random() * (Sparkle.TileShineMax - Sparkle.TileShineMin),
				size = UDim2.fromScale(1, 1),
				swatch = props.swatch,
				zIndex = props.zIndex,
			}, {
				Bob = e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(),
					Size = UDim2.fromScale(1, 1),
					ZIndex = (props.zIndex or 1) + 1,
				}, {
					Emoji = e("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.new(),
						Size = UDim2.fromScale(1, 1),
						ref = emojiRef,
						ZIndex = (props.zIndex or 1) + 1,
					}, {
						Label = Primitives.text({
							Stroke = false,
							Text = props.icon,
							TextSize = size * UIConfig.Shape.IconFill,
							ZIndex = (props.zIndex or 1) + 2,
						}),
					}),
				}),
			}),
		}),
		Label = Primitives.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Fit = true,
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 8, 0, labelHeight),
			Text = props.label,
			TextSize = props.labelTextSize or TextSizes.Body,
			ZIndex = (props.zIndex or 1) + 2,
		}),
	})
end
