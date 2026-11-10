--!strict

--[[
	Net
	Packet definitions for every remote, shared by both realms. Packet serializes each call
	into one per-frame buffer, so fixed schemas (structs/arrays) are used wherever the shape
	is known and Packet.Any only where keys are dynamic (DataSync).

	Server code never fires these directly: inbound handlers live in
	ServerStorage.Modules.Remotes.*Remotes and every outbound send goes through
	ServerStorage.Modules.Remotes.Outbound. Client code fires the inbound packets and
	listens to the outbound ones.

	Client -> Server:
		PurchaseUpgrade(upgradeId)
		UnlockMap(mapId)
		LeaveRun()
		QuickPlay(mapId)                   start a private solo room now
		CreateRoom(mapId, modeId, maxPlayers, friendsOnly)
		UpdateRoom(mapId, modeId, maxPlayers, friendsOnly)   host only, while Waiting
		JoinRoom(roomId)
		LeaveRoom()
		SetRoomReady(ready)
		StartRoom()                        host only
		KickRoomMember(userId)             host only
		InviteToRoom(userId)               host only, friend in this server
		WatchRooms(watching)               true while the room browser is open
		ClaimDaily()
		UsePotion(potionId)
		Rebirth()
		OpenCrate(crateId)
		EquipCosmetic(kind, id)
		EquipPet(uid)
		UnequipPet(uid)
		DeletePet(uid)
		MergePet(uid)
		TutorialStep(step)                 advance the saved tutorial, 255 = finish it

	Server -> Client:
		SelectionSync(mapId, modeId)
		DataSync(snapshot)                 full Profile.Data table
		RoomState(payload)                 the room this client is in, InRoom false = none;
		                                   Status "Waiting", "Countdown" or "Running", StartsAt = server clock,
		                                   RoomMember.IsFriend = member is a friend of the room host
		RoomList({ RoomSummary })          joinable rooms visible to this client, sent while watching
		RoomInvite(roomId, hostName, mapId)  a friend invited this client to their room
		OpenRoomMenu()                     lobby portal touched, open the play window
		RunState(state, timeLeft, score, combo)   timeLeft -1 = untimed, combo 1..ComboMax
		RunEnded(summary)                  RunSummary struct, see below
		PowerupState(active)               { { Id, TimeLeft, Duration } }
		PowerupPicked(powerupId)
		ObjectStained(object, step)        object Model, step 1..ObjectConfig.TintSteps
		ObjectSoiled(object, bonus)        object Model fully soiled, bonus points
		QuestState(quests)                 { { Id, Text, Progress, Target, Done } }
		GoldenTargets(paths)               prop name paths relative to the map model
		NpcCaught(penaltySeconds)
		DailyState(state)                  { Day, CanClaim, SecondsUntilNext, Streak }
		Notify(kind, text)                 kind "Info" | "Success" | "Error"
		ReviveOffer(productId, tier, windowSeconds)  timed run hit zero, revive is buyable
		PassState(ownedPassKeys)           { "DoubleCoins", "Magnet", ... } owned gamepasses
		MapProgress(MapId, Percent)        live percent of the current run on that map
		SpecialEvent(MapId, EndsAt)        Special Time map, EndsAt = server clock time it ends,
		                                   MapId "" means the event just ended
		CosmeticState(equippedSkin, equippedTrail, ownedSkins, ownedTrails)
		CrateResult(crateId, kind, id, isNew, refund)
		PetInventory(state)                { Pets = { PetEntry }, Equipped = { uid }, Slots,
		                                   Stink, Index = { { PetId, Variant } }, IndexClaimed = { mapId } }
		PetDrop(petId, variant, isNew, converted)  pet rolled at 100% map clear, converted = gems if full
		PetPoop(uid, gems)                 one equipped pet pooped during a run, client plays the puddle
		PetStacks(uid, stacks)             low-bandwidth stack update after a poop, client re-derives Stink
		LeaderboardData(Period, Entries)   Entries { { Rank, Name, Value } }, Period "Daily" | "Weekly" | "AllTime"

	RunSummary:
		{ Score, Coins, Gems, Xp, MapId, ModeId, ObjectsSoiled, TargetReached,
		  QuestsCompleted, QuestCoins, QuestGems, BonusCoins, BonusGems,
		  LeveledUp, NewLevel, OutOfTime }
		Coins and Gems are totals including quest and target bonuses; LeveledUp is levels gained.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packet = require(ReplicatedStorage.Packages.Packet)

local PowerupEntry = {
	Id = Packet.String,
	TimeLeft = Packet.NumberF32,
	Duration = Packet.NumberF32,
}

local QuestEntry = {
	Id = Packet.String,
	Text = Packet.String,
	Progress = Packet.NumberF32,
	Target = Packet.NumberF32,
	Done = Packet.Boolean8,
}

local RunSummary = {
	Score = Packet.NumberU32,
	Coins = Packet.NumberU32,
	Gems = Packet.NumberU32,
	Xp = Packet.NumberU32,
	MapId = Packet.String,
	ModeId = Packet.String,
	ObjectsSoiled = Packet.NumberU16,
	TargetReached = Packet.Boolean8,
	QuestsCompleted = Packet.NumberU8,
	QuestCoins = Packet.NumberU32,
	QuestGems = Packet.NumberU32,
	BonusCoins = Packet.NumberU32,
	BonusGems = Packet.NumberU32,
	LeveledUp = Packet.NumberU16,
	NewLevel = Packet.NumberU16,
	OutOfTime = Packet.Boolean8,
}

local MapProgressPayload = {
	MapId = Packet.String,
	Percent = Packet.NumberF32,
}

local SpecialEventPayload = {
	MapId = Packet.String,
	EndsAt = Packet.NumberF64,
}

local CrateResultStruct = {
	CrateId = Packet.String,
	Kind = Packet.String,
	Id = Packet.String,
	IsNew = Packet.Boolean8,
	Refund = Packet.NumberU32,
}

local PetEntry = {
	Uid = Packet.String,
	PetId = Packet.String,
	Variant = Packet.String,
	Stacks = Packet.NumberU16,
}

local PetIndexEntry = {
	PetId = Packet.String,
	Variant = Packet.String,
}

local PetInventoryState = {
	Pets = { PetEntry },
	Equipped = { Packet.String },
	Slots = Packet.NumberU8,
	Stink = Packet.NumberF32,
	Index = { PetIndexEntry },
	IndexClaimed = { Packet.String },
}

local LeaderboardEntry = {
	Rank = Packet.NumberU8,
	Name = Packet.String,
	Value = Packet.NumberU32,
}

local LeaderboardDataPayload = {
	Period = Packet.String,
	Entries = { LeaderboardEntry },
}

local Net = {}

Net.PurchaseUpgrade = Packet.new("PurchaseUpgrade", Packet.String)
Net.UnlockMap = Packet.new("UnlockMap", Packet.String)
Net.LeaveRun = Packet.new("LeaveRun")
Net.TutorialStep = Packet.new("TutorialStep", Packet.NumberU8)

Net.SelectionSync = Packet.new("SelectionSync", Packet.String, Packet.String)
Net.DataSync = Packet.new("DataSync", Packet.Any)
Net.RunState = Packet.new("RunState", Packet.String, Packet.NumberF32, Packet.NumberU32, Packet.NumberU8)
Net.RunEnded = Packet.new("RunEnded", RunSummary)
Net.PowerupState = Packet.new("PowerupState", { PowerupEntry })
Net.PowerupPicked = Packet.new("PowerupPicked", Packet.String)
Net.ObjectStained = Packet.new("ObjectStained", Packet.Instance, Packet.NumberU8)
Net.ObjectSoiled = Packet.new("ObjectSoiled", Packet.Instance, Packet.NumberU32)
Net.QuestState = Packet.new("QuestState", { QuestEntry })
Net.NpcCaught = Packet.new("NpcCaught", Packet.NumberU8)
Net.Notify = Packet.new("Notify", Packet.String, Packet.String)
Net.MapProgress = Packet.new("MapProgress", MapProgressPayload)
Net.SpecialEvent = Packet.new("SpecialEvent", SpecialEventPayload)

local DailyStateEntry = {
	Day = Packet.NumberU8,
	CanClaim = Packet.Boolean8,
	SecondsUntilNext = Packet.NumberU32,
	Streak = Packet.NumberU8,
}

Net.ClaimDaily = Packet.new("ClaimDaily")
Net.DailyState = Packet.new("DailyState", DailyStateEntry)

Net.ReviveOffer = Packet.new("ReviveOffer", Packet.NumberU32, Packet.NumberU8, Packet.NumberF32)
Net.PassState = Packet.new("PassState", { Packet.String })

Net.UsePotion = Packet.new("UsePotion", Packet.String)

Net.Rebirth = Packet.new("Rebirth")
Net.OpenCrate = Packet.new("OpenCrate", Packet.String)
Net.EquipCosmetic = Packet.new("EquipCosmetic", Packet.String, Packet.String)

Net.CosmeticState = Packet.new("CosmeticState", Packet.String, Packet.String, Packet.Any, Packet.Any)
Net.CrateResult = Packet.new("CrateResult", CrateResultStruct)

Net.EquipPet = Packet.new("EquipPet", Packet.String)
Net.UnequipPet = Packet.new("UnequipPet", Packet.String)
Net.DeletePet = Packet.new("DeletePet", Packet.String)
Net.MergePet = Packet.new("MergePet", Packet.String)

Net.PetInventory = Packet.new("PetInventory", PetInventoryState)
Net.PetDrop = Packet.new("PetDrop", Packet.String, Packet.String, Packet.Boolean8, Packet.NumberU16)
Net.PetPoop = Packet.new("PetPoop", Packet.String, Packet.NumberU8)
Net.PetStacks = Packet.new("PetStacks", Packet.String, Packet.NumberU16)

local RoomMember = {
	UserId = Packet.NumberF64,
	Name = Packet.String,
	Level = Packet.NumberU16,
	Ready = Packet.Boolean8,
	IsFriend = Packet.Boolean8,
}

local RoomStatePayload = {
	InRoom = Packet.Boolean8,
	Id = Packet.NumberU16,
	HostId = Packet.NumberF64,
	MapId = Packet.String,
	ModeId = Packet.String,
	MaxPlayers = Packet.NumberU8,
	FriendsOnly = Packet.Boolean8,
	Status = Packet.String,
	StartsAt = Packet.NumberF64,
	Members = { RoomMember },
}

local RoomSummary = {
	Id = Packet.NumberU16,
	HostName = Packet.String,
	MapId = Packet.String,
	ModeId = Packet.String,
	Players = Packet.NumberU8,
	MaxPlayers = Packet.NumberU8,
	FriendsOnly = Packet.Boolean8,
	HostIsFriend = Packet.Boolean8,
}

Net.QuickPlay = Packet.new("QuickPlay", Packet.String)
Net.CreateRoom = Packet.new("CreateRoom", Packet.String, Packet.String, Packet.NumberU8, Packet.Boolean8)
Net.UpdateRoom = Packet.new("UpdateRoom", Packet.String, Packet.String, Packet.NumberU8, Packet.Boolean8)
Net.JoinRoom = Packet.new("JoinRoom", Packet.NumberU16)
Net.LeaveRoom = Packet.new("LeaveRoom")
Net.SetRoomReady = Packet.new("SetRoomReady", Packet.Boolean8)
Net.StartRoom = Packet.new("StartRoom")
Net.KickRoomMember = Packet.new("KickRoomMember", Packet.NumberF64)
Net.InviteToRoom = Packet.new("InviteToRoom", Packet.NumberF64)
Net.WatchRooms = Packet.new("WatchRooms", Packet.Boolean8)

Net.RoomState = Packet.new("RoomState", RoomStatePayload)
Net.RoomList = Packet.new("RoomList", { RoomSummary })
Net.RoomInvite = Packet.new("RoomInvite", Packet.NumberU16, Packet.String, Packet.String)
Net.OpenRoomMenu = Packet.new("OpenRoomMenu")

Net.GoldenTargets = Packet.new("GoldenTargets", { Packet.String })
Net.LeaderboardData = Packet.new("LeaderboardData", LeaderboardDataPayload)

return Net
