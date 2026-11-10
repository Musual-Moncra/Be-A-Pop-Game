--!strict

--[[
	KeyHint
	Small keycap that shows the PC shortcut of an action (KeybindConfig label), e.g. "P" on the
	Pets tile. Renders nothing unless the player is on keyboard and mouse, and never animates.

	Props: action (KeybindConfig action id), anchorPoint, position (default bottom-left corner,
		slightly outside), zIndex
	Dependencies: React, UIConfig, Primitives, Keybinds
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Components = ReplicatedStorage.Modules.UIComponents
local Keybinds = require(Components.Keybinds)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Hint = UIConfig.KeyHint
local Palette = UIConfig.Palette

return function(props: any)
	local shown = Keybinds.useHints()
	local label = Keybinds.label(props.action)
	if not shown or label == "" then
		return nil
	end
	local width = math.max(Hint.Size, Hint.CharWidth * #label + Hint.Padding * 2)
	return e("Frame", {
		AnchorPoint = props.anchorPoint or Vector2.new(0, 1),
		BackgroundColor3 = Hint.Face,
		BorderSizePixel = 0,
		Position = props.position or UDim2.new(0, -Hint.Offset, 1, Hint.Offset),
		Size = UDim2.fromOffset(width, Hint.Size),
		ZIndex = props.zIndex or 10,
	}, {
		Corner = Primitives.corner(Hint.Radius),
		Stroke = Primitives.stroke(Palette.Ink, Hint.Stroke),
		Gradient = Primitives.gradient(Hint.Face, Hint.Bottom),
		Label = Primitives.text({
			Size = UDim2.fromScale(1, 1),
			Text = label,
			Color = Palette.Ink,
			Stroke = false,
			TextSize = Hint.TextSize,
			ZIndex = (props.zIndex or 10) + 1,
		}),
	})
end
