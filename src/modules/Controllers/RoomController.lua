--!strict

--[[
	RoomController
	Client store for the play-room packets. Net.RoomState carries the room this client is in,
	Net.RoomList carries the joinable rooms while the browser is watching, Net.RoomInvite
	carries a friend invite and Net.OpenRoomMenu asks for the play window. Screens read
	RoomController.Get() and subscribe to RoomController.Changed.

	API:
		RoomController.Get() -> State
		RoomController.Changed -> Signal (fires with the new State)
		RoomController.OpenRequested -> Signal ()       open the play window
		RoomController.SetWatching(watching)           fires Net.WatchRooms, true while browsing
		RoomController.DismissInvite()                 drops the pending invite prompt

	State:
		Room: the room this client is in, nil when not in one (RoomState payload)
		Rooms: joinable rooms sent while watching (RoomSummary list)
		Invite: pending friend invite { RoomId, HostName, MapId }, nil when none
		Watching: true while Net.WatchRooms(true) is in effect (true/false)

	Dependencies: Net, Signal, DataController, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

export type RoomMember = {
	UserId: number,
	Name: string,
	Level: number,
	Ready: boolean,
	IsFriend: boolean,
}

export type Room = {
	InRoom: boolean,
	Id: number,
	HostId: number,
	MapId: string,
	ModeId: string,
	MaxPlayers: number,
	FriendsOnly: boolean,
	Status: string,
	StartsAt: number,
	Members: { RoomMember },
}

export type RoomSummary = {
	Id: number,
	HostName: string,
	MapId: string,
	ModeId: string,
	Players: number,
	MaxPlayers: number,
	FriendsOnly: boolean,
	HostIsFriend: boolean,
}

export type Invite = {
	RoomId: number,
	HostName: string,
	MapId: string,
}

export type State = {
	Room: Room?,
	Rooms: { RoomSummary },
	Invite: Invite?,
	Watching: boolean,
}

local RoomController = {}

RoomController.Changed = Signal.new()
RoomController.OpenRequested = Signal.new()

local state: State = {
	Room = nil,
	Rooms = {},
	Invite = nil,
	Watching = false,
}

local publishScheduled = false

local function publish()
	if not publishScheduled then
		publishScheduled = true
		task.defer(function()
			publishScheduled = false
			state = table.clone(state)
			RoomController.Changed:Fire(state)
		end)
	end
end

local function cleanMembers(source: any): { RoomMember }
	local members: { RoomMember } = {}
	if type(source) ~= "table" then
		return members
	end
	for _, entry in source do
		if type(entry) == "table" and tonumber(entry.UserId) ~= nil then
			table.insert(members, {
				UserId = math.floor(tonumber(entry.UserId) or 0),
				Name = if type(entry.Name) == "string" then entry.Name else "",
				Level = math.max(0, math.floor(tonumber(entry.Level) or 0)),
				Ready = entry.Ready == true,
				IsFriend = entry.IsFriend == true,
			})
		end
	end
	return members
end

local function cleanRoom(payload: any): Room?
	if type(payload) ~= "table" or payload.InRoom ~= true then
		return nil
	end
	return {
		InRoom = true,
		Id = math.max(0, math.floor(tonumber(payload.Id) or 0)),
		HostId = math.floor(tonumber(payload.HostId) or 0),
		MapId = if type(payload.MapId) == "string" then payload.MapId else "",
		ModeId = if type(payload.ModeId) == "string" then payload.ModeId else "",
		MaxPlayers = math.max(1, math.floor(tonumber(payload.MaxPlayers) or 1)),
		FriendsOnly = payload.FriendsOnly == true,
		Status = if type(payload.Status) == "string" then payload.Status else "",
		StartsAt = tonumber(payload.StartsAt) or 0,
		Members = cleanMembers(payload.Members),
	}
end

local function cleanSummaries(source: any): { RoomSummary }
	local rooms: { RoomSummary } = {}
	if type(source) ~= "table" then
		return rooms
	end
	for _, entry in source do
		if type(entry) == "table" and tonumber(entry.Id) ~= nil then
			table.insert(rooms, {
				Id = math.floor(tonumber(entry.Id) or 0),
				HostName = if type(entry.HostName) == "string" then entry.HostName else "",
				MapId = if type(entry.MapId) == "string" then entry.MapId else "",
				ModeId = if type(entry.ModeId) == "string" then entry.ModeId else "",
				Players = math.max(0, math.floor(tonumber(entry.Players) or 0)),
				MaxPlayers = math.max(1, math.floor(tonumber(entry.MaxPlayers) or 1)),
				FriendsOnly = entry.FriendsOnly == true,
				HostIsFriend = entry.HostIsFriend == true,
			})
		end
	end
	return rooms
end

function RoomController.Get(): State
	return state
end

function RoomController.SetWatching(watching: boolean)
	if state.Watching == watching then
		return
	end
	state.Watching = watching
	Net.WatchRooms:Fire(watching)
	publish()
end

function RoomController.DismissInvite()
	if state.Invite == nil then
		return
	end
	state.Invite = nil
	publish()
end

Net.RoomState.OnClientEvent:Connect(function(payload: any)
	state.Room = cleanRoom(payload)
	if state.Room ~= nil then
		state.Invite = nil
	end
	publish()
end)

Net.RoomList.OnClientEvent:Connect(function(payload: any)
	state.Rooms = cleanSummaries(payload)
	publish()
end)

Net.RoomInvite.OnClientEvent:Connect(function(roomId: any, hostName: any, mapId: any)
	local id = math.floor(tonumber(roomId) or 0)
	if id <= 0 then
		return
	end
	local name = if type(hostName) == "string" then hostName else ""
	state.Invite = {
		RoomId = id,
		HostName = name,
		MapId = if type(mapId) == "string" then mapId else "",
	}
	publish()
	DataController.PushToast(UIConfig.Text.ToastInfoKind, string.format(UIConfig.Text.InviteToastFormat, name))
end)

Net.OpenRoomMenu.OnClientEvent:Connect(function()
	RoomController.OpenRequested:Fire()
end)

return RoomController
