--!strict

--[[
	NpcVisionController
	Draws, for every patrolling NPC, a red catch circle (CatchRadius) around its feet and a flat
	vision triangle on the floor in front of it (tip at the NPC, ViewLength deep, ViewWidth wide
	at the far edge, built from two mirrored WedgeParts), recoloured while that NPC chases. The
	server NpcService moves the NPCs and sets the NpcState attribute ("Patrol" | "Chase" |
	"Return"); this controller reads each NPC pivot, snaps the shapes to the map floor with a
	downward raycast and moves all of them with one Workspace:BulkMoveTo per frame.

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
	left: WedgePart,
	right: WedgePart,
	ring: Part,
	params: RaycastParams?,
	floorY: number,
}

local zones: { [Model]: Zone } = {}
local zonesFolder: Folder? = nil

local function floorFor(zone: Zone, origin: Vector3): number
	if zone.params == nil then
		return zone.floorY
	end
	local height = NpcConfig.FloorRayHeight
	local result = Workspace:Raycast(origin + Vector3.new(0, height, 0), Vector3.new(0, -height * 2, 0), zone.params)
	if result ~= nil then
		zone.floorY = result.Position.Y
	end
	return zone.floorY
end

local function flatPart<T>(part: T & BasePart, color: Color3, transparency: number): T
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Parent = zonesFolder
	return part
end

local function addZone(npc: Model, params: RaycastParams?)
	if zones[npc] ~= nil or zonesFolder == nil then
		return
	end

	local halfSize = Vector3.new(NpcConfig.ZoneHeight, NpcConfig.ViewWidth * 0.5, NpcConfig.ViewLength)
	local left = flatPart(Instance.new("WedgePart"), NpcConfig.ZoneColor, NpcConfig.ZoneTransparency)
	left.Name = "NpcViewLeft"
	left.Size = halfSize
	local right = flatPart(Instance.new("WedgePart"), NpcConfig.ZoneColor, NpcConfig.ZoneTransparency)
	right.Name = "NpcViewRight"
	right.Size = halfSize
	local ring = flatPart(Instance.new("Part"), NpcConfig.RingColor, NpcConfig.RingTransparency)
	ring.Name = "NpcCatchRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(NpcConfig.ZoneHeight, NpcConfig.CatchRadius * 2, NpcConfig.CatchRadius * 2)

	zones[npc] = {
		left = left,
		right = right,
		ring = ring,
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

local UP = Vector3.yAxis
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local function halfCFrame(tip: Vector3, forward: Vector3, side: Vector3): CFrame
	local center = tip + forward * (NpcConfig.ViewLength * 0.5) + side * (NpcConfig.ViewWidth * 0.25)
	return CFrame.fromMatrix(center, side:Cross(forward), side)
end

local function update()
	table.clear(moveParts)
	table.clear(moveCFrames)
	for npc, zone in zones do
		if not npc:IsDescendantOf(Workspace) then
			zone.left:Destroy()
			zone.right:Destroy()
			zone.ring:Destroy()
			zones[npc] = nil
			continue
		end

		local pivot = npc:GetPivot()
		local look = pivot.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		forward = if forward.Magnitude > 0 then forward.Unit else Vector3.new(0, 0, -1)
		local rightSide = forward:Cross(UP)

		local y = floorFor(zone, pivot.Position) + NpcConfig.ZoneHeight * 0.5
		local tip = Vector3.new(pivot.Position.X, y, pivot.Position.Z)
		local color = if npc:GetAttribute("NpcState") == "Chase" then NpcConfig.ChaseColor else NpcConfig.ZoneColor
		zone.left.Color = color
		zone.right.Color = color

		table.insert(moveParts, zone.left)
		table.insert(moveCFrames, halfCFrame(tip, forward, -rightSide))
		table.insert(moveParts, zone.right)
		table.insert(moveCFrames, halfCFrame(tip, forward, rightSide))
		table.insert(moveParts, zone.ring)
		table.insert(moveCFrames, CFrame.new(tip) * CFrame.Angles(0, 0, math.pi / 2))
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
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
