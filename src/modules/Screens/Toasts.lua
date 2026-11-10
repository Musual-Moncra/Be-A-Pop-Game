--!strict

--[[
	Toasts
	Stack of notification toasts at the top centre (unlock results, purchases, quest
	completions, level ups). Each toast pops in with a squishy scale overshoot and a short
	non-uniform squash, then settles. Motion tokens come from UIConfig.Animation.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, TweenService, UIConfig, Primitives, ChunkyButton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ChunkyButton = require(ReplicatedStorage.Modules.UIComponents.ChunkyButton)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Animation = UIConfig.Animation
local Sizes = UIConfig.Sizes.Toast

local function Toast(props: any)
	local popRef = React.useRef(nil)
	local bodyRef = React.useRef(nil)

	React.useEffect(function()
		local pop = popRef.current
		local body = bodyRef.current
		if pop == nil or body == nil then
			return
		end
		pop.Scale = Animation.PopInStart
		body.Size = UDim2.fromScale(Animation.PressSquashX, Animation.PressSquashY)
		TweenService:Create(
			body,
			TweenInfo.new(Animation.PressSquashTime, Animation.SmoothStyle, Animation.SmoothDirection),
			{ Size = UDim2.fromScale(1, 1) }
		):Play()
		local grow = TweenService:Create(
			pop,
			TweenInfo.new(Animation.PopInTime * 0.35, Animation.SpringStyle, Animation.SpringDirection),
			{ Scale = Animation.PopInOver }
		)
		grow:Play()
		local settle = task.delay(Animation.PopInTime * 0.35, function()
			TweenService:Create(
				pop,
				TweenInfo.new(Animation.PopInTime * 0.3, Animation.SmoothStyle, Animation.SmoothDirection),
				{ Scale = Animation.PopInUnder }
			):Play()
		end)
		local finish = task.delay(Animation.PopInTime * 0.65, function()
			TweenService:Create(
				pop,
				TweenInfo.new(Animation.PopInTime * 0.35, Animation.SpringStyle, Animation.SpringDirection),
				{ Scale = 1 }
			):Play()
		end)
		return function()
			grow:Cancel()
			task.cancel(settle)
			task.cancel(finish)
		end
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.toast.Id,
		Size = UDim2.fromOffset(Sizes.Width, Sizes.Height),
	}, {
		Pop = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Scale = e("UIScale", { ref = popRef }),
			Body = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(Animation.PressSquashX, Animation.PressSquashY),
				ref = bodyRef,
			}, {
				Toast = e(ChunkyButton, {
					gloss = true,
					size = UDim2.fromScale(1, 1),
					swatch = UIConfig.ToastSwatches[props.toast.Kind] or UIConfig.ToastSwatches.Info,
					text = props.toast.Text,
					textSize = UIConfig.TextSizes.Body,
				}),
			}),
		}),
	})
end

return function(props: any)
	local layout = UIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"].Toasts
	local toasts: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, Sizes.Gap, Enum.HorizontalAlignment.Center),
	}
	for _, toast in props.data.Toasts do
		toasts["Toast" .. toast.Id] = e(Toast, { toast = toast })
	end
	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = layout.Position,
		Size = UDim2.fromOffset(Sizes.Width, 0),
	}, toasts)
end
