--!strict

--[[
	MapRemotes
	Inbound map remotes: UnlockMap and SelectRun from the Play window.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, MapService, RunService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local MapService = require(ServerStorage.Modules.Services.MapService)
local RunService = require(ServerStorage.Modules.Services.RunService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.UnlockMap, "UnlockMap", { "string" }, function(plr, mapId)
		MapService.UnlockMap(plr, mapId)
	end)

	RemoteGuard.Bind(Net.SelectRun, "SelectRun", { "string", "string" }, function(plr, mapId, modeId)
		if RunService.IsPlayerInRun(plr) then
			return
		end
		MapService.SelectRun(plr, mapId, modeId)
	end)
end
