--!strict

--[[
	UpgradeService
	Handles upgrade purchases from the client and applies their stats.

	Purchase flow: validate id -> validate max level -> SpendCoins(cost) ->
	level + 1 -> publish. Any failure simply drops the request; the server
	never trusts client input.

	API:
		UpgradeService.ApplyStats(plr, character?)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.Config.UpgradeConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

local UpgradeService = {}

local LastPurchase: { [Player]: number } = {}
local StatsApplied: { [Player]: boolean } = {}

local function getLevel(data, id: string): number
	local upgrades = data.Upgrades
	if upgrades == nil then
		return 0
	end
	return upgrades[id] or 0
end

function UpgradeService.ApplyStats(plr: Player, character: Model?)
	character = character or plr.Character
	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", DataConfig.HumanoidWaitTimeout) :: Humanoid?
	end
	if humanoid == nil then
		return
	end

	local data = DataService.Get(plr)
	local level = if data ~= nil then getLevel(data, "Speed") else 0

	humanoid.WalkSpeed = UpgradeConfig.GetValue("Speed", level)
end

local function onCharacterAdded(plr: Player, character: Model)
	UpgradeService.ApplyStats(plr, character)
end

local function trackPlayer(plr: Player)
	plr.CharacterAdded:Connect(function(character)
		onCharacterAdded(plr, character)
	end)

	if plr.Character ~= nil then
		UpgradeService.ApplyStats(plr, plr.Character)
	end
end

DataService.Changed:Connect(function(plr, _data)
	if StatsApplied[plr] then
		return
	end
	StatsApplied[plr] = true
	UpgradeService.ApplyStats(plr, plr.Character)
end)

Net.PurchaseUpgrade.OnServerEvent:Connect(function(plr, id)
	local now = os.clock()
	local last = LastPurchase[plr]
	if last ~= nil and now - last < DataConfig.PurchaseRateLimit then
		return
	end
	LastPurchase[plr] = now

	if type(id) ~= "string" then
		return
	end

	local definition = UpgradeConfig.Upgrades[id]
	if definition == nil then
		return
	end

	local data = DataService.Get(plr)
	if data == nil then
		return
	end

	local level = getLevel(data, id)
	if level >= definition.MaxLevel then
		return
	end

	local cost = UpgradeConfig.GetCost(id, level)
	if not DataService.SpendCoins(plr, cost) then
		return
	end

	data.Upgrades[id] = level + 1
	DataService.MarkChanged(plr)

	if id == "Speed" then
		UpgradeService.ApplyStats(plr, plr.Character)
	end
end)

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(plr)
	LastPurchase[plr] = nil
	StatsApplied[plr] = nil
end)

for _, plr in Players:GetPlayers() do
	trackPlayer(plr)
end

return UpgradeService
