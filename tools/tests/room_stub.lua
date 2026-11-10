-- Headless harness for RoomService: fake players, stubbed services and a manual scheduler.
local clock = 0
local queue = {}
local os = {
	clock = function()
		return clock
	end,
}
local function pump(seconds)
	clock += seconds or 0
	local again = true
	while again do
		again = false
		for i, item in queue do
			if item.at <= clock then
				table.remove(queue, i)
				item.fn()
				again = true
				break
			end
		end
	end
end
local task = {
	delay = function(s, fn, ...)
		local a = { ... }
		table.insert(queue, {
			at = clock + s,
			fn = function()
				fn(table.unpack(a))
			end,
		})
	end,
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err)
		end
	end,
}
local Signal = function()
	local handlers = {}
	return {
		Connect = function(_, f)
			table.insert(handlers, f)
		end,
		Fire = function(_, ...)
			for _, h in handlers do
				h(...)
			end
		end,
	}
end
local PlayersRemoving = Signal()
local allPlayers = {}
local PlayersService = {
	PlayerRemoving = PlayersRemoving,
	GetPlayerByUserId = function(_, id)
		return allPlayers[id]
	end,
}
local log = { notes = {}, states = {}, released = 0, acquired = 0, invites = 0 }
local outcomes = {}
local running = {}
local pendingStarts = {}
local RunEnded = Signal()
local Stubs = {
	DataService = {
		Get = function(p)
			return p.data
		end,
		IsMapUnlocked = function(p, m)
			return p.data ~= nil and p.data.maps[m] == true
		end,
	},
	MapInstanceService = {
		GetTemplate = function()
			return {}
		end,
		Acquire = function(def)
			if log.noSlots then
				return nil
			end
			log.acquired += 1
			return { model = { name = "map" .. log.acquired }, mapDef = def, offset = 0, slot = 1 }
		end,
		Release = function()
			log.released += 1
		end,
	},
	NpcService = { SetupInstance = function() end, RemoveInstance = function() end },
	RunService = {
		IsPlayerInRun = function(p)
			return running[p] == true
		end,
		StartRun = function(p)
			if outcomes[p] == "yield" then
				table.insert(pendingStarts, { p = p, co = coroutine.running() })
				local ok = coroutine.yield()
				if ok then
					running[p] = true
				end
				return ok
			end
			if outcomes[p] == "fail" then
				return false
			end
			running[p] = true
			return true
		end,
		EndRun = function(p)
			if running[p] then
				running[p] = nil
				RunEnded:Fire(p)
			end
		end,
	},
	Outbound = {
		Notify = function(p, kind, text)
			table.insert(log.notes, { p = p, kind = kind, text = text })
		end,
		RoomState = function(p, s)
			log.states[p] = s
		end,
		RoomList = function(p, l)
			p.list = l
		end,
		RoomInvite = function(p)
			log.invites += 1
			p.invited = true
		end,
	},
	RunEvents = { RunEnded = RunEnded },
	ConfigLookup = {
		GetMap = function(id)
			return if id == "Bad" then nil else { Id = id, Enabled = id ~= "Off", DisplayName = id }
		end,
		GetMode = function(id)
			return if id == "Bad" then nil else { Id = id, RequiredLevel = if id == "Hard" then 50 else 1 }
		end,
		GetDefaultMode = function()
			return { Id = "M", RequiredLevel = 1 }
		end,
	},
	MessageConfig = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}),
	RoomConfig = {
		PlayerOptions = { 1, 2, 4, 6, 8 },
		StartCountdown = 5,
		SoloStartCountdown = 0,
		RequireAllReady = true,
		InviteCooldown = 10,
		KickBlockTime = 120,
		ListSyncInterval = 1,
		FriendCacheTime = 120,
		EmptyRoomGrace = 2,
		MaxRooms = 2,
	},
}
local function node(name)
	return setmetatable({ __stub = name }, {
		__index = function(_, k)
			return node(k)
		end,
	})
end
local function require(target)
	return Stubs[target.__stub] or error("no stub for " .. tostring(target.__stub))
end
local game = {
	GetService = function(_, name)
		if name == "Players" then
			return PlayersService
		elseif name == "Workspace" then
			return {
				GetServerTimeNow = function()
					return clock
				end,
			}
		end
		return node(name)
	end,
}
local nextId = 1
local function Player(name, opts)
	opts = opts or {}
	local p = {
		UserId = nextId,
		DisplayName = name,
		data = { Level = opts.level or 10, maps = opts.maps or { Z1 = true, Z2 = true } },
		friends = opts.friends or {},
	}
	nextId += 1
	p.IsFriendsWith = function(self, id)
		return self.friends[id] == true
	end
	allPlayers[p.UserId] = p
	return p
