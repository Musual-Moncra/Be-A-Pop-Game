--!strict

--[[
	UpgradeRemotes
	Inbound upgrade remote: PurchaseUpgrade from the Upgrade window.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, UpgradeService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local UpgradeService = require(ServerStorage.Modules.Services.UpgradeService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.PurchaseUpgrade, "PurchaseUpgrade", { "string" }, function(plr, upgradeId)
		UpgradeService.Purchase(plr, upgradeId)
	end)
end
