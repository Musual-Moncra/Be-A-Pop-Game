--!strict

--[[
	PetRemotes
	Inbound pet remotes: hatch an egg, equip/unequip a pet, delete a pet and merge
	five identical pets. Every handler is rate limited and type checked by RemoteGuard.
	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, PetService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local PetService = require(ServerStorage.Modules.Services.PetService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(Net.HatchEgg, "HatchEgg", { "string" }, function(plr, eggId)
		PetService.HatchEgg(plr, eggId)
	end)

	RemoteGuard.Bind(Net.EquipPet, "EquipPet", { "string" }, function(plr, uid)
		PetService.Equip(plr, uid)
	end)

	RemoteGuard.Bind(Net.UnequipPet, "UnequipPet", { "string" }, function(plr, uid)
		PetService.Unequip(plr, uid)
	end)

	RemoteGuard.Bind(Net.DeletePet, "DeletePet", { "string" }, function(plr, uid)
		PetService.Delete(plr, uid)
	end)

	RemoteGuard.Bind(Net.MergePet, "MergePet", { "string" }, function(plr, uid)
		PetService.Merge(plr, uid)
	end)
end
