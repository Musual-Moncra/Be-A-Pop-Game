--!strict

--[[
	RunService
	Coordinates map/mode selection, gameplay runs, wall/ceiling surface stains,
	scoring, lifespan countdown, and reward payout.

	API:
		RunService.StartRun(plr: Player): boolean
		RunService.EndRun(plr: Player, outOfTime: boolean)
		RunService.IsPlayerInRun(plr: Player): boolean
		RunService.GetRun(plr: Player): ActiveRun?
		RunService.SelectRun(plr: Player, mapId: string, modeId: string): boolean
		RunService.GetSelection(plr: Player): { mapId: string, modeId: string }

	Dependencies:
		DataService, UpgradeService, GameConfig, UpgradeConfig, MapConfig,
		ModeConfig, RunConfig, Net, Trove
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Services = ServerStorage.Modules.Services
local DataService = require(Services.DataService)
local UpgradeService = require(Services.UpgradeService)

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Config.UpgradeConfig)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type ActiveRun = {
	player: Player,
	trove: any,
	mapId: string,
	modeId: string,
	timeLeft: number,
	elapsedTime: number,
	score: number,
	visitedCells: { [string]: boolean },
	stainParts: { BasePart },
	stainFolder: Folder,
	stainTimer: number,
	syncTimer: number,
	active: boolean,
}

local RunService = {}

local activeRuns: { [Player]: ActiveRun } = {}
local portalDebounce: { [Player]: number } = {}
local playerSelections: { [Player]: { mapId: string, modeId: string } } = {}

local function getUpgradeLevel(plr: Player, id: string): number
	local data = DataService.Get(plr)
	if data == nil or data.Upgrades == nil then
		return 0
	end
	return data.Upgrades[id] or 0
end

local function getGravityUp(character: Model): Vector3
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp.CFrame.UpVector
	end
	local attr = character:GetAttribute("GravityUp")
	if typeof(attr) == "Vector3" and attr.Magnitude > 0.001 then
		return attr.Unit
	end
	return Vector3.yAxis
end

local function getSurfaceCFrame(position: Vector3, normal: Vector3): CFrame
	if math.abs(normal.Y) > 0.999 then
		local sign = math.sign(normal.Y)
		return CFrame.new(position) * CFrame.Angles(if sign < 0 then math.pi else 0, 0, 0)
	else
		local right = normal:Cross(Vector3.yAxis).Unit
		local forward = right:Cross(normal).Unit
		return CFrame.fromMatrix(position, right, normal, forward)
	end
end

local function dropSurfaceStain(run: ActiveRun, character: Model, hrp: BasePart, modelName: string)
	local gravityUp = getGravityUp(character)
	local rayOrigin = hrp.Position + gravityUp * RunConfig.StainRayUpOffset
	local rayDirection = -gravityUp * RunConfig.StainRayLength

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	local mapModel = Workspace:FindFirstChild(modelName)
	if mapModel ~= nil then
		rayParams.FilterDescendantsInstances = { mapModel }
	end

	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
	if rayResult == nil then
		return
	end

	local normal = rayResult.Normal.Unit
	local hitPos = rayResult.Position
	local cellSize = GameConfig.StainCellSize

	local qx = math.floor((hitPos.X + cellSize * 0.5) / cellSize)
	local qy = math.floor((hitPos.Y + cellSize * 0.5) / cellSize)
	local qz = math.floor((hitPos.Z + cellSize * 0.5) / cellSize)
	local nx = math.round(normal.X * 10) / 10
	local ny = math.round(normal.Y * 10) / 10
	local nz = math.round(normal.Z * 10) / 10
	local cellKey = `{qx}:{qy}:{qz}|{nx}:{ny}:{nz}`

	if run.visitedCells[cellKey] then
		return
	end
	run.visitedCells[cellKey] = true
	run.score += 1

	if #run.stainParts >= GameConfig.MaxStainParts then
		local oldest = table.remove(run.stainParts, 1)
		if oldest ~= nil and oldest.Parent ~= nil then
			oldest:Destroy()
		end
	end

	local stainSizeLvl = getUpgradeLevel(run.player, "StainSize")
	local stainSize = UpgradeConfig.GetValue("StainSize", stainSizeLvl)
	local centerPos = hitPos + normal * (RunConfig.StainThickness * 0.5 + RunConfig.StainSurfaceOffset)

	local stain = Instance.new("Part")
	stain.Name = "Stain"
	stain.Anchored = true
	stain.CanCollide = false
	stain.CanTouch = false
	stain.CanQuery = false
	stain.CastShadow = false
	stain.Material = Enum.Material.SmoothPlastic
	stain.Color = RunConfig.StainColor
	stain.Transparency = RunConfig.StainTransparency
	stain.Size = Vector3.new(stainSize, RunConfig.StainThickness, stainSize)
	stain.CFrame = getSurfaceCFrame(centerPos, normal)
	stain.Parent = run.stainFolder

	table.insert(run.stainParts, stain)
end

function RunService.IsPlayerInRun(plr: Player): boolean
	return activeRuns[plr] ~= nil
end

function RunService.GetRun(plr: Player): ActiveRun?
	return activeRuns[plr]
end

function RunService.GetSelection(plr: Player): { mapId: string, modeId: string }
	local selection = playerSelections[plr]
	if selection == nil then
		selection = {
			mapId = MapConfig.DefaultMapId,
			modeId = ModeConfig.DefaultModeId,
		}
		playerSelections[plr] = selection
	end
	return selection
end

function RunService.SelectRun(plr: Player, mapId: string, modeId: string): boolean
	if type(mapId) ~= "string" or type(modeId) ~= "string" then
		return false
	end

	local mapDef = MapConfig.GetMap(mapId)
	local modeDef = ModeConfig.GetMode(modeId)
	if mapDef == nil or not mapDef.Enabled or modeDef == nil then
		return false
	end

	playerSelections[plr] = {
		mapId = mapId,
		modeId = modeId,
	}

	if plr.Parent == Players then
		Net.SelectionSync:FireClient(plr, mapId, modeId)
	end
	return true
end

function RunService.EndRun(plr: Player, _outOfTime: boolean)
	local run = activeRuns[plr]
	if run == nil or not run.active then
		return
	end

	run.active = false
	activeRuns[plr] = nil

	local modeDef = ModeConfig.GetMode(run.modeId)
	local score = run.score
	local coins = if modeDef ~= nil and modeDef.AwardsCoins
		then math.floor(score * GameConfig.CoinsPerScore)
		else 0

	if coins > 0 then
		DataService.AddCoins(plr, coins)
	end

	if plr.Parent == Players then
		Net.RunEnded:FireClient(plr, score, coins)
	end

	if plr.Parent == Players and plr.Character ~= nil then
		local hrp = plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = plr.Character:FindFirstChildOfClass("Humanoid")
		if hrp ~= nil and hum ~= nil and hum.Health > 0 then
			plr.Character:PivotTo(CFrame.new(GameConfig.LobbySpawn))
		end
		UpgradeService.ApplyStats(plr, plr.Character)
	end

	run.trove:Clean()
	run.trove:Destroy()
end

function RunService.StartRun(plr: Player): boolean
	if activeRuns[plr] ~= nil then
		return false
	end

	local character = plr.Character
	if character == nil then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if rootPart == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end

	local selection = RunService.GetSelection(plr)
	local mapDef = MapConfig.GetMap(selection.mapId)
	if mapDef == nil or not mapDef.Enabled then
		mapDef = MapConfig.GetMap(MapConfig.DefaultMapId)
	end
	local modeDef = ModeConfig.GetMode(selection.modeId)
	if modeDef == nil then
		modeDef = ModeConfig.GetMode(ModeConfig.DefaultModeId)
	end
	if mapDef == nil or modeDef == nil then
		return false
	end

	local lifespanLvl = getUpgradeLevel(plr, "Lifespan")
	local initialTimeLeft = if modeDef.UsesTimer
		then UpgradeConfig.GetValue("Lifespan", lifespanLvl)
		else RunConfig.PracticeTimeLeft

	UpgradeService.ApplyStats(plr, character)

	character:PivotTo(CFrame.new(mapDef.Spawn))

	local runTrove = Trove.new()
	local stainFolder = Instance.new("Folder")
	stainFolder.Name = RunConfig.StainFolderPrefix .. plr.Name
	stainFolder.Parent = Workspace
	runTrove:Add(stainFolder)

	local run: ActiveRun = {
		player = plr,
		trove = runTrove,
		mapId = mapDef.Id,
		modeId = modeDef.Id,
		timeLeft = initialTimeLeft,
		elapsedTime = 0,
		score = 0,
		visitedCells = {},
		stainParts = {},
		stainFolder = stainFolder,
		stainTimer = 0,
		syncTimer = 0,
		active = true,
	}
	activeRuns[plr] = run

	Net.RunState:FireClient(plr, GameConfig.RunStates.Running, initialTimeLeft, 0)

	runTrove:Connect(humanoid.Died, function()
		if activeRuns[plr] == run then
			RunService.EndRun(plr, false)
		end
	end)

	task.spawn(function()
		while run.active do
			local dt = task.wait(RunConfig.RunLoopStepInterval)
			if not run.active then
				break
			end

			run.elapsedTime += dt
			if modeDef.UsesTimer then
				run.timeLeft = math.max(0, run.timeLeft - dt)
			end

			run.stainTimer += dt
			run.syncTimer += dt

			local currentChar = plr.Character
			local hrp = if currentChar ~= nil then currentChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local hum = if currentChar ~= nil then currentChar:FindFirstChildOfClass("Humanoid") else nil

			if currentChar == nil or hrp == nil or hum == nil or hum.Health <= 0 then
				RunService.EndRun(plr, false)
				break
			end

			if run.stainTimer >= GameConfig.StainInterval then
				run.stainTimer -= GameConfig.StainInterval
				dropSurfaceStain(run, currentChar, hrp, mapDef.ModelName)
			end

			if run.syncTimer >= RunConfig.RunStateSyncInterval then
				run.syncTimer = 0
				local reportedTime = if modeDef.UsesTimer then run.timeLeft else RunConfig.PracticeTimeLeft
				Net.RunState:FireClient(plr, GameConfig.RunStates.Running, reportedTime, run.score)
			end

			local isTimedOut = (modeDef.UsesTimer and run.timeLeft <= 0)
				or (not modeDef.UsesTimer and modeDef.MaxDuration > 0 and run.elapsedTime >= modeDef.MaxDuration)
			if isTimedOut then
				RunService.EndRun(plr, true)
				break
			end
		end
	end)

	return true
end

local function startNpcPatrol(npcModel: Model, patrolDef: RunConfig.NpcPatrolConfig)
	local startPos = patrolDef.startPos
	local endPos = patrolDef.endPos
	local totalDist = (endPos - startPos).Magnitude
	if totalDist == 0 then
		return
	end
	local travelTime = totalDist / patrolDef.speed

	task.spawn(function()
		local forward = true
		while npcModel.Parent ~= nil do
			local fromPos = if forward then startPos else endPos
			local toPos = if forward then endPos else startPos
			local lookTarget = toPos + (toPos - fromPos).Unit

			local startTime = os.clock()
			while npcModel.Parent ~= nil do
				local elapsed = os.clock() - startTime
				local alpha = math.clamp(elapsed / travelTime, 0, 1)
				local currentPos = fromPos:Lerp(toPos, alpha)
				local rotCFrame = CFrame.lookAt(currentPos, Vector3.new(lookTarget.X, currentPos.Y, lookTarget.Z))
				npcModel:PivotTo(rotCFrame)

				if alpha >= 1 then
					break
				end
				task.wait(RunConfig.RunLoopStepInterval)
			end

			forward = not forward
			task.wait(RunConfig.NpcTurnaroundPause)
		end
	end)
end

local function setupNpcsForMap(mapDef: MapConfig.MapDefinition)
	local mapModel = Workspace:WaitForChild(mapDef.ModelName, RunConfig.InstanceWaitTimeout)
	if mapModel == nil then
		return
	end
	local npcsFolder = mapModel:WaitForChild("NPCs", RunConfig.InstanceWaitTimeout)
	if npcsFolder == nil then
		return
	end

	local patrols = RunConfig.NpcPatrols[mapDef.Id]
	if patrols == nil then
		return
	end

	for _, patrolDef in patrols do
		local npcModel = npcsFolder:FindFirstChild(patrolDef.name) :: Model?
		if npcModel ~= nil and npcModel:IsA("Model") then
			startNpcPatrol(npcModel, patrolDef)
		end
	end
end

local function setupAllNpcs()
	for _, mapDef in MapConfig.Maps do
		if mapDef.Enabled then
			task.spawn(setupNpcsForMap, mapDef)
		end
	end
end

local function setupPortal()
	local lobby = Workspace:WaitForChild("Lobby", RunConfig.InstanceWaitTimeout)
	if lobby == nil then
		return
	end
	local portal = lobby:WaitForChild("Portal", RunConfig.InstanceWaitTimeout) :: BasePart?
	if portal == nil then
		return
	end

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		if character == nil then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil then
			return
		end

		local now = os.clock()
		local lastTouch = portalDebounce[player] or 0
		if now - lastTouch < RunConfig.PortalTouchDebounce then
			return
		end
		portalDebounce[player] = now

		if activeRuns[player] == nil then
			RunService.StartRun(player)
		end
	end)
end

local function onPlayerAdded(plr: Player)
	playerSelections[plr] = {
		mapId = MapConfig.DefaultMapId,
		modeId = ModeConfig.DefaultModeId,
	}
	Net.SelectionSync:FireClient(plr, MapConfig.DefaultMapId, ModeConfig.DefaultModeId)
end

task.spawn(setupPortal)
task.spawn(setupAllNpcs)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Lobby" then
		task.spawn(setupPortal)
	else
		for _, mapDef in MapConfig.Maps do
			if mapDef.Enabled and child.Name == mapDef.ModelName then
				task.spawn(setupNpcsForMap, mapDef)
			end
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

Net.StartRun.OnServerEvent:Connect(function(plr)
	if activeRuns[plr] == nil then
		RunService.StartRun(plr)
	end
end)

Net.SelectRun.OnServerEvent:Connect(function(plr, mapId, modeId)
	RunService.SelectRun(plr, mapId, modeId)
end)

Players.PlayerRemoving:Connect(function(plr)
	portalDebounce[plr] = nil
	playerSelections[plr] = nil
	local run = activeRuns[plr]
	if run ~= nil then
		run.active = false
		activeRuns[plr] = nil
		run.trove:Clean()
		run.trove:Destroy()
	end
end)

return RunService
