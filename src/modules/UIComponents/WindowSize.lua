--!strict

--[[
	WindowSize
	Sizing helpers shared by every modal window screen.

	API:
		WindowSize.fit(ui, width, height) -> (width, height)
			clamps a window's design size to the safe area minus the layout's WindowMargin,
			leaving room for the ribbon header that sticks out above the window
		WindowSize.chrome() -> number
			design pixels the header and padding add around a window's content height,
			so a screen can size its window to its content

	Dependencies: UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local Sizes = UIConfig.Sizes.Window

local WindowSize = {}

function WindowSize.fit(ui: any, width: number, height: number): (number, number)
	local margin = UIConfig.Layouts[if ui.mobile then "Mobile" else "PC"].WindowMargin
	return math.min(width, ui.safeWidth - margin * 2),
		math.min(height, ui.safeHeight - margin * 2 - Sizes.HeaderHeight * (0.5 + Sizes.CenterShift))
end

function WindowSize.chrome(): number
	return Sizes.HeaderHeight / 2 + Sizes.Padding * 2
end

return WindowSize
