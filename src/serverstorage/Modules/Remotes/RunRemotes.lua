--!strict

--[[
	RunRemotes
	Inbound run remote: LeaveRun from the run HUD. Runs are started by RoomService, never by
	the client. Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, RunService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RunService = require(ServerStorage.Modules.Services.RunService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.LeaveRun, "LeaveRun", {}, function(plr)
		RunService.EndRun(plr, false)
	end)
end
