--!strict

--[[
	UpgradeService
	Validates upgrade purchases and applies upgrade stats to the character.

	Purchase flow: validate id -> validate max level -> SpendCoins(cost) ->
	level + 1 -> publish -> notify. Every failure is reported to the player;
	the server never trusts client input. The remote itself is bound in Remotes.UpgradeRemotes.

	API:
		UpgradeService.Purchase(plr, upgradeId) -> boolean
		UpgradeService.ApplyStats(plr, character?)

	Dependencies: DataService, Outbound, ConfigLookup, MessageConfig, DataConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)

local UpgradeService = {}

local StatsApplied: { [Player]: boolean } = {}
local PlayerConnections: { [Player]: { RBXScriptConnection } } = {}

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
		if character.Parent == nil then
			return
		end
		humanoid = character:WaitForChild("Humanoid", DataConfig.HumanoidWaitTimeout) :: Humanoid?
	end
	if humanoid == nil then
		return
	end

	local data = DataService.Get(plr)
	local level = if data ~= nil then getLevel(data, "Speed") else 0
	humanoid.WalkSpeed = ConfigLookup.GetUpgradeValue("Speed", level)
end

function UpgradeService.Purchase(plr: Player, id: string): boolean
	local definition = ConfigLookup.GetUpgrade(id)
	local data = DataService.Get(plr)
	if definition == nil or data == nil or data.Upgrades == nil then
		return false
	end

	local level = getLevel(data, id)
	if level >= definition.MaxLevel then
		Outbound.Notify(plr, "Error", MessageConfig.MaxLevelReached)
		return false
	end

	if not DataService.SpendCoins(plr, ConfigLookup.GetUpgradeCost(id, level)) then
		Outbound.Notify(plr, "Error", MessageConfig.NotEnoughCoins)
		return false
	end

	data.Upgrades[id] = level + 1
	DataService.MarkChanged(plr)

	if id == "Speed" then
		UpgradeService.ApplyStats(plr, plr.Character)
	end

	Outbound.Notify(plr, "Success", string.format(MessageConfig.UpgradeBought, definition.DisplayName))
	return true
end

local function trackPlayer(plr: Player)
	if PlayerConnections[plr] ~= nil then
		return
	end
	PlayerConnections[plr] = {
		plr.CharacterAdded:Connect(function(character)
			UpgradeService.ApplyStats(plr, character)
		end),
	}
	if plr.Character ~= nil then
		task.spawn(UpgradeService.ApplyStats, plr, plr.Character)
	end
end

DataService.Changed:Connect(function(plr, _data)
	if StatsApplied[plr] then
		return
	end
	StatsApplied[plr] = true
	UpgradeService.ApplyStats(plr, plr.Character)
end)

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(plr)
	StatsApplied[plr] = nil
	local connections = PlayerConnections[plr]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
		PlayerConnections[plr] = nil
	end
end)

for _, plr in Players:GetPlayers() do
	trackPlayer(plr)
end

return UpgradeService
