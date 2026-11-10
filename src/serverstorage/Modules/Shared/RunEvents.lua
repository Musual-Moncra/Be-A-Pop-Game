--!strict

--[[
	RunEvents
	Server-only signals shared by the run services. The service that owns an event fires it;
	the other services listen without requiring each other.

	API:
		RunEvents.RunStarted(plr, mapId, modeId, mapModel)
		RunEvents.Stained(plr, points, objectType)
		RunEvents.ObjectSoiled(plr, objectType, bonusPoints)
		RunEvents.GoldenSoiled(plr, name, gems, points)
		RunEvents.PowerupEaten(plr, powerupId)
		RunEvents.TimeBonus(plr, seconds)
		RunEvents.RunEnded(plr, summary)
		RunEvents.TimeUp(plr)                       lifespan is low, the revive offer opens
		RunEvents.ReviveActivated(plr, seconds)     revive bought, add lifespan and close the window
		RunEvents.StainBomb(plr)                    soil every prop near the player
		RunEvents.TargetSoiled(plr, mapId, objectType)   a target's hidden stain meter reached 100%
		RunEvents.MiniBombDetonated(plr, originPosition, radius)
		RunEvents.ScoreBonus(plr, points, source)   extra run score from a pickup or an NPC

	Dependencies: Signal
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local RunEvents = {}

RunEvents.RunStarted = Signal.new()
RunEvents.Stained = Signal.new()
RunEvents.ObjectSoiled = Signal.new()
RunEvents.PowerupEaten = Signal.new()
RunEvents.TimeBonus = Signal.new()
RunEvents.RunEnded = Signal.new()
RunEvents.TimeUp = Signal.new()
RunEvents.ReviveActivated = Signal.new()
RunEvents.StainBomb = Signal.new()
RunEvents.TargetSoiled = Signal.new()
RunEvents.MiniBombDetonated = Signal.new()
RunEvents.GoldenSoiled = Signal.new()
RunEvents.ScoreBonus = Signal.new()

return RunEvents
