--!strict

--[[
	RunService
	Owns active runs: lifespan, staining, area scoring, object soiling, NPC catches,
	timed bonuses, rewards and the run result packet.

	API:
		RunService.StartRun(plr: Player): boolean
		RunService.EndRun(plr: Player, outOfTime: boolean)
		RunService.IsPlayerInRun(plr: Player): boolean
		RunService.GetRun(plr: Player): ActiveRun?

	Dependencies:
		DataService, UpgradeService, MapService, RunEvents, PowerupService?, QuestService?,
		ConfigLookup, GameConfig, MapConfig, ModeConfig, ObjectConfig, RunConfig, MessageConfig, DataConfig, Net, Trove
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Services = ServerStorage.Modules.Services
local DataService = require(Services.DataService)
local UpgradeService = require(Services.UpgradeService)
local MapService = require(Services.MapService)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local ObjectConfig = require(ReplicatedStorage.Modules.Config.ObjectConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Trove = require(ReplicatedStorage.Packages.Trove)

local DataConfig = require(script.Parent.Parent.Config.DataConfig)

export type ActiveRun = {
	player: Player,
	trove: any,
	mapDef: ConfigLookup.MapDefinition,
	modeDef: ConfigLookup.ModeDefinition,
	mapModel: Model?,
	hasTimer: boolean,
	timeLeft: number,
	elapsedTime: number,
	score: number,
	visitedCells: { [string]: boolean },
	objectStains: { [Model]: number },
	objectsSoiled: number,
	stainParts: { BasePart },
	stainFolder: Folder,
	stainTimer: number,
	syncTimer: number,
	npcCooldown: number,
	targetReached: boolean,
	powerupsStarted: boolean,
	questsStarted: boolean,
	active: boolean,
}

local RunService = {}

local activeRuns: { [Player]: ActiveRun } = {}
local portalDebounce: { [Player]: number } = {}

local function optionalRequire(name: string): any
	local module = Services:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn(`{name} failed to load: {result}`)
		return nil
	end
	return result
end

local PowerupService = optionalRequire("PowerupService")
local QuestService = optionalRequire("QuestService")

local function getUpgradeValue(plr: Player, id: string): number
	local data = DataService.Get(plr)
	local level = 0
	if data ~= nil and data.Upgrades ~= nil then
		level = data.Upgrades[id] or 0
	end
	return ConfigLookup.GetUpgradeValue(id, level)
end

local function getMultipliers(plr: Player): { Speed: number, StainSize: number, Points: number }
	local defaults = { Speed = 1, StainSize = 1, Points = 1 }
	if PowerupService == nil then
		return defaults
	end
	local ok, result = pcall(PowerupService.GetMultipliers, plr)
	if not ok or type(result) ~= "table" then
		return defaults
	end
	return {
		Speed = tonumber(result.Speed) or 1,
		StainSize = tonumber(result.StainSize) or 1,
		Points = tonumber(result.Points) or 1,
	}
end

local function startPowerups(run: ActiveRun): boolean
	if PowerupService == nil or not run.modeDef.PowerupsEnabled or run.mapModel == nil then
		return false
	end
	local ok = pcall(PowerupService.StartRun, run.player, run.mapModel, run.modeDef)
	return ok
end

local function stopPowerups(plr: Player)
	if PowerupService == nil then
		return
	end
	pcall(PowerupService.StopRun, plr)
end

local function startQuests(run: ActiveRun): boolean
	if QuestService == nil then
		return false
	end
	local ok = pcall(QuestService.StartRun, run.player, run.mapDef, run.modeDef)
	return ok
end

local function finishQuests(plr: Player): any
	if QuestService == nil then
		return nil
	end
	local ok, result = pcall(QuestService.FinishRun, plr)
	if not ok or type(result) ~= "table" then
		return nil
	end
	return result
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

local function findObjectType(hit: BasePart, mapModel: Model): (Model?, string?)
	local props = mapModel:FindFirstChild("Props")
	if props == nil then
		return nil, nil
	end
	local current: Instance? = hit
	while current ~= nil and current ~= props do
		if current.Parent == props and current:IsA("Model") then
			local objectType = current:GetAttribute("ObjectType")
			if typeof(objectType) == "string" and ConfigLookup.GetObject(objectType) ~= nil then
				return current, objectType
			end
			return nil, nil
		end
		current = current.Parent
	end
	return nil, nil
end

local function addStain(run: ActiveRun, position: Vector3, normal: Vector3, stainSize: number)
	if #run.stainParts >= GameConfig.MaxStainParts then
		local oldest = table.remove(run.stainParts, 1)
		if oldest ~= nil and oldest.Parent ~= nil then
			oldest:Destroy()
		end
	end

	local centerPos = position + normal * (RunConfig.StainThickness * 0.5 + RunConfig.StainSurfaceOffset)
	local stain = Instance.new("Part")
	stain.Name = "Stain"
	stain.Anchored = true
	stain.CanCollide = false
	stain.CanTouch = false
	stain.CanQuery = false
	stain.CastShadow = false
	stain.Material = RunConfig.StainMaterial
	stain.Color = RunConfig.StainColor
	stain.Transparency = RunConfig.StainTransparency
	stain.Size = Vector3.new(stainSize, RunConfig.StainThickness, stainSize)
	stain.CFrame = getSurfaceCFrame(centerPos, normal)
	stain.Parent = run.stainFolder

	table.insert(run.stainParts, stain)
end

local function scoreStain(run: ActiveRun, hitPart: BasePart, stainSize: number)
	local multipliers = getMultipliers(run.player)
	local objectModel, objectType = nil, nil
	if run.mapModel ~= nil then
		objectModel, objectType = findObjectType(hitPart, run.mapModel)
	end

	local objectDef = if objectType ~= nil then ConfigLookup.GetObject(objectType) else nil
	local multiplier = if objectDef ~= nil then objectDef.PointsMultiplier else ObjectConfig.SurfacePointsMultiplier

	local area = stainSize * stainSize
	local points = area * GameConfig.PointsPerStud * multiplier * multipliers.Points
	run.score += points
	RunEvents.Stained:Fire(run.player, points, objectType)

	if objectModel == nil or objectDef == nil then
		return
	end

	local count = (run.objectStains[objectModel] or 0) + 1
	run.objectStains[objectModel] = count

	local step =
		math.clamp(math.ceil(count / objectDef.StainsToSoil * ObjectConfig.TintSteps), 1, ObjectConfig.TintSteps)
	Net.ObjectStained:FireClient(run.player, objectModel, step)

	if count == objectDef.StainsToSoil then
		run.score += objectDef.SoilBonus
		run.objectsSoiled += 1
		Net.ObjectSoiled:FireClient(run.player, objectModel, objectDef.SoilBonus)
		RunEvents.ObjectSoiled:Fire(run.player, objectType, objectDef.SoilBonus)
	end
end

local function dropSurfaceStain(run: ActiveRun, character: Model, hrp: BasePart)
	if run.mapModel == nil then
		return
	end

	local gravityUp = getGravityUp(character)
	local rayOrigin = hrp.Position + gravityUp * RunConfig.StainRayUpOffset
	local rayDirection = -gravityUp * RunConfig.StainRayLength

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { run.mapModel }

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

	local multipliers = getMultipliers(run.player)
	local stainSize = getUpgradeValue(run.player, "StainSize") * multipliers.StainSize
	addStain(run, hitPos, normal, stainSize)
	scoreStain(run, rayResult.Instance, stainSize)
end

local function checkNpcCatch(run: ActiveRun, hrp: BasePart)
	if not run.modeDef.NpcsEnabled or run.npcCooldown > 0 or run.mapModel == nil then
		return
	end
	local npcsFolder = run.mapModel:FindFirstChild("NPCs")
	if npcsFolder == nil then
		return
	end

	for _, npc in npcsFolder:GetChildren() do
		if npc:IsA("Model") then
			local offset = npc:GetPivot().Position - hrp.Position
			if offset.Magnitude <= RunConfig.NpcCatchRadius then
				run.npcCooldown = RunConfig.NpcCatchCooldown
				if run.hasTimer then
					run.timeLeft = math.max(0, run.timeLeft - RunConfig.NpcCatchTimePenalty)
				end
				Net.NpcCaught:FireClient(run.player, RunConfig.NpcCatchTimePenalty)
				return
			end
		end
	end
end

function RunService.IsPlayerInRun(plr: Player): boolean
	return activeRuns[plr] ~= nil
end

function RunService.GetRun(plr: Player): ActiveRun?
	return activeRuns[plr]
end

function RunService.EndRun(plr: Player, outOfTime: boolean)
	local run = activeRuns[plr]
	if run == nil or not run.active then
		return
	end

	run.active = false
	activeRuns[plr] = nil

	if run.powerupsStarted then
		stopPowerups(plr)
	end

	local questResult = if run.questsStarted then finishQuests(plr) else nil
	local questCoins = if type(questResult) == "table" then tonumber(questResult.Coins) or 0 else 0
	local questGems = if type(questResult) == "table" then tonumber(questResult.Gems) or 0 else 0
	local questsCompleted = if type(questResult) == "table" then tonumber(questResult.Completed) or 0 else 0

	local modeDef = run.modeDef
	local mapDef = run.mapDef
	local score = math.floor(run.score)
	local baseCoins = 0
	local xp = 0
	local targetReached = run.targetReached

	if modeDef.RewardMultiplier > 0 then
		local coinBonus = getUpgradeValue(plr, "CoinBonus")
		baseCoins = math.floor(
			score * GameConfig.CoinsPerPoint * mapDef.RewardMultiplier * modeDef.RewardMultiplier * (1 + coinBonus / 100)
		)
		xp = math.floor(score * GameConfig.XpPerPoint * mapDef.RewardMultiplier * modeDef.RewardMultiplier)
	end

	local bonusCoins = if targetReached then modeDef.TargetBonusCoins else 0
	local bonusGems = if targetReached then modeDef.TargetBonusGems else 0

	DataService.RecordRun(plr, score)
	if run.objectsSoiled > 0 then
		DataService.IncrementStat(plr, "ObjectsSoiled", run.objectsSoiled)
	end
	if baseCoins + bonusCoins > 0 then
		DataService.AddCoins(plr, baseCoins + bonusCoins)
	end

	local levelsGained = if xp > 0 then DataService.AddXp(plr, xp) else 0
	local levelGems = levelsGained * GameConfig.GemsPerLevelUp
	if levelGems + bonusGems > 0 then
		DataService.AddGems(plr, levelGems + bonusGems)
	end

	local data = DataService.Get(plr)
	local newLevel = if data ~= nil then data.Level else DataConfig.Template.Level
	if levelsGained > 0 and plr.Parent == Players then
		Net.Notify:FireClient(plr, "Success", string.format(MessageConfig.LevelUp, newLevel))
	end

	local summary = {
		Score = score,
		Coins = baseCoins + bonusCoins + questCoins,
		Gems = levelGems + bonusGems + questGems,
		Xp = xp,
		MapId = mapDef.Id,
		ModeId = modeDef.Id,
		ObjectsSoiled = run.objectsSoiled,
		TargetReached = targetReached,
		QuestsCompleted = questsCompleted,
		LeveledUp = levelsGained,
		NewLevel = newLevel,
		OutOfTime = outOfTime,
		QuestCoins = questCoins,
		QuestGems = questGems,
		BonusCoins = bonusCoins,
		BonusGems = bonusGems,
	}

	RunEvents.RunEnded:Fire(plr, summary)
	if plr.Parent == Players then
		Net.RunEnded:FireClient(plr, summary)
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

	local selection = MapService.GetSelection(plr)
	local mapDef = ConfigLookup.GetMap(selection.mapId)
	if mapDef == nil or not mapDef.Enabled or not DataService.IsMapUnlocked(plr, selection.mapId) then
		mapDef = ConfigLookup.GetMap(MapConfig.DefaultMapId)
	end
	if mapDef == nil or not mapDef.Enabled then
		return false
	end

	local modeDef = ConfigLookup.GetMode(selection.modeId)
	if modeDef == nil then
		modeDef = ConfigLookup.GetMode(ModeConfig.DefaultModeId)
	end
	if modeDef == nil then
		return false
	end

	local hasTimer = modeDef.Duration ~= -1
	local initialTimeLeft = if modeDef.Duration == 0
		then getUpgradeValue(plr, "Lifespan")
		elseif modeDef.Duration == -1 then RunConfig.PracticeTimeLeft
		else modeDef.Duration

	UpgradeService.ApplyStats(plr, character)
	character:PivotTo(CFrame.new(mapDef.Spawn))

	local mapModel = Workspace:FindFirstChild(mapDef.ModelName) :: Model?

	local runTrove = Trove.new()
	local stainFolder = Instance.new("Folder")
	stainFolder.Name = RunConfig.StainFolderPrefix .. plr.Name
	stainFolder.Parent = Workspace
	runTrove:Add(stainFolder)

	local run: ActiveRun = {
		player = plr,
		trove = runTrove,
		mapDef = mapDef,
		modeDef = modeDef,
		mapModel = mapModel,
		hasTimer = hasTimer,
		timeLeft = initialTimeLeft,
		elapsedTime = 0,
		score = 0,
		visitedCells = {},
		objectStains = {},
		objectsSoiled = 0,
		stainParts = {},
		stainFolder = stainFolder,
		stainTimer = 0,
		syncTimer = 0,
		npcCooldown = 0,
		targetReached = false,
		powerupsStarted = false,
		questsStarted = false,
		active = true,
	}
	activeRuns[plr] = run

	run.powerupsStarted = startPowerups(run)
	run.questsStarted = startQuests(run)

	RunEvents.RunStarted:Fire(plr, mapDef.Id, modeDef.Id)
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
			run.npcCooldown = math.max(0, run.npcCooldown - dt)
			if run.hasTimer then
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

			local multipliers = getMultipliers(plr)
			local walkSpeed = getUpgradeValue(plr, "Speed") * multipliers.Speed
			if hum.WalkSpeed ~= walkSpeed then
				hum.WalkSpeed = walkSpeed
			end

			if run.stainTimer >= GameConfig.StainInterval then
				run.stainTimer -= GameConfig.StainInterval
				dropSurfaceStain(run, currentChar, hrp)
			end

			checkNpcCatch(run, hrp)

			if not run.targetReached and modeDef.TargetScore > 0 and run.score >= modeDef.TargetScore then
				run.targetReached = true
				Net.Notify:FireClient(plr, "Success", MessageConfig.TargetReached)
			end

			if run.syncTimer >= RunConfig.RunStateSyncInterval then
				run.syncTimer = 0
				local reportedTime = if run.hasTimer then run.timeLeft else RunConfig.PracticeTimeLeft
				Net.RunState:FireClient(plr, GameConfig.RunStates.Running, reportedTime, math.floor(run.score))
			end

			local isTimedOut = (run.hasTimer and run.timeLeft <= 0)
				or (not run.hasTimer and modeDef.MaxDuration > 0 and run.elapsedTime >= modeDef.MaxDuration)
			if isTimedOut then
				RunService.EndRun(plr, true)
				break
			end
		end
	end)

	return true
end

local function startNpcPatrol(npcModel: Model, patrolDef: any)
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

local function setupNpcsForMap(mapDef: ConfigLookup.MapDefinition)
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
	for _, mapDef in ConfigLookup.GetSortedMaps() do
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

RunEvents.TimeBonus:Connect(function(plr: Player, seconds: number)
	local run = activeRuns[plr]
	if run == nil or not run.active or not run.hasTimer then
		return
	end
	run.timeLeft += seconds
end)

task.spawn(setupPortal)
task.spawn(setupAllNpcs)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Lobby" then
		task.spawn(setupPortal)
	else
		for _, mapDef in ConfigLookup.GetSortedMaps() do
			if mapDef.Enabled and child.Name == mapDef.ModelName then
				task.spawn(setupNpcsForMap, mapDef)
			end
		end
	end
end)

Net.StartRun.OnServerEvent:Connect(function(plr)
	if activeRuns[plr] == nil then
		RunService.StartRun(plr)
	end
end)

Net.LeaveRun.OnServerEvent:Connect(function(plr)
	RunService.EndRun(plr, false)
end)

Players.PlayerRemoving:Connect(function(plr)
	portalDebounce[plr] = nil
	local run = activeRuns[plr]
	if run ~= nil then
		run.active = false
		activeRuns[plr] = nil
		if run.powerupsStarted then
			stopPowerups(plr)
		end
		run.trove:Clean()
		run.trove:Destroy()
	end
end)

return RunService
