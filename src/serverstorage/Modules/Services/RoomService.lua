--!strict

--[[
	RoomService
	Owns play rooms and their lifecycle. A host creates a room with a map, a mode and a size;
	members join, mark ready and the host starts a countdown. When the countdown ends the
	service acquires a private map copy from MapInstanceService, starts one run per member in
	that copy and keeps the room Running until every run ended, then releases the map and
	closes the room. All checks (map ownership, mode level, size, friendship, kick block,
	ready flags, host-only actions) run here on the server.

	API:
		RoomService.CreateRoom(plr, mapId, modeId, maxPlayers, friendsOnly)
		RoomService.UpdateRoom(plr, mapId, modeId, maxPlayers, friendsOnly)
		RoomService.JoinRoom(plr, roomId)
		RoomService.LeaveRoom(plr)
		RoomService.SetReady(plr, ready)
		RoomService.StartRoom(plr)
		RoomService.KickMember(plr, userId)
		RoomService.Invite(plr, userId)
		RoomService.WatchRooms(plr, watching)

	RoomState goes to every member on every change; RoomList goes to watchers, throttled by
	RoomConfig.ListSyncInterval and limited to Waiting rooms that are not full. A friends-only
	room only appears to friends of its host.

	Dependencies: Players, Workspace, DataService, MapInstanceService, NpcService, RunService,
		Outbound, RunEvents, ConfigLookup, MessageConfig, RoomConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Services = ServerStorage.Modules.Services
local DataService = require(Services.DataService)
local MapInstanceService = require(Services.MapInstanceService)
local NpcService = require(Services.NpcService)
local RunService = require(Services.RunService)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)

local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local RoomConfig = require(ReplicatedStorage.Modules.Config.RoomConfig)

local WAITING = "Waiting"
local COUNTDOWN = "Countdown"
local RUNNING = "Running"

type Member = {
	ready: boolean,
}

type Room = {
	id: number,
	host: Player,
	members: { [Player]: Member },
	order: { Player },
	mapId: string,
	modeId: string,
	maxPlayers: number,
	friendsOnly: boolean,
	status: string,
	startsAt: number,
	countdownToken: number,
	instance: MapInstanceService.MapInstance?,
	runsLeft: number,
	kicked: { [number]: number },
	inviteAt: { [number]: number },
	closing: boolean,
}

type FriendEntry = {
	value: boolean,
	at: number,
}

local RoomService = {}

local rooms: { [number]: Room } = {}
local roomByPlayer: { [Player]: Room } = {}
local roomOfRun: { [Player]: Room } = {}
local watchers: { [Player]: boolean } = {}
local listNextAt: { [Player]: number } = {}
local listScheduled: { [Player]: boolean } = {}
local friendCache: { [number]: { [number]: FriendEntry } } = {}
local nextRoomId = 0

local function getLevel(plr: Player): number
	local data = DataService.Get(plr)
	local level: number = if data ~= nil then data.Level else 1
	return level
end

local function isFriend(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	local now = os.clock()
	local row = friendCache[a.UserId]
	local entry = if row ~= nil then row[b.UserId] else nil
	if entry ~= nil and now - entry.at < RoomConfig.FriendCacheTime then
		return entry.value
	end

	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value: boolean = ok and result == true
	if row == nil then
		row = {}
		friendCache[a.UserId] = row
	end
	row[b.UserId] = { value = value, at = now }
	return value
end

local function isPlayerOption(value: number): boolean
	for _, option in RoomConfig.PlayerOptions do
		if option == value then
			return true
		end
	end
	return false
end

local function roomCount(): number
	local count = 0
	for _ in rooms do
		count += 1
	end
	return count
end

local function allocateRoomId(): number?
	for _ = 1, 65535 do
		nextRoomId = nextRoomId % 65535 + 1
		if rooms[nextRoomId] == nil then
			return nextRoomId
		end
	end
	return nil
end

local function emptyState(): any
	return {
		InRoom = false,
		Id = 0,
		HostId = 0,
		MapId = "",
		ModeId = "",
		MaxPlayers = 0,
		FriendsOnly = false,
		Status = WAITING,
		StartsAt = 0,
		Members = {},
	}
end

local function roomState(room: Room): any
	local order = table.clone(room.order)
	local friendFlags: { [Player]: boolean } = {}
	for _, plr in order do
		friendFlags[plr] = isFriend(room.host, plr)
	end

	local members = {}
	for _, plr in order do
		local member = room.members[plr]
		if member ~= nil then
			table.insert(members, {
				UserId = plr.UserId,
				Name = plr.DisplayName,
				Level = getLevel(plr),
				Ready = if plr == room.host then true else member.ready,
				IsFriend = friendFlags[plr] == true,
			})
		end
	end

	return {
		InRoom = true,
		Id = room.id,
		HostId = room.host.UserId,
		MapId = room.mapId,
		ModeId = room.modeId,
		MaxPlayers = room.maxPlayers,
		FriendsOnly = room.friendsOnly,
		Status = room.status,
		StartsAt = room.startsAt,
		Members = members,
	}
end

local function broadcast(room: Room)
	local order = table.clone(room.order)
	local payload = roomState(room)
	for _, plr in order do
		if roomByPlayer[plr] == room then
			Outbound.RoomState(plr, payload)
		end
	end
end

local function sendList(plr: Player)
	local snapshot = {}
	for _, room in rooms do
		table.insert(snapshot, room)
	end

	local entries = {}
	for _, room in snapshot do
		if room.status == WAITING and #room.order < room.maxPlayers then
			local friend = isFriend(plr, room.host)
			if not room.friendsOnly or friend then
				table.insert(entries, {
					Id = room.id,
					HostName = room.host.DisplayName,
					MapId = room.mapId,
					ModeId = room.modeId,
					Players = #room.order,
					MaxPlayers = room.maxPlayers,
					FriendsOnly = room.friendsOnly,
					HostIsFriend = friend,
				})
			end
		end
	end
	Outbound.RoomList(plr, entries)
end

local function refreshList(plr: Player)
	if watchers[plr] ~= true then
		return
	end
	local now = os.clock()
	local wait = (listNextAt[plr] or 0) - now
	if wait > 0 then
		if listScheduled[plr] == true then
			return
		end
		listScheduled[plr] = true
		task.delay(wait, function()
			listScheduled[plr] = nil
			if watchers[plr] ~= true then
				return
			end
			listNextAt[plr] = os.clock() + RoomConfig.ListSyncInterval
			sendList(plr)
		end)
		return
	end
	listNextAt[plr] = now + RoomConfig.ListSyncInterval
	sendList(plr)
end

local function refreshLists()
	local snapshot = {}
	for plr in watchers do
		table.insert(snapshot, plr)
	end
	for _, plr in snapshot do
		refreshList(plr)
	end
end

local function closeRoom(room: Room)
	if room.closing then
		return
	end
	room.closing = true
	rooms[room.id] = nil

	local runningPlayers = {}
	for plr, runRoom in roomOfRun do
		if runRoom == room then
			table.insert(runningPlayers, plr)
		end
	end
	for _, plr in runningPlayers do
		roomOfRun[plr] = nil
	end

	local order = table.clone(room.order)
	for _, plr in order do
		roomByPlayer[plr] = nil
		Outbound.RoomState(plr, emptyState())
	end
	table.clear(room.members)
	table.clear(room.order)

	local instance = room.instance
	room.instance = nil
	if instance ~= nil then
		NpcService.SetInstanceActive(instance.model, false)
		task.delay(RoomConfig.EmptyRoomGrace, function()
			MapInstanceService.Release(instance)
		end)
	end

	refreshLists()
end

local function detach(room: Room, plr: Player)
	roomByPlayer[plr] = nil
	room.members[plr] = nil
	local index = table.find(room.order, plr)
	if index ~= nil then
		table.remove(room.order, index)
	end
end

local function afterLeave(room: Room, left: Player)
	if room.closing or rooms[room.id] ~= room then
		return
	end
	if #room.order == 0 then
		closeRoom(room)
		return
	end
	if room.host == left then
		local nextHost = room.order[1]
		if nextHost ~= nil then
			room.host = nextHost
		end
		for _, member in room.members do
			member.ready = false
		end
		if room.status == COUNTDOWN then
			room.status = WAITING
			room.countdownToken += 1
			room.startsAt = 0
		end
	end
	broadcast(room)
	refreshLists()
end

local function finishRun(plr: Player)
	local room = roomOfRun[plr]
	if room == nil then
		return
	end
	roomOfRun[plr] = nil
	if room.closing or rooms[room.id] ~= room then
		return
	end
	room.runsLeft -= 1
	if room.runsLeft <= 0 then
		room.runsLeft = 0
		closeRoom(room)
	end
end

local function addMember(room: Room, plr: Player, ready: boolean)
	room.members[plr] = { ready = ready }
	table.insert(room.order, plr)
	roomByPlayer[plr] = room
end

local function beginRun(room: Room)
	local mapDef = ConfigLookup.GetMap(room.mapId)
	local modeDef = ConfigLookup.GetMode(room.modeId)
	if mapDef == nil or modeDef == nil then
		room.status = WAITING
		room.startsAt = 0
		broadcast(room)
		return
	end

	local instance = MapInstanceService.Acquire(mapDef)
	if instance == nil then
		room.status = WAITING
		room.startsAt = 0
		broadcast(room)
		local order = table.clone(room.order)
		for _, plr in order do
			Outbound.Notify(plr, "Error", MessageConfig.RoomUnavailable)
		end
		return
	end

	room.instance = instance
	room.status = RUNNING
	room.startsAt = 0
	NpcService.SetupInstance(instance)

	local order = table.clone(room.order)
	local started = 0
	for _, plr in order do
		if roomByPlayer[plr] == room then
			if RunService.StartRun(plr, instance, modeDef) then
				if roomByPlayer[plr] == room then
					started += 1
					roomOfRun[plr] = room
				else
					RunService.EndRun(plr, false)
				end
			else
				detach(room, plr)
				Outbound.RoomState(plr, emptyState())
				Outbound.Notify(plr, "Error", MessageConfig.RoomRunFailed)
			end
		end
	end

	if roomByPlayer[room.host] ~= room then
		local nextHost = room.order[1]
		if nextHost ~= nil then
			room.host = nextHost
			for _, member in room.members do
				member.ready = false
			end
		end
	end

	if started == 0 or #room.order == 0 then
		closeRoom(room)
		return
	end

	room.runsLeft = started
	broadcast(room)
	refreshLists()
end

local function startCountdown(room: Room)
	room.status = COUNTDOWN
	room.countdownToken += 1
	local token = room.countdownToken
	local seconds = if #room.order == 1 then RoomConfig.SoloStartCountdown else RoomConfig.StartCountdown
	room.startsAt = Workspace:GetServerTimeNow() + seconds
	broadcast(room)
	refreshLists()

	task.delay(seconds, function()
		if room.countdownToken ~= token or room.status ~= COUNTDOWN or rooms[room.id] ~= room then
			return
		end
		beginRun(room)
	end)
end

function RoomService.CreateRoom(plr: Player, mapId: string, modeId: string, maxPlayers: number, friendsOnly: boolean)
	if RunService.IsPlayerInRun(plr) then
		Outbound.Notify(plr, "Error", MessageConfig.RoomInRun)
		return
	end
	if roomByPlayer[plr] ~= nil then
		Outbound.Notify(plr, "Error", MessageConfig.AlreadyInRoom)
		return
	end
	if DataService.Get(plr) == nil then
		Outbound.Notify(plr, "Error", MessageConfig.DataLoading)
		return
	end
	if roomCount() >= RoomConfig.MaxRooms then
		Outbound.Notify(plr, "Error", MessageConfig.RoomLimit)
		return
	end

	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil or not mapDef.Enabled then
		Outbound.Notify(plr, "Error", MessageConfig.MapUnavailable)
		return
	end
	if MapInstanceService.GetTemplate(mapDef) == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomUnavailable)
		return
	end
	if not DataService.IsMapUnlocked(plr, mapId) then
		Outbound.Notify(plr, "Error", MessageConfig.MapLocked)
		return
	end

	local modeDef = ConfigLookup.GetMode(modeId)
	if modeDef == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomModeUnavailable)
		return
	end
	if getLevel(plr) < modeDef.RequiredLevel then
		Outbound.Notify(plr, "Error", string.format(MessageConfig.ModeLocked, modeDef.RequiredLevel))
		return
	end
	if not isPlayerOption(maxPlayers) then
		Outbound.Notify(plr, "Error", MessageConfig.RoomSizeInvalid)
		return
	end

	local roomId = allocateRoomId()
	if roomId == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomLimit)
		return
	end

	local room: Room = {
		id = roomId,
		host = plr,
		members = {},
		order = {},
		mapId = mapId,
		modeId = modeId,
		maxPlayers = maxPlayers,
		friendsOnly = friendsOnly,
		status = WAITING,
		startsAt = 0,
		countdownToken = 0,
		instance = nil,
		runsLeft = 0,
		kicked = {},
		inviteAt = {},
		closing = false,
	}
	rooms[roomId] = room
	addMember(room, plr, true)
	broadcast(room)
	refreshLists()