end
--ROOMSERVICE--
local Room = RoomServiceFactory()
local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
	end
end
local function state(p)
	return log.states[p] or { InRoom = false, Members = {} }
end
local function lastNote(p)
	for i = #log.notes, 1, -1 do
		if log.notes[i].p == p then
			return log.notes[i].text
		end
	end
	return nil
end
local function endAll(...)
	for _, p in { ... } do
		Stubs.RunService.EndRun(p, false)
	end
	pump(3)
end
local function cleanup(...)
	for _, p in { ... } do
		Room.LeaveRoom(p)
	end
	pump(3)
end

do -- create validation
	local a = Player("a", { maps = { Z1 = true } })
	Room.CreateRoom(a, "Z2", "M", 4, false)
	check("locked map refused", not state(a).InRoom and lastNote(a) == "MapLocked")
	Room.CreateRoom(a, "Bad", "M", 4, false)
	check("unknown map refused", not state(a).InRoom)
	Room.CreateRoom(a, "Off", "M", 4, false)
	check("disabled map refused", not state(a).InRoom)
	Room.CreateRoom(a, "Z1", "M", 3, false)
	check("size outside options refused", not state(a).InRoom and lastNote(a) == "RoomSizeInvalid")
	Room.CreateRoom(a, "Z1", "Hard", 4, false)
	check("mode level refused", not state(a).InRoom and lastNote(a) == "ModeLocked")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	check("valid create", state(a).InRoom and state(a).Status == "Waiting")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	check("second create refused", lastNote(a) == "AlreadyInRoom")
	cleanup(a)
	check("last leave closes", not state(a).InRoom)
end

do -- quick play
	local a = Player("a", { maps = { Z1 = true } })
	Room.QuickPlay(a, "Z2")
	check("quick play locked map refused", not state(a).InRoom and lastNote(a) == "MapLocked")
	Room.QuickPlay(a, "Z1")
	check(
		"quick play private one-player room",
		state(a).InRoom and state(a).MaxPlayers == 1 and state(a).FriendsOnly == true
	)
	check("quick play default mode", state(a).ModeId == "M")
	pump(0)
	check("quick play starts immediately", state(a).Status == "Running" and running[a])
	local rel = log.released
	Room.QuickPlay(a, "Z1")
	check("quick play refused while running", lastNote(a) == "RoomInRun")
	endAll(a)
	check("quick play map released", log.released == rel + 1)
end

