--!strict

--[[
	Twinkle
	Spawns little four-point stars inside its parent at random spots: each zooms 0 → 1 → 0,
	spins 45 degrees and fades over Sparkle.TwinkleLife. Animation is driven by the shared
	SparkleClock and capped at Sparkle.MaxTwinkle stars on screen.

	Props: rate (stars per second, default 1), color (Color3, default gold), size (design pixels),
		zIndex, active (false stops spawning), clip (true clips stars to the parent)
	Dependencies: React, UIConfig, Primitives, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Primitives = require(Components.Primitives)
local SparkleClock = require(Components.SparkleClock)

local e = React.createElement
local Sparkle = UIConfig.Sparkle
local Palette = UIConfig.Palette

return function(props: any)
	local containerRef = React.useRef(nil)

	React.useEffect(function()
		local container = containerRef.current
		if container == nil then
			return
		end
		local stars = {}
		local accumulator = 0
		local rate = props.rate or 1
		local color = props.color or Sparkle.TwinkleGold
		local baseSize = props.size or Sparkle.TwinkleSize
		local zIndex = props.zIndex or 5

		local disconnect = SparkleClock.Subscribe(function(dt: number)
			if props.active ~= false then
				accumulator += dt * rate
				while accumulator >= 1 do
					accumulator -= 1
					if SparkleClock.Reserve("Twinkle", Sparkle.MaxTwinkle, 1) < 1 then
						break
					end
					local star = Instance.new("TextLabel")
					star.Name = "Twinkle"
					star.AnchorPoint = Vector2.new(0.5, 0.5)
					star.BackgroundTransparency = 1
					star.FontFace = Primitives.displayFont()
					star.Position = UDim2.fromScale(math.random(), math.random())
					star.Rotation = 0
					star.Text = Sparkle.TwinkleText
					star.TextColor3 = color
					star.TextSize = 1
					star.Visible = false
					star.ZIndex = zIndex
					star.Parent = container
					local stroke = Instance.new("UIStroke")
					stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
					stroke.Color = Palette.Ink
					stroke.Thickness = 1
					stroke.Parent = star
					table.insert(stars, { label = star, age = 0 })
				end
			end

			for index = #stars, 1, -1 do
				local entry = stars[index]
				entry.age += dt
				local progress = math.min(1, entry.age / Sparkle.TwinkleLife)
				local zoom = math.sin(progress * math.pi)
				entry.label.Visible = zoom > 0.05
				entry.label.TextSize = math.max(1, baseSize * zoom)
				entry.label.Rotation = progress * Sparkle.TwinkleSpin
				local alpha = math.min(1, progress / 0.2, (1 - progress) / 0.25)
				entry.label.TextTransparency = 1 - math.max(0, alpha)
				if progress >= 1 then
					entry.label:Destroy()
					table.remove(stars, index)
					SparkleClock.Release("Twinkle", 1)
				end
			end
		end)

		return function()
			disconnect()
			local alive = #stars
			for _, entry in stars do
				entry.label:Destroy()
			end
			table.clear(stars)
			if alive > 0 then
				SparkleClock.Release("Twinkle", alive)
			end
		end
	end, { props.active, props.rate, props.color, props.size, props.zIndex } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = props.clip == true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex,
		ref = containerRef,
	})
end