end

function RoomService.UpdateRoom(plr: Player, mapId: string, modeId: string, maxPlayers: number, friendsOnly: boolean)
	local room = roomByPlayer[plr]
	if room == nil then
		return
	end
	if room.host ~= plr then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotHost)
		return
	end
	if room.status ~= WAITING then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotWaiting)
		return
	end

	local mapDef = ConfigLookup.GetMap(mapId)
	if mapDef == nil or not mapDef.Enabled then
		Outbound.Notify(plr, "Error", MessageConfig.MapUnavailable)
		return
	end
	if MapInstanceService.GetTemplate(mapDef) == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomUnavailable)
		return
	end

	local modeDef = ConfigLookup.GetMode(modeId)
	if modeDef == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomModeUnavailable)
		return
	end
	if getLevel(plr) < modeDef.RequiredLevel then
		Outbound.Notify(plr, "Error", string.format(MessageConfig.ModeLocked, modeDef.RequiredLevel))
		return
	end
	if not isPlayerOption(maxPlayers) or maxPlayers < #room.order then
		Outbound.Notify(plr, "Error", MessageConfig.RoomSizeInvalid)
		return
	end

	for _, member in room.order do
		if not DataService.IsMapUnlocked(member, mapId) then
			local text = string.format(MessageConfig.RoomMemberMapLocked, member.DisplayName, mapDef.DisplayName)
			Outbound.Notify(plr, "Error", text)
			return
		end
	end

	room.mapId = mapId
	room.modeId = modeId
	room.maxPlayers = maxPlayers
	room.friendsOnly = friendsOnly
	broadcast(room)
	refreshLists()
