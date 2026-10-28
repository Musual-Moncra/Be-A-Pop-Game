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
		SelectRun(mapId, modeId)
		StartRun()
		LeaveRun()
		ClaimDaily()

	Server -> Client:
		SelectionSync(mapId, modeId)
		DataSync(snapshot)                 full Profile.Data table
		RunState(state, timeLeft, score)   timeLeft -1 = untimed
		RunEnded(summary)                  RunSummary struct, see below
		PowerupState(active)               { { Id, TimeLeft, Duration } }
		PowerupPicked(powerupId)
		ObjectStained(object, step)        object Model, step 1..ObjectConfig.TintSteps
		ObjectSoiled(object, bonus)        object Model fully soiled, bonus points
		QuestState(quests)                 { { Id, Text, Progress, Target, Done } }
		NpcCaught(penaltySeconds)
		DailyState(state)                  { Day, CanClaim, SecondsUntilNext, Streak }
		Notify(kind, text)                 kind "Info" | "Success" | "Error"
		ReviveOffer(productId, tier, windowSeconds)  timed run hit zero, revive is buyable
		PassState(ownedPassKeys)           { "DoubleCoins", "Magnet", ... } owned gamepasses
		MapProgress(MapId, Percent)        live percent of the current run on that map
		SpecialEvent(MapId, EndsAt)        Special Time map, EndsAt = server clock time it ends,
		                                   MapId "" means the event just ended

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

local Net = {}

Net.PurchaseUpgrade = Packet.new("PurchaseUpgrade", Packet.String)
Net.UnlockMap = Packet.new("UnlockMap", Packet.String)
Net.SelectRun = Packet.new("SelectRun", Packet.String, Packet.String)
Net.StartRun = Packet.new("StartRun")
Net.LeaveRun = Packet.new("LeaveRun")

Net.SelectionSync = Packet.new("SelectionSync", Packet.String, Packet.String)
Net.DataSync = Packet.new("DataSync", Packet.Any)
Net.RunState = Packet.new("RunState", Packet.String, Packet.NumberF32, Packet.NumberU32)
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

return Net
