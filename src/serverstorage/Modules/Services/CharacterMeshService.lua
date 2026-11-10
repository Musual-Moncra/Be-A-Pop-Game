--!strict

--[[
	CharacterMeshService
	Loads the mesh data of the StarterCharacter MeshParts on the server. A MeshPart synced by
	Rojo keeps its MeshId but has no mesh data, so the poop would be invisible. Each MeshPart
	with an empty MeshSize gets its mesh rebuilt from its MeshId with ApplyMesh, keeping its
	Size and CFrame. Runs before players spawn, and again on every spawned character in case a
	player spawned first.

	API: none (the returned function is spawned by runFramework at Priority 0).
	Dependencies: AssetService, Players, StarterPlayer
]]

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local meshCache: { [string]: MeshPart } = {}

local function loadMesh(meshId: string): MeshPart?
	local cached = meshCache[meshId]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
	end)
	if not ok then
		warn(string.format("[CharacterMesh] %s could not load: %s", meshId, tostring(result)))
		return nil
	end
	meshCache[meshId] = result
	return result
end

local function repair(root: Instance)
	for _, part in root:GetDescendants() do
		if part:IsA("MeshPart") and part.MeshSize == Vector3.zero and part.MeshId ~= "" then
			local source = loadMesh(part.MeshId)
			if source ~= nil then
				local size, cframe = part.Size, part.CFrame
				part:ApplyMesh(source)
				part.Size = size
				part.CFrame = cframe
			end
		end
	end
end

return function()
	local starter = StarterPlayer:FindFirstChild("StarterCharacter")
	if starter ~= nil then
		repair(starter)
	end
	local function watch(plr: Player)
		plr.CharacterAdded:Connect(repair)
		if plr.Character ~= nil then
			repair(plr.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
end
