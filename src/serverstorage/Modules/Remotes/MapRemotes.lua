--!strict

--[[
	MapRemotes
	Inbound map remote: UnlockMap from the map card. Map and mode are chosen when a room is
	created, so there is no SelectRun packet. Started by runFramework at Priority 5.

	Dependencies: RemoteGuard, MapService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local MapService = require(ServerStorage.Modules.Services.MapService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.UnlockMap, "UnlockMap", { "string" }, function(plr, mapId)
		MapService.UnlockMap(plr, mapId)
	end)
end