end

function RoomService.JoinRoom(plr: Player, roomId: number)
	if RunService.IsPlayerInRun(plr) then
		Outbound.Notify(plr, "Error", MessageConfig.RoomInRun)
		return
	end
	if roomByPlayer[plr] ~= nil then
		Outbound.Notify(plr, "Error", MessageConfig.AlreadyInRoom)
		return
	end

	local room = rooms[roomId]
	if room == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotFound)
		return
	end
	if room.status ~= WAITING and room.status ~= COUNTDOWN then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotWaiting)
		return
	end
	if #room.order >= room.maxPlayers then
		Outbound.Notify(plr, "Error", MessageConfig.RoomFull)
		return
	end
	local blockedUntil = room.kicked[plr.UserId]
	if blockedUntil ~= nil and os.clock() < blockedUntil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomJoinBlocked)
		return
	end
	if DataService.Get(plr) == nil then
		Outbound.Notify(plr, "Error", MessageConfig.DataLoading)
		return
	end
	if not DataService.IsMapUnlocked(plr, room.mapId) then
		Outbound.Notify(plr, "Error", MessageConfig.RoomMapLocked)
		return
	end

	if room.friendsOnly then
		local host = room.host
		local friend = isFriend(host, plr)
		if not friend then
			Outbound.Notify(plr, "Error", MessageConfig.RoomFriendsOnly)
			return
		end
		if rooms[room.id] ~= room then
			Outbound.Notify(plr, "Error", MessageConfig.RoomNotFound)
			return
		end
		if room.status ~= WAITING and room.status ~= COUNTDOWN then
			Outbound.Notify(plr, "Error", MessageConfig.RoomNotWaiting)
			return
		end
		if #room.order >= room.maxPlayers then
			Outbound.Notify(plr, "Error", MessageConfig.RoomFull)
			return
		end
	end

	addMember(room, plr, room.status == COUNTDOWN)
	broadcast(room)
	refreshLists()
