--!strict

--[[
	useDeviceLayout
	React hook returning "PC" or "Mobile". Mobile means touch-only input or
	a viewport narrower than UIConfig.Theme.MobileMaxWidth; re-evaluates on
	viewport, touch or keyboard changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local function readLayout(): string
	local camera = Workspace.CurrentCamera
	local width = if camera ~= nil then camera.ViewportSize.X else 1920
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return if touchOnly or width < UIConfig.Theme.MobileMaxWidth then "Mobile" else "PC"
end

return function(): string
	local layout, setLayout = React.useState(readLayout())

	React.useEffect(function()
		local connections = {
			UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
				setLayout(readLayout())
			end),
			UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
				setLayout(readLayout())
			end),
		}

		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			table.insert(
				connections,
				camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					setLayout(readLayout())
				end)
			)
		end

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	return layout
end
