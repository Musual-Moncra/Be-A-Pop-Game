--!strict

--[[
	DataService
	Owns every player profile and is the only place that writes Profile.Data.

	Profiles live in the ProfileStore named in DataConfig (schema v1). Sessions are
	locked, and a player whose profile cannot be loaded is kicked rather than
	allowed to play with data that will never be saved.

	API:
		DataService.Get(plr)                    -> data | nil
		DataService.AddCoins(plr, n)
		DataService.AddGems(plr, n)
		DataService.SpendCoins(plr, n)          -> bool
		DataService.AddXp(plr, xp)              -> levelsGained
		DataService.UnlockMap(plr, mapId)       -> ok, reason
		DataService.IsMapUnlocked(plr, mapId)   -> bool
		DataService.IncrementStat(plr, key, n)
		DataService.RecordRun(plr, score)
		DataService.GetBoostMultiplier(plr, kind) -> number
		DataService.RecordDailyClaim(plr, streak, boostId, boostDuration, skinId)
		DataService.MarkChanged(plr)            re-publish after an external mutation
		DataService.HasPurchase(plr, purchaseId) -> bool
		DataService.RecordPurchase(plr, purchaseId, maxHistory)
		DataService.HasGrantedPet(plr, petId)   -> bool
		DataService.GrantPet(plr, petId)
		DataService.SetCoinBoostUntil(plr, unixSeconds)
		DataService.Changed                     -> Signal (plr, data)

	Every mutation marks the player dirty; one deferred publish per frame then fires Changed,
	updates leaderstats and queues a single DataSync, so a run ending (coins + xp + gems +
	stats) costs one packet instead of five.

	Dependencies: ProfileStore, Signal, Outbound, ConfigLookup, GameConfig, DataConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.Packages.ProfileStore)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)

local PlayerStore = ProfileStore.New(DataConfig.StoreName, DataConfig.Template)

local DataService = {}

DataService.Changed = Signal.new()

local Profiles: { [Player]: any } = {}
local CoinsValues: { [Player]: IntValue } = {}
local LevelValues: { [Player]: IntValue } = {}
local Leaving: { [Player]: boolean } = {}
local Dirty: { [Player]: boolean } = {}
local flushScheduled = false

function DataService.Get(plr: Player)
	local profile = Profiles[plr]
	if profile == nil then
		return nil
	end
	return profile.Data
end

local function updateLeaderstats(plr: Player, data)
	local coins = CoinsValues[plr]
	if coins ~= nil and coins.Parent ~= nil then
		coins.Value = data.Coins
	end
	local level = LevelValues[plr]
	if level ~= nil and level.Parent ~= nil then
		level.Value = data.Level
	end
end

local function flush()
	flushScheduled = false
	for plr in Dirty do
		local data = DataService.Get(plr)
		if data ~= nil then
			DataService.Changed:Fire(plr, data)
			updateLeaderstats(plr, data)
			Outbound.DataSync(plr, data)
		end
	end
	table.clear(Dirty)
end

local function publish(plr: Player)
	Dirty[plr] = true
	if not flushScheduled then
		flushScheduled = true
		task.defer(flush)
	end
end

function DataService.AddCoins(plr: Player, amount: number)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	data.Coins += amount
	publish(plr)
end

function DataService.AddGems(plr: Player, amount: number)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	data.Gems += amount
	publish(plr)
end

function DataService.AddXp(plr: Player, xp: number): number
	local data = DataService.Get(plr)
	if data == nil or xp <= 0 then
		return 0
	end

	data.Xp += xp
	local levelsGained = 0
	while data.Level < GameConfig.MaxLevel do
		local needed = ConfigLookup.GetLevelXp(data.Level)
		if data.Xp < needed then
			break
		end
		data.Xp -= needed
		data.Level += 1
		levelsGained += 1
	end
	if data.Level >= GameConfig.MaxLevel then
		data.Xp = 0
	end
	if levelsGained > 0 then
		data.Gems += levelsGained * GameConfig.GemsPerLevelUp
	end
	publish(plr)
	return levelsGained
end

function DataService.SpendCoins(plr: Player, amount: number): boolean
	local data = DataService.Get(plr)
	if data == nil then
		return false
	end
	if amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	publish(plr)
	return true
end

function DataService.RecordRun(plr: Player, score: number)
	local data = DataService.Get(plr)
	if data == nil or data.Stats == nil then
		return
	end
	data.Stats.TotalRuns += 1
	data.Stats.BestScore = math.max(data.Stats.BestScore, score)
	publish(plr)
end

function DataService.UnlockMap(plr: Player, mapId: string): (boolean, string?)
	local data = DataService.Get(plr)
	if data == nil then
		return false, "NoData"
	end

	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil or not mapDef.Enabled then
		return false, "Unavailable"
	end
	if data.UnlockedMaps[mapId] == true then
		return false, "AlreadyUnlocked"
	end

	local previous = ConfigLookup.GetPreviousMap(mapId)
	if previous ~= nil and data.UnlockedMaps[previous.Id] ~= true then
		return false, "NeedPrevious"
	end
	if data.Level < mapDef.RequiredLevel then
		return false, "NeedLevel"
	end
	if mapDef.UnlockCost > 0 and not DataService.SpendCoins(plr, mapDef.UnlockCost) then
		return false, "NotEnoughCoins"
	end

	data.UnlockedMaps[mapId] = true
	publish(plr)
	return true, nil
