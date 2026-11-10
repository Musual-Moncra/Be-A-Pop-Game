--!strict

--[[
	Twinkle
	Little four-point stars that pop up at random spots inside the parent: each zooms 0 → 1 → 0
	over Sparkle.TwinkleLife. A star is two crossed rounded bars (no text, so
	nothing is re-rasterised) animated by one UIScale. Stars are pooled per Twinkle and reused,
	the shared SparkleClock drives them, nothing runs while the parent is off-screen or hidden,
	and Sparkle.MaxTwinkle caps the stars alive on screen.

	Props: rate (stars per second, default 1), color (Color3, default gold), size (design pixels),
		zIndex, active (false stops spawning), clip (true clips stars to the parent)
	Dependencies: React, UIConfig, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local SparkleClock = require(ReplicatedStorage.Modules.UIComponents.SparkleClock)

local e = React.createElement
local Sparkle = UIConfig.Sparkle

type Star = { frame: Frame, scale: UIScale, age: number, busy: boolean }

local function makeStar(container: Instance, color: Color3, size: number, zIndex: number): Star
	local frame = Instance.new("Frame")
	frame.Name = "Twinkle"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(size, size)
	frame.Visible = false
	frame.ZIndex = zIndex
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = frame
	for index = 1, 2 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = if index == 1
			then UDim2.fromScale(Sparkle.TwinkleThickness, 1)
			else UDim2.fromScale(1, Sparkle.TwinkleThickness)
		bar.ZIndex = zIndex
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = bar
		bar.Parent = frame
	end
	frame.Parent = container
	return { frame = frame, scale = scale, age = 0, busy = false }
end

return function(props: any)
	local containerRef = React.useRef(nil)

	React.useEffect(function()
		local container = containerRef.current
		if container == nil then
			return
		end
		local pool: { Star } = {}
		local busy = 0
		local accumulator = 0
		local rate = props.rate or 1
		local color = props.color or Sparkle.TwinkleGold
		local size = props.size or Sparkle.TwinkleSize
		local zIndex = props.zIndex or 5
		local poolSize = math.max(1, math.ceil(rate * Sparkle.TwinkleLife) + 1)

		local function retire(star: Star)
			star.busy = false
			star.frame.Visible = false
			star.scale.Scale = 0
			busy -= 1
			SparkleClock.Release("Twinkle", 1)
		end

		local disconnect = SparkleClock.Subscribe(function(dt: number)
			if busy == 0 and not SparkleClock.OnScreen(container) then
				accumulator = 0
				return
			end
			if props.active ~= false then
				accumulator += dt * rate
				while accumulator >= 1 do
					accumulator -= 1
					if busy >= poolSize or SparkleClock.Reserve("Twinkle", Sparkle.MaxTwinkle, 1) < 1 then
						accumulator = 0
						break
					end
					local star: Star? = nil
					for _, candidate in pool do
						if not candidate.busy then
							star = candidate
							break
						end
					end
					if star == nil then
						star = makeStar(container, color, size, zIndex)
						table.insert(pool, star :: Star)
					end
					local chosen = star :: Star
					chosen.busy = true
					chosen.age = 0
					chosen.frame.Position = UDim2.fromScale(math.random(), math.random())
					chosen.frame.Visible = true
					busy += 1
				end
			end
			for _, star in pool do
				if star.busy then
					star.age += dt
					local progress = star.age / Sparkle.TwinkleLife
					if progress >= 1 then
						retire(star)
					else
						star.scale.Scale = math.sin(progress * math.pi)
					end
				end
			end
		end)

		return function()
			disconnect()
			for _, star in pool do
				if star.busy then
					SparkleClock.Release("Twinkle", 1)
				end
				star.frame:Destroy()
			end
			table.clear(pool)
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
