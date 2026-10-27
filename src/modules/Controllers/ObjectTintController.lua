--!strict

--[[
	ObjectTintController
	Client controller that visually tints map props towards the soiled color as they
	accumulate stains, applies the soiled material when fully soiled, and restores
	original part colors and materials when a run ends.

	Dependencies:
		ReplicatedStorage, ObjectConfig, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectConfig = require(ReplicatedStorage.Modules.Config.ObjectConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

local ObjectTintController = {}

local modelPartsCache: { [Instance]: { BasePart } } = {}
local originalColors: { [BasePart]: Color3 } = {}
local originalMaterials: { [BasePart]: Enum.Material } = {}

local function getBaseParts(instance: Instance): { BasePart }
	local cached = modelPartsCache[instance]
	if cached ~= nil then
		return cached
	end
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, desc in instance:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end
	modelPartsCache[instance] = parts
	return parts
end

local function saveOriginal(part: BasePart)
	if originalColors[part] == nil then
		originalColors[part] = part.Color
		originalMaterials[part] = part.Material
	end
end

Net.ObjectStained.OnClientEvent:Connect(function(obj: Instance, step: number)
	if obj == nil then
		return
	end
	local alpha = math.clamp(step / ObjectConfig.TintSteps, 0, 1)
	for _, part in getBaseParts(obj) do
		saveOriginal(part)
		local origColor = originalColors[part]
		if origColor ~= nil then
			part.Color = origColor:Lerp(ObjectConfig.SoiledColor, alpha)
		end
	end
end)

Net.ObjectSoiled.OnClientEvent:Connect(function(obj: Instance, _bonus: number)
	if obj == nil then
		return
	end
	for _, part in getBaseParts(obj) do
		saveOriginal(part)
		part.Color = ObjectConfig.SoiledColor
		part.Material = ObjectConfig.SoiledMaterial
	end
end)

Net.RunEnded.OnClientEvent:Connect(function(_summary: any)
	for part, origColor in originalColors do
		if part.Parent ~= nil then
			part.Color = origColor
			local origMat = originalMaterials[part]
			if origMat ~= nil then
				part.Material = origMat
			end
		end
	end
	table.clear(originalColors)
	table.clear(originalMaterials)
	table.clear(modelPartsCache)
end)

return ObjectTintController
