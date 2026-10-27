--!strict

--[[
	LobbyState
	Shared lobby route so the menu wheel and the two panels agree on what is open.
	API: LobbyState.Get() -> "None" | "Play" | "Upgrades" | "Stats";
	     LobbyState.SetActive(route).
	Dependencies: Signal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local LobbyState = {}

LobbyState.Changed = Signal.new()
LobbyState.Routes = {
	None = "None",
	Play = "Play",
	Upgrades = "Upgrades",
	Stats = "Stats",
}

local active = LobbyState.Routes.None

function LobbyState.Get(): string
	return active
end

function LobbyState.SetActive(route: string)
	if LobbyState.Routes[route] == nil then
		return
	end
	if route == active then
		return
	end
	active = route
	LobbyState.Changed:Fire(active)
end

return LobbyState
