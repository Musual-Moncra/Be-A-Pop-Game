--!strict

--[[
	PowerupService
	Spawns food items during active runs, checks server-side pickups, manages active
	power-up boosts and multipliers, and synchronizes power-up state to the client.

	One shared Heartbeat drives every session at PowerupConfig.TickInterval. Character
	scaling is applied only when the target scale actually changes, because every server
	ScaleTo rewrites the client-owned body and stalls its movement for a moment.
	RunService owns the session lifetime: it calls StartRun when a run begins and StopRun
	when it ends (death and leaving included).

	API:
		PowerupService.StartRun(plr: Player, mapModel: Model, mode: ConfigLookup.ModeDefinition)
		PowerupService.StopRun(plr: Player)
		PowerupService.GetMultipliers(plr: Player) -> Multipliers { Speed, StainSize, Points }

	Dependencies: PowerupConfig, ConfigLookup, RunEvents, DataService, Outbound
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PowerupConfig = require(ReplicatedStorage.Modules.Config.PowerupConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local DataService = require(script.Parent.DataService)

export type Multipliers = {
	Speed: number,
	StainSize: number,
	Points: number,
}

type ActiveBoost = {
	Duration: number,
	ExpiresAt: number,
}

type SpawnedFood = {
	powerupId: string,
	expiresAt: number,
}

type PowerupSession = {
	player: Player,
	playArea: BasePart?,
	folder: Folder,
	rayParams: RaycastParams,
	foods: { [BasePart]: SpawnedFood },
	foodCount: number,
	boosts: { [string]: ActiveBoost },
	multipliers: Multipliers,
	appliedScale: number,
	nextSpawnTime: number,
	nextSyncTime: number,
}

local PowerupService = {}

local NEUTRAL: Multipliers = table.freeze({ Speed = 1, StainSize = 1, Points = 1 })

local sessions: { [Player]: PowerupSession } = {}
local tickAccumulator = 0
local totalWeight = 0
for _, def in PowerupConfig.Powerups do
	totalWeight += def.Weight
end

local function pickRandomPowerupId(): string?
	if totalWeight <= 0 then
		return nil
	end
	local roll = math.random() * totalWeight
	local last: string? = nil
	for id, def in PowerupConfig.Powerups do
		roll -= def.Weight
		last = id
		if roll <= 0 then
			return id
		end
	end
	return last
end

local function getDurationMultiplier(plr: Player): number
	local data = DataService.Get(plr)
	local level = if data ~= nil and data.Upgrades ~= nil then data.Upgrades.PowerupDuration or 0 else 0
	return ConfigLookup.GetUpgradeValue("PowerupDuration", level)
end

local function setCharacterScale(plr: Player, scale: number): boolean
	local character = plr.Character
	if character == nil or character.Parent == nil then
		return false
	end
	if math.abs(character:GetScale() - scale) < 1e-3 then
		return true
	end
	return (pcall(character.ScaleTo, character, scale))
end

local function recompute(session: PowerupSession)
	local speed, stainSize, points, scale = 1, 1, 1, 1
	for id in session.boosts do
		local def = ConfigLookup.GetPowerup(id)
		if def ~= nil then
			speed *= def.SpeedMultiplier
			stainSize *= def.StainSizeMultiplier
			points *= def.PointsMultiplier
			scale = math.max(scale, def.CharacterScale)
		end
	end
	session.multipliers = { Speed = speed, StainSize = stainSize, Points = points }

	if scale ~= session.appliedScale and setCharacterScale(session.player, scale) then
		session.appliedScale = scale
	end
end

local function syncState(session: PowerupSession, now: number)
	local payload = {}
	for id, boost in session.boosts do
		local timeLeft = boost.ExpiresAt - now
		if timeLeft > 0 then
			table.insert(payload, { Id = id, TimeLeft = timeLeft, Duration = boost.Duration })
		end
	end
	Outbound.PowerupState(session.player, payload)
end

local function spawnFood(session: PowerupSession, now: number)
	local playArea = session.playArea
	local powerupId = pickRandomPowerupId()
	local def = if powerupId ~= nil then ConfigLookup.GetPowerup(powerupId) else nil
	if playArea == nil or powerupId == nil or def == nil then
		return
	end

	local areaPos, areaSize = playArea.Position, playArea.Size
	local rayOrigin = Vector3.new(
		areaPos.X + (math.random() * 2 - 1) * areaSize.X * 0.5,
		areaPos.Y + areaSize.Y * 0.5 - PowerupConfig.SpawnRayTopInset,
		areaPos.Z + (math.random() * 2 - 1) * areaSize.Z * 0.5
	)
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -areaSize.Y, 0), session.rayParams)
	if result == nil then
		return
	end

	local part = Instance.new("Part")
	part.Name = powerupId
	part:SetAttribute("PowerupId", powerupId)
	part.Shape = PowerupConfig.ItemShape
	part.Size = Vector3.one * PowerupConfig.ItemSize
	part.Color = def.Color
	part.Material = PowerupConfig.ItemMaterial
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(result.Position + Vector3.yAxis * PowerupConfig.SpawnHeight)
	part.Parent = session.folder

	session.foods[part] = { powerupId = powerupId, expiresAt = now + PowerupConfig.ItemLifetime }
	session.foodCount += 1
end

local function removeFood(session: PowerupSession, part: BasePart)
	session.foods[part] = nil
	session.foodCount -= 1
	part:Destroy()
end

local function eat(session: PowerupSession, powerupId: string, now: number)
	local plr = session.player
	local def = ConfigLookup.GetPowerup(powerupId)
	if def == nil then
		return
	end

	if def.TimeBonus > 0 then
		RunEvents.TimeBonus:Fire(plr, def.TimeBonus)
	end

	local duration = def.Duration * getDurationMultiplier(plr)
	if duration > 0 then
		session.boosts[powerupId] = { Duration = duration, ExpiresAt = now + duration }
		recompute(session)
	end

	DataService.IncrementStat(plr, "PowerupsEaten", 1)
	RunEvents.PowerupEaten:Fire(plr, powerupId)
	Outbound.PowerupPicked(plr, powerupId)
	syncState(session, now)
end

local function step(session: PowerupSession, now: number)
	local character = session.player.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local reach = PowerupConfig.PickupRadius * session.appliedScale

	for part, food in session.foods do
		if hrp ~= nil and (hrp.Position - part.Position).Magnitude <= reach then
			removeFood(session, part)
			eat(session, food.powerupId, now)
		elseif now >= food.expiresAt then
			removeFood(session, part)
		end
	end

	local expired = false
	for id, boost in session.boosts do
		if now >= boost.ExpiresAt then
			session.boosts[id] = nil
			expired = true
		end
	end
	if expired then
		recompute(session)
		syncState(session, now)
	end

	if now >= session.nextSpawnTime then
		session.nextSpawnTime = now + PowerupConfig.SpawnInterval
		if session.foodCount < PowerupConfig.MaxActivePerRun then
			spawnFood(session, now)
		end
	end

	if now >= session.nextSyncTime then
		session.nextSyncTime = now + PowerupConfig.SyncInterval
		syncState(session, now)
	end
end

function PowerupService.GetMultipliers(plr: Player): Multipliers
	local session = sessions[plr]
	return if session ~= nil then session.multipliers else NEUTRAL
end

function PowerupService.StopRun(plr: Player)
	local session = sessions[plr]
	if session == nil then
		return
	end
	sessions[plr] = nil

	session.folder:Destroy()
	if session.appliedScale ~= 1 then
		setCharacterScale(plr, 1)
	end
	Outbound.PowerupState(plr, {})
end

function PowerupService.StartRun(plr: Player, mapModel: Model, mode: ConfigLookup.ModeDefinition)
	PowerupService.StopRun(plr)
	if not mode.PowerupsEnabled then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = PowerupConfig.FolderPrefix .. tostring(plr.UserId)
	folder.Parent = Workspace

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { mapModel }

	local now = os.clock()
	sessions[plr] = {
		player = plr,
		playArea = mapModel:FindFirstChild("PlayArea", true) :: BasePart?,
		folder = folder,
		rayParams = rayParams,
		foods = {},
		foodCount = 0,
		boosts = {},
		multipliers = NEUTRAL,
		appliedScale = 1,
		nextSpawnTime = now + PowerupConfig.FirstSpawnDelay,
		nextSyncTime = now + PowerupConfig.SyncInterval,
	}
end

RunService.Heartbeat:Connect(function(dt)
	tickAccumulator += dt
	if tickAccumulator < PowerupConfig.TickInterval then
		return
	end
	tickAccumulator = 0

	local now = os.clock()
	for _, session in sessions do
		step(session, now)
	end
end)

Players.PlayerRemoving:Connect(PowerupService.StopRun)

return PowerupService
