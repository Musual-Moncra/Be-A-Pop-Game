--!strict

--[[
	NpcService
	Owns every patrolling NPC: path-found patrol legs, vision triangle test, chase, walk back,
	the state attribute the client vision zones read, panic on soiling, panic-coin drops and the
	catch penalty. RoomService calls SetupInstance when a room acquires a map copy, Step from the
	shared run heartbeat, CheckCatch for every active run and Panic when an object is soiled.
	RunService calls SoilContact every run tick (players splat an NPC by rolling into it) and
	SoilFromStain when a stain ray hits an NPC model.

	Patrol legs use PathfindingService: each leg is computed once per NPC and followed waypoint by
	waypoint, and the whole server may start at most NpcConfig.PathsPerSecond path computations
	per second. A leg whose computation fails or is over budget falls back to the straight patrol
	line, so NPCs never stop moving.

	A soiled NPC (one whose own model a stain ray hits) flees from the poop at NpcConfig.PanicSpeed
	for NpcConfig.PanicSeconds, shows the "!" billboard, plays the NpcSqueal sound and drops
	NpcConfig.PanicCoinCount score orbs. Each NPC can be soiled for score only once. A fully
	soiled prop near a patrolling NPC makes it panic the same way but without orbs or the mark.

	API:
		NpcService.SetupInstance(instance: MapInstance)
		NpcService.RemoveInstance(mapModel: Model)
		NpcService.Step(now: number)
		NpcService.CheckCatch(run: CatchRun, hrp: BasePart)
		NpcService.SoilContact(mapModel: Model, hrp: BasePart) -> number
		NpcService.SoilFromStain(mapModel: Model, hitPart: BasePart, plr: Player) -> number
		NpcService.Panic(mapModel: Model, plr: Player, position: Vector3)

	Vision test: triangle on the floor with its tip at the NPC, ViewLength deep along the look
	direction and ViewWidth wide at the far edge (half width grows linearly with distance),
	widened by LoseMargin when losing a target. Chase speed is capped by NpcConfig.ChaseMax.
	Player positions are the body centre of the Hitbox capsule, and catches measure from its centre
	line, so the head and tail count. Height counts: a player more than ViewHeight above or below the NPC is not seen, and more
	than CatchHeight away vertically is not caught (standing on furniture is safe).
	A chasing NPC that catches its target gives up and ignores everyone for RestTime, so it never camps.
	The NpcState attribute is "Patrol", "Chase", "Return" or "Panic"; NpcVisionController draws it.

	Dependencies:
		Players, PathfindingService, Workspace, RunEvents, Outbound, ConfigLookup, NpcConfig,
		RunConfig, SoundConfig
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)

local NpcConfig = require(ReplicatedStorage.Modules.Config.NpcConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)
local SoundConfig = require(ReplicatedStorage.Modules.Config.SoundConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Hitbox = require(ReplicatedStorage.Modules.Shared.Hitbox)

export type MapInstance = {
	model: Model,
	mapDef: { Id: string, ModelName: string },
	offset: Vector3,
	slot: number,
}

export type CatchRun = {
	player: Player,
	mapDef: { Id: string },
	mapModel: Model,
	modeDef: { NpcsEnabled: boolean },
	npcCooldown: number,
	hasTimer: boolean,
	timeLeft: number,
}

type Npc = {
	model: Model,
	mapModel: Model,
	aPos: Vector3,
	bPos: Vector3,
	baseSpeed: number,
	state: string,
	target: Player?,
	fromPos: Vector3,
	toPos: Vector3,
	travelTime: number,
	startedAt: number,
	pausedUntil: number,
	panicUntil: number,
	panicGui: BillboardGui?,
	soiled: boolean,
	loseSince: number,
	restUntil: number,
	path: { Vector3 }?,
	pathIndex: number,
	pathFor: Vector3?,
	pathState: string,
	pathRequestId: number,
}

type RunPlayer = {
	player: Player,
	position: Vector3,
	root: CFrame,
	scale: number,
}

type PanicCoin = {
	part: BasePart,
	mapModel: Model,
	points: number,
	expiresAt: number,
}

local PATROL = "Patrol"
local CHASE = "Chase"
local RETURN = "Return"
local PANIC = "Panic"
local STATE_ATTRIBUTE = "NpcState"

local PATH_NONE = "None"
local PATH_PENDING = "Pending"
local PATH_READY = "Ready"
local PATH_FAILED = "Failed"

local NpcService = {}

local npcs: { [Model]: { Npc } } = {}
local runsByMap: { [Model]: { RunPlayer } } = {}
local runMaps: { [Player]: Model } = {}
local panicCoins: { PanicCoin } = {}
local lastStep = 0

local pathWindowStart = os.clock()
local pathsThisWindow = 0

local function takePathToken(now: number): boolean
	if now - pathWindowStart >= 1 then
		pathWindowStart = now
		pathsThisWindow = 0
	end
	if pathsThisWindow >= NpcConfig.PathsPerSecond then
		return false
	end
	pathsThisWindow += 1
	return true
end

local function setState(npc: Npc, state: string)
	if npc.state == state then
		return
	end
	npc.state = state
	npc.model:SetAttribute(STATE_ATTRIBUTE, state)
end

local function poseAt(npc: Npc, position: Vector3, heading: Vector3)
	local flat = Vector3.new(heading.X, 0, heading.Z)
	if flat.Magnitude < 1e-3 then
		npc.model:PivotTo(CFrame.new(position))
	else
		npc.model:PivotTo(CFrame.lookAt(position, position + flat))
	end
end

local function startMove(npc: Npc, targetPos: Vector3, speed: number, now: number)
	local current = npc.model:GetPivot().Position
	local distance = (targetPos - current).Magnitude
	npc.fromPos = current
	npc.toPos = targetPos
	npc.startedAt = now
	npc.travelTime = math.max(distance / speed, 1e-3)
	npc.pausedUntil = 0
end

local function closestOnLine(npc: Npc, point: Vector3): Vector3
	local line = npc.bPos - npc.aPos
	local lengthSq = line:Dot(line)
	if lengthSq <= 1e-6 then
		return npc.aPos
	end
	local alpha = math.clamp((point - npc.aPos):Dot(line) / lengthSq, 0, 1)
	return npc.aPos + line * alpha
end

local function inView(pivot: CFrame, position: Vector3, margin: number): boolean
	local pivotPos = pivot.Position
	if math.abs(position.Y - pivotPos.Y) > NpcConfig.ViewHeight + margin then
		return false
	end
	local dx = position.X - pivotPos.X
	local dz = position.Z - pivotPos.Z
	local maxForward = NpcConfig.ViewLength + margin
	local maxHalfWidth = NpcConfig.ViewWidth * 0.5 + margin
	if dx * dx + dz * dz > maxForward * maxForward + maxHalfWidth * maxHalfWidth then
		return false
	end
	local localPos = pivot:PointToObjectSpace(position)
	local ahead = -localPos.Z
	if ahead < -margin or ahead > maxForward then
		return false
	end
	local halfWidth = math.max(ahead, 0) / NpcConfig.ViewLength * (NpcConfig.ViewWidth * 0.5)
	return math.abs(localPos.X) <= halfWidth + margin
end

local function resetPath(npc: Npc)
	npc.path = nil
	npc.pathIndex = 0
	npc.pathFor = nil
	npc.pathState = PATH_NONE
	npc.pathRequestId += 1
end

local function requestPath(npc: Npc, destination: Vector3, now: number)
	if npc.pathState ~= PATH_NONE or not takePathToken(now) then
		return
	end
	npc.pathState = PATH_PENDING
	npc.pathFor = destination
	npc.pathRequestId += 1
	local requestId = npc.pathRequestId
	local origin = npc.model:GetPivot().Position

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = NpcConfig.PathAgentRadius,
			AgentHeight = NpcConfig.PathAgentHeight,
			AgentCanJump = NpcConfig.PathAgentCanJump,
		})
		local ok = pcall(function()
			path:ComputeAsync(origin, destination)
		end)
		if npc.pathRequestId ~= requestId or npc.pathFor ~= destination then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			local waypoints = path:GetWaypoints()
			for index = 2, #waypoints do
				table.insert(points, waypoints[index].Position)
			end
			if #points > 0 then
				npc.path = points
				npc.pathIndex = 1
				npc.pathState = PATH_READY
				return
			end
		end
		npc.pathState = PATH_FAILED
	end)
