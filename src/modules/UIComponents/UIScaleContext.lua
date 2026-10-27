--!strict

--[[
	UIScaleContext
	React context carrying the root UI scale (design pixel -> screen pixel) that App applies,
	so components can turn measured screen pixels back into design pixels.

	Usage: React.useContext(UIScaleContext) -> number (1 when no provider is mounted)

	Dependencies: React
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

return React.createContext(1)
