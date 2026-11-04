--!strict

--[[
	RoomRemotes
	Inbound room remotes: create, update, join, leave, ready, start, kick, invite and the
	room-browser watch switch. Every handler goes through RemoteGuard; RoomService does all
	validation. Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: RemoteGuard, RoomService, Net
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)
local RoomService = require(ServerStorage.Modules.Services.RoomService)
local RemoteGuard = require(script.Parent.RemoteGuard)

return function()
	RemoteGuard.Bind(
		Net.CreateRoom,
		"CreateRoom",
		{ "string", "string", "number", "boolean" },
		function(plr, mapId, modeId, maxPlayers, friendsOnly)
			RoomService.CreateRoom(plr, mapId, modeId, maxPlayers, friendsOnly)
		end
	)

	RemoteGuard.Bind(
		Net.UpdateRoom,
		"UpdateRoom",
		{ "string", "string", "number", "boolean" },
		function(plr, mapId, modeId, maxPlayers, friendsOnly)
			RoomService.UpdateRoom(plr, mapId, modeId, maxPlayers, friendsOnly)
		end
	)

	RemoteGuard.Bind(Net.JoinRoom, "JoinRoom", { "number" }, function(plr, roomId)
		RoomService.JoinRoom(plr, roomId)
	end)

	RemoteGuard.Bind(Net.LeaveRoom, "LeaveRoom", {}, function(plr)
		RoomService.LeaveRoom(plr)
	end)

	RemoteGuard.Bind(Net.SetRoomReady, "SetRoomReady", { "boolean" }, function(plr, ready)
		RoomService.SetReady(plr, ready)
	end)

	RemoteGuard.Bind(Net.StartRoom, "StartRoom", {}, function(plr)
		RoomService.StartRoom(plr)
	end)

	RemoteGuard.Bind(Net.KickRoomMember, "KickRoomMember", { "number" }, function(plr, userId)
		RoomService.KickMember(plr, userId)
	end)

	RemoteGuard.Bind(Net.InviteToRoom, "InviteToRoom", { "number" }, function(plr, userId)
		RoomService.Invite(plr, userId)
	end)

	RemoteGuard.Bind(Net.WatchRooms, "WatchRooms", { "boolean" }, function(plr, watching)
		RoomService.WatchRooms(plr, watching)
	end)
end
