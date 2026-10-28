--!strict

--[[
	RunEvents
	Server-only signals shared by the run services. The service that owns an event fires it;
	the other services listen without requiring each other.

	API:
		RunEvents.RunStarted(plr, mapId, modeId)
		RunEvents.Stained(plr, points, objectType)
		RunEvents.ObjectSoiled(plr, objectType, bonusPoints)
		RunEvents.PowerupEaten(plr, powerupId)
		RunEvents.TimeBonus(plr, seconds)
		RunEvents.RunEnded(plr, summary)
		RunEvents.TargetSoiled(plr, mapId, objectType)   a target's hidden stain meter reached 100%

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
RunEvents.TargetSoiled = Signal.new()

return RunEvents