end

function RoomService.LeaveRoom(plr: Player)
	local room = roomByPlayer[plr]
	if room == nil then
		return
	end
	detach(room, plr)
	Outbound.RoomState(plr, emptyState())
	afterLeave(room, plr)
	if RunService.IsPlayerInRun(plr) then
		RunService.EndRun(plr, false)
	end
end

function RoomService.SetReady(plr: Player, ready: boolean)
	local room = roomByPlayer[plr]
	if room == nil or room.status ~= WAITING then
		return
	end
	local member = room.members[plr]
	if member == nil or room.host == plr then
		return
	end
	member.ready = ready
	broadcast(room)
end

function RoomService.StartRoom(plr: Player)
	local room = roomByPlayer[plr]
	if room == nil then
		return
	end
	if room.host ~= plr then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotHost)
		return
	end
	if room.status ~= WAITING then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotWaiting)
		return
	end

	if RoomConfig.RequireAllReady then
		for _, member in room.order do
			local entry = room.members[member]
			if member ~= room.host and entry ~= nil and entry.ready ~= true then
				Outbound.Notify(plr, "Error", MessageConfig.RoomReadyNeeded)
				return
			end
		end
	end

	startCountdown(room)
end

function RoomService.KickMember(plr: Player, userId: number)
	local room = roomByPlayer[plr]
	if room == nil then
		return
	end
	if room.host ~= plr then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotHost)
		return
	end
	if room.status == RUNNING then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotWaiting)
		return
	end

	local target = Players:GetPlayerByUserId(userId)
	if target == nil or target == room.host or room.members[target] == nil then
		return
	end

	room.kicked[userId] = os.clock() + RoomConfig.KickBlockTime
	detach(room, target)
	Outbound.RoomState(target, emptyState())
	Outbound.Notify(target, "Error", MessageConfig.RoomKicked)
	afterLeave(room, target)
