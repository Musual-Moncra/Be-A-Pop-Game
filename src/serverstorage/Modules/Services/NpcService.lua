--!strict

--[[
	NpcService
	Owns every patrolling NPC: line patrol walk, vision triangle test, chase, walk back, the state
	attribute the client vision zones read, panic flees and the catch penalty. RoomService calls
	SetupInstance when a room acquires a map copy, Step from the shared run heartbeat, CheckCatch
	for every active run and Panic when an object is soiled. Patrol, panic and catch behave as
	before; Chase and Return are the new states. NPC state is per map copy: a chase, a catch and
	a panic only touch NPCs of the same instance, and an idle instance stops stepping.

	API:
		NpcService.SetupInstance(instance: MapInstance)
		NpcService.SetInstanceActive(mapModel: Model, active: boolean)
		NpcService.Step(now: number)
		NpcService.CheckCatch(run: CatchRun, hrp: BasePart)
		NpcService.Panic(mapModel: Model, plr: Player, position: Vector3)

	Vision test: triangle on the floor with its tip at the NPC, ViewLength deep along the look
	direction and ViewWidth wide at the far edge (half width grows linearly with distance),
	widened by LoseMargin when losing a target. Chase speed is capped by NpcConfig.ChaseMax.
	Height counts: a player more than ViewHeight above or below the NPC is not seen, and more
	than CatchHeight away vertically is not caught (standing on furniture is safe).
	A chasing NPC that catches its target gives up and ignores everyone for RestTime, so it never camps.
	The NpcState attribute is "Patrol", "Chase" or "Return"; NpcVisionController draws it.

	Dependencies:
		Players, RunEvents, Outbound, ConfigLookup, EventConfig, NpcConfig, RunConfig
]]

local Players = game:GetService("Players")

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)

local EventConfig = require(ReplicatedStorage.Modules.Config.EventConfig)
local NpcConfig = require(ReplicatedStorage.Modules.Config.NpcConfig)
local RunConfig = require(ReplicatedStorage.Modules.Config.RunConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)

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
	active: boolean,
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
	loseSince: number,
	restUntil: number,
}

type RunPlayer = {
	player: Player,
	mapModel: Model,
	position: Vector3,
}

local PATROL = "Patrol"
local CHASE = "Chase"
local RETURN = "Return"
local STATE_ATTRIBUTE = "NpcState"

local NpcService = {}

local npcs: { [Model]: Npc } = {}
local runMaps: { [Player]: Model } = {}
local lastStep = 0

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
	if math.abs(position.Y - pivot.Position.Y) > NpcConfig.ViewHeight + margin then
		return false
	end
	local localPos = pivot:PointToObjectSpace(position)
	local ahead = -localPos.Z
	if ahead < -margin or ahead > NpcConfig.ViewLength + margin then
		return false
	end
	local halfWidth = math.max(ahead, 0) / NpcConfig.ViewLength * NpcConfig.ViewWidth * 0.5
	return math.abs(localPos.X) <= halfWidth + margin
end

local function resumePatrol(npc: Npc, now: number)
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
	setState(npc, RETURN)
	startMove(npc, closestOnLine(npc, npc.model:GetPivot().Position), npc.baseSpeed * NpcConfig.ReturnSpeed, now)
end

local function stepPatrol(npc: Npc, now: number)
	if npc.panicUntil > 0 and now >= npc.panicUntil then
		npc.panicUntil = 0
		startMove(npc, npc.toPos, npc.baseSpeed, now)
	end
	if now < npc.pausedUntil then
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
			targetPosition = hrp.Position
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
		setState(npc, PATROL)
		npc.fromPos = arrived
		npc.toPos = other
		npc.travelTime = math.max((other - arrived).Magnitude / npc.baseSpeed, 1e-3)
		npc.startedAt = now
	end
end

