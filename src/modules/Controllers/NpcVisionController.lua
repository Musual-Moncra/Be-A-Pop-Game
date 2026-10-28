--!strict

--[[
	NpcVisionController
	Draws a flat vision oval on the floor in front of every patrolling NPC and recolours it while
	that NPC chases. The server NpcService moves the NPCs and sets the NpcState attribute
	("Patrol" | "Chase" | "Return"); this controller reads each NPC model pivot, places a
	client-only Neon ellipsoid (Part + Sphere SpecialMesh) ViewOffset ahead along the look
	direction and snaps it to the map floor with a downward raycast, once per frame.

	Dependencies: Workspace, RunService, MapConfig, NpcConfig, RunConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local NpcConfig = require(ReplicatedStorage.Modules.Config.NpcConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)

type MapDefinition = {
	Id: string,
	ModelName: string,
	Enabled: boolean,
}

type Zone = {
	part: Part,
	params: RaycastParams?,
	floorY: number,
}

local zones: { [Model]: Zone } = {}
local zonesFolder: Folder? = nil

local function floorFor(zone: Zone, center: Vector3): number
	if zone.params == nil then
		return zone.floorY
	end
	local result = Workspace:Raycast(center + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), zone.params)
	if result ~= nil then
		zone.floorY = result.Position.Y
	end
	return zone.floorY
end

local function addZone(npc: Model, params: RaycastParams?)
	if zones[npc] ~= nil or zonesFolder == nil then
		return
	end

	local part = Instance.new("Part")
	part.Name = "NpcVisionZone"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = NpcConfig.ZoneColor
	part.Transparency = NpcConfig.ZoneTransparency
	part.Size = Vector3.new(NpcConfig.ViewWidth, NpcConfig.ZoneHeight, NpcConfig.ViewLength)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part

	part.Parent = zonesFolder
	zones[npc] = {
		part = part,
		params = params,
		floorY = npc:GetPivot().Position.Y,
	}
end

local function mapParams(mapModel: Model): RaycastParams?
	local floor = mapModel:FindFirstChild("Floor")
	if floor == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { floor }
	params.IgnoreWater = true
	return params
end

local function setupMap(mapDef: MapDefinition)
	local patrolDefs = RunConfig.NpcPatrols[mapDef.Id]
	local mapModel = if mapDef.Enabled then Workspace:FindFirstChild(mapDef.ModelName) else nil
	local npcsFolder = if mapModel ~= nil then mapModel:FindFirstChild("NPCs") else nil
	if patrolDefs == nil or npcsFolder == nil then
		return
	end

	local params = mapParams(mapModel)
	for _, patrolDef in patrolDefs do
		local npc = npcsFolder:FindFirstChild(patrolDef.name)
		if npc ~= nil and npc:IsA("Model") then
			addZone(npc, params)
		end
	end
end

local function update()
	for npc, zone in zones do
		if not npc:IsDescendantOf(Workspace) then
			zone.part:Destroy()
			zones[npc] = nil
			continue
		end

		local pivot = npc:GetPivot()
		local look = pivot.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		else
			flat = flat.Unit
		end

		local center = pivot.Position + flat * NpcConfig.ViewOffset
		local y = floorFor(zone, center) + NpcConfig.ZoneHeight * 0.5
		local position = Vector3.new(center.X, y, center.Z)
		zone.part.CFrame = CFrame.lookAt(position, position + flat)
		zone.part.Color = if npc:GetAttribute("NpcState") == "Chase"
			then NpcConfig.ChaseColor
			else NpcConfig.ZoneColor
	end
end

return function()
	local folder = Instance.new("Folder")
	folder.Name = "NpcVisionZones"
	folder.Parent = Workspace
	zonesFolder = folder

	for _, mapDef in MapConfig.Maps do
		task.spawn(setupMap, mapDef)
	end

	Workspace.ChildAdded:Connect(function(child)
		for _, mapDef in MapConfig.Maps do
			if child.Name == mapDef.ModelName then
				task.spawn(setupMap, mapDef)
				return
			end
		end
	end)

	RunService.RenderStepped:Connect(update)
end
