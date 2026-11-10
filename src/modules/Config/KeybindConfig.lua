--!strict

--[[
	KeybindConfig
	PC keyboard shortcuts. Every action lists the keys that trigger it and the label drawn on its
	key hint. Keys never fire while the player types in chat or a text box, and hints only show
	while the player uses keyboard and mouse. Pure data, no functions.

	Movement keys (W A S D, arrows, Space, Shift) are kept free on purpose.

	Fields:
		Actions: one table per action id, keyed by the action id
			Keys: keys that trigger the action (Enum.KeyCode list)
			Label: text on the key hint (text)
		Routes: lobby window actions mapped to the LobbyState route and tab they open; pressing
			the key again while that window is open closes it (route = LobbyState route, Tab = tab id or "")

	Action ids:
		Play, Shop, Pets, Index, Upgrades, Daily, Rebirth, Skins, Rooms: open the lobby window
		Close: close the open window
		PrevTab / NextTab: switch the open window's tab
		Confirm: the main button of the result window and the pet reveal (CONTINUE / COLLECT)
]]

return {
	Actions = {
		Play = { Keys = { Enum.KeyCode.F }, Label = "F" },
		Shop = { Keys = { Enum.KeyCode.B }, Label = "B" },
		Pets = { Keys = { Enum.KeyCode.P }, Label = "P" },
		Index = { Keys = { Enum.KeyCode.I }, Label = "I" },
		Upgrades = { Keys = { Enum.KeyCode.U }, Label = "U" },
		Daily = { Keys = { Enum.KeyCode.G }, Label = "G" },
		Rebirth = { Keys = { Enum.KeyCode.R }, Label = "R" },
		Skins = { Keys = { Enum.KeyCode.K }, Label = "K" },
		Rooms = { Keys = { Enum.KeyCode.M }, Label = "M" },
		Close = { Keys = { Enum.KeyCode.X, Enum.KeyCode.Backspace }, Label = "X" },
		PrevTab = { Keys = { Enum.KeyCode.Q }, Label = "Q" },
		NextTab = { Keys = { Enum.KeyCode.E }, Label = "E" },
		Confirm = { Keys = { Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter }, Label = "Enter" },
	},

	Routes = {
		Play = { Route = "Play", Tab = "" },
		Shop = { Route = "Shop", Tab = "" },
		Pets = { Route = "Pets", Tab = "" },
		Index = { Route = "Pets", Tab = "Index" },
		Upgrades = { Route = "Upgrades", Tab = "" },
		Daily = { Route = "Daily", Tab = "" },
		Rebirth = { Route = "Rebirth", Tab = "" },
		Skins = { Route = "Skins", Tab = "" },
		Rooms = { Route = "Play", Tab = "" },
	},
}
