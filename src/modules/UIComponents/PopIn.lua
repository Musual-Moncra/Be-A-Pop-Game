--!strict

--[[
	PopIn
	The one pop-in animation every window, card, row and toast uses: a UIScale zooms from
	Animation.PopInStart to 1 in a single Back-Out tween (a cute overshoot without chaining
	tweens). Anything delayed past Animation.PopInMaxDelay appears at once, so a long grid does
	not run dozens of tweens when it opens.

	API: PopIn.play(scale: UIScale, delay: number?) -> Tween?   (cancel it on unmount if needed)
	Dependencies: TweenService, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local Animation = UIConfig.Animation

local PopIn = {}

function PopIn.play(scale: UIScale, delay: number?): Tween?
	local wait = delay or 0
	if wait > Animation.PopInMaxDelay then
		scale.Scale = 1
		return nil
	end
	scale.Scale = Animation.PopInStart
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(Animation.PopInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, wait),
		{ Scale = 1 }
	)
	tween:Play()
	return tween
end

return PopIn
