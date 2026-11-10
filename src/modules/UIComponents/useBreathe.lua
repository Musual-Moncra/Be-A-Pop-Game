--!strict

--[[
	useBreathe
	Idle zoom for a UIScale: scale 1.00 ↔ scale, sine over period, phase-offset so neighbours
	never pulse in sync. Runs on the shared SparkleClock tick, skips elements that are hidden or off-screen and
	only writes the scale when it changed visibly.

	Usage: useBreathe(scaleRef, scale, period, phase, active?)
	Dependencies: React, UIConfig, SparkleClock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local SparkleClock = require(ReplicatedStorage.Modules.UIComponents.SparkleClock)

local TAU = math.pi * 2

return function(scaleRef: any, scale: number, period: number, phase: number?, active: boolean?)
	React.useEffect(function()
		local target = scaleRef.current
		if target == nil then
			return
		end
		if active == false or period <= 0 then
			target.Scale = 1
			return
		end
		local offset = (phase or 0) * TAU
		local holder = target.Parent
		local disconnect = SparkleClock.Subscribe(function(_dt: number, now: number)
			if holder ~= nil and holder:IsA("GuiObject") and not SparkleClock.OnScreen(holder) then
				return
			end
			local value = 1 + (scale - 1) * (0.5 + 0.5 * math.sin(now / period * TAU + offset))
			if math.abs(value - target.Scale) >= UIConfig.Sparkle.BreatheEpsilon then
				target.Scale = value
			end
		end)
		return function()
			disconnect()
			if target.Parent ~= nil then
				target.Scale = 1
			end
		end
	end, { scale, period, phase, active } :: { any })
end
