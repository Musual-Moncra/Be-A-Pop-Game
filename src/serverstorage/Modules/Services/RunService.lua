--!strict

--[[
	RunService
	Owns active runs: lifespan, staining, area scoring, object soiling, NPC catches,
	timed bonuses, rewards and the run result packet. Also drives the lobby portal.
	NPC patrols, vision, chase and the catch penalty live in NpcService.

	Every active run and every NPC is advanced by one shared Heartbeat stepper at
	RunConfig.RunLoopStepInterval, instead of one thread per run and per NPC. The remotes
	are bound in Remotes.RunRemotes.

	API:
		RunService.StartRun(plr: Player, instance: MapInstance, modeDef: ModeDefinition): boolean
		RunService.EndRun(plr: Player, outOfTime: boolean)
		RunService.IsPlayerInRun(plr: Player): boolean
		RunService.GetRun(plr: Player): ActiveRun?

	A run always plays in the map copy a room acquired from MapInstanceService: spawn and every
	authored map position are shifted by instance.offset. The spawn region is requested from
	streaming before the character is moved, so the client never lands on a missing floor.

	Dependencies:
		DataService, UpgradeService, PowerupService, PotionService, QuestService, MonetizationService,
		EventService, PetService, GoldenTargetService, RebirthService, NpcService, RunEvents, Outbound, ConfigLookup, GameConfig,
		ObjectConfig, MonetizationConfig, RunConfig, MessageConfig, DataConfig, Trove
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Heartbeat = game:GetService("RunService").Heartbeat

local Services = ServerStorage.Modules.Services
local DataService = require(Services.DataService)
local UpgradeService = require(Services.UpgradeService)
local PetService = require(Services.PetService)
local PowerupService = require(Services.PowerupService)
local PotionService = require(Services.PotionService)
local QuestService = require(Services.QuestService)
local EventService = require(Services.EventService)
local MonetizationService = require(Services.MonetizationService)
local GoldenTargetService = require(Services.GoldenTargetService)
local RebirthService = require(Services.RebirthService)
local NpcService = require(Services.NpcService)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local DataConfig = require(ServerStorage.Modules.Config.DataConfig)

local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local MonetizationConfig = require(ReplicatedStorage.Modules.Config.MonetizationConfig)
local ObjectConfig = require(ReplicatedStorage.Modules.Config.ObjectConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Hitbox = require(ReplicatedStorage.Modules.Shared.Hitbox)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type MapInstance = {
	model: Model,
	mapDef: ConfigLookup.MapDefinition,
	offset: Vector3,
	slot: number,
}

export type ActiveRun = {
	player: Player,
	trove: any,
	mapDef: ConfigLookup.MapDefinition,
	modeDef: ConfigLookup.ModeDefinition,
	mapModel: Model,
	propsFolder: Instance?,
	rayParams: RaycastParams,
	hasTimer: boolean,
	timeLeft: number,
	elapsedTime: number,
	score: number,
	visitedCells: { [number]: boolean },
	stainKeys: { [BasePart]: number },
	stainCells: number,
	objectStains: { [Model]: number },
	objectCache: { [Instance]: Model | false },
	sentTint: { [Model]: number },
	pendingTint: { [Model]: number },
	objectsSoiled: number,
	comboLevel: number,
	comboCells: number,
	comboLastCellTime: number,
	stainParts: { BasePart },
	stainCursor: number,
	stainFolder: Folder,
	stainTimer: number,
	syncTimer: number,
	npcCooldown: number,
	targetReached: boolean,
	reviveDeadline: number,
	active: boolean,
}

local CELL_KEY_OFFSET = 32768
local CELL_KEY_RANGE = 65536
local FACE_COUNT = 6

local RunService = {}

local activeRuns: { [Player]: ActiveRun } = {}
local portalDebounce: { [Player]: number } = {}
local stepAccumulator = 0

local function getUpgradeValue(plr: Player, id: string): number
	local data = DataService.Get(plr)
	local level = if data ~= nil and data.Upgrades ~= nil then data.Upgrades[id] or 0 else 0
	return ConfigLookup.GetUpgradeValue(id, level)
end

local function getStainSize(plr: Player, multipliers: PowerupService.Multipliers): number
	local potionStainMultiplier = PotionService.GetMultiplier(plr, "StainSize")
	return getUpgradeValue(plr, "StainSize") * multipliers.StainSize * potionStainMultiplier
end

local function getSurfaceCFrame(position: Vector3, normal: Vector3): CFrame
	if math.abs(normal.Y) > 0.999 then
		return CFrame.new(position) * CFrame.Angles(if normal.Y < 0 then math.pi else 0, 0, 0)
	end
	local right = normal:Cross(Vector3.yAxis).Unit
	local forward = right:Cross(normal).Unit
	return CFrame.fromMatrix(position, right, normal, forward)
end

local function findObjectType(hit: BasePart, props: Instance?, cache: { [Instance]: Model | false }): (Model?, string?)
	local cached = cache[hit]
	if cached ~= nil then
		if cached == false then
			return nil, nil
		end
		local cachedType = cached:GetAttribute("ObjectType")
		if typeof(cachedType) == "string" then
			return cached, cachedType
		end
		return nil, nil
	end
	if props == nil then
		return nil, nil
	end
	local current: Instance? = hit
	while current ~= nil and current ~= props do
		if current.Parent == props and current:IsA("Model") then
			local objectType = current:GetAttribute("ObjectType")
			if typeof(objectType) == "string" and ConfigLookup.GetObject(objectType) ~= nil then
				cache[hit] = current
				return current, objectType
			end
			cache[hit] = false
			return nil, nil
		end
		current = current.Parent
	end
	cache[hit] = false
	return nil, nil
end

local function addStain(run: ActiveRun, position: Vector3, normal: Vector3, stainSize: number, key: number)
	local centerPos = position + normal * (RunConfig.StainThickness * 0.5 + RunConfig.StainSurfaceOffset)
	local cframe = getSurfaceCFrame(centerPos, normal)
	local size = Vector3.new(stainSize, RunConfig.StainThickness, stainSize)

	local stain: BasePart
	if #run.stainParts >= GameConfig.MaxStainParts then
		run.stainCursor += 1
		if run.stainCursor > #run.stainParts then
			run.stainCursor = 1
		end
		stain = run.stainParts[run.stainCursor]
		local oldKey = run.stainKeys[stain]
		if run.visitedCells[oldKey] then
			run.visitedCells[oldKey] = nil
			run.stainCells -= 1
		end
		if stain.Size ~= size then
			stain.Size = size
		end
		stain.CFrame = cframe
	else
		stain = Instance.new("Part")
		stain.Name = "Stain"
		stain.Anchored = true
		stain.CanCollide = false
		stain.CanTouch = false
		stain.CanQuery = false
		stain.CastShadow = false
		stain.Material = RunConfig.StainMaterial
		stain.Color = RunConfig.StainColor
		stain.Transparency = RunConfig.StainTransparency
		stain.Size = size
		stain.CFrame = cframe
		stain.Parent = run.stainFolder
		table.insert(run.stainParts, stain)
	end
	run.stainKeys[stain] = key
end

local function queueTint(run: ActiveRun, objectModel: Model, step: number)
	if step <= (run.sentTint[objectModel] or 0) then
		return
	end
	run.sentTint[objectModel] = step
	run.pendingTint[objectModel] = step
end

local function flushTints(run: ActiveRun)
	local pending = run.pendingTint
	if next(pending) == nil then
		return
	end
	for objectModel, step in pending do
		Outbound.ObjectStained(run.player, objectModel, step)
	end
	table.clear(pending)
end

local function scoreStain(run: ActiveRun, hitPart: BasePart, stainSize: number, pointsMultiplier: number)
	local objectModel, objectType = findObjectType(hitPart, run.propsFolder, run.objectCache)

	local objectDef = if objectType ~= nil then ConfigLookup.GetObject(objectType) else nil
	local multiplier = if objectDef ~= nil then objectDef.PointsMultiplier else ObjectConfig.SurfacePointsMultiplier
	local eventMultiplier = EventService.GetMultipliers(run.mapDef.Id).Points

	local points = stainSize * stainSize * GameConfig.PointsPerStud * multiplier * pointsMultiplier * eventMultiplier
	run.score += points
	RunEvents.Stained:Fire(run.player, points, objectType)

	local npcBonus = NpcService.SoilFromStain(run.mapModel, hitPart, run.player)
	if npcBonus > 0 then
		RunEvents.ScoreBonus:Fire(run.player, npcBonus, "Npc")
	end

	if objectModel == nil or objectDef == nil then
		return
	end

	local count = (run.objectStains[objectModel] or 0) + 1
	run.objectStains[objectModel] = count

	local tintStep =
		math.clamp(math.ceil(count / objectDef.StainsToSoil * ObjectConfig.TintSteps), 1, ObjectConfig.TintSteps)
	queueTint(run, objectModel, tintStep)

	if count == objectDef.StainsToSoil then
		run.score += objectDef.SoilBonus
		run.objectsSoiled += 1
		Outbound.ObjectSoiled(run.player, objectModel, objectDef.SoilBonus)
		RunEvents.ObjectSoiled:Fire(run.player, objectType, objectDef.SoilBonus)
		RunEvents.TargetSoiled:Fire(run.player, run.mapDef.Id, objectType)
		NpcService.Panic(run.mapModel, run.player, objectModel:GetPivot().Position)
		run.score += GoldenTargetService.Soil(run.player, objectModel, objectDef)
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
	queueTint(run, objectModel, ObjectConfig.TintSteps)
	Outbound.ObjectSoiled(run.player, objectModel, objectDef.SoilBonus)
	RunEvents.ObjectSoiled:Fire(run.player, objectType, objectDef.SoilBonus)
	RunEvents.TargetSoiled:Fire(run.player, run.mapDef.Id, objectType)
	NpcService.Panic(run.mapModel, run.player, objectModel:GetPivot().Position)
	run.score += GoldenTargetService.Soil(run.player, objectModel, objectDef)
end

local function soilPropsInRadius(run: ActiveRun, origin: Vector3, radius: number)
	local props = if run.mapModel ~= nil then run.mapModel:FindFirstChild("Props") else nil
	if props == nil then
		return
	end
	for _, child in props:GetChildren() do
		if child:IsA("Model") and (child:GetPivot().Position - origin).Magnitude <= radius then
			soilObject(run, child)
		end
	end
end

local function faceIndex(normal: Vector3): number
	local x, y, z = math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z)
	if y >= x and y >= z then
		return if normal.Y > 0 then 0 else 1
	elseif x >= z then
		return if normal.X > 0 then 2 else 3
	end
	return if normal.Z > 0 then 4 else 5
end

local function cellKey(hitPos: Vector3, normal: Vector3): number
	local cellSize = GameConfig.StainCellSize
	local x = math.floor(hitPos.X / cellSize + 0.5) + CELL_KEY_OFFSET
	local y = math.floor(hitPos.Y / cellSize + 0.5) + CELL_KEY_OFFSET
	local z = math.floor(hitPos.Z / cellSize + 0.5) + CELL_KEY_OFFSET
	return ((x * CELL_KEY_RANGE + y) * CELL_KEY_RANGE + z) * FACE_COUNT + faceIndex(normal)
end

local function advanceCombo(run: ActiveRun)
	if run.elapsedTime - run.comboLastCellTime >= RunConfig.ComboDecay then
		run.comboLevel = 1
		run.comboCells = 0
	end
	run.comboCells += 1
	if run.comboLevel < RunConfig.ComboMax and run.comboCells >= RunConfig.ComboStep then
		run.comboCells -= RunConfig.ComboStep
		run.comboLevel += 1
	end
	run.comboLastCellTime = run.elapsedTime
end

local function comboMultiplier(run: ActiveRun): number
	return 1 + RunConfig.ComboBonus * (run.comboLevel - 1)
end

local function dropSurfaceStain(run: ActiveRun, hrp: BasePart, multipliers: PowerupService.Multipliers)
	local scale = Hitbox.Scale(hrp)
	local rootCFrame = hrp.CFrame
	local gravityUp = rootCFrame.UpVector
	local origin = Hitbox.Center(rootCFrame, scale) + gravityUp * (RunConfig.StainRayUpOffset * scale)
	local rayResult = Workspace:Raycast(origin, -gravityUp * (RunConfig.StainRayLength * scale), run.rayParams)
	if rayResult == nil then
		return
	end

	local normal = rayResult.Normal
	local key = cellKey(rayResult.Position, normal)
	if run.visitedCells[key] then
		return
	end
	run.visitedCells[key] = true
	run.stainCells += 1
	advanceCombo(run)

	local stainSize = getStainSize(run.player, multipliers)
	addStain(run, rayResult.Position, normal, stainSize, key)
	scoreStain(run, rayResult.Instance, stainSize, multipliers.Points * comboMultiplier(run))
end

local function stepRun(run: ActiveRun, dt: number)
	local plr = run.player
	local modeDef = run.modeDef

	run.elapsedTime += dt
	if run.comboLevel > 1 and run.elapsedTime - run.comboLastCellTime >= RunConfig.ComboDecay then
		run.comboLevel -= 1
		run.comboCells = 0
		run.comboLastCellTime = run.elapsedTime
	end
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
	local potionSpeedMultiplier = PotionService.GetMultiplier(plr, "Speed")
	local walkSpeed = getUpgradeValue(plr, "Speed") * multipliers.Speed * potionSpeedMultiplier
	if math.abs(hum.WalkSpeed - walkSpeed) > 0.01 then
		hum.WalkSpeed = walkSpeed
	end

	if run.stainTimer >= GameConfig.StainInterval then
		run.stainTimer %= GameConfig.StainInterval
		dropSurfaceStain(run, hrp, multipliers)
	end

	NpcService.CheckCatch(run, hrp)
	flushTints(run)

	if not run.targetReached and modeDef.TargetScore > 0 and run.score >= modeDef.TargetScore then
		run.targetReached = true
		Outbound.Notify(plr, "Success", MessageConfig.TargetReached)
	end

	if run.syncTimer >= RunConfig.RunStateSyncInterval then
		run.syncTimer = 0
		local reportedTime = if run.hasTimer then run.timeLeft else RunConfig.PracticeTimeLeft
		Outbound.RunState(plr, GameConfig.RunStates.Running, reportedTime, run.score, run.comboLevel)
	end

	if run.reviveDeadline > 0 and run.timeLeft > MonetizationConfig.ReviveOfferAt then
		run.reviveDeadline = 0
	end
	if
		run.hasTimer
		and run.reviveDeadline == 0
		and run.timeLeft <= MonetizationConfig.ReviveOfferAt
		and MonetizationService.CanRevive(plr)
	then
		run.reviveDeadline = run.elapsedTime + MonetizationConfig.ReviveWindow
		RunEvents.TimeUp:Fire(plr)
	end

	local timedOut = (run.hasTimer and run.timeLeft <= 0)
		or (not run.hasTimer and modeDef.MaxDuration > 0 and run.elapsedTime >= modeDef.MaxDuration)
	if timedOut and (run.reviveDeadline == 0 or run.elapsedTime >= run.reviveDeadline) then
		RunService.EndRun(plr, true)
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
	GoldenTargetService.StopRun(plr)
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
				* PetService.GetMultipliers(plr).Stink
				* RebirthService.GetMultiplier(plr)
		)
		xp = math.floor(score * GameConfig.XpPerPoint * rewardScale)
	end

	local bonusCoins = if run.targetReached then math.floor(modeDef.TargetBonusCoins * coinMultiplier) else 0
	local bonusGems = if run.targetReached then math.floor(modeDef.TargetBonusGems * gemMultiplier) else 0
	local questCoins = math.floor(questResult.Coins * coinMultiplier)
	local questGems = math.floor(questResult.Gems * gemMultiplier)
	local eventGemMultiplier = EventService.GetMultipliers(mapDef.Id).Gems

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

	local baseGems = levelsGained * GameConfig.GemsPerLevelUp + bonusGems
	local eventGems = math.floor(baseGems * (eventGemMultiplier - 1))
	if eventGems > 0 then
		DataService.AddGems(plr, eventGems)
	end

	local summary = {
		Score = score,
		Coins = baseCoins + bonusCoins + questCoins,
		Gems = baseGems + eventGems + questGems,
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
			task.spawn(function()
				pcall(plr.RequestStreamAroundAsync, plr, GameConfig.LobbySpawn)
				if character.Parent ~= nil and not RunService.IsPlayerInRun(plr) then
					character:PivotTo(CFrame.new(GameConfig.LobbySpawn))
				end
			end)
		end
		UpgradeService.ApplyStats(plr, character)
	end

	run.trove:Destroy()
end

function RunService.StartRun(plr: Player, instance: MapInstance, modeDef: ConfigLookup.ModeDefinition): boolean
	if activeRuns[plr] ~= nil then
		return false
	end
	if DataService.Get(plr) == nil then
		Outbound.Notify(plr, "Error", MessageConfig.DataLoading)
		return false
	end

	local mapDef = instance.mapDef
	local mapModel = instance.model
	if mapModel.Parent == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RunUnavailable)
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

	local spawn = mapDef.Spawn + instance.offset
	local hasTimer = modeDef.Duration ~= -1
	local potionLifespanMultiplier = PotionService.GetMultiplier(plr, "Lifespan")
	local initialTimeLeft = if modeDef.Duration == 0
		then getUpgradeValue(plr, "Lifespan") * potionLifespanMultiplier
		elseif modeDef.Duration == -1 then RunConfig.PracticeTimeLeft
		else modeDef.Duration * potionLifespanMultiplier

	UpgradeService.ApplyStats(plr, character)
	pcall(plr.RequestStreamAroundAsync, plr, spawn)
	if plr.Parent ~= Players or character.Parent == nil or mapModel.Parent == nil then
		return false
	end
	character:PivotTo(CFrame.new(spawn))

	GoldenTargetService.StartRun(plr, mapModel)
	local runTrove = Trove.new()

	local stainFolder = runTrove:Add(Instance.new("Folder"))
	stainFolder.Name = RunConfig.StainFolderPrefix .. plr.Name
	stainFolder.Parent = Workspace

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { mapModel }

	local run: ActiveRun = {
		player = plr,
		trove = runTrove,
		mapDef = mapDef,
		modeDef = modeDef,
		mapModel = mapModel,
		propsFolder = mapModel:FindFirstChild("Props"),
		rayParams = rayParams,
		hasTimer = hasTimer,
		timeLeft = initialTimeLeft,
		elapsedTime = 0,
		score = 0,
		visitedCells = {},
		stainKeys = {},
		stainCells = 0,
		objectStains = {},
		objectCache = {},
		sentTint = {},
		pendingTint = {},
		objectsSoiled = 0,
		comboLevel = 1,
		comboCells = 0,
		comboLastCellTime = 0,
		stainParts = {},
		stainCursor = 0,
		stainFolder = stainFolder,
		stainTimer = 0,
		syncTimer = 0,
		npcCooldown = 0,
		targetReached = false,
		reviveDeadline = 0,
		active = true,
	}
	activeRuns[plr] = run

	PowerupService.StartRun(plr, mapModel, modeDef)
	QuestService.StartRun(plr, mapDef, modeDef)

	RunEvents.RunStarted:Fire(plr, mapDef.Id, modeDef.Id, mapModel)
	Outbound.RunState(plr, GameConfig.RunStates.Running, initialTimeLeft, 0, 1)

	runTrove:Connect(humanoid.Died, function()
		RunService.EndRun(plr, false)
	end)

	return true
end

local portalConnection: RBXScriptConnection? = nil

local function setupPortal()
	local lobby = Workspace:WaitForChild("Lobby", RunConfig.InstanceWaitTimeout)
	if lobby == nil then
		return
	end
	local deadline = os.clock() + RunConfig.InstanceWaitTimeout
	local portal = lobby:FindFirstChild("Portal", true)
	while portal == nil and os.clock() < deadline do
		task.wait(RunConfig.PortalFindRetryInterval)
		portal = lobby:FindFirstChild("Portal", true)
	end
	if portal == nil or not portal:IsA("BasePart") then
		return
	end
	if portalConnection ~= nil then
		portalConnection:Disconnect()
	end

	portalConnection = portal.Touched:Connect(function(hit)
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
		Outbound.OpenRoomMenu(player)
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
	if run == nil or not run.active then
		return
	end
	local character = plr.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if hrp == nil then
		return
	end
	local stainSize = getStainSize(plr, PowerupService.GetMultipliers(plr))
	soilPropsInRadius(run, hrp.Position, ConfigLookup.GetStainBombRadius(stainSize))
end)

RunEvents.MiniBombDetonated:Connect(function(plr: Player, origin: Vector3, radius: number)
	local run = activeRuns[plr]
	if run == nil or not run.active then
		return
	end
	soilPropsInRadius(run, origin, radius)
end)

RunEvents.ScoreBonus:Connect(function(plr: Player, points: number, _source: string?)
	local run = activeRuns[plr]
	if run == nil or not run.active then
		return
	end
	local amount = math.floor(points)
	if amount <= 0 then
		return
	end
	run.score += amount
end)

Heartbeat:Connect(function(dt)
	stepAccumulator += dt
	if stepAccumulator < RunConfig.RunLoopStepInterval then
		return
	end
	local step = stepAccumulator
	stepAccumulator = 0

	for _, run in activeRuns do
		if run.active then
			stepRun(run, step)
		end
	end

	NpcService.Step(os.clock())
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Lobby" then
		task.spawn(setupPortal)
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

return RunService
