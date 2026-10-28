--!strict

--[[
	RebirthRemotes
	Inbound rebirth remote: Rebirth triggered from client.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, RebirthService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RebirthService = require(ServerStorage.Modules.Services.RebirthService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.Rebirth, "Rebirth", {}, function(plr)
		RebirthService.Rebirth(plr)
	end)
end
