--!strict

--[[
	ContentCheckService
	Studio-only sanity check for content owned by designers, animators and balance. On server start
	it compares the Config modules with the instances in the Assets folders and warns about
	every mismatch in the Output window, so nobody has to read code to find a typo.
	Does nothing in a live server.

	Checks: every enabled map has its template, spawn inside the map, its patrol NPCs and valid
	ObjectType attributes on Props; every sound key has its Sound template; room sizes and default
	are valid; pet MapIds point at real maps; pet follower models that are missing or unnamed are
	listed as notes; CharacterConfig.RootWidth matches the StarterCharacter. Ids still at 0, empty
	animations and empty sounds are listed as notes.

	Dependencies: ServerStorage.Assets, ReplicatedStorage.Assets, ConfigLookup, AssetConfig,
	MapConfig, MonetizationConfig, PetConfig, PotionConfig, RoomConfig, RunConfig, SoundConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StudioRunService = game:GetService("RunService")

local Config = ReplicatedStorage.Modules.Config
local AssetConfig = require(Config.AssetConfig)
local CharacterConfig = require(Config.CharacterConfig)
local MapConfig = require(Config.MapConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local PetConfig = require(Config.PetConfig)
local PotionConfig = require(Config.PotionConfig)
local RoomConfig = require(Config.RoomConfig)
local RunConfig = require(Config.RunConfig)
local SoundConfig = require(Config.SoundConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)

local problems: { string } = {}
local notes: { string } = {}

local function problem(text: string, ...: any)
	table.insert(problems, string.format(text, ...))
end

local function checkMap(mapDef: any, maps: Instance)
	local template = maps:FindFirstChild(mapDef.ModelName)
	if template == nil or not template:IsA("Model") then
		problem("Map %s: no Model named %s in ServerStorage.Assets.Maps", mapDef.Id, mapDef.ModelName)
		return
	end

	local center, size = template:GetBoundingBox()
	local spawnLocal = center:PointToObjectSpace(mapDef.Spawn)
	if math.abs(spawnLocal.X) > size.X / 2 or math.abs(spawnLocal.Z) > size.Z / 2 then
		problem("Map %s: Spawn %s is outside the map", mapDef.Id, tostring(mapDef.Spawn))
	end

	local npcFolder = template:FindFirstChild("NPCs")
	for _, patrol in RunConfig.NpcPatrols[mapDef.Id] or {} do
		if npcFolder == nil or npcFolder:FindFirstChild(patrol.name) == nil then
			problem("Map %s: patrol NPC %s is not in the NPCs folder", mapDef.Id, patrol.name)
		end
	end

	local props = template:FindFirstChild("Props")
	if props == nil then
		problem("Map %s: no Props folder, nothing can be soiled", mapDef.Id)
		return
	end
	for _, prop in props:GetChildren() do
		local objectType = prop:GetAttribute("ObjectType")
		if objectType ~= nil and ConfigLookup.GetObject(objectType) == nil then
			problem(
				"Map %s: prop %s has unknown ObjectType %s (add it to ObjectConfig)",
				mapDef.Id,
				prop.Name,
				objectType
			)
		end
	end
end

local function run()
	local assets = ServerStorage:FindFirstChild("Assets")
	local maps = if assets ~= nil then assets:FindFirstChild("Maps") else nil
	if maps == nil then
		problem("ServerStorage.Assets.Maps is missing")
	else
		for _, mapDef in MapConfig.Maps do
			if mapDef.Enabled then
				checkMap(mapDef, maps)
			end
		end
	end

	local sounds = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Sounds")
	for key, definition in SoundConfig.Sfx do
		if definition.Asset == "" then
			table.insert(notes, "Sound " .. key .. " has no asset yet")
		elseif sounds == nil or sounds:FindFirstChild(definition.Asset) == nil then
			problem("Sound %s: no Sound named %s in ReplicatedStorage.Assets.Sounds", key, definition.Asset)
		end
	end

	local character = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	local characterRoot = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if characterRoot ~= nil and math.abs(characterRoot.Size.X - CharacterConfig.RootWidth) > 1e-3 then
		problem("CharacterConfig.RootWidth should be %f to match the StarterCharacter", characterRoot.Size.X)
	end

	if table.find(RoomConfig.PlayerOptions, RoomConfig.DefaultMaxPlayers) == nil then
		problem("RoomConfig.DefaultMaxPlayers %d is not in PlayerOptions", RoomConfig.DefaultMaxPlayers)
	end

	local replicatedAssets = ReplicatedStorage:FindFirstChild("Assets")
	local assetModels = if replicatedAssets ~= nil then replicatedAssets:FindFirstChild("Models") else nil
	local petModels = if assetModels ~= nil then assetModels:FindFirstChild("Pets") else nil

	for _, pet in PetConfig.Pets do
		if pet.MapId ~= "" and ConfigLookup.GetMap(pet.MapId) == nil then
			problem("Pet %s points at unknown map %s", pet.Id, pet.MapId)
		end
		if pet.ModelName == "" then
			table.insert(notes, "Pet " .. pet.Id .. " has no ModelName")
		elseif petModels == nil or petModels:FindFirstChild(pet.ModelName) == nil then
			table.insert(notes, "Pet model missing: " .. pet.ModelName)
		end
	end
	if PetConfig.BaseSlots < 1 then
		problem("PetConfig.BaseSlots must be at least 1")
	end

	for name, id in AssetConfig.Animations do
		if id == "" then
			table.insert(notes, "Animation " .. name .. " has no id yet")
		end
	end
	local missingIds = {}
	for key, pass in MonetizationConfig.Gamepasses do
		if pass.Id == 0 then
			table.insert(missingIds, key)
		end
	end
	for _, pack in MonetizationConfig.DevProducts.GemPacks do
		if pack.Id == 0 then
			table.insert(missingIds, pack.DisplayName)
		end
	end
	for _, pack in MonetizationConfig.DevProducts.CoinPacks do
		if pack.Id == 0 then
			table.insert(missingIds, pack.DisplayName)
		end
	end
	for _, tier in MonetizationConfig.DevProducts.Revive do
		if tier.Id == 0 then
			table.insert(missingIds, tier.DisplayName)
		end
	end
	if MonetizationConfig.DevProducts.StainBomb.Id == 0 then
		table.insert(missingIds, MonetizationConfig.DevProducts.StainBomb.DisplayName)
	end
	if MonetizationConfig.DevProducts.NewbiePack.Id == 0 then
		table.insert(missingIds, MonetizationConfig.DevProducts.NewbiePack.DisplayName)
	end
	for _, potion in PotionConfig.Potions do
		if potion.ProductId == 0 then
			table.insert(missingIds, potion.DisplayName)
		end
	end
	table.sort(missingIds)
	if #missingIds > 0 then
		table.insert(notes, "Product/gamepass Ids still 0: " .. table.concat(missingIds, ", "))
	end

	for _, text in problems do
		warn("[ContentCheck] " .. text)
	end
	print(string.format("[ContentCheck] %d problems, %d notes", #problems, #notes))
	if #notes > 0 then
		print("[ContentCheck] Notes: " .. table.concat(notes, "; "))
	end
end

if StudioRunService:IsStudio() then
	task.defer(run)
end

return {}
