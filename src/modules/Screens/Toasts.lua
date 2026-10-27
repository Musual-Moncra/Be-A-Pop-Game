--!strict

--[[
	Toasts
	Stack of notification toasts at the top centre (unlock results, purchases, quest
	completions, level ups). Each toast is a coloured chunky bar that pops in.

	Props: data (DataController state), ui (useUIScale result)
	Dependencies: React, UIConfig, Primitives, ChunkyButton
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
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if scale == nil then
			return
		end
		scale.Scale = Animation.OpenFromScale
		TweenService:Create(scale, TweenInfo.new(Animation.Open, Animation.SpringStyle, Animation.SpringDirection), {
			Scale = 1,
		}):Play()
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.toast.Id,
		Size = UDim2.fromOffset(Sizes.Width, Sizes.Height),
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Body = e(ChunkyButton, {
			size = UDim2.fromScale(1, 1),
			swatch = UIConfig.ToastSwatches[props.toast.Kind] or UIConfig.ToastSwatches.Info,
			text = props.toast.Text,
			textSize = UIConfig.TextSizes.Body,
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
