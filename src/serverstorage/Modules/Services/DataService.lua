--!strict

--[[
	DataService
	Owns every player profile and is the only place that writes Profile.Data.

	Profiles live in the ProfileStore named in DataConfig (schema v1). Sessions are
	locked, and a player whose profile cannot be loaded is kicked rather than
	allowed to play with data that will never be saved.

	API:
		DataService.Get(plr)            -> data | nil
		DataService.AddCoins(plr, n)
		DataService.SpendCoins(plr, n)  -> bool
		DataService.RecordRun(plr, score)
		DataService.MarkChanged(plr)    re-publish after an external mutation
		DataService.Changed             -> Signal (plr, data)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.Packages.ProfileStore)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)

local PlayerStore = ProfileStore.New(DataConfig.StoreName, DataConfig.Template)

local DataService = {}

DataService.Changed = Signal.new()

local Profiles: { [Player]: any } = {}
local CoinsValues: { [Player]: IntValue } = {}
local Leaving: { [Player]: boolean } = {}

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
end

local function publish(plr: Player, data)
	DataService.Changed:Fire(plr, data)
	updateLeaderstats(plr, data)
	if plr.Parent == Players then
		Net.DataSync:FireClient(plr, data)
	end
end

function DataService.AddCoins(plr: Player, amount: number)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	data.Coins += amount
	publish(plr, data)
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
	publish(plr, data)
	return true
end

function DataService.RecordRun(plr: Player, score: number)
	local data = DataService.Get(plr)
	if data == nil or data.Stats == nil then
		return
	end
	data.Stats.TotalRuns += 1
	data.Stats.BestScore = math.max(data.Stats.BestScore, score)
	publish(plr, data)
end

function DataService.MarkChanged(plr: Player)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	publish(plr, data)
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

	coins.Value = data.Coins
	CoinsValues[plr] = coins
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
	publish(plr, profile.Data)
end

local function onPlayerRemoving(plr: Player)
	local profile = Profiles[plr]

	Leaving[plr] = true
	Profiles[plr] = nil
	CoinsValues[plr] = nil

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
		profile:EndSession()
	end
	task.wait(DataConfig.ShutdownSaveWait)
end)

return DataService
