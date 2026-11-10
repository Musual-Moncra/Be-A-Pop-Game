--!strict

--[[
	PetReveal
	Full-screen pet drop reveal: the pet shakes as a dark silhouette, then the rarity card flips
	in (width 0 to full) behind rotating rarity rays and sparkles, showing the name, rarity,
	variant, Stink value and a NEW! ribbon (or the gems it turned into when the bag was full).
	Tapping after the flip or COLLECT acknowledges it. App shows one queued drop at a time,
	after a run and before the result window.

	Props: drop (one PetDrop from DataController), ui (useUIScale result)
	Dependencies: React, TweenService, DataController, ConfigLookup, UIConfig, RunUIConfig,
		PetView, Components (ChunkyButton, Chip, Inset, Primitives, Rays, Sparkle, WindowSize, Format)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local RunUIConfig = require(ReplicatedStorage.Modules.Config.RunUIConfig)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local Components = ReplicatedStorage.Modules.UIComponents
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local Sparkle = require(Components.Sparkle)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Reveal = RunUIConfig.Reveal
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local TextSizes = UIConfig.TextSizes

local function Silhouette(_props: any)
	local frameRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local frame = frameRef.current
		local scale = scaleRef.current
		if frame == nil or scale == nil then
			return
		end
		local tween = TweenService:Create(
			frame,
			TweenInfo.new(Reveal.ShakeSeconds / 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 8 }
		)
		tween:Play()
		local pulse = TweenService:Create(
			scale,
			TweenInfo.new(Reveal.ShakeSeconds / 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.12 }
		)
		pulse:Play()
		return function()
			tween:Cancel()
			pulse:Cancel()
		end
	end, {})

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Reveal.IconSize, Reveal.IconSize),
		ref = frameRef,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Well = e(Inset, {
			radius = "Round",
			size = UDim2.fromScale(1, 1),
		}, {
			Face = e("Frame", {
				BackgroundColor3 = Palette.Ink,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, { Corner = Primitives.corner("Round") }),
			Icon = Primitives.text({
				Stroke = false,
				Text = Reveal.LockedIcon,
				TextSize = Reveal.IconSize * Shape.IconFill,
				Transparency = 0.45,
				ZIndex = 2,
			}),
		}),
	})
end