local function acquire(npc: Npc, pivot: CFrame, runs: { RunPlayer }): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, run in runs do
		if run.mapModel == npc.mapModel and inView(pivot, run.position, 0) then
			local distance = (run.position - pivot.Position).Magnitude
			if distance < bestDistance then
				best = run.player
				bestDistance = distance
			end
		end
	end
	return best
end

local function collectRuns(): { RunPlayer }
	local runs: { RunPlayer } = {}
	for plr, mapModel in runMaps do
		local character = plr.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if hrp ~= nil and humanoid ~= nil and humanoid.Health > 0 then
			table.insert(runs, {
				player = plr,
				mapModel = mapModel,
				position = hrp.Position,
			})
		end
	end
	return runs
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

	local now = os.clock()
	for _, patrolDef in patrolDefs do
		local aPos = patrolDef.startPos + instance.offset
		local bPos = patrolDef.endPos + instance.offset
		local distance = (bPos - aPos).Magnitude
		local travelTime = if patrolDef.speed > 0 then distance / patrolDef.speed else 0
		local model = npcsFolder:FindFirstChild(patrolDef.name)
		if model ~= nil and model:IsA("Model") and travelTime > 0 and npcs[model] == nil then
			npcs[model] = {
				model = model,
				mapModel = mapModel,
				active = true,
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
				loseSince = 0,
				restUntil = 0,
			}
			model:SetAttribute(STATE_ATTRIBUTE, PATROL)
		end
	end
end

function NpcService.SetInstanceActive(mapModel: Model, active: boolean)
	for _, npc in npcs do
		if npc.mapModel == mapModel then
			npc.active = active
		end
	end
end

function NpcService.Step(now: number)
	local dt = math.clamp(now - lastStep, 0, 0.25)
	lastStep = now
	local runs = collectRuns()

	for model, npc in npcs do
		if model.Parent == nil then
			npcs[model] = nil
			continue
		end
		if not npc.active then
			continue
		end

		if npc.state == CHASE then
			stepChase(npc, now, dt)
		else
			if npc.state == RETURN then
				stepReturn(npc, now)
			else
				stepPatrol(npc, now)
			end

			if npc.target == nil and now >= npc.restUntil then
				local target = acquire(npc, model:GetPivot(), runs)
				if target ~= nil then
					npc.target = target
					npc.loseSince = 0
					setState(npc, CHASE)
				end
			end
		end
	end
end

function NpcService.CheckCatch(run: CatchRun, hrp: BasePart)
	if not run.modeDef.NpcsEnabled or run.npcCooldown > 0 then
		return
	end

	local position = hrp.Position
	for _, npc in npcs do
		if npc.mapModel == run.mapModel and npc.model.Parent ~= nil then
			local npcPosition = npc.model:GetPivot().Position
			local flat = Vector3.new(npcPosition.X - position.X, 0, npcPosition.Z - position.Z).Magnitude
			if flat <= NpcConfig.CatchRadius and math.abs(npcPosition.Y - position.Y) <= NpcConfig.CatchHeight then
				local caught = if npc.state == CHASE then npc.target == run.player else true
				if caught then
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

function NpcService.Panic(mapModel: Model, plr: Player, position: Vector3)
	local character = plr.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local fleeFrom = if hrp ~= nil then hrp.Position else position
	local now = os.clock()

	for _, npc in npcs do
		if npc.mapModel == mapModel and npc.state == PATROL and npc.model.Parent ~= nil then
			if (npc.model:GetPivot().Position - position).Magnitude <= EventConfig.TargetPanic.Radius then
				local fleeTo = if (npc.aPos - fleeFrom).Magnitude > (npc.bPos - fleeFrom).Magnitude
					then npc.aPos
					else npc.bPos
				startMove(npc, fleeTo, npc.baseSpeed * EventConfig.TargetPanic.SpeedMultiplier, now)
				npc.panicUntil = now + EventConfig.TargetPanic.DurationSeconds
			end
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
	for _, npc in npcs do
		if npc.target == plr then
			giveUp(npc, os.clock())
		end
	end
end)

return NpcService