do -- ready rules, countdown, three members
	local a, b, c = Player("a"), Player("b"), Player("c")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	local id = state(a).Id
	Room.JoinRoom(b, id)
	Room.JoinRoom(c, id)
	check("three members", #state(a).Members == 3)
	Room.StartRoom(b)
	check("non-host cannot start", lastNote(b) == "RoomNotHost")
	Room.StartRoom(a)
	check("start needs ready", lastNote(a) == "RoomReadyNeeded" and state(a).Status == "Waiting")
	Room.SetReady(b, true)
	Room.SetReady(c, true)
	Room.StartRoom(a)
	check("countdown", state(a).Status == "Countdown")
	pump(4)
	check("still counting", state(a).Status == "Countdown")
	pump(1)
	check("running", state(a).Status == "Running" and log.acquired >= 1)
	check("all in run", running[a] and running[b] and running[c])

	local released = log.released
	Stubs.RunService.EndRun(b, false)
	check("early finisher released", not state(b).InRoom)
	check("others still playing", running[a] and running[c] and state(a).InRoom)
	Room.CreateRoom(b, "Z1", "M", 2, false)
	check("early finisher can make a new room", state(b).InRoom and state(b).Id ~= id)
	cleanup(b)
	local rel2 = log.released
	Stubs.RunService.EndRun(a, false)
	pump(3)
	check("map kept while one plays", log.released == rel2 and running[c])
	Stubs.RunService.EndRun(c, false)
	pump(3)
	check("map released exactly once", log.released == rel2 + 1, log.released - released)
	check("all out", not state(a).InRoom and not state(c).InRoom)
end

do -- host leaves during countdown
	local a, b = Player("a"), Player("b")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	Room.SetReady(b, true)
	Room.StartRoom(a)
	Room.LeaveRoom(a)
	check("host left: back to waiting", state(b).Status == "Waiting")
	check("new host", state(b).HostId == b.UserId)
	local acquired = log.acquired
	pump(10)
	check("cancelled countdown never starts", log.acquired == acquired and not running[b])
	cleanup(b)
end

do -- member leaves countdown, countdown continues
	local a, b = Player("a"), Player("b")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	Room.SetReady(b, true)
	Room.StartRoom(a)
	Room.LeaveRoom(b)
	check("member left: still counting", state(a).Status == "Countdown")
	pump(6)
	check("host alone starts", running[a] and not running[b])
	endAll(a)
end

do -- kick
	local a, b = Player("a"), Player("b")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	local id = state(a).Id
	Room.JoinRoom(b, id)
	Room.KickMember(b, a.UserId)
	check("non-host cannot kick", lastNote(b) == "RoomNotHost")
	Room.KickMember(a, b.UserId)
	check("kicked out", not state(b).InRoom and lastNote(b) == "RoomKicked")
	Room.JoinRoom(b, id)
	check("rejoin blocked", not state(b).InRoom and lastNote(b) == "RoomJoinBlocked")
	pump(121)
	Room.JoinRoom(b, id)
	check("rejoin after block", state(b).InRoom)
	cleanup(a, b)
end

do -- friends only, full, locked map, level
	local stranger = Player("s")
	local friend = Player("f")
	local a = Player("a", { friends = { [friend.UserId] = true } })
	friend.friends[a.UserId] = true
	Room.CreateRoom(a, "Z1", "M", 2, true)
	local id = state(a).Id
	Room.WatchRooms(stranger, true)
	check("hidden from strangers", stranger.list ~= nil and #stranger.list == 0)
	Room.WatchRooms(friend, true)
	check("visible to friends", friend.list ~= nil and #friend.list == 1)
	Room.WatchRooms(stranger, false)
	Room.WatchRooms(friend, false)
	Room.JoinRoom(stranger, id)
	check("friends-only refuses stranger", not state(stranger).InRoom and lastNote(stranger) == "RoomFriendsOnly")
	Room.JoinRoom(friend, id)
	check("friend joins", state(friend).InRoom)
	local extra = Player("x", { friends = {} })
	a.friends[extra.UserId] = true
	Room.JoinRoom(extra, id)
	check("full room refused", not state(extra).InRoom and lastNote(extra) == "RoomFull")
	cleanup(a, friend)

	local b = Player("b")
	local poor = Player("p", { maps = { Z1 = true } })
	Room.CreateRoom(b, "Z2", "M", 4, false)
	Room.JoinRoom(poor, state(b).Id)
	check("map locked joiner refused", not state(poor).InRoom and lastNote(poor) == "RoomMapLocked")
	cleanup(b)

	local c = Player("c", { level = 60 })
	local low = Player("l", { level = 5 })
	Room.CreateRoom(c, "Z1", "Hard", 4, false)
	Room.JoinRoom(low, state(c).Id)
	check("low level joiner refused", not state(low).InRoom and lastNote(low) == "ModeLocked")
	cleanup(c)
end

do -- update
	local a, b = Player("a"), Player("b", { maps = { Z1 = true } })
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	Room.SetReady(b, true)
	Room.UpdateRoom(b, "Z1", "M", 6, false)
	check("non-host cannot update", lastNote(b) == "RoomNotHost")
	Room.UpdateRoom(a, "Z2", "M", 4, false)
	check("update refuses map a member lacks", state(a).MapId == "Z1")
	Room.UpdateRoom(a, "Z1", "M", 1, false)
	check("update refuses size below members", state(a).MaxPlayers == 4)
	Room.UpdateRoom(a, "Z1", "M", 6, true)
	check("update applies", state(a).MaxPlayers == 6 and state(a).FriendsOnly)
	for _, m in state(a).Members do
		if m.UserId == b.UserId then
			check("update clears ready", m.Ready == false)
		end
	end
	cleanup(a, b)
end

do -- invite
	local f = Player("f")
	local s = Player("s")
	local a = Player("a", { friends = { [f.UserId] = true } })
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.Invite(a, s.UserId)
	check("stranger not invited", s.invited ~= true and lastNote(a) == "RoomInviteNotFriend")
	Room.Invite(a, f.UserId)
	check("friend invited", f.invited == true)
	local before = log.invites
	Room.Invite(a, f.UserId)
	check("invite cooldown", log.invites == before and lastNote(a) == "RoomInviteCooldown")
	cleanup(a)
end

do -- StartRun fails for one member
	local a, b, c = Player("a"), Player("b"), Player("c")
	outcomes[b] = "fail"
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	Room.JoinRoom(c, state(a).Id)
	Room.SetReady(b, true)
	Room.SetReady(c, true)
	Room.StartRoom(a)
	pump(5)
	check("failed member removed", not state(b).InRoom and lastNote(b) == "RoomRunFailed")
	check("others play", running[a] and running[c])
	local rel = log.released
	endAll(a)
	check("map kept for last player", log.released == rel)
	endAll(c)
	check("map released after failed member", log.released == rel + 1)
end

do -- every StartRun fails
	local a = Player("a")
	outcomes[a] = "fail"
	local rel = log.released
	Room.CreateRoom(a, "Z1", "M", 1, false)
	Room.StartRoom(a)
	pump(1)
	pump(3)
	check("all failed: room closed", not state(a).InRoom)
	check("all failed: map released", log.released == rel + 1)
end

do -- no free slots
	local a = Player("a")
	log.noSlots = true
	Room.CreateRoom(a, "Z1", "M", 1, false)
	Room.StartRoom(a)
	pump(1)
	check("no slot: back to waiting", state(a).Status == "Waiting" and lastNote(a) == "RoomUnavailable")
	log.noSlots = false
	Room.StartRoom(a)
	pump(1)
	check("no slot: start works later", running[a])
	endAll(a)
end

do -- member leaves while StartRun is yielding on streaming
	local a, b = Player("a"), Player("b")
	outcomes[a] = "yield"
	outcomes[b] = "yield"
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	Room.SetReady(b, true)
	Room.StartRoom(a)
	pump(5)
	check("both streaming, room running", #pendingStarts == 2 and state(a).Status == "Running")
	Room.LeaveRoom(b)
	check("leaver out while streaming", not state(b).InRoom)
	for _, s in pendingStarts do
		coroutine.resume(s.co, true)
	end
	table.clear(pendingStarts)
	check("late starter ended", not running[b])
	check("stayer plays", running[a])
	local rel = log.released
	endAll(a)
	check("room closes after late leaver", log.released == rel + 1 and not state(a).InRoom)
end

do -- run ends before other members finished streaming
	local a, b = Player("a"), Player("b")
	outcomes[b] = "yield"
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	Room.SetReady(b, true)
	Room.StartRoom(a)
	pump(5)
	local rel = log.released
	Stubs.RunService.EndRun(a, false)
	pump(3)
	check("map kept while member streams", log.released == rel)
	coroutine.resume(pendingStarts[1].co, true)
	table.clear(pendingStarts)
	check("streamer plays", running[b])
	endAll(b)
	check("released after streamer", log.released == rel + 1)
end

do -- PlayerRemoving in each state
	local function remove(p)
		running[p] = nil
		PlayersRemoving:Fire(p)
	end
	local a, b = Player("a"), Player("b")
	Room.CreateRoom(a, "Z1", "M", 4, false)
	Room.JoinRoom(b, state(a).Id)
	remove(a)
	check("waiting: host gone, b is host", state(b).HostId == b.UserId and #state(b).Members == 1)
	remove(b)

	local c, d = Player("c"), Player("d")
	Room.CreateRoom(c, "Z1", "M", 4, false)
	Room.JoinRoom(d, state(c).Id)
	Room.SetReady(d, true)
	Room.StartRoom(c)
	remove(d)
	check("countdown: member gone keeps counting", state(c).Status == "Countdown")
	pump(6)
	check("countdown: host runs", running[c])
	local rel = log.released
	remove(c)
	pump(3)
	check("running: last player gone releases map", log.released == rel + 1)

	local e, f = Player("e"), Player("f")
	Room.CreateRoom(e, "Z1", "M", 4, false)
	Room.JoinRoom(f, state(e).Id)
	Room.SetReady(f, true)
	Room.StartRoom(e)
	pump(5)
	rel = log.released
	remove(e)
	pump(3)
	check("running: one gone, map kept", log.released == rel and running[f])
	endAll(f)
	check("running: other finishes, released once", log.released == rel + 1)
end

do -- room limit
	local p1, p2, p3 = Player("1"), Player("2"), Player("3")
	Room.CreateRoom(p1, "Z1", "M", 2, false)
	Room.CreateRoom(p2, "Z1", "M", 2, false)
	Room.CreateRoom(p3, "Z1", "M", 2, false)
	check("room limit", not state(p3).InRoom and lastNote(p3) == "RoomLimit")
	cleanup(p1, p2)
end

check("every acquired map released", log.acquired == log.released, log.acquired .. " vs " .. log.released)
print(string.format("ROOM TESTS: %d / %d passed", passed, passed + failed))
if failed > 0 then
	error("room tests failed", 0)
end
