--!strict

--[[
	CosmeticRemotes
	Inbound cosmetic remotes: OpenCrate and EquipCosmetic.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, CosmeticService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local CosmeticService = require(ServerStorage.Modules.Services.CosmeticService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.OpenCrate, "OpenCrate", { "string" }, function(plr, crateId)
		CosmeticService.OpenCrate(plr, crateId)
	end)

	RemoteGuard.Bind(Net.EquipCosmetic, "EquipCosmetic", { "string", "string" }, function(plr, kind, id)
		CosmeticService.Equip(plr, kind, id)
	end)
end
