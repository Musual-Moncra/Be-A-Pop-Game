--!strict

--[[
	Inset
	Dark recessed box used for bar tracks, value wells and list backgrounds.

	Props: size, position, anchorPoint, layoutOrder, zIndex, automaticSize, clip, radius (design pixels, or "Round"),
	       padding (design pixels), children

	Dependencies: React, UIConfig, Primitives
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Primitives = require(ReplicatedStorage.Modules.UIComponents.Primitives)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape

return function(props: any)
	local children = {
		Corner = Primitives.corner(props.radius or Shape.Radius),
		Stroke = Primitives.stroke(Palette.InsetStroke, Shape.Stroke),
		Padding = if props.padding ~= nil then Primitives.padding(props.padding) else nil,
	}
	for key, child in props.children or {} do
		children[key] = child
	end
	return e("Frame", {
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		BackgroundColor3 = Palette.Inset,
		BackgroundTransparency = Shape.InsetTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = props.clip == true,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		Size = props.size,
		ZIndex = props.zIndex,
	}, children)
end