end

function RoomService.Invite(plr: Player, userId: number)
	local room = roomByPlayer[plr]
	if room == nil then
		return
	end
	if room.host ~= plr then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotHost)
		return
	end
	if room.status == RUNNING then
		Outbound.Notify(plr, "Error", MessageConfig.RoomNotWaiting)
		return
	end

	local target = Players:GetPlayerByUserId(userId)
	if target == nil then
		Outbound.Notify(plr, "Error", MessageConfig.RoomInviteOffline)
		return
	end
	if target == plr or room.members[target] ~= nil then
		return
	end
	if not isFriend(plr, target) then
		Outbound.Notify(plr, "Error", MessageConfig.RoomInviteNotFriend)
		return
	end

	local now = os.clock()
	local last = room.inviteAt[userId]
	if last ~= nil and now - last < RoomConfig.InviteCooldown then
		Outbound.Notify(plr, "Error", string.format(MessageConfig.RoomInviteCooldown, target.DisplayName))
		return
	end
	room.inviteAt[userId] = now

	Outbound.RoomInvite(target, room.id, plr.DisplayName, room.mapId)
	Outbound.Notify(plr, "Success", string.format(MessageConfig.RoomInviteSent, target.DisplayName))
end

function RoomService.WatchRooms(plr: Player, watching: boolean)
	if watching then
		watchers[plr] = true
		listNextAt[plr] = 0
		refreshList(plr)
	else
		watchers[plr] = nil
		listNextAt[plr] = nil
		listScheduled[plr] = nil
	end
end

RunEvents.RunEnded:Connect(function(plr: Player)
	finishRun(plr)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	watchers[plr] = nil
	listNextAt[plr] = nil
	listScheduled[plr] = nil
	friendCache[plr.UserId] = nil

	local room = roomByPlayer[plr]
	if room == nil then
		roomOfRun[plr] = nil
		return
	end

	local wasRunning = roomOfRun[plr] ~= nil
	roomOfRun[plr] = nil
	detach(room, plr)

	if wasRunning and not room.closing and rooms[room.id] == room then
		room.runsLeft -= 1
		if room.runsLeft <= 0 then
			closeRoom(room)
			return
		end
	end
	afterLeave(room, plr)
end)

return RoomService
