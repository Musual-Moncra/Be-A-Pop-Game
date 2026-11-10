--!strict

--[[
	LobbyState
	Shared lobby route so the menu wheel and the two panels agree on what is open.
	API: LobbyState.Get() -> a LobbyState.Routes value ("None", "Play", "Upgrades", "Daily",
	     "Shop", "Pets", "Skins", "Rebirth");
	     LobbyState.GetTab() -> the tab requested for the open window, nil = the window default;
	     LobbyState.SetActive(route, tab?) -> open a route and optionally ask its window for a tab.
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
	Daily = "Daily",
	Shop = "Shop",
	Pets = "Pets",
	Skins = "Skins",
	Rebirth = "Rebirth",
}

local active = LobbyState.Routes.None
local requestedTab: string? = nil

function LobbyState.Get(): string
	return active
end

function LobbyState.GetTab(): string?
	return requestedTab
end

function LobbyState.SetActive(route: string, tab: string?)
	if LobbyState.Routes[route] == nil then
		return
	end
	local nextTab = if route == LobbyState.Routes.None then nil else tab
	if route == active and nextTab == requestedTab then
		return
	end
	active = route
	requestedTab = nextTab
	LobbyState.Changed:Fire(active, requestedTab)
end

return LobbyState