return function(props: any)
	local drop = props.drop
	local phase, setPhase = React.useState("shake")
	local dismissedRef = React.useRef(false)
	local flipRef = React.useRef(nil)
	local revealedAt = React.useRef(0)

	React.useEffect(function()
		dismissedRef.current = false
		setPhase("shake")
		local thread = task.delay(Reveal.ShakeSeconds, function()
			setPhase("flip")
		end)
		return function()
			task.cancel(thread)
		end
	end, { drop.At } :: { any })

	React.useEffect(function()
		if phase ~= "flip" then
			return
		end
		revealedAt.current = os.clock() + Reveal.FlipSeconds
		local thread = task.delay(Reveal.FlipSeconds, function()
			setPhase("revealed")
		end)
		return function()
			task.cancel(thread)
		end
	end, { phase } :: { any })

	local pet = ConfigLookup.GetPet(drop.PetId)
	local variant = ConfigLookup.GetVariant(drop.Variant)
	local rarity = if pet ~= nil then ConfigLookup.GetRarity(pet.Rarity) else nil
	local rarityId = if pet ~= nil then pet.Rarity else nil
	local rarityName = if rarity ~= nil then rarity.DisplayName else (if pet ~= nil then pet.Rarity else "")
	local variantName = if variant ~= nil then variant.DisplayName else drop.Variant
	local raysColor = if rarity ~= nil then rarity.Color else Palette.Sparkle
	local faceColor = if pet ~= nil then pet.Color else Palette.Ink
	local petIcon = Reveal.PetIcon
	if pet ~= nil then
		local configured = (pet :: any).Icon
		if type(configured) == "string" and configured ~= "" then
			petIcon = configured
		end
	end
	local cardWidth, cardHeight = WindowSize.fit(props.ui, Reveal.CardWidth, Reveal.CardHeight)
	local flipped = phase == "flip" or phase == "revealed"
	local revealed = phase == "revealed"

	React.useEffect(function()
		local wrapper = flipRef.current
		if wrapper == nil or phase ~= "flip" then
			return
		end
		wrapper.Size = UDim2.fromOffset(0, cardHeight)
		local grow = TweenService:Create(
			wrapper,
			TweenInfo.new(Reveal.FlipSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(cardWidth * Reveal.FlipOvershoot, cardHeight) }
		)
		grow:Play()
		local thread = task.delay(Reveal.FlipSeconds, function()
			if wrapper.Parent ~= nil then
				TweenService:Create(
					wrapper,
					TweenInfo.new(Reveal.FlipSeconds * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ Size = UDim2.fromOffset(cardWidth, cardHeight) }
				):Play()
			end
		end)
		return function()
			grow:Cancel()
			task.cancel(thread)
		end
	end, { phase } :: { any })

	local sparkles: { [string]: any } = {}
	if flipped then
		for index, star in Reveal.Sparkles do
			sparkles["Sparkle" .. index] = e(Sparkle, {
				delay = index * 0.12,
				position = UDim2.fromScale(star.X, star.Y),
				size = star.Size,
				zIndex = 1,
			})
		end
	end

	local function tap()
		if not revealed or dismissedRef.current then
			return
		end
		if os.clock() < revealedAt.current + Reveal.TapAfter then
			return
		end
		dismissedRef.current = true
		DataController.DismissPetDrop()
	end

	local children: { [string]: any } = {
		Rays = if flipped
			then e(Rays, {
				anchorPoint = Vector2.new(0.5, 0.5),
				color = raysColor,
				position = UDim2.fromScale(0.5, 0.5),
				size = Reveal.RaysSize,
				zIndex = 1,
			})
			else nil,
		Silhouette = if phase == "shake" then e(Silhouette) else nil,
		Flip = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if revealed then UDim2.fromOffset(cardWidth, cardHeight) else UDim2.fromOffset(0, cardHeight),
			ref = flipRef,
			ZIndex = 2,
		}, {
			Card = e(ChunkyButton, {
				anchorPoint = Vector2.new(0.5, 0.5),
				gloss = true,
				position = UDim2.fromScale(0.5, 0.5),
				rarity = rarityId,
				size = UDim2.fromOffset(cardWidth, cardHeight),
				swatch = "Purple",
				zIndex = 2,
			}, {
				Ribbon = if drop.IsNew
					then e("Frame", {
						AnchorPoint = Vector2.new(0, 0),
						BackgroundTransparency = 1,
						Position = UDim2.new(0.05, 0, 0.06, 0),
						Rotation = Reveal.NewRibbonRotation,
						Size = UDim2.fromOffset(1, 1),
						ZIndex = 6,
					}, {
						Tag = e(Chip, {
							height = TextSizes.Large,
							swatch = "Red",
							text = Reveal.NewTag,
							textSize = TextSizes.Body,
							zIndex = 6,
						}),
					})
					else nil,
				Icon = e(Inset, {
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.3),
					radius = "Round",
					size = UDim2.fromOffset(Reveal.IconSize, Reveal.IconSize),
					zIndex = 3,
				}, {
					Face = e("Frame", {
						BackgroundColor3 = faceColor,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
					}, { Corner = Primitives.corner("Round") }),
					Emoji = Primitives.text({
						Stroke = false,
						Text = if pet ~= nil then petIcon else Reveal.LockedIcon,
						TextSize = Reveal.IconSize * Shape.IconFill,
						ZIndex = 4,
					}),
				}),
				Name = if pet ~= nil
					then Primitives.text({
						Color = Palette.Sparkle,
						Fit = true,
						Position = UDim2.new(0.08, 0, 0.54, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Title + Shape.TextStroke * 2),
						Text = string.format(Reveal.NameFormat, pet.DisplayName),
						TextSize = TextSizes.Title,
						ZIndex = 4,
					})
					else nil,
				Rarity = if pet ~= nil
					then Primitives.text({
						Position = UDim2.new(0.08, 0, 0.65, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Header),
						Text = string.format(Reveal.TraitFormat, rarityName, variantName),
						TextSize = TextSizes.Header,
						ZIndex = 4,
					})
					else nil,
				Stink = if pet ~= nil
					then Primitives.text({
						Color = Palette.Sparkle,
						Position = UDim2.new(0.08, 0, 0.73, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Large),
						Text = string.format(
							Reveal.StinkFormat,
							Format.multiplier(PetView.Stink(drop.PetId, drop.Variant, 0))
						),
						TextSize = TextSizes.Large,
						ZIndex = 4,
					})
					else nil,
				Converted = if drop.Converted > 0
					then Primitives.text({
						Color = Palette.Sparkle,
						Position = UDim2.new(0.08, 0, 0.80, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Body),
						Text = string.format(Reveal.ConvertedFormat, drop.Converted),
						TextSize = TextSizes.Body,
						ZIndex = 4,
					})
					else nil,
				Collect = if revealed
					then e(ChunkyButton, {
						anchorPoint = Vector2.new(0.5, 1),
						gloss = true,
						onActivated = tap,
						position = UDim2.new(0.5, 0, 1, -12),
						shine = true,
						size = UDim2.fromOffset(Reveal.CollectWidth, Reveal.CollectHeight),
						swatch = Reveal.CollectSwatch,
						text = Reveal.CollectText,
						textSize = TextSizes.Title,
						zIndex = 5,
					})
					else nil,
			}),
		}),
	}
	for key, sparkle in sparkles do
		children[key] = sparkle
	end
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Palette.Overlay,
		BackgroundTransparency = Reveal.OverlayTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		[React.Event.Activated] = tap,
	}, children)
end
