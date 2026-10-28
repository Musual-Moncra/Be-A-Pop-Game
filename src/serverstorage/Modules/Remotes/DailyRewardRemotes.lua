--!strict

--[[
	DailyRewardRemotes
	Inbound daily reward remote: ClaimDaily from the daily rewards panel.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, DailyRewardService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local DailyRewardService = require(ServerStorage.Modules.Services.DailyRewardService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.ClaimDaily, "ClaimDaily", {}, function(plr)
		DailyRewardService.Claim(plr)
	end)
end
