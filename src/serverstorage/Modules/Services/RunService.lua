--!strict

--[[
	RunService
	Owns active runs: lifespan, staining, area scoring, object soiling, NPC catches,
	timed bonuses, rewards and the run result packet. Also drives the lobby portal and
	the NPC patrols.

	Every active run and every NPC patrol is advanced by one shared Heartbeat stepper at
	RunConfig.RunLoopStepInterval, instead of one thread per run and per NPC. The remotes
	are bound in Remotes.RunRemotes.

	API:
		RunService.StartRun(plr: Player): boolean
		RunService.EndRun(plr: Player, outOfTime: boolean)
		RunService.IsPlayerInRun(plr: Player): boolean
		RunService.GetRun(plr: Player): ActiveRun?

	Dependencies:
		DataService, UpgradeService, MapService, PowerupService, QuestService, MonetizationService,
		RunEvents, Outbound, ConfigLookup, GameConfig, MapConfig, ModeConfig, ObjectConfig,
		MonetizationConfig, RunConfig, MessageConfig, DataConfig, Trove
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Heartbeat = game:GetService("RunService").Heartbeat

local Services = ServerStorage.Modules.Services
local DataService = require(Services.DataService)
local UpgradeService = require(Services.UpgradeService)
local MapService = require(Services.MapService)
local PowerupService = require(Services.PowerupService)
local QuestService = require(Services.QuestService)
local MonetizationService = require(Services.MonetizationService)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local DataConfig = require(ServerStorage.Modules.Config.DataConfig)

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local MapConfig = require(ReplicatedStorage.Modules.Config.MapConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local ModeConfig = require(ReplicatedStorage.Modules.Config.ModeConfig)
local MonetizationConfig = require(ReplicatedStorage.Modules.Config.MonetizationConfig)
local ObjectConfig = require(ReplicatedStorage.Modules.Config.ObjectConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type ActiveRun = {
	player: Player,
	trove: any,
	mapDef: ConfigLookup.MapDefinition,
	modeDef: ConfigLookup.ModeDefinition,
	mapModel: Model?,
	npcsFolder: Instance?,
	rayParams: RaycastParams,
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
	reviveDeadline: number,
	active: boolean,
}

type Patrol = {
	model: Model,
	fromPos: Vector3,
	toPos: Vector3,
	travelTime: number,
	startedAt: number,
	pausedUntil: number,
}

local RunService = {}

local activeRuns: { [Player]: ActiveRun } = {}
local portalDebounce: { [Player]: number } = {}
local patrols: { [Model]: Patrol } = {}
local stepAccumulator = 0
local reviveEnabled = ConfigLookup.IsReviveAvailable()

local function getUpgradeValue(plr: Player, id: string): number
	local data = DataService.Get(plr)
	local level = if data ~= nil and data.Upgrades ~= nil then data.Upgrades[id] or 0 else 0
	return ConfigLookup.GetUpgradeValue(id, level)
end

local function getSurfaceCFrame(position: Vector3, normal: Vector3): CFrame
	if math.abs(normal.Y) > 0.999 then
		return CFrame.new(position) * CFrame.Angles(if normal.Y < 0 then math.pi else 0, 0, 0)
	end
	local right = normal:Cross(Vector3.yAxis).Unit
	local forward = right:Cross(normal).Unit
	return CFrame.fromMatrix(position, right, normal, forward)
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
		if oldest ~= nil then
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

local function scoreStain(run: ActiveRun, hitPart: BasePart, stainSize: number, pointsMultiplier: number)
	local objectModel, objectType = nil, nil
	if run.mapModel ~= nil then
		objectModel, objectType = findObjectType(hitPart, run.mapModel)
	end

	local objectDef = if objectType ~= nil then ConfigLookup.GetObject(objectType) else nil
	local multiplier = if objectDef ~= nil then objectDef.PointsMultiplier else ObjectConfig.SurfacePointsMultiplier

	local points = stainSize * stainSize * GameConfig.PointsPerStud * multiplier * pointsMultiplier
	run.score += points
	RunEvents.Stained:Fire(run.player, points, objectType)

	if objectModel == nil or objectDef == nil then
		return
	end

	local count = (run.objectStains[objectModel] or 0) + 1
	run.objectStains[objectModel] = count

	local tintStep =
		math.clamp(math.ceil(count / objectDef.StainsToSoil * ObjectConfig.TintSteps), 1, ObjectConfig.TintSteps)
	Outbound.ObjectStained(run.player, objectModel, tintStep)

	if count == objectDef.StainsToSoil then
		run.score += objectDef.SoilBonus
		run.objectsSoiled += 1
		Outbound.ObjectSoiled(run.player, objectModel, objectDef.SoilBonus)
		RunEvents.ObjectSoiled:Fire(run.player, objectType, objectDef.SoilBonus)
	end
end

local function soilObject(run: ActiveRun, objectModel: Model)
	local objectType = objectModel:GetAttribute("ObjectType")
	if typeof(objectType) ~= "string" then
		return
	end
	local objectDef = ConfigLookup.GetObject(objectType)
	if objectDef == nil then
		return
	end
	if (run.objectStains[objectModel] or 0) >= objectDef.StainsToSoil then
		return
	end

	run.objectStains[objectModel] = objectDef.StainsToSoil
	run.score += objectDef.SoilBonus
	run.objectsSoiled += 1
	Outbound.ObjectStained(run.player, objectModel, ObjectConfig.TintSteps)
	Outbound.ObjectSoiled(run.player, objectModel, objectDef.SoilBonus)
	RunEvents.ObjectSoiled:Fire(run.player, objectType, objectDef.SoilBonus)
end

local function cellKey(hitPos: Vector3, normal: Vector3): string
	local cellSize = GameConfig.StainCellSize
	return string.format(
		"%d:%d:%d|%d:%d:%d",
		math.floor(hitPos.X / cellSize + 0.5),
		math.floor(hitPos.Y / cellSize + 0.5),
		math.floor(hitPos.Z / cellSize + 0.5),
		math.round(normal.X * 10),
		math.round(normal.Y * 10),
		math.round(normal.Z * 10)
	)
end

local function dropSurfaceStain(run: ActiveRun, hrp: BasePart, multipliers: PowerupService.Multipliers)
	local gravityUp = hrp.CFrame.UpVector
	local rayResult = Workspace:Raycast(
		hrp.Position + gravityUp * RunConfig.StainRayUpOffset,
		-gravityUp * RunConfig.StainRayLength,
		run.rayParams
	)
	if rayResult == nil then
		return
	end

	local normal = rayResult.Normal
	local key = cellKey(rayResult.Position, normal)
	if run.visitedCells[key] then
		return
	end
	run.visitedCells[key] = true

	local stainSize = getUpgradeValue(run.player, "StainSize") * multipliers.StainSize
	addStain(run, rayResult.Position, normal, stainSize)
	scoreStain(run, rayResult.Instance, stainSize, multipliers.Points)
end

local function checkNpcCatch(run: ActiveRun, hrp: BasePart)
	local npcsFolder = run.npcsFolder
	if not run.modeDef.NpcsEnabled or run.npcCooldown > 0 or npcsFolder == nil then
		return
	end

	local position = hrp.Position
	for _, npc in npcsFolder:GetChildren() do
		if npc:IsA("Model") and (npc:GetPivot().Position - position).Magnitude <= RunConfig.NpcCatchRadius then
			run.npcCooldown = RunConfig.NpcCatchCooldown
			if run.hasTimer then
				run.timeLeft = math.max(0, run.timeLeft - RunConfig.NpcCatchTimePenalty)
			end
			Outbound.NpcCaught(run.player, RunConfig.NpcCatchTimePenalty)
			return
		end
	end
end

local function stepRun(run: ActiveRun, dt: number)
	local plr = run.player
	local modeDef = run.modeDef

	run.elapsedTime += dt
	run.npcCooldown = math.max(0, run.npcCooldown - dt)
	if run.hasTimer then
		run.timeLeft = math.max(0, run.timeLeft - dt)
	end
	run.stainTimer += dt
	run.syncTimer += dt

	local character = plr.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local hum = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if hrp == nil or hum == nil or hum.Health <= 0 then
		RunService.EndRun(plr, false)
		return
	end

	local multipliers = PowerupService.GetMultipliers(plr)
	local walkSpeed = getUpgradeValue(plr, "Speed") * multipliers.Speed
	if hum.WalkSpeed ~= walkSpeed then
		hum.WalkSpeed = walkSpeed
	end

	if run.stainTimer >= GameConfig.StainInterval then
		run.stainTimer -= GameConfig.StainInterval
		dropSurfaceStain(run, hrp, multipliers)
	end

	checkNpcCatch(run, hrp)

	if not run.targetReached and modeDef.TargetScore > 0 and run.score >= modeDef.TargetScore then
		run.targetReached = true
		Outbound.Notify(plr, "Success", MessageConfig.TargetReached)
	end

	if run.syncTimer >= RunConfig.RunStateSyncInterval then
		run.syncTimer = 0
		local reportedTime = if run.hasTimer then run.timeLeft else RunConfig.PracticeTimeLeft
		Outbound.RunState(plr, GameConfig.RunStates.Running, reportedTime, run.score)
	end

	local timedOut = (run.hasTimer and run.timeLeft <= 0)
		or (not run.hasTimer and modeDef.MaxDuration > 0 and run.elapsedTime >= modeDef.MaxDuration)
	if timedOut and run.hasTimer and reviveEnabled and run.reviveDeadline == 0 then
		run.reviveDeadline = run.elapsedTime + MonetizationConfig.ReviveWindow
		RunEvents.TimeUp:Fire(plr)
	end
	if run.reviveDeadline > 0 then
		if run.elapsedTime >= run.reviveDeadline then
			RunService.EndRun(plr, true)
		end
		return
	end
	if timedOut then
		RunService.EndRun(plr, true)
	end
end

local function stepPatrol(patrol: Patrol, now: number)
	if patrol.model.Parent == nil then
		patrols[patrol.model] = nil
		return
	end
	if now < patrol.pausedUntil then
		return
	end

	local alpha = math.clamp((now - patrol.startedAt) / patrol.travelTime, 0, 1)
	local position = patrol.fromPos:Lerp(patrol.toPos, alpha)
	local heading = patrol.toPos - patrol.fromPos
	patrol.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(heading.X, 0, heading.Z)))

	if alpha >= 1 then
		patrol.fromPos, patrol.toPos = patrol.toPos, patrol.fromPos
		patrol.pausedUntil = now + RunConfig.NpcTurnaroundPause
		patrol.startedAt = patrol.pausedUntil
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

	PowerupService.StopRun(plr)
	local questResult = QuestService.FinishRun(plr)

	local modeDef = run.modeDef
	local mapDef = run.mapDef
	local score = math.floor(run.score)
	local baseCoins = 0
	local xp = 0

	local coinMultiplier = MonetizationService.GetCoinMultiplier(plr)
	local gemMultiplier = MonetizationService.GetGemMultiplier(plr)

	if modeDef.RewardMultiplier > 0 then
		local rewardScale = mapDef.RewardMultiplier * modeDef.RewardMultiplier
		local coinBonus = getUpgradeValue(plr, "CoinBonus")
		baseCoins = math.floor(
			score
				* GameConfig.CoinsPerPoint
				* rewardScale
				* (1 + coinBonus / 100)
				* DataService.GetBoostMultiplier(plr, "Coins")
				* coinMultiplier
		)
		xp = math.floor(score * GameConfig.XpPerPoint * rewardScale)
	end

	local bonusCoins = if run.targetReached then math.floor(modeDef.TargetBonusCoins * coinMultiplier) else 0
	local bonusGems = if run.targetReached then math.floor(modeDef.TargetBonusGems * gemMultiplier) else 0
	local questCoins = math.floor(questResult.Coins * coinMultiplier)
	local questGems = math.floor(questResult.Gems * gemMultiplier)

	DataService.RecordRun(plr, score)
	if run.objectsSoiled > 0 then
		DataService.IncrementStat(plr, "ObjectsSoiled", run.objectsSoiled)
	end
	if baseCoins + bonusCoins > 0 then
		DataService.AddCoins(plr, baseCoins + bonusCoins)
	end
	if bonusGems > 0 then
		DataService.AddGems(plr, bonusGems)
	end
	if questCoins > questResult.Coins then
		DataService.AddCoins(plr, questCoins - questResult.Coins)
	end
	if questGems > questResult.Gems then
		DataService.AddGems(plr, questGems - questResult.Gems)
	end

	local levelsGained = DataService.AddXp(plr, xp)
	local data = DataService.Get(plr)
	local newLevel = if data ~= nil then data.Level else DataConfig.Template.Level
	if levelsGained > 0 then
		Outbound.Notify(plr, "Success", string.format(MessageConfig.LevelUp, newLevel))
	end

	local summary = {
		Score = score,
		Coins = baseCoins + bonusCoins + questCoins,
		Gems = levelsGained * GameConfig.GemsPerLevelUp + bonusGems + questGems,
		Xp = xp,
		MapId = mapDef.Id,
		ModeId = modeDef.Id,
		ObjectsSoiled = run.objectsSoiled,
		TargetReached = run.targetReached,
		QuestsCompleted = questResult.Completed,
		QuestCoins = questResult.Coins,
		QuestGems = questResult.Gems,
		BonusCoins = bonusCoins,
		BonusGems = bonusGems,
		LeveledUp = levelsGained,
		NewLevel = newLevel,
		OutOfTime = outOfTime,
	}

	RunEvents.RunEnded:Fire(plr, summary)
	Outbound.RunEnded(plr, summary)

	local character = plr.Character
	if plr.Parent == Players and character ~= nil then
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum ~= nil and hum.Health > 0 then
			character:PivotTo(CFrame.new(GameConfig.LobbySpawn))
		end
		UpgradeService.ApplyStats(plr, character)
	end

	run.trove:Destroy()
end

local function resolveSelection(plr: Player): (ConfigLookup.MapDefinition?, ConfigLookup.ModeDefinition?)
	local selection = MapService.GetSelection(plr)
	local mapDef = ConfigLookup.GetMap(selection.mapId)
	if mapDef == nil or not mapDef.Enabled or not DataService.IsMapUnlocked(plr, selection.mapId) then
		mapDef = ConfigLookup.GetMap(MapConfig.DefaultMapId)
	end
	local modeDef = ConfigLookup.GetMode(selection.modeId) or ConfigLookup.GetMode(ModeConfig.DefaultModeId)
	if mapDef == nil or not mapDef.Enabled then
		return nil, nil
	end
	return mapDef, modeDef
end

function RunService.StartRun(plr: Player): boolean
	if activeRuns[plr] ~= nil then
		return false
	end

	local character = plr.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if character:FindFirstChild("HumanoidRootPart") == nil then
		return false
	end

	local mapDef, modeDef = resolveSelection(plr)
	if mapDef == nil or modeDef == nil then
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

	local stainFolder = runTrove:Add(Instance.new("Folder"))
	stainFolder.Name = RunConfig.StainFolderPrefix .. plr.Name
	stainFolder.Parent = Workspace

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = if mapModel ~= nil then { mapModel } else {}

	local run: ActiveRun = {
		player = plr,
		trove = runTrove,
		mapDef = mapDef,
		modeDef = modeDef,
		mapModel = mapModel,
		npcsFolder = if mapModel ~= nil then mapModel:FindFirstChild("NPCs") else nil,
		rayParams = rayParams,
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
		reviveDeadline = 0,
		active = true,
	}
	activeRuns[plr] = run

	if mapModel ~= nil then
		PowerupService.StartRun(plr, mapModel, modeDef)
	end
	QuestService.StartRun(plr, mapDef, modeDef)

	RunEvents.RunStarted:Fire(plr, mapDef.Id, modeDef.Id)
	Outbound.RunState(plr, GameConfig.RunStates.Running, initialTimeLeft, 0)

	runTrove:Connect(humanoid.Died, function()
		RunService.EndRun(plr, false)
	end)

	return true
end

local function setupNpcsForMap(mapDef: ConfigLookup.MapDefinition)
	local patrolDefs = RunConfig.NpcPatrols[mapDef.Id]
	local mapModel = if patrolDefs ~= nil
		then Workspace:WaitForChild(mapDef.ModelName, RunConfig.InstanceWaitTimeout)
		else nil
	local npcsFolder = if mapModel ~= nil then mapModel:WaitForChild("NPCs", RunConfig.InstanceWaitTimeout) else nil
	if npcsFolder == nil then
		return
	end

	local now = os.clock()
	for _, patrolDef in patrolDefs do
		local model = npcsFolder:FindFirstChild(patrolDef.name)
		local distance = (patrolDef.endPos - patrolDef.startPos).Magnitude
		if model ~= nil and model:IsA("Model") and distance > 0 and patrols[model] == nil then
			patrols[model] = {
				model = model,
				fromPos = patrolDef.startPos,
				toPos = patrolDef.endPos,
				travelTime = distance / patrolDef.speed,
				startedAt = now,
				pausedUntil = 0,
			}
		end
	end
end

local function setupPortal()
	local lobby = Workspace:WaitForChild("Lobby", RunConfig.InstanceWaitTimeout)
	local portal = if lobby ~= nil then lobby:WaitForChild("Portal", RunConfig.InstanceWaitTimeout) else nil
	if portal == nil or not portal:IsA("BasePart") then
		return
	end

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = if character ~= nil then Players:GetPlayerFromCharacter(character) else nil
		if player == nil then
			return
		end
		local now = os.clock()
		if now - (portalDebounce[player] or 0) < RunConfig.PortalTouchDebounce then
			return
		end
		portalDebounce[player] = now
		RunService.StartRun(player)
	end)
end

RunEvents.TimeBonus:Connect(function(plr: Player, seconds: number)
	local run = activeRuns[plr]
	if run ~= nil and run.active and run.hasTimer then
		run.timeLeft += seconds
	end
end)

RunEvents.ReviveActivated:Connect(function(plr: Player, seconds: number)
	local run = activeRuns[plr]
	if run ~= nil and run.active and run.reviveDeadline > 0 then
		run.reviveDeadline = 0
		run.timeLeft += seconds
	end
end)

RunEvents.StainBomb:Connect(function(plr: Player)
	local run = activeRuns[plr]
	if run == nil or not run.active or run.mapModel == nil then
		return
	end

	local character = plr.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if hrp == nil then
		return
	end
	local props = run.mapModel:FindFirstChild("Props")
	if props == nil then
		return
	end

	local position = hrp.Position
	for _, child in props:GetChildren() do
		if child:IsA("Model") and (child:GetPivot().Position - position).Magnitude <= MonetizationConfig.StainBombRadius then
			soilObject(run, child)
		end
	end
end)

Heartbeat:Connect(function(dt)
	stepAccumulator += dt
	if stepAccumulator < RunConfig.RunLoopStepInterval then
		return
	end
	local step = stepAccumulator
	stepAccumulator = 0

	for _, run in activeRuns do
		stepRun(run, step)
	end

	local now = os.clock()
	for _, patrol in patrols do
		stepPatrol(patrol, now)
	end
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Lobby" then
		task.spawn(setupPortal)
		return
	end
	for _, mapDef in ConfigLookup.GetSortedMaps() do
		if mapDef.Enabled and child.Name == mapDef.ModelName then
			task.spawn(setupNpcsForMap, mapDef)
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	portalDebounce[plr] = nil
	local run = activeRuns[plr]
	if run ~= nil then
		run.active = false
		activeRuns[plr] = nil
		PowerupService.StopRun(plr)
		QuestService.FinishRun(plr)
		run.trove:Destroy()
	end
end)

task.spawn(setupPortal)
for _, mapDef in ConfigLookup.GetSortedMaps() do
	if mapDef.Enabled then
		task.spawn(setupNpcsForMap, mapDef)
	end
end

return RunService
