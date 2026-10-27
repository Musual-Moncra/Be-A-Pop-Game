--!strict

--[[
	LobbyState
	Shared lobby route for PlayMenu and UpgradeMenu so only one is visible.
	API: LobbyState.Get() -> "Play" | "Upgrades"; LobbyState.SetActive(route).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local LobbyState = {}

LobbyState.Changed = Signal.new()
LobbyState.Routes = {
	Play = "Play",
	Upgrades = "Upgrades",
}

local active = LobbyState.Routes.Play

function LobbyState.Get(): string
	return active
end

function LobbyState.SetActive(route: string)
	if route ~= LobbyState.Routes.Play and route ~= LobbyState.Routes.Upgrades then
		return
	end
	if route == active then
		return
	end
	active = route
	LobbyState.Changed:Fire(active)
end

return LobbyState
