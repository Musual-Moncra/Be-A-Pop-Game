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
	materials: { Enum.Material },
	step: number,
}

local modelTintCache: { [Instance]: TintEntry } = {}

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
	local materials: { Enum.Material } = table.create(#parts)
	for index, part in parts do
		colors[index] = part.Color
		materials[index] = part.Material
	end
	local entry: TintEntry = { parts = parts, colors = colors, materials = materials, step = 0 }
	modelTintCache[instance] = entry
	return entry
end

Net.ObjectStained.OnClientEvent:Connect(function(obj: Instance, step: number)
	if obj == nil then
		return
	end
	local entry = getTintEntry(obj)
	if step == entry.step or entry.step > ObjectConfig.TintSteps then
		return
	end
	entry.step = step
	local alpha = math.clamp(step / ObjectConfig.TintSteps, 0, 1)
	for index, part in entry.parts do
		part.Color = entry.colors[index]:Lerp(ObjectConfig.SoiledColor, alpha)
	end
end)

Net.ObjectSoiled.OnClientEvent:Connect(function(obj: Instance, _bonus: number)
	if obj == nil then
		return
	end
	local entry = getTintEntry(obj)
	entry.step = ObjectConfig.TintSteps + 1
	for _, part in entry.parts do
		part.Color = ObjectConfig.SoiledColor
		part.Material = ObjectConfig.SoiledMaterial
	end
end)

Net.RunEnded.OnClientEvent:Connect(function(_summary: any)
	for _, entry in modelTintCache do
		for index, part in entry.parts do
			if part.Parent ~= nil then
				part.Color = entry.colors[index]
				part.Material = entry.materials[index]
			end
		end
	end
	table.clear(modelTintCache)
end)

return ObjectTintController
