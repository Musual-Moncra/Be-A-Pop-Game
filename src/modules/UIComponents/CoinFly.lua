--!strict

--[[
	CoinFly
	Flies a handful of icons along an arc from a source to a target, then calls onArrive (the
	target pill can punch). Fire it by changing `trigger`; the flight is driven by the shared
	SparkleClock.

	Props: trigger (any value; a change fires a flight), from / to (UDim2 inside the parent),
		icon (emoji), count (default Sparkle.CoinFlyCount), duration (seconds), onArrive,
		zIndex, active
	Dependencies: React, UIConfig, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local SparkleClock = require(Components.SparkleClock)

local e = React.createElement
local Sparkle = UIConfig.Sparkle

local function bezier(a: UDim2, control: UDim2, b: UDim2, t: number): UDim2
	local inv = 1 - t
	return UDim2.new(
		inv * inv * a.X.Scale + 2 * inv * t * control.X.Scale + t * t * b.X.Scale,
		inv * inv * a.X.Offset + 2 * inv * t * control.X.Offset + t * t * b.X.Offset,
		inv * inv * a.Y.Scale + 2 * inv * t * control.Y.Scale + t * t * b.Y.Scale,
		inv * inv * a.Y.Offset + 2 * inv * t * control.Y.Offset + t * t * b.Y.Offset
	)
end

return function(props: any)
	local containerRef = React.useRef(nil)
	local flightsRef = React.useRef({})
	local lastTrigger = React.useRef(nil)

	React.useEffect(function()
		local disconnect = SparkleClock.Subscribe(function(dt: number)
			local flights = flightsRef.current
			for index = #flights, 1, -1 do
				local flight = flights[index]
				flight.age += dt
				local progress = if flight.age <= 0 then 0 else math.min(1, flight.age / flight.duration)
				flight.label.Position = bezier(flight.from, flight.control, flight.to, progress)
				flight.label.TextTransparency = if progress > 0.85 then (progress - 0.85) / 0.15 else 0
				if progress >= 1 then
					flight.label:Destroy()
					table.remove(flights, index)
					if #flights == 0 and flight.onArrive ~= nil then
						flight.onArrive()
					end
				end
			end
		end)
		return function()
			disconnect()
			for _, flight in flightsRef.current do
				flight.label:Destroy()
			end
			table.clear(flightsRef.current)
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
		local from = props.from or UDim2.fromScale(0.5, 0.5)
		local to = props.to or UDim2.fromScale(0.5, 0.5)
		local control = UDim2.new(
			(from.X.Scale + to.X.Scale) / 2,
			(from.X.Offset + to.X.Offset) / 2,
			(from.Y.Scale + to.Y.Scale) / 2,
			(from.Y.Offset + to.Y.Offset) / 2 - Sparkle.CoinFlyArc
		)
		local count = props.count or Sparkle.CoinFlyCount
		local duration = props.duration or Sparkle.CoinFlyDuration
		for index = 1, count do
			local icon = Instance.new("TextLabel")
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.BackgroundTransparency = 1
			icon.FontFace = Font.new(UIConfig.Fonts.Display, UIConfig.Fonts.DisplayWeight)
			icon.Position = from
			icon.Size = UDim2.fromOffset(Sparkle.CoinFlySize, Sparkle.CoinFlySize)
			icon.Text = props.icon or "💰"
			icon.TextSize = Sparkle.CoinFlySize
			icon.ZIndex = props.zIndex or 8
			icon.Parent = container
			table.insert(flightsRef.current, {
				age = -index * 0.03,
				control = control,
				duration = duration,
				from = from,
				label = icon,
				onArrive = props.onArrive,
				to = to,
			})
		end
	end, { props.trigger, props.from, props.to, props.icon, props.count, props.duration, props.active } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex,
		ref = containerRef,
	})
end
