--!strict

--[[
	PotionRemotes
	Inbound potion remotes: UsePotion from lobby/inventory.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, PotionService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local PotionService = require(ServerStorage.Modules.Services.PotionService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.UsePotion, "UsePotion", { "string" }, function(plr, potionId)
		PotionService.UsePotion(plr, potionId)
	end)
end
