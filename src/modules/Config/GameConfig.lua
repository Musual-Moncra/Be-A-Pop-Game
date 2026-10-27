--!strict

--[[
	GameConfig
	Global tuning shared by server and client. Pure data, no side effects.

	Fields:
		RunStates: table of valid run state strings (Idle, Running)
		CoinsPerScore: conversion multiplier of score to coins (coins per score point)
		StainCellSize: dimensions of grid cells on surfaces (studs)
		StainInterval: delay between stain placement attempts (seconds)
		MaxStainParts: maximum active stain parts allowed per player (part count)
		LobbySpawn: world coordinates for lobby spawn and return (studs)
]]

local GameConfig = {}

GameConfig.RunStates = {
	Idle = "Idle",
	Running = "Running",
}

GameConfig.CoinsPerScore = 0.5
GameConfig.StainCellSize = 4
GameConfig.StainInterval = 0.15
GameConfig.MaxStainParts = 600

GameConfig.LobbySpawn = Vector3.new(0, 5, 0)

return GameConfig
