--!strict

--[[
	useUIScale
	React hook that turns the real screen into design pixels. The whole UI is drawn in
	UIConfig design pixels and multiplied by `scale` through one UIScale at the root.

	Usage: useUIScale(screenGui, safeGui)
		screenGui: the full-screen ScreenGui (ScreenInsets None) the UI is mounted in
		safeGui: an empty ScreenGui with CoreUISafeInsets, used only to measure the safe area
			(Roblox top bar, phone notches and home indicator)
	Returns UIScale:
		scale: design pixel -> screen pixel multiplier
		mobile: touch-only input or a safe area narrower than UIConfig.Scale.MobileMaxWidth
		width / height: full screen size in design pixels
		safe: { Top, Left, Bottom, Right } inset of the safe area from each screen edge (design pixels)
		safeWidth / safeHeight: safe area size in design pixels
	The scale fits the safe area by height and by width (UIConfig.Scale.ReferenceHeight /
	ReferenceWidth), whichever is smaller, so wide windows never overflow narrow screens.

	Layout testing: set a Vector2 attribute "PreviewSize" (screen pixels) on the screenGui to lay
	the UI out as if the screen had that size (drawn in the top-left corner), and a boolean
	"PreviewTouch" to force the Mobile layout. Remove the attributes to return to the real screen.

	Dependencies: React, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local Scale = UIConfig.Scale

export type SafeInsets = {
	Top: number,
	Left: number,
	Bottom: number,
	Right: number,
}

export type UIScale = {
	scale: number,
	mobile: boolean,
	width: number,
	height: number,
	safe: SafeInsets,
	safeWidth: number,
	safeHeight: number,
}

local function screenSize(screenGui: ScreenGui): Vector2
	local size = screenGui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		return size
	end
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else Vector2.new(Scale.ReferenceWidth, Scale.ReferenceHeight)
end

local function read(screenGui: ScreenGui, safeGui: ScreenGui): UIScale
	local full = screenSize(screenGui)
	local safePos = safeGui.AbsolutePosition - screenGui.AbsolutePosition
	local safeSize = safeGui.AbsoluteSize
	if safeSize.X <= 0 or safeSize.Y <= 0 then
		safePos, safeSize = Vector2.zero, full
	end

	local preview = screenGui:GetAttribute("PreviewSize")
	if typeof(preview) == "Vector2" and preview.X > 0 and preview.Y > 0 then
		full, safePos, safeSize = preview, Vector2.zero, preview
	end

	local touchOnly = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		or screenGui:GetAttribute("PreviewTouch") == true
	local mobile = touchOnly or safeSize.X < Scale.MobileMaxWidth
	local refHeight = if mobile then Scale.MobileReferenceHeight else Scale.ReferenceHeight
	local refWidth = if mobile then Scale.MobileReferenceWidth else Scale.ReferenceWidth
	local scale = math.clamp(math.min(safeSize.Y / refHeight, safeSize.X / refWidth), Scale.Min, Scale.Max)

	local safe: SafeInsets = {
		Top = math.max(0, safePos.Y) / scale,
		Left = math.max(0, safePos.X) / scale,
		Bottom = math.max(0, full.Y - safePos.Y - safeSize.Y) / scale,
		Right = math.max(0, full.X - safePos.X - safeSize.X) / scale,
	}

	return {
		scale = scale,
		mobile = mobile,
		width = full.X / scale,
		height = full.Y / scale,
		safe = safe,
		safeWidth = safeSize.X / scale,
		safeHeight = safeSize.Y / scale,
	}
end

return function(screenGui: ScreenGui, safeGui: ScreenGui): UIScale
	local value, setValue = React.useState(function()
		return read(screenGui, safeGui)
	end)

	React.useEffect(function()
		local function refresh()
			setValue(read(screenGui, safeGui))
		end
		local connections = {
			screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh),
			screenGui.AttributeChanged:Connect(refresh),
			safeGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh),
			safeGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh),
			UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh),
			UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refresh),
		}
		refresh()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { screenGui, safeGui } :: { any })

	return value
end
