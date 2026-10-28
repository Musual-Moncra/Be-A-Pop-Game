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

type TintEntry = {
	parts: { BasePart },
	colors: { Color3 },
}

local modelTintCache: { [Instance]: TintEntry } = {}
local originalColors: { [BasePart]: Color3 } = {}
local originalMaterials: { [BasePart]: Enum.Material } = {}

local function saveOriginal(part: BasePart)
	if originalColors[part] == nil then
		originalColors[part] = part.Color
		originalMaterials[part] = part.Material
	end
end

local function getTintEntry(instance: Instance): TintEntry
	local cached = modelTintCache[instance]
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
	local colors: { Color3 } = table.create(#parts)
	for index, part in parts do
		saveOriginal(part)
		colors[index] = part.Color
	end
	local entry = { parts = parts, colors = colors }
	modelTintCache[instance] = entry
	return entry
end

Net.ObjectStained.OnClientEvent:Connect(function(obj: Instance, step: number)
	if obj == nil then
		return
	end
	local alpha = math.clamp(step / ObjectConfig.TintSteps, 0, 1)
	local entry = getTintEntry(obj)
	for index, part in entry.parts do
		part.Color = entry.colors[index]:Lerp(ObjectConfig.SoiledColor, alpha)
	end
end)

Net.ObjectSoiled.OnClientEvent:Connect(function(obj: Instance, _bonus: number)
	if obj == nil then
		return
	end
	local entry = getTintEntry(obj)
	for _, part in entry.parts do
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
	table.clear(modelTintCache)
end)

return ObjectTintController
