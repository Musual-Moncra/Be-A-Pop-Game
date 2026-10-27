--!strict

--[[
	PowerupService
	Spawns food items during active runs, checks server-side pickups, manages active
	power-up boosts and multipliers, and synchronizes power-up state to the client.

	API:
		PowerupService.StartRun(plr: Player, mapModel: Model, mode: ConfigLookup.ModeDefinition)
		PowerupService.StopRun(plr: Player)
		PowerupService.GetMultipliers(plr: Player) -> { Speed: number, StainSize: number, Points: number }

	Dependencies:
		Players, Workspace, RunService, ReplicatedStorage, ServerStorage,
		PowerupConfig, ConfigLookup, Net, RunEvents, DataService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PowerupConfig = require(ReplicatedStorage.Modules.Config.PowerupConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local DataService = require(script.Parent.DataService)

type ActiveBoost = {
	Duration: number,
	ExpiresAt: number,
}

type SpawnedFood = {
	part: BasePart,
	powerupId: string,
	spawnedAt: number,
}

type PowerupSession = {
	player: Player,
	mapModel: Model,
	playArea: BasePart?,
	folder: Folder,
	spawnedFoods: { [BasePart]: SpawnedFood },
	activeBoosts: { [string]: ActiveBoost },
	nextSpawnTime: number,
	nextSyncTime: number,
	heartbeatConn: RBXScriptConnection?,
	characterConn: RBXScriptConnection?,
	diedConn: RBXScriptConnection?,
}

local PowerupService = {}

local sessions: { [Player]: PowerupSession } = {}

local function getDurationMultiplier(plr: Player): number
	local data = DataService.Get(plr)
	local level = 0
	if data ~= nil and data.Upgrades ~= nil then
		level = data.Upgrades.PowerupDuration or 0
	end
	return ConfigLookup.GetUpgradeValue("PowerupDuration", level)
end

local function pickRandomPowerupId(): string?
	local totalWeight = 0
	for _, def in PowerupConfig.Powerups do
		totalWeight += def.Weight
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = math.random() * totalWeight
	for id, def in PowerupConfig.Powerups do
		roll -= def.Weight
		if roll <= 0 then
			return id
		end
	end
	for id in PowerupConfig.Powerups do
		return id
	end
	return nil
end

local function syncState(plr: Player, session: PowerupSession)
	if plr.Parent ~= Players then
		return
	end
	local now = os.clock()
	local payload = {}
	for id, boost in session.activeBoosts do
		local timeLeft = math.max(0, boost.ExpiresAt - now)
		if timeLeft > 0 then
			table.insert(payload, {
				Id = id,
				TimeLeft = timeLeft,
				Duration = boost.Duration,
			})
		end
	end
	Net.PowerupState:FireClient(plr, payload)
end

local function applyScale(plr: Player, session: PowerupSession)
	local character = plr.Character
	if character == nil or character.Parent == nil then
		return
	end
	local now = os.clock()
	local scale = 1
	for id, boost in session.activeBoosts do
		if boost.ExpiresAt > now then
			local def = ConfigLookup.GetPowerup(id)
			if def ~= nil and def.CharacterScale > 1 then
				scale = math.max(scale, def.CharacterScale)
			end
		end
	end
	pcall(function()
		character:ScaleTo(scale)
	end)
end

local function spawnFood(session: PowerupSession)
	local playArea = session.playArea
	if playArea == nil then
		return
	end
	local powerupId = pickRandomPowerupId()
	if powerupId == nil then
		return
	end
	local def = ConfigLookup.GetPowerup(powerupId)
	if def == nil then
		return
	end

	local topY = playArea.Position.Y + playArea.Size.Y * 0.5 - PowerupConfig.SpawnRayTopInset
	local halfX = playArea.Size.X * 0.5
	local halfZ = playArea.Size.Z * 0.5
	local rx = (math.random() * 2 - 1) * halfX
	local rz = (math.random() * 2 - 1) * halfZ
	local rayOrigin = Vector3.new(playArea.Position.X + rx, topY, playArea.Position.Z + rz)
	local rayDirection = Vector3.new(0, -playArea.Size.Y, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { session.mapModel }
	local result = Workspace:Raycast(rayOrigin, rayDirection, params)

	if result == nil then
		return
	end

	local spawnPos = result.Position + Vector3.new(0, PowerupConfig.SpawnHeight, 0)

	local part = Instance.new("Part")
	part.Name = powerupId
	part:SetAttribute("PowerupId", powerupId)
	part.Shape = PowerupConfig.ItemShape
	part.Size = Vector3.new(PowerupConfig.ItemSize, PowerupConfig.ItemSize, PowerupConfig.ItemSize)
	part.Color = def.Color
	part.Material = PowerupConfig.ItemMaterial
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(spawnPos)
	part.Parent = session.folder

	session.spawnedFoods[part] = {
		part = part,
		powerupId = powerupId,
		spawnedAt = os.clock(),
	}
end

local function bindCharacter(plr: Player, session: PowerupSession, character: Model)
	if session.diedConn ~= nil then
		session.diedConn:Disconnect()
		session.diedConn = nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		session.diedConn = humanoid.Died:Connect(function()
			PowerupService.StopRun(plr)
		end)
	end
	applyScale(plr, session)
end

function PowerupService.GetMultipliers(plr: Player): { Speed: number, StainSize: number, Points: number }
	local speed = 1
	local stainSize = 1
	local points = 1
	local session = sessions[plr]
	if session ~= nil then
		local now = os.clock()
		for id, boost in session.activeBoosts do
			if boost.ExpiresAt > now then
				local def = ConfigLookup.GetPowerup(id)
				if def ~= nil then
					speed *= def.SpeedMultiplier
					stainSize *= def.StainSizeMultiplier
					points *= def.PointsMultiplier
				end
			end
		end
	end
	return {
		Speed = speed,
		StainSize = stainSize,
		Points = points,
	}
end

function PowerupService.StopRun(plr: Player)
	local session = sessions[plr]
	if session == nil then
		return
	end
	sessions[plr] = nil

	if session.heartbeatConn ~= nil then
		session.heartbeatConn:Disconnect()
		session.heartbeatConn = nil
	end
	if session.characterConn ~= nil then
		session.characterConn:Disconnect()
		session.characterConn = nil
	end
	if session.diedConn ~= nil then
		session.diedConn:Disconnect()
		session.diedConn = nil
	end

	session.folder:Destroy()
	table.clear(session.spawnedFoods)
	table.clear(session.activeBoosts)

	if plr.Character ~= nil and plr.Character.Parent ~= nil then
		pcall(function()
			plr.Character:ScaleTo(1)
		end)
	end

	if plr.Parent == Players then
		Net.PowerupState:FireClient(plr, {})
	end
end

function PowerupService.StartRun(plr: Player, mapModel: Model, mode: ConfigLookup.ModeDefinition)
	PowerupService.StopRun(plr)

	if not mode.PowerupsEnabled then
		return
	end

	local playArea = mapModel:FindFirstChild("PlayArea", true) :: BasePart?
	local folder = Instance.new("Folder")
	folder.Name = PowerupConfig.FolderPrefix .. tostring(plr.UserId)
	folder.Parent = Workspace

	local session: PowerupSession = {
		player = plr,
		mapModel = mapModel,
		playArea = playArea,
		folder = folder,
		spawnedFoods = {},
		activeBoosts = {},
		nextSpawnTime = os.clock() + PowerupConfig.FirstSpawnDelay,
		nextSyncTime = os.clock() + PowerupConfig.SyncInterval,
		heartbeatConn = nil,
		characterConn = nil,
		diedConn = nil,
	}
	sessions[plr] = session

	if plr.Character ~= nil then
		bindCharacter(plr, session, plr.Character)
	end

	session.characterConn = plr.CharacterAdded:Connect(function(character)
		task.defer(function()
			if sessions[plr] == session then
				bindCharacter(plr, session, character)
			end
		end)
	end)

	session.heartbeatConn = RunService.Heartbeat:Connect(function()
		if sessions[plr] ~= session then
			return
		end
		local now = os.clock()

		local character = plr.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if hrp ~= nil then
			local hrpPos = hrp.Position
			local foodsSnapshot = table.clone(session.spawnedFoods)
			for part, food in foodsSnapshot do
				if session.spawnedFoods[part] ~= nil and (hrpPos - part.Position).Magnitude <= PowerupConfig.PickupRadius then
					session.spawnedFoods[part] = nil
					part:Destroy()

					local def = ConfigLookup.GetPowerup(food.powerupId)
					if def ~= nil then
						if def.TimeBonus > 0 then
							RunEvents.TimeBonus:Fire(plr, def.TimeBonus)
						end

						local durationMult = getDurationMultiplier(plr)
						local totalDuration = def.Duration * durationMult
						if totalDuration > 0 then
							session.activeBoosts[food.powerupId] = {
								Duration = totalDuration,
								ExpiresAt = now + totalDuration,
							}
							applyScale(plr, session)
						end

						DataService.IncrementStat(plr, "PowerupsEaten", 1)
						RunEvents.PowerupEaten:Fire(plr, food.powerupId)
						Net.PowerupPicked:FireClient(plr, food.powerupId)
						syncState(plr, session)
					end
				end
			end
		end

		for part, food in table.clone(session.spawnedFoods) do
			if now - food.spawnedAt >= PowerupConfig.ItemLifetime then
				session.spawnedFoods[part] = nil
				part:Destroy()
			end
		end

		local boostExpired = false
		for id, boost in table.clone(session.activeBoosts) do
			if now >= boost.ExpiresAt then
				session.activeBoosts[id] = nil
				boostExpired = true
			end
		end
		if boostExpired then
			applyScale(plr, session)
			syncState(plr, session)
		end

		if now >= session.nextSpawnTime then
			session.nextSpawnTime = now + PowerupConfig.SpawnInterval
			local count = 0
			for _ in session.spawnedFoods do
				count += 1
			end
			if count < PowerupConfig.MaxActivePerRun then
				spawnFood(session)
			end
		end

		if now >= session.nextSyncTime then
			session.nextSyncTime = now + PowerupConfig.SyncInterval
			syncState(plr, session)
		end
	end)
end

Players.PlayerRemoving:Connect(function(plr)
	PowerupService.StopRun(plr)
end)

RunEvents.RunEnded:Connect(function(plr, _summary)
	PowerupService.StopRun(plr)
end)

return PowerupService
