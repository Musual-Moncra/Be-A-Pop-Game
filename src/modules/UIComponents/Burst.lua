--!strict

--[[
	Burst
	Confetti burst: rounded candy pieces and stars fly out from a point, fall with gravity and
	fade. Fire it by changing `trigger`; animation runs on the shared SparkleClock and is capped
	at Sparkle.MaxBurst pieces on screen.

	Props: trigger (any value; a change fires a burst), origin (UDim2 inside the parent, default centre),
		count (pieces, default Sparkle.BurstCount), colors (list of Color3), zIndex, active
	Dependencies: React, UIConfig, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local SparkleClock = require(Components.SparkleClock)

local e = React.createElement
local Sparkle = UIConfig.Sparkle

local function pick(list: { Color3 }): Color3
	return list[math.random(1, #list)]
end

return function(props: any)
	local containerRef = React.useRef(nil)
	local piecesRef = React.useRef({})
	local lastTrigger = React.useRef(nil)
	local originRef = React.useRef(props.origin or UDim2.fromScale(0.5, 0.5))
	originRef.current = props.origin or UDim2.fromScale(0.5, 0.5)
	local colorsRef = React.useRef(props.colors or Sparkle.BurstColors)
	colorsRef.current = props.colors or Sparkle.BurstColors

	React.useEffect(function()
		local disconnect = SparkleClock.Subscribe(function(dt: number)
			local pieces = piecesRef.current
			for index = #pieces, 1, -1 do
				local piece = pieces[index]
				piece.age += dt
				local life = Sparkle.BurstLife
				local progress = math.min(1, piece.age / life)
				piece.vx *= 0.985
				piece.vy += Sparkle.BurstGravity * dt
				local x = piece.x + piece.vx * dt
				local y = piece.y + piece.vy * dt
				piece.x = x
				piece.y = y
				piece.label.Position = piece.origin + UDim2.fromOffset(x, y)
				piece.label.Rotation = piece.rotation + piece.spin * piece.age
				if piece.isStar then
					piece.label.TextTransparency = progress
				else
					piece.label.BackgroundTransparency = progress
				end
				piece.label.Size =
					UDim2.fromOffset(piece.size * (1 - progress * 0.4), piece.size * (1 - progress * 0.4))
				if progress >= 1 then
					piece.label:Destroy()
					table.remove(pieces, index)
					SparkleClock.Release("Burst", 1)
				end
			end
		end)
		return function()
			disconnect()
			local alive = #piecesRef.current
			for _, piece in piecesRef.current do
				piece.label:Destroy()
			end
			table.clear(piecesRef.current)
			if alive > 0 then
				SparkleClock.Release("Burst", alive)
			end
		end
	end, {})

	React.useEffect(function()
		local trigger = props.trigger
		if trigger == nil or lastTrigger.current == trigger or props.active == false then
			return
		end
		lastTrigger.current = trigger
		local container = containerRef.current
		if container == nil then
			return
		end
		local requested = props.count or Sparkle.BurstCount
		local granted = SparkleClock.Reserve("Burst", Sparkle.MaxBurst, requested)
		local origin = originRef.current
		for _ = 1, granted do
			local isStar = math.random() < 0.3
			local label
			if isStar then
				label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Text = Sparkle.BurstStarText
				label.TextColor3 = pick(colorsRef.current)
				label.TextSize = Sparkle.BurstSize * 2
				label.FontFace = Font.new(UIConfig.Fonts.Display, UIConfig.Fonts.DisplayWeight)
			else
				label = Instance.new("Frame")
				label.BackgroundColor3 = pick(colorsRef.current)
				label.BorderSizePixel = 0
				label.Size = UDim2.fromOffset(Sparkle.BurstSize, Sparkle.BurstSize)
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = label
			end
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = origin
			label.ZIndex = props.zIndex or 8
			local scale = Instance.new("UIScale")
			scale.Scale = 1
			scale.Parent = label
			label.Parent = container
			local angle = -math.pi / 2 + (math.random() - 0.5) * math.pi * 0.9
			local speed = math.random(Sparkle.BurstSpeedMin, Sparkle.BurstSpeedMax)
			table.insert(piecesRef.current, {
				age = 0,
				isStar = isStar,
				label = label,
				rotation = math.random(0, 360),
				size = if isStar then Sparkle.BurstSize * 2 else Sparkle.BurstSize,
				spin = math.random(-360, 360),
				vx = math.cos(angle) * speed,
				vy = math.sin(angle) * speed,
				x = 0,
				y = 0,
				origin = origin,
			})
		end
	end, { props.trigger, props.count, props.active } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex,
		ref = containerRef,
	})
end
