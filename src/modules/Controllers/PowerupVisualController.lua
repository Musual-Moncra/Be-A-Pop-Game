--!strict

--[[
	PowerupVisualController
	Client-only look of food items: bobbing, spinning and a floating emoji icon
	(PowerupConfig Icon) above each one so players can tell foods apart.

	Dependencies:
		Workspace, RunService, ReplicatedStorage, PowerupConfig, ConfigLookup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PowerupConfig = require(ReplicatedStorage.Modules.Config.PowerupConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)

local PowerupVisualController = {}

local tracked: { [BasePart]: CFrame } = {}

local function trackPart(instance: Instance)
	if not instance:IsA("BasePart") or tracked[instance] ~= nil then
		return
	end
	local powerupId = instance:GetAttribute("PowerupId")
	if typeof(powerupId) ~= "string" then
		return
	end
	tracked[instance] = instance.CFrame
	local definition = ConfigLookup.GetPowerup(powerupId)
	if definition ~= nil then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Icon"
		billboard.AlwaysOnTop = false
		billboard.LightInfluence = 0
		billboard.Size = UDim2.fromScale(PowerupConfig.IconSize, PowerupConfig.IconSize)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, PowerupConfig.IconHeight, 0)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = definition.Icon
		label.TextScaled = true
		label.Parent = billboard
		billboard.Parent = instance
	end
	instance.Destroying:Connect(function()
		tracked[instance] = nil
	end)
end

local function trackFolder(folder: Instance)
	if
		not folder:IsA("Folder")
		or string.sub(folder.Name, 1, #PowerupConfig.FolderPrefix) ~= PowerupConfig.FolderPrefix
	then
		return
	end
	for _, child in folder:GetChildren() do
		trackPart(child)
	end
	folder.ChildAdded:Connect(trackPart)
end

for _, child in Workspace:GetChildren() do
	trackFolder(child)
end
Workspace.ChildAdded:Connect(trackFolder)

local TAU = math.pi + math.pi
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

RunService.RenderStepped:Connect(function()
	if next(tracked) == nil then
		return
	end
	local now = os.clock()
	local bobOffset = Vector3.new(0, math.sin(now * PowerupConfig.BobSpeed * TAU) * PowerupConfig.BobHeight, 0)
	local rot = CFrame.Angles(0, math.rad(now * PowerupConfig.SpinSpeed), 0)
	table.clear(moveParts)
	table.clear(moveCFrames)
	for part, baseCFrame in tracked do
		if part.Parent ~= nil then
			table.insert(moveParts, part)
			table.insert(moveCFrames, (baseCFrame + bobOffset) * rot)
		else
			tracked[part] = nil
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

return PowerupVisualController
