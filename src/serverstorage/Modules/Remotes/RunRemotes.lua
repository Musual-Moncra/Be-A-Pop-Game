--!strict

--[[
	RunRemotes
	Inbound run remotes: StartRun and LeaveRun from the Play window and the run HUD.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, RunService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RunService = require(ServerStorage.Modules.Services.RunService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.StartRun, "StartRun", {}, function(plr)
		if not RunService.IsPlayerInRun(plr) then
			RunService.StartRun(plr)
		end
	end)

	RemoteGuard.Bind(Net.LeaveRun, "LeaveRun", {}, function(plr)
		RunService.EndRun(plr, false)
	end)
end