end

function DataService.IsMapUnlocked(plr: Player, mapId: string): boolean
	local data = DataService.Get(plr)
	if data == nil then
		return false
	end
	return data.UnlockedMaps[mapId] == true
end

function DataService.IncrementStat(plr: Player, key: string, amount: number)
	local data = DataService.Get(plr)
	if data == nil or data.Stats == nil then
		return
	end
	data.Stats[key] = (data.Stats[key] or 0) + amount
	publish(plr)
end

function DataService.MarkChanged(plr: Player)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	publish(plr)
end

function DataService.GetBoostMultiplier(plr: Player, kind: string): number
	local data = DataService.Get(plr)
	if data == nil or data.Boosts == nil then
		return 1
	end
	local expiresAt = data.Boosts[kind]
	if type(expiresAt) ~= "number" or expiresAt <= os.time() then
		return 1
	end
	local boost = ConfigLookup.GetDailyBoost(kind)
	if boost == nil then
		return 1
	end
	return boost.Multiplier
end

function DataService.RecordDailyClaim(
	plr: Player,
	streak: number,
	boostId: string?,
	boostDuration: number,
	skinId: string?
)
	local data = DataService.Get(plr)
	if data == nil or data.Daily == nil then
		return
	end
	local now = os.time()
	data.Daily.LastClaim = now
	data.Daily.Streak = streak
	if boostId ~= nil and boostDuration > 0 then
		if data.Boosts == nil then
			data.Boosts = {}
		end
		data.Boosts[boostId] = now + boostDuration
	end
	if skinId ~= nil and skinId ~= "" then
		if data.OwnedSkins == nil then
			data.OwnedSkins = {}
		end
		data.OwnedSkins[skinId] = true
	end
	publish(plr)
end

function DataService.HasPurchase(plr: Player, purchaseId: string): boolean
	local data = DataService.Get(plr)
	if data == nil or data.Purchases == nil then
		return false
	end
	return table.find(data.Purchases, purchaseId) ~= nil
end

function DataService.RecordPurchase(plr: Player, purchaseId: string, maxHistory: number)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	if data.Purchases == nil then
		data.Purchases = {}
	end
	if table.find(data.Purchases, purchaseId) ~= nil then
		return
	end

	table.insert(data.Purchases, purchaseId)
	while #data.Purchases > maxHistory do
		table.remove(data.Purchases, 1)
	end
	publish(plr)
end

function DataService.HasGrantedPet(plr: Player, petId: string): boolean
	local data = DataService.Get(plr)
	if data == nil or data.GrantedPets == nil then
		return false
	end
	return table.find(data.GrantedPets, petId) ~= nil
end

function DataService.GrantPet(plr: Player, petId: string)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	if data.GrantedPets == nil then
		data.GrantedPets = {}
	end
	if table.find(data.GrantedPets, petId) ~= nil then
		return
	end
	table.insert(data.GrantedPets, petId)
	publish(plr)
end

function DataService.SetCoinBoostUntil(plr: Player, unixSeconds: number)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	data.CoinBoostUntil = unixSeconds
	publish(plr)
end

local function setupLeaderstats(plr: Player, data)
	local leaderstats = plr:FindFirstChild("leaderstats")
	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = plr
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if coins == nil then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
	end

	local level = leaderstats:FindFirstChild("Level")
	if level == nil then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Parent = leaderstats
	end

	coins.Value = data.Coins
	level.Value = data.Level
	CoinsValues[plr] = coins
	LevelValues[plr] = level
end

local function onPlayerAdded(plr: Player)
	if Profiles[plr] ~= nil then
		return
	end

	local profile = PlayerStore:StartSessionAsync(tostring(plr.UserId), {
		Cancel = function()
			return plr.Parent ~= Players
		end,
	})

	if profile == nil then
		plr:Kick(DataConfig.LoadFailedKick)
		return
	end

	profile:AddUserId(plr.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[plr] = nil
		CoinsValues[plr] = nil
		LevelValues[plr] = nil

		local isLeaving = Leaving[plr] == true
		Leaving[plr] = nil

		if not isLeaving and plr.Parent == Players then
			plr:Kick(DataConfig.SessionEndedKick)
		end
	end)

	if plr.Parent ~= Players then
		profile:EndSession()
		return
	end

	Profiles[plr] = profile
	setupLeaderstats(plr, profile.Data)
	publish(plr)
end

local function onPlayerRemoving(plr: Player)
	local profile = Profiles[plr]

	Leaving[plr] = true
	Dirty[plr] = nil
	Profiles[plr] = nil
	CoinsValues[plr] = nil
	LevelValues[plr] = nil

	if profile ~= nil then
		profile:EndSession()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

game:BindToClose(function()
	for plr, profile in Profiles do
		Leaving[plr] = true
		Profiles[plr] = nil
		CoinsValues[plr] = nil
		LevelValues[plr] = nil
		profile:EndSession()
	end
	task.wait(DataConfig.ShutdownSaveWait)
end)

return DataService
