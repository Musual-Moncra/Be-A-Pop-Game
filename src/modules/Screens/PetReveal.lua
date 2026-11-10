--!strict

--[[
	PetReveal
	Full-screen pet drop reveal: the pet shakes as a dark silhouette for a moment, then bursts
	with rarity-coloured rays showing its name, rarity, variant, Stink value and NEW tag (or the
	gems it turned into when the bag was full). It never closes by itself: tapping or COLLECT
	after the shake acknowledges it. App shows one queued drop at a time, after a run and
	before the result window.

	Props: drop (one PetDrop from DataController), ui (useUIScale result)
	Dependencies: React, TweenService, DataController, ConfigLookup, UIConfig, LobbyUIConfig,
		PetView, Primitives, ChunkyButton, Chip, Inset, Rays, Format, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local PetView = require(ReplicatedStorage.Modules.UIs.PetView)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local Components = ReplicatedStorage.Modules.UIComponents
local Chip = require(Components.Chip)
local ChunkyButton = require(Components.ChunkyButton)
local Format = require(Components.Format)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)
local Rays = require(Components.Rays)
local WindowSize = require(Components.WindowSize)

local e = React.createElement
local Reveal = LobbyUIConfig.PetReveal
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape
local Animation = UIConfig.Animation
local TextSizes = UIConfig.TextSizes

return function(props: any)
	local drop = props.drop
	local phase, setPhase = React.useState("shake")
	local dismissedRef = React.useRef(false)
	local iconScaleRef = React.useRef(nil)
	local iconRef = React.useRef(nil)

	React.useEffect(function()
		dismissedRef.current = false
		setPhase("shake")
		local thread = task.delay(Reveal.ShakeSeconds, function()
			setPhase("revealed")
		end)
		return function()
			task.cancel(thread)
		end
	end, { drop.At } :: { any })

	React.useEffect(function()
		local icon = iconRef.current
		if icon == nil or phase ~= "shake" then
			return
		end
		local tween = TweenService:Create(
			icon,
			TweenInfo.new(Reveal.ShakeSeconds / 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 8 }
		)
		tween:Play()
		return function()
			tween:Cancel()
			icon.Rotation = 0
		end
	end, { phase } :: { any })

	React.useEffect(function()
		local scale = iconScaleRef.current
		if scale == nil or phase ~= "revealed" then
			return
		end
		scale.Scale = 0
		TweenService:Create(scale, TweenInfo.new(Animation.Open, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = 1,
		}):Play()
	end, { phase } :: { any })

	local pet = ConfigLookup.GetPet(drop.PetId)
	local variant = ConfigLookup.GetVariant(drop.Variant)
	local rarity = if pet ~= nil then ConfigLookup.GetRarity(pet.Rarity) else nil
	local revealed = phase == "revealed"
	local rarityName = if rarity ~= nil then rarity.DisplayName else (if pet ~= nil then pet.Rarity else "")
	local variantName = if variant ~= nil then variant.DisplayName else drop.Variant
	local swatch = if rarity ~= nil then (Reveal.RaritySwatches[rarity.Id] or Reveal.Swatch) else Reveal.Swatch
	local raysColor = if rarity ~= nil then rarity.Color else Palette.Sparkle
	local faceColor = if revealed and pet ~= nil then pet.Color else Palette.Ink

	local width, height = WindowSize.fit(props.ui, Reveal.Width, Reveal.Height)
	local iconCenter = UDim2.fromScale(0.5, 0.32)

	local function tap()
		if phase ~= "revealed" or dismissedRef.current then
			return
		end
		dismissedRef.current = true
		DataController.DismissPetDrop()
	end

	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Palette.Overlay,
		BackgroundTransparency = Reveal.OverlayTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		[React.Event.Activated] = tap,
	}, {
		Card = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height),
		}, {
			Body = e(ChunkyButton, {
				size = UDim2.fromScale(1, 1),
				swatch = swatch,
				zIndex = 2,
			}, {
				Rays = if revealed
					then e(Rays, {
						color = raysColor,
						position = iconCenter,
						size = Reveal.RaysSize,
						zIndex = 2,
					})
					else nil,
				Icon = e(Inset, {
					anchorPoint = Vector2.new(0.5, 0.5),
					position = iconCenter,
					radius = "Round",
					size = UDim2.fromOffset(Reveal.IconSize, Reveal.IconSize),
					zIndex = 3,
				}, {
					Scale = e("UIScale", { ref = iconScaleRef }),
					Fill = e("Frame", {
						BackgroundColor3 = faceColor,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1,
					}, { Corner = Primitives.corner("Round") }),
					Emoji = e("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
						ref = iconRef,
					}, {
						Label = Primitives.text({
							Stroke = false,
							Text = if revealed then LobbyUIConfig.Pets.PetIcon else Reveal.LockedIcon,
							TextSize = Reveal.IconSize * Shape.IconFill,
							Transparency = if revealed then 0 else 0.25,
							ZIndex = 3,
						}),
					}),
				}),
				Name = if revealed and pet ~= nil
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
				Rarity = if revealed and pet ~= nil
					then Primitives.text({
						Position = UDim2.new(0.08, 0, 0.65, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Header),
						Text = string.format(LobbyUIConfig.Pets.TraitFormat, rarityName, variantName),
						TextSize = TextSizes.Header,
						ZIndex = 4,
					})
					else nil,
				Stink = if revealed and pet ~= nil
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
				Converted = if revealed and drop.Converted > 0
					then Primitives.text({
						Color = Palette.TextSoft,
						Position = UDim2.new(0.08, 0, 0.80, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Body),
						Text = string.format(Reveal.ConvertedFormat, drop.Converted),
						TextSize = TextSizes.Body,
						ZIndex = 4,
					})
					else nil,
				New = if revealed and drop.IsNew
					then e(Chip, {
						anchorPoint = Vector2.new(1, 0),
						height = TextSizes.Large,
						position = UDim2.new(0.92, 0, 0.08, 0),
						swatch = "Gold",
						text = Reveal.NewTag,
						textSize = TextSizes.Body,
						zIndex = 5,
					})
					else nil,
				Collect = if revealed
					then e(ChunkyButton, {
						anchorPoint = Vector2.new(0.5, 1),
						onActivated = tap,
						position = UDim2.new(0.5, 0, 1, -12),
						size = UDim2.fromOffset(Reveal.CollectWidth, Reveal.CollectHeight),
						swatch = Reveal.CollectSwatch,
						text = Reveal.CollectText,
						textSize = TextSizes.Title,
						zIndex = 5,
					})
					else nil,
			}),
		}),
	})
end
