--!strict

--[[
	MapAnimController
	Client-only ambient animation of map details (ceiling fans, swaying plants and trees,
	bobbing balloons, swings, pulsing neon signs). Finds every Part or Model in Workspace
	with an AnimKind attribute, remembers its rest pose and animates it each frame with the
	MapAnimConfig kind of that name. Details far from the camera are skipped.

	Dependencies:
		Workspace, RunService, ReplicatedStorage, MapAnimConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapAnimConfig = require(ReplicatedStorage.Modules.Config.MapAnimConfig)

local MapAnimController = {}

type Detail = {
	instance: PVInstance,
	kind: any,
	phase: number,
	rest: CFrame,
	hinge: CFrame,
	parts: { BasePart },
	baseTransparency: { number },
	near: boolean,
}

local TAU = math.pi + math.pi
local details: { [PVInstance]: Detail } = {}

local function collectParts(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function getBounds(instance: PVInstance): (CFrame, Vector3)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	end
	local part = instance :: BasePart
	return part.CFrame, part.Size
end

local function track(instance: Instance)
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
		return
	end
	local kindName = instance:GetAttribute("AnimKind")
	if typeof(kindName) ~= "string" then
		return
	end
	local kind = MapAnimConfig.Kinds[kindName]
	local pv = instance :: PVInstance
	if kind == nil or details[pv] ~= nil then
		return
	end
	local phase = instance:GetAttribute("AnimPhase")
	local boundsCFrame, boundsSize = getBounds(pv)
	local rest = pv:GetPivot()
	local parts = collectParts(instance)
	local baseTransparency = {}
	for index, part in parts do
		baseTransparency[index] = part.Transparency
	end
	details[pv] = {
		instance = pv,
		kind = kind,
		phase = if typeof(phase) == "number" then phase else 0,
		rest = rest,
		hinge = CFrame.new(boundsCFrame.Position + Vector3.new(0, boundsSize.Y / 2, 0)),
		parts = parts,
		baseTransparency = baseTransparency,
		near = false,
	}
	instance.Destroying:Connect(function()
		details[pv] = nil
	end)
end

local function poseFor(detail: Detail, now: number): CFrame?
	local kind = detail.kind
	local t = now + detail.phase
	if kind.Type == "Spin" then
		local angle = math.rad((t * kind.Speed) % 360)
		return detail.rest * CFrame.Angles(0, angle, 0)
	elseif kind.Type == "Bob" then
		return detail.rest + Vector3.new(0, math.sin(t * kind.Frequency * TAU) * kind.Amplitude, 0)
	elseif kind.Type == "Sway" then
		local wave = math.rad(kind.Angle)
		local tilt = CFrame.Angles(math.sin(t * kind.Frequency * TAU) * wave, 0, math.cos(t * kind.Frequency * TAU) * wave)
		return detail.rest * tilt
	elseif kind.Type == "Swing" then
		local angle = math.sin(t * kind.Frequency * TAU) * math.rad(kind.Angle)
		local hinge = detail.hinge
		return hinge * CFrame.Angles(angle, 0, 0) * hinge:Inverse() * detail.rest
	end
	return nil
end

local function applyPulse(detail: Detail, now: number)
	local kind = detail.kind
	local alpha = (math.sin((now + detail.phase) * kind.Frequency * TAU) + 1) / 2
	local fade = kind.MinTransparency + (kind.MaxTransparency - kind.MinTransparency) * alpha
	for index, part in detail.parts do
		part.Transparency = math.clamp(detail.baseTransparency[index] + fade, 0, 1)
	end
end

local lastCull = 0

local function refreshCulling(now: number)
	if now - lastCull < MapAnimConfig.CullCheckInterval then
		return
	end
	lastCull = now
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for _, detail in details do
		detail.near = (detail.rest.Position - cameraPosition).Magnitude <= MapAnimConfig.MaxDistance
	end
end

for _, descendant in Workspace:GetDescendants() do
	track(descendant)
end
Workspace.DescendantAdded:Connect(track)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	refreshCulling(now)
	for instance, detail in details do
		if detail.near then
			if detail.kind.Type == "Pulse" then
				applyPulse(detail, now)
			else
				local pose = poseFor(detail, now)
				if pose ~= nil then
					instance:PivotTo(pose)
				end
			end
		end
	end
end)

return MapAnimController