end

local function clearPanicGui(npc: Npc)
	if npc.panicGui ~= nil then
		npc.panicGui:Destroy()
		npc.panicGui = nil
	end
end

local function getAnchorPart(model: Model): BasePart?
	local part = model.PrimaryPart
	if part ~= nil then
		return part
	end
	local found = model:FindFirstChildWhichIsA("BasePart", true)
	return if found ~= nil then found :: BasePart else nil
end

local function showPanicGui(npc: Npc)
	clearPanicGui(npc)
	local anchor = getAnchorPart(npc.model)
	if anchor == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NpcPanic"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(NpcConfig.PanicBillboardWidth, NpcConfig.PanicBillboardHeight)
	gui.StudsOffset = Vector3.new(0, NpcConfig.PanicBillboardOffset, 0)
	gui.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Name = "Mark"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = NpcConfig.PanicBillboardText
	label.TextColor3 = NpcConfig.PanicBillboardColor
	label.TextScaled = true
	label.TextWrapped = false
	label.Parent = gui

	gui.Parent = anchor
	npc.panicGui = gui
end

local function playPanicSound(npc: Npc)
	local definition = SoundConfig.Sfx[NpcConfig.PanicSoundKey]
	if definition == nil or definition.Asset == "" then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = if assets ~= nil then assets:FindFirstChild("Sounds") else nil
	if sounds == nil then
		return
	end
	local template = sounds:FindFirstChild(definition.Asset)
	if template == nil or not template:IsA("Sound") or template.SoundId == "" then
		return
	end
	local anchor = getAnchorPart(npc.model)
	if anchor == nil then
		return
	end

	local sound = template:Clone()
	sound.Volume = definition.Volume
	local pitchRange = math.max(0, definition.PitchMax - definition.PitchMin)
	sound.PlaybackSpeed = definition.PitchMin + math.random() * pitchRange
	sound.Parent = anchor
	sound:Play()

	task.delay(SoundConfig.MaxSoundLifetime, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
end

local function startPanic(npc: Npc, fromPosition: Vector3, now: number, reward: boolean)
	npc.target = nil
	npc.loseSince = 0
	npc.panicUntil = now + NpcConfig.PanicSeconds
	resetPath(npc)
	local fleeTo = if (npc.aPos - fromPosition).Magnitude > (npc.bPos - fromPosition).Magnitude
		then npc.aPos
		else npc.bPos
	startMove(npc, fleeTo, NpcConfig.PanicSpeed, now)
	setState(npc, PANIC)
	if reward then
		showPanicGui(npc)
		playPanicSound(npc)
	end
end

local function endPanic(npc: Npc, now: number)
	npc.panicUntil = 0
	clearPanicGui(npc)
	resetPath(npc)
	setState(npc, RETURN)
	startMove(npc, closestOnLine(npc, npc.model:GetPivot().Position), npc.baseSpeed * NpcConfig.ReturnSpeed, now)
end

local function stepPanic(npc: Npc, now: number)
	local alpha = math.clamp((now - npc.startedAt) / npc.travelTime, 0, 1)
	local position = npc.fromPos:Lerp(npc.toPos, alpha)
	poseAt(npc, position, npc.toPos - npc.fromPos)
	if now >= npc.panicUntil then
		endPanic(npc, now)
	end
end

local function resumePatrol(npc: Npc, now: number)
	resetPath(npc)
	local arrived = npc.toPos
	local other = if (arrived - npc.aPos).Magnitude <= (arrived - npc.bPos).Magnitude then npc.bPos else npc.aPos
	npc.fromPos = arrived
	npc.toPos = other
	npc.travelTime = math.max((other - arrived).Magnitude / npc.baseSpeed, 1e-3)
	npc.pausedUntil = now + NpcConfig.TurnaroundPause
	npc.startedAt = npc.pausedUntil
end

local function giveUp(npc: Npc, now: number)
	npc.target = nil
	npc.loseSince = 0
	resetPath(npc)
	setState(npc, RETURN)
	startMove(npc, closestOnLine(npc, npc.model:GetPivot().Position), npc.baseSpeed * NpcConfig.ReturnSpeed, now)
end

local function stepPatrol(npc: Npc, now: number, dt: number)
	if now < npc.pausedUntil then
		return
	end

	if npc.pathState == PATH_NONE then
		requestPath(npc, npc.toPos, now)
	end

	local path = npc.path
	if npc.pathState == PATH_READY and path ~= nil then
		local waypoint = path[npc.pathIndex]
		if waypoint == nil then
			resetPath(npc)
			resumePatrol(npc, now)
			return
		end
		local position = npc.model:GetPivot().Position
		local delta = waypoint - position
		local distance = delta.Magnitude
		local step = npc.baseSpeed * dt
		if distance <= math.max(step, NpcConfig.PathWaypointRadius) then
			npc.pathIndex += 1
			if npc.pathIndex > #path then
				resetPath(npc)
				resumePatrol(npc, now)
			end
		else
			poseAt(npc, position + delta.Unit * step, delta)
		end
		return
	end

	local alpha = math.clamp((now - npc.startedAt) / npc.travelTime, 0, 1)
	local position = npc.fromPos:Lerp(npc.toPos, alpha)
	poseAt(npc, position, npc.toPos - npc.fromPos)

	if alpha >= 1 then
		resumePatrol(npc, now)
	end
end

local function stepChase(npc: Npc, now: number, dt: number)
	local target = npc.target
	local targetPosition: Vector3? = nil
	if target ~= nil and target.Parent == Players and runMaps[target] == npc.mapModel then
		local character = target.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if hrp ~= nil and humanoid ~= nil and humanoid.Health > 0 then
			targetPosition = Hitbox.Center(hrp.CFrame, Hitbox.Scale(hrp))
		end
	end
	if targetPosition == nil then
		giveUp(npc, now)
		return
	end

	local pivot = npc.model:GetPivot()
	if inView(pivot, targetPosition, NpcConfig.LoseMargin) then
		npc.loseSince = 0
	elseif npc.loseSince == 0 then
		npc.loseSince = now
	elseif now - npc.loseSince >= NpcConfig.LoseTime then
		giveUp(npc, now)
		return
	end

	local delta = Vector3.new(targetPosition.X - pivot.Position.X, 0, targetPosition.Z - pivot.Position.Z)
	local distance = delta.Magnitude
	local stopDistance = NpcConfig.CatchRadius * 0.5
	if distance > stopDistance then
		local move =
			math.min(distance - stopDistance, math.min(npc.baseSpeed * NpcConfig.ChaseSpeed, NpcConfig.ChaseMax) * dt)
		poseAt(npc, pivot.Position + delta.Unit * move, delta)
	else
		poseAt(npc, pivot.Position, delta)
	end
end

local function stepReturn(npc: Npc, now: number)
	if now < npc.pausedUntil then
		return
	end

	local alpha = math.clamp((now - npc.startedAt) / npc.travelTime, 0, 1)
	local position = npc.fromPos:Lerp(npc.toPos, alpha)
	poseAt(npc, position, npc.toPos - npc.fromPos)

	if alpha >= 1 then
		local arrived = npc.toPos
		local other = if (arrived - npc.aPos).Magnitude <= (arrived - npc.bPos).Magnitude then npc.bPos else npc.aPos
		resetPath(npc)
		setState(npc, PATROL)
		npc.fromPos = arrived
		npc.toPos = other
		npc.travelTime = math.max((other - arrived).Magnitude / npc.baseSpeed, 1e-3)
		npc.startedAt = now
	end
end

local function acquire(pivot: CFrame, runs: { RunPlayer }): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, run in runs do
		if inView(pivot, run.position, 0) then
			local distance = (run.position - pivot.Position).Magnitude
			if distance < bestDistance then
				best = run.player
				bestDistance = distance
			end
		end
	end
	return best
end

local function collectRuns()
	for _, runs in runsByMap do
		table.clear(runs)
	end
	for plr, mapModel in runMaps do
		local character = plr.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local runs = runsByMap[mapModel]
		if runs ~= nil and hrp ~= nil and humanoid ~= nil and humanoid.Health > 0 then
			local scale = Hitbox.Scale(hrp)
			table.insert(runs, {
				player = plr,
				position = Hitbox.Center(hrp.CFrame, scale),
				root = hrp.CFrame,
				scale = scale,
			})
		end
	end
end

local function findNpcByHit(mapModel: Model, hit: BasePart): Npc?
	local folder = mapModel:FindFirstChild("NPCs")
	if folder == nil then
		return nil
	end
	local current: Instance? = hit
	while current ~= nil and current.Parent ~= folder do
		current = current.Parent
	end
	if current == nil or not current:IsA("Model") then
		return nil
	end
	for _, npc in npcs[mapModel] or {} do
		if npc.model == current then
			return npc
		end
	end
	return nil
end

local function getCoinFolder(mapModel: Model): Folder
	local folder = mapModel:FindFirstChild(NpcConfig.PanicCoinFolderName)
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = NpcConfig.PanicCoinFolderName
	created.Parent = mapModel
	return created
end

local function spawnPanicCoins(npc: Npc)
	local folder = getCoinFolder(npc.mapModel)
	local origin = npc.model:GetPivot().Position
	local now = os.clock()
	for index = 1, NpcConfig.PanicCoinCount do
		local part = Instance.new("Part")
		part.Name = "PanicCoin"
		part.Shape = Enum.PartType.Ball
		part.Material = NpcConfig.PanicCoinMaterial
		part.Color = NpcConfig.PanicCoinColor
		part.Size = Vector3.one * NpcConfig.PanicCoinSize
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(origin + ConfigLookup.GetPanicCoinOffset(index, NpcConfig.PanicCoinCount))
		part.Parent = folder
		table.insert(panicCoins, {
			part = part,
			mapModel = npc.mapModel,
			points = NpcConfig.PanicCoinPoints,
			expiresAt = now + NpcConfig.PanicCoinLifetime,
		})
	end
end

local function stepPanicCoins(now: number)
	local radiusSq = NpcConfig.PanicCoinPickupRadius * NpcConfig.PanicCoinPickupRadius
	for index = #panicCoins, 1, -1 do
		local coin = panicCoins[index]
		local part = coin.part
		local collected = false
		local runs = runsByMap[coin.mapModel]
		if part.Parent ~= nil and runs ~= nil then
			local position = part.Position
			for _, run in runs do
				local delta = Hitbox.ClosestPoint(run.root, run.scale, position) - position
				if delta:Dot(delta) <= radiusSq then
					RunEvents.ScoreBonus:Fire(run.player, coin.points, "PanicCoin")
					collected = true
					break
				end
			end
		end
		if collected or part.Parent == nil or now >= coin.expiresAt then
			if part.Parent ~= nil then
				part:Destroy()
			end
			table.remove(panicCoins, index)
		end
	end
end

function NpcService.SetupInstance(instance: MapInstance)
	local mapDef = instance.mapDef
	local mapModel = instance.model
	local patrolDefs = RunConfig.NpcPatrols[mapDef.Id]
	if patrolDefs == nil then
		return
	end
	local npcsFolder = mapModel:FindFirstChild("NPCs")
	if npcsFolder == nil then
		return
	end

	local list: { Npc } = {}
	npcs[mapModel] = list
	runsByMap[mapModel] = {}

	local now = os.clock()
	for _, patrolDef in patrolDefs do
		local aPos = patrolDef.startPos + instance.offset
		local bPos = patrolDef.endPos + instance.offset
		local distance = (bPos - aPos).Magnitude
		local travelTime = if patrolDef.speed > 0 then distance / patrolDef.speed else 0
		local model = npcsFolder:FindFirstChild(patrolDef.name)
		if model ~= nil and model:IsA("Model") and travelTime > 0 then
			table.insert(list, {
				model = model,
				mapModel = mapModel,
				aPos = aPos,
				bPos = bPos,
				baseSpeed = patrolDef.speed,
				state = PATROL,
				target = nil,
				fromPos = aPos,
				toPos = bPos,
				travelTime = travelTime,
				startedAt = now,
				pausedUntil = 0,
				panicUntil = 0,
				panicGui = nil,
				soiled = false,
				loseSince = 0,
				restUntil = 0,
				path = nil,
				pathIndex = 0,
				pathFor = nil,
				pathState = PATH_NONE,
				pathRequestId = 0,
			})
			model:SetAttribute(STATE_ATTRIBUTE, PATROL)
		end
	end
end

function NpcService.RemoveInstance(mapModel: Model)
	npcs[mapModel] = nil
	runsByMap[mapModel] = nil
	for index = #panicCoins, 1, -1 do
		local coin = panicCoins[index]
		if coin.mapModel == mapModel then
			if coin.part.Parent ~= nil then
				coin.part:Destroy()
			end
			table.remove(panicCoins, index)
		end
	end
end

function NpcService.Step(now: number)
	local dt = math.clamp(now - lastStep, 0, 0.25)
	lastStep = now
	collectRuns()

	for mapModel, list in npcs do
		local runs = runsByMap[mapModel]
		for _, npc in list do
			if npc.state == CHASE then
				stepChase(npc, now, dt)
			elseif npc.state == PANIC then
				stepPanic(npc, now)
			else
				if npc.state == RETURN then
					stepReturn(npc, now)
				else
					stepPatrol(npc, now, dt)
				end

				if npc.target == nil and now >= npc.restUntil and runs ~= nil then
					local target = acquire(npc.model:GetPivot(), runs)
					if target ~= nil then
						npc.target = target
						npc.loseSince = 0
						setState(npc, CHASE)
					end
				end
			end
		end
	end

	stepPanicCoins(now)
end

function NpcService.CheckCatch(run: CatchRun, hrp: BasePart)
	if not run.modeDef.NpcsEnabled or run.npcCooldown > 0 then
		return
	end

	local root = hrp.CFrame
	local scale = Hitbox.Scale(hrp)
	local catchRadiusSq = NpcConfig.CatchRadius * NpcConfig.CatchRadius
	for _, npc in npcs[run.mapModel] or {} do
		if npc.state ~= PANIC and (npc.state ~= CHASE or npc.target == run.player) then
			local npcPosition = npc.model:GetPivot().Position
			local position = Hitbox.ClosestPoint(root, scale, npcPosition)
			local dx = npcPosition.X - position.X
			local dz = npcPosition.Z - position.Z
			if math.abs(npcPosition.Y - position.Y) <= NpcConfig.CatchHeight and dx * dx + dz * dz <= catchRadiusSq then
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Include
				rayParams.FilterDescendantsInstances = { run.mapModel }
				rayParams.RespectCanCollide = true
				local blocked = Workspace:Raycast(npcPosition, position - npcPosition, rayParams)
				if blocked == nil or blocked.Instance:IsDescendantOf(npc.model) then
					if npc.state == CHASE then
						local now = os.clock()
						giveUp(npc, now)
						npc.restUntil = now + NpcConfig.RestTime
					end
					run.npcCooldown = NpcConfig.CatchCooldown
					if run.hasTimer then
						run.timeLeft = math.max(0, run.timeLeft - NpcConfig.CatchPenalty)
					end
					Outbound.NpcCaught(run.player, NpcConfig.CatchPenalty)
					return
				end
			end
		end
	end
end

local function soilNpc(npc: Npc, fromPosition: Vector3): number
	if npc.soiled then
		return 0
	end
	npc.soiled = true
	startPanic(npc, fromPosition, os.clock(), true)
	spawnPanicCoins(npc)
	return NpcConfig.PanicSoilBonus
end

function NpcService.SoilContact(mapModel: Model, hrp: BasePart): number
	local list = npcs[mapModel]
	if list == nil then
		return 0
	end

	local root = hrp.CFrame
	local scale = Hitbox.Scale(hrp)
	local checkSq = NpcConfig.SoilCheckRadius * NpcConfig.SoilCheckRadius
	local contact = ConfigLookup.GetNpcSoilContactRadius(scale)
	local contactSq = contact * contact
	local total = 0

	for _, npc in list do
		if not npc.soiled then
			local npcPosition = npc.model:GetPivot().Position
			local ox = npcPosition.X - root.Position.X
			local oy = npcPosition.Y - root.Position.Y
			local oz = npcPosition.Z - root.Position.Z
			if ox * ox + oy * oy + oz * oz <= checkSq then
				local closest = Hitbox.ClosestPoint(root, scale, npcPosition)
				local dx = npcPosition.X - closest.X
				local dy = npcPosition.Y - closest.Y
				local dz = npcPosition.Z - closest.Z
				if dx * dx + dy * dy + dz * dz <= contactSq then
					total += soilNpc(npc, root.Position)
				end
			end
		end
	end
	return total
end

function NpcService.SoilFromStain(mapModel: Model, hitPart: BasePart, plr: Player): number
	local npc = findNpcByHit(mapModel, hitPart)
	if npc == nil then
		return 0
	end
	local character = plr.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local fromPosition = if hrp ~= nil then hrp.Position else npc.model:GetPivot().Position
	return soilNpc(npc, fromPosition)
end

function NpcService.Panic(mapModel: Model, plr: Player, position: Vector3)
	local character = plr.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local fleeFrom = if hrp ~= nil then hrp.Position else position
	local now = os.clock()

	for _, npc in npcs[mapModel] or {} do
		if npc.state == PATROL and (npc.model:GetPivot().Position - position).Magnitude <= NpcConfig.PanicRadius then
			startPanic(npc, fleeFrom, now, false)
		end
	end
end

RunEvents.RunStarted:Connect(function(plr: Player, _mapId: string, modeId: string, mapModel: Model?)
	local modeDef = ConfigLookup.GetMode(modeId)
	if modeDef ~= nil and modeDef.NpcsEnabled and mapModel ~= nil then
		runMaps[plr] = mapModel
	end
end)

RunEvents.RunEnded:Connect(function(plr: Player)
	runMaps[plr] = nil
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	runMaps[plr] = nil
	for _, list in npcs do
		for _, npc in list do
			if npc.target == plr then
				giveUp(npc, os.clock())
			end
		end
	end
end)

return NpcService
