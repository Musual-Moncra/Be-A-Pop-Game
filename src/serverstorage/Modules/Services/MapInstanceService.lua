--!strict

--[[
	MapInstanceService
	Owns the live copies of the playable maps. A room acquires one copy when its countdown
	ends; the copy is a clone of the ServerStorage.Assets.Maps template moved to a free grid
	slot, tagged for the client controllers and released after the room finishes.

	API:
		MapInstanceService.Acquire(mapDef) -> MapInstance?    nil when the template or a slot is missing
		MapInstanceService.Release(instance)
		MapInstanceService.GetTemplate(mapDef) -> Model?       read-only template, never a live copy
		MapInstanceService.Get(model) -> MapInstance?

	MapInstance:
		model: the live clone parented under Workspace.Rooms
		mapDef: ConfigLookup.MapDefinition it was cloned from
		offset: world offset added to every authored position (Vector3)
		slot: grid slot number, 1..RoomConfig.MaxRooms

	Live copies carry the MapId (string) and MapOffset (Vector3) attributes and the
	RoomConfig.MapTag CollectionService tag. Slot n sits at
	SlotOrigin + (column * SlotSpacing, 0, row * SlotSpacing), so copies never overlap and
	stay further apart than the streaming radius.

	Dependencies: CollectionService, ServerStorage, Workspace, ConfigLookup, RoomConfig
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local RoomConfig = require(ReplicatedStorage.Modules.Config.RoomConfig)

export type MapInstance = {
	model: Model,
	mapDef: ConfigLookup.MapDefinition,
	offset: Vector3,
	slot: number,
}

local MapInstanceService = {}

local instances: { [Model]: MapInstance } = {}
local usedSlots: { [number]: boolean } = {}
local templates: { [string]: Model } = {}

local function mapFolder(): Folder
	local existing = Workspace:FindFirstChild(RoomConfig.MapFolderName)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = RoomConfig.MapFolderName
	folder.Parent = Workspace
	return folder
end

local function slotOffset(slot: number): Vector3
	local index = slot - 1
	local column = index % RoomConfig.SlotColumns
	local row = math.floor(index / RoomConfig.SlotColumns)
	return RoomConfig.SlotOrigin + Vector3.new(column * RoomConfig.SlotSpacing, 0, row * RoomConfig.SlotSpacing)
end

function MapInstanceService.GetTemplate(mapDef: ConfigLookup.MapDefinition): Model?
	local cached = templates[mapDef.Id]
	if cached ~= nil then
		if cached.Parent ~= nil then
			return cached
		end
		templates[mapDef.Id] = nil
	end

	local assets = ServerStorage:FindFirstChild("Assets")
	local maps = if assets ~= nil then assets:FindFirstChild("Maps") else nil
	local template = if maps ~= nil then maps:FindFirstChild(mapDef.ModelName) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end
	templates[mapDef.Id] = template
	return template
end

function MapInstanceService.Get(model: Model): MapInstance?
	return instances[model]
end

function MapInstanceService.Acquire(mapDef: ConfigLookup.MapDefinition): MapInstance?
	local template = MapInstanceService.GetTemplate(mapDef)
	if template == nil then
		return nil
	end

	local slot: number? = nil
	for index = 1, RoomConfig.MaxRooms do
		if usedSlots[index] ~= true then
			slot = index
			break
		end
	end
	if slot == nil then
		return nil
	end

	local offset = slotOffset(slot)
	local clone = template:Clone() :: Model
	clone:PivotTo(clone:GetPivot() + offset)
	clone:SetAttribute("MapId", mapDef.Id)
	clone:SetAttribute("MapOffset", offset)
	CollectionService:AddTag(clone, RoomConfig.MapTag)
	clone.Parent = mapFolder()

	usedSlots[slot] = true
	local instance: MapInstance = {
		model = clone,
		mapDef = mapDef,
		offset = offset,
		slot = slot,
	}
	instances[clone] = instance
	return instance
end

function MapInstanceService.Release(instance: MapInstance)
	if instances[instance.model] == nil then
		return
	end
	instances[instance.model] = nil
	usedSlots[instance.slot] = nil
	CollectionService:RemoveTag(instance.model, RoomConfig.MapTag)
	instance.model:Destroy()
end

return MapInstanceService
