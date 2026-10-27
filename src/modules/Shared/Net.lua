--!strict

--[[
	Net
	Single source of truth for every remote (Packet). Require from both realms.
	Packets are created with Packet.new(...); the installed Packet module is not callable.

	Client -> Server:
		Net.PurchaseUpgrade:Fire(upgradeId)
		Net.UnlockMap:Fire(mapId)
		Net.SelectRun:Fire(mapId, modeId)
		Net.StartRun:Fire()
		Net.LeaveRun:Fire()

	Server -> Client:
		Net.SelectionSync:FireClient(plr, mapId, modeId)
		Net.DataSync:FireClient(plr, snapshot)              full Profile.Data table
		Net.RunState:FireClient(plr, state, timeLeft, score) timeLeft -1 = untimed
		Net.RunEnded:FireClient(plr, summary)                RunSummary table, see below
		Net.PowerupState:FireClient(plr, active)             { { Id, TimeLeft, Duration } }
		Net.PowerupPicked:FireClient(plr, powerupId)
		Net.ObjectStained:FireClient(plr, object, step)      object Model, step 1..ObjectConfig.TintSteps
		Net.ObjectSoiled:FireClient(plr, object, bonus)      object Model fully soiled, bonus points
		Net.QuestState:FireClient(plr, quests)               { { Id, Text, Progress, Target, Done } }
		Net.NpcCaught:FireClient(plr, penaltySeconds)
		Net.Notify:FireClient(plr, kind, text)               kind "Info" | "Success" | "Error"

	RunSummary:
		{ Score, Coins, Gems, Xp, MapId, ModeId, ObjectsSoiled, TargetReached,
		  QuestsCompleted, QuestCoins, QuestGems, BonusCoins, BonusGems,
		  LeveledUp, NewLevel, OutOfTime }
		Coins and Gems are totals including quest and target bonuses; LeveledUp is levels gained.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packet = require(ReplicatedStorage.Packages.Packet)

local Net = {}

Net.PurchaseUpgrade = Packet.new("PurchaseUpgrade", Packet.String)
Net.UnlockMap = Packet.new("UnlockMap", Packet.String)
Net.SelectRun = Packet.new("SelectRun", Packet.String, Packet.String)
Net.StartRun = Packet.new("StartRun")
Net.LeaveRun = Packet.new("LeaveRun")

Net.SelectionSync = Packet.new("SelectionSync", Packet.String, Packet.String)
Net.DataSync = Packet.new("DataSync", Packet.Any)
Net.RunState = Packet.new("RunState", Packet.String, Packet.NumberF64, Packet.NumberF64)
Net.RunEnded = Packet.new("RunEnded", Packet.Any)
Net.PowerupState = Packet.new("PowerupState", Packet.Any)
Net.PowerupPicked = Packet.new("PowerupPicked", Packet.String)
Net.ObjectStained = Packet.new("ObjectStained", Packet.Instance, Packet.NumberU8)
Net.ObjectSoiled = Packet.new("ObjectSoiled", Packet.Instance, Packet.NumberF64)
Net.QuestState = Packet.new("QuestState", Packet.Any)
Net.NpcCaught = Packet.new("NpcCaught", Packet.NumberF64)
Net.Notify = Packet.new("Notify", Packet.String, Packet.String)

return Net
