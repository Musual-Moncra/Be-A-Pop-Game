--!strict

--[[
	Net
	Single source of truth for every remote (Packet). Require from both realms.
	Packets are created with Packet.new(...); the installed Packet module is not callable.

	Client:
		local Net = require(ReplicatedStorage.Modules.Shared.Net)
		Net.PurchaseUpgrade:Fire("Speed")
		Net.StartRun:Fire()
		Net.SelectRun:Fire(mapId, modeId)
		Net.SelectionSync.OnClientEvent:Connect(function(mapId, modeId) end)
		Net.DataSync.OnClientEvent:Connect(function(snapshot) end)
		Net.RunState.OnClientEvent:Connect(function(state, timeLeft, score) end)
		Net.RunEnded.OnClientEvent:Connect(function(score, coins) end)

	Server:
		local Net = require(ReplicatedStorage.Modules.Shared.Net)
		Net.PurchaseUpgrade.OnServerEvent:Connect(function(player, id) end)
		Net.StartRun.OnServerEvent:Connect(function(player) end)
		Net.SelectRun.OnServerEvent:Connect(function(player, mapId, modeId) end)
		Net.SelectionSync:FireClient(player, mapId, modeId)
		Net.DataSync:FireClient(player, snapshot)
		Net.RunState:FireClient(player, state, timeLeft, score)
		Net.RunEnded:FireClient(player, score, coins)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packet = require(ReplicatedStorage.Packages.Packet)

local Net = {}

Net.PurchaseUpgrade = Packet.new("PurchaseUpgrade", Packet.String)
Net.StartRun = Packet.new("StartRun")
Net.SelectRun = Packet.new("SelectRun", Packet.String, Packet.String)

Net.SelectionSync = Packet.new("SelectionSync", Packet.String, Packet.String)
Net.DataSync = Packet.new("DataSync", Packet.Any)
Net.RunState = Packet.new("RunState", Packet.String, Packet.NumberF64, Packet.NumberF64)
Net.RunEnded = Packet.new("RunEnded", Packet.NumberF64, Packet.NumberF64)

return Net
