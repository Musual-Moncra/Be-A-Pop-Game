--!strict

--[[
	RemoteConfig
	Server-only limits for client -> server remotes. Pure data, no functions.

	Fields:
		RateLimits: minimum time between two accepted calls of one remote from one player, keyed by
			Net packet name; a call arriving sooner is dropped silently (seconds)
			PurchaseUpgrade: buying an upgrade
			UnlockMap: buying a map
			LeaveRun: leaving a run from the HUD
			CreateRoom: opening a room
			UpdateRoom: changing the map, mode or size of a waiting room
			JoinRoom: joining a room from the browser or an invite
			LeaveRoom: leaving the current room
			SetRoomReady: toggling the ready flag
			StartRoom: host pressing START
			KickRoomMember: host kicking a member
			InviteToRoom: host inviting a friend
			WatchRooms: opening or closing the room browser
			ClaimDaily: claiming the daily login reward
			Rebirth: executing a rebirth
			OpenCrate: opening a cosmetic crate
			EquipCosmetic: equipping or unequipping a skin or trail
			HatchEgg: opening one egg
			EquipPet: equipping one owned pet
			UnequipPet: unequipping one owned pet
			DeletePet: deleting one owned pet
			MergePet: merging five identical pets
		DefaultRateLimit: limit used for a remote missing from RateLimits (seconds)
		MaxStringLength: longest string argument a client may send on any remote (characters)
]]

return {
	RateLimits = {
		PurchaseUpgrade = 0.2,
		UnlockMap = 0.2,
		LeaveRun = 0.5,
		CreateRoom = 0.5,
		UpdateRoom = 0.5,
		JoinRoom = 0.3,
		LeaveRoom = 0.3,
		SetRoomReady = 0.2,
		StartRoom = 0.5,
		KickRoomMember = 0.3,
		InviteToRoom = 0.5,
		WatchRooms = 0.2,
		ClaimDaily = 1,
		Rebirth = 0.5,
		OpenCrate = 0.3,
		EquipCosmetic = 0.2,
		HatchEgg = 0.5,
		EquipPet = 0.1,
		UnequipPet = 0.1,
		DeletePet = 0.2,
		MergePet = 0.5,
	},

	DefaultRateLimit = 0.2,

	MaxStringLength = 64,
}
