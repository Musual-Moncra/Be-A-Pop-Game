--!strict

--[[
	DailyRewardService
	Owns the 7-day login streak. It derives the claimable day from server time, pays the
	day's reward through DataService and pushes DailyState to the client after every
	change. A claim is only ever a request: nothing the client sends is trusted.

	API:
		DailyRewardService.GetState(plr) -> { Day, CanClaim, SecondsUntilNext, Streak }
		DailyRewardService.Claim(plr) -> ok, reason
		DailyRewardService.Publish(plr)

	Day is the day to claim while CanClaim is true and the day already claimed while it is
	false. SecondsUntilNext counts down the claim cooldown; the client ticks it down.
	Streak is the number of days claimed in the current cycle, 0 after a reset.

	Dependencies: DataService, Outbound, ConfigLookup, DailyRewardConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local DailyRewardConfig = require(ReplicatedStorage.Modules.Config.DailyRewardConfig)
local DataService = require(script.Parent.DataService)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)

export type DailyState = {
	Day: number,
	CanClaim: boolean,
	SecondsUntilNext: number,
	Streak: number,
}

local DailyRewardService = {}

local function currentStreak(data: any, now: number): number
	local daily = data.Daily
	if daily == nil or daily.LastClaim <= 0 then
		return 0
	end
	if now - daily.LastClaim >= DailyRewardConfig.StreakResetAfter then
		return 0
	end
	return math.max(0, math.floor(daily.Streak))
end

local function nextDay(streak: number): number
	return (streak % DailyRewardConfig.StreakLength) + 1
end

local function buildState(plr: Player): DailyState
	local data = DataService.Get(plr)
	if data == nil then
		return { Day = 1, CanClaim = false, SecondsUntilNext = 0, Streak = 0 }
	end

	local daily = data.Daily
	local now = os.time()
	local streak = currentStreak(data, now)
	if daily == nil or daily.LastClaim <= 0 then
		return { Day = nextDay(streak), CanClaim = true, SecondsUntilNext = 0, Streak = streak }
	end

	local elapsed = now - daily.LastClaim
	if elapsed >= DailyRewardConfig.ClaimCooldown then
		return { Day = nextDay(streak), CanClaim = true, SecondsUntilNext = 0, Streak = streak }
	end

	return {
		Day = math.clamp(streak, 1, DailyRewardConfig.StreakLength),
		CanClaim = false,
		SecondsUntilNext = DailyRewardConfig.ClaimCooldown - elapsed,
		Streak = streak,
	}
end

function DailyRewardService.GetState(plr: Player): DailyState
	return buildState(plr)
end

function DailyRewardService.Publish(plr: Player)
	Outbound.DailyState(plr, buildState(plr))
end

function DailyRewardService.Claim(plr: Player): (boolean, string?)
	local data = DataService.Get(plr)
	if data == nil or data.Daily == nil then
		return false, "NoData"
	end

	local state = buildState(plr)
	if not state.CanClaim then
		return false, "Cooldown"
	end

	local reward = ConfigLookup.GetDailyReward(state.Day)
	if reward == nil then
		return false, "NoReward"
	end

	local boostId: string? = nil
	local boostDuration = 0
	if reward.Kind == "Boost" and reward.BoostId ~= "" then
		local boost = ConfigLookup.GetDailyBoost(reward.BoostId)
		boostDuration = if reward.Duration > 0 then reward.Duration else (if boost ~= nil then boost.Duration else 0)
		if boostDuration > 0 then
			boostId = reward.BoostId
		end
	end

	local skinId: string? = nil
	if reward.Kind == "Skin" and reward.SkinId ~= "" then
		skinId = reward.SkinId
	end

	if reward.Kind == "Coins" and reward.Amount > 0 then
		DataService.AddCoins(plr, reward.Amount)
	elseif reward.Kind == "Gems" and reward.Amount > 0 then
		DataService.AddGems(plr, reward.Amount)
	end

	DataService.RecordDailyClaim(plr, state.Day, boostId, boostDuration, skinId)
	DailyRewardService.Publish(plr)
	Outbound.Notify(plr, "Success", string.format(DailyRewardConfig.ClaimToast, reward.Label))
	return true, nil
end

local function publishWhenLoaded(plr: Player)
	task.spawn(function()
		local connection: RBXScriptConnection
		connection = DataService.Changed:Connect(function(changedPlr: Player)
			if changedPlr ~= plr then
				return
			end
			connection:Disconnect()
			DailyRewardService.Publish(plr)
		end)

		if DataService.Get(plr) ~= nil then
			connection:Disconnect()
			DailyRewardService.Publish(plr)
		end
	end)
end

Players.PlayerAdded:Connect(publishWhenLoaded)

for _, plr in Players:GetPlayers() do
	publishWhenLoaded(plr)
end

return DailyRewardService
