--!strict

--[[
	EventConfig
	Timed world events, map completion reporting and target panic tuning. Pure data, no functions.

	Fields:
		StepInterval: heartbeat check interval for timed events (seconds)
		SpecialTime.IntervalSeconds: time between the end of one Special Time and the start of the next (seconds)
		SpecialTime.FirstDelaySeconds: delay before the first Special Time after the server starts (seconds)
		SpecialTime.DurationSeconds: how long one Special Time lasts (seconds)
		SpecialTime.PointsMultiplier: score multiplier while standing on the event map (multiplier)
		SpecialTime.GemMultiplier: gem reward multiplier while playing the event map (multiplier)
		MapProgress.SyncInterval: time between live map-percent sends to the client (seconds)
		MapProgress.MinSendDelta: smallest percent change worth a live map-percent send (percent)
		MapProgress.SaveStepPercent: best percent is checkpointed to the save every this many percent (percent)
		TargetPanic.DurationSeconds: how long an NPC panics after a nearby prop is fully soiled (seconds)
		TargetPanic.SpeedMultiplier: patrol speed of a panicking NPC (multiplier)
		TargetPanic.Radius: props within this distance of an NPC make it panic when fully soiled (studs)
]]

local EventConfig = {}

EventConfig.StepInterval = 0.5

EventConfig.SpecialTime = {
	IntervalSeconds = 240,
	FirstDelaySeconds = 240,
	DurationSeconds = 120,
	PointsMultiplier = 2,
	GemMultiplier = 2,
}

EventConfig.MapProgress = {
	SyncInterval = 0.5,
	MinSendDelta = 0.1,
	SaveStepPercent = 10,
}

EventConfig.TargetPanic = {
	DurationSeconds = 4,
	SpeedMultiplier = 2.2,
	Radius = 45,
}

return EventConfig
