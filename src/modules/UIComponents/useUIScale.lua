--!strict

--[[
	useUIScale
	React hook that turns the real screen into design pixels. The whole UI is drawn in
	UIConfig design pixels and multiplied by `scale` through one UIScale at the root.

	Usage: useUIScale(screenGui) — measures the ScreenGui's AbsoluteSize (safe area included).
	Returns { scale: number, mobile: boolean, width: number, height: number }
		width / height: usable screen size in design pixels (after scaling)
	Mobile = touch-only input or a viewport narrower than UIConfig.Scale.MobileMaxWidth.

	Dependencies: React, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

export type UIScale = {
	scale: number,
	mobile: boolean,
	width: number,
	height: number,
}

local function read(screenGui: ScreenGui): UIScale
	local size = screenGui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		local camera = Workspace.CurrentCamera
		size = if camera ~= nil
			then camera.ViewportSize
			else Vector2.new(UIConfig.Scale.ReferenceHeight, UIConfig.Scale.ReferenceHeight)
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local mobile = touchOnly or size.X < UIConfig.Scale.MobileMaxWidth
	local reference = if mobile then UIConfig.Scale.MobileReferenceHeight else UIConfig.Scale.ReferenceHeight
	local scale = math.clamp(size.Y / reference, UIConfig.Scale.Min, UIConfig.Scale.Max)
	return {
		scale = scale,
		mobile = mobile,
		width = size.X / scale,
		height = size.Y / scale,
	}
end

return function(screenGui: ScreenGui): UIScale
	local value, setValue = React.useState(function()
		return read(screenGui)
	end)

	React.useEffect(function()
		local function refresh()
			setValue(read(screenGui))
		end
		local connections = {
			screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh),
			UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh),
			UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refresh),
		}
		refresh()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { screenGui })

	return value
end
