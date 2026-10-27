--!strict

--[[
	ProgressBar
	Rounded track plus a scaled fill. Props: ratio (0-1), size, position,
	layoutOrder, fillColor, trackColor, visible.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local e = React.createElement
local Theme = UIConfig.Theme

return function(props: any)
	local ratio = math.clamp(tonumber(props.ratio) or 0, 0, 1)

	return e("Frame", {
		BackgroundColor3 = props.trackColor or Theme.Colors.BarTrack,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		Visible = props.visible ~= false,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.Radii.Pill }),
		Fill = e("Frame", {
			BackgroundColor3 = props.fillColor or Theme.Colors.Accent,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(ratio, 1),
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.Radii.Pill }),
		}),
	})
end
