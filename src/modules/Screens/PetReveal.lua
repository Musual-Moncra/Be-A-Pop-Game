--!strict

--[[
	PetReveal
	Full-screen pet drop reveal: waits for the MAP CLEARED banner to finish, then the pet shakes
	as a dark silhouette for a moment and bursts with rarity-coloured rays showing its name,
	rarity, variant, Stink value and NEW tag (or the gems it turned into when the bag was full).
	Tapping after a short delay, or waiting, closes it.

	Props: data (DataController state with LastPetDrop), ui (useUIScale result)
	Dependencies: React, TweenService, DataController, ConfigLookup, JuiceConfig, UIConfig,
		LobbyUIConfig, PetView, Primitives, ChunkyButton, Chip, Inset, Rays, Format, WindowSize
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local JuiceConfig = require(ReplicatedStorage.Modules.Config.JuiceConfig)
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
	local drop = props.data.LastPetDrop
	local phase, setPhase = React.useState("waiting")
	local startedAt = React.useRef(os.clock())
	local iconScaleRef = React.useRef(nil)
	local iconRef = React.useRef(nil)
	local bannerSeconds = JuiceConfig.MilestoneClearSeconds

	React.useEffect(function()
		startedAt.current = os.clock()
		setPhase("waiting")
		local shakeThread = task.delay(bannerSeconds, function()
			setPhase("shake")
		end)
		local revealThread = task.delay(bannerSeconds + Reveal.ShakeSeconds, function()
			setPhase("revealed")
		end)
		return function()
			task.cancel(shakeThread)
			task.cancel(revealThread)
		end
	end, { drop.At } :: { any })

	React.useEffect(function()
		if phase ~= "revealed" then
			return
		end
		local thread = task.delay(Reveal.AutoSeconds, DataController.DismissPetDrop)
		return function()
			task.cancel(thread)
		end
	end, { phase } :: { any })

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
		if os.clock() - startedAt.current < bannerSeconds + Reveal.TapAfter then
			return
		end
		DataController.DismissPetDrop()
	end

	if phase == "waiting" then
		return nil
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
						Position = UDim2.new(0.08, 0, 0.66, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Header),
						Text = string.format(LobbyUIConfig.Pets.TraitFormat, rarityName, variantName),
						TextSize = TextSizes.Header,
						ZIndex = 4,
					})
					else nil,
				Stink = if revealed and pet ~= nil
					then Primitives.text({
						Color = Palette.Sparkle,
						Position = UDim2.new(0.08, 0, 0.75, 0),
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
						Position = UDim2.new(0.08, 0, 0.83, 0),
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
				Tap = if revealed
					then Primitives.text({
						Color = Palette.TextSoft,
						Position = UDim2.new(0.08, 0, 0.9, 0),
						Size = UDim2.new(0.84, 0, 0, TextSizes.Body),
						StrokeSize = Shape.SmallTextStroke,
						Text = Reveal.TapText,
						TextSize = TextSizes.Body,
						ZIndex = 4,
					})
					else nil,
			}),
		}),
	})
end
