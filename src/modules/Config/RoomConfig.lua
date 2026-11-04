--!strict

--[[
	RoomConfig
	Rules of the play rooms and where their map copies are placed. Pure data, no functions.

	Fields:
		PlayerOptions: room sizes the host can pick, smallest first (players)
		DefaultMaxPlayers: size preselected in the create-room form, must be in PlayerOptions (players)
		DefaultFriendsOnly: friends-only switch preselected in the create-room form (true/false)
		StartCountdown: time between the host pressing START and the run beginning (seconds)
		SoloStartCountdown: same, when the host is alone in the room (seconds)
		RequireAllReady: true means START is refused until every non-host member is ready (true/false)
		InviteCooldown: minimum delay between two invites to the same friend (seconds)
		KickBlockTime: how long a kicked player cannot rejoin that room (seconds)
		ListSyncInterval: minimum delay between two room list updates to one watcher (seconds)
		FriendCacheTime: how long a friendship check result is reused (seconds)
		EmptyRoomGrace: how long a finished room keeps its map before it is destroyed (seconds)
		SlotOrigin: world offset of the first room slot, clear of the lobby (studs)
		SlotSpacing: distance between two room slots, keep above the streaming radius (studs)
		SlotColumns: slots per row of the room grid (count)
		MaxRooms: most rooms alive on one server (count)
		MapFolderName: Workspace folder that holds the live map copies (string)
		MapTag: CollectionService tag on every live map copy (string)
]]

return {
	PlayerOptions = { 1, 2, 4, 6, 8 },
	DefaultMaxPlayers = 4,
	DefaultFriendsOnly = false,
	StartCountdown = 5,
	SoloStartCountdown = 0,
	RequireAllReady = true,
	InviteCooldown = 10,
	KickBlockTime = 120,
	ListSyncInterval = 1,
	FriendCacheTime = 120,
	EmptyRoomGrace = 2,
	SlotOrigin = Vector3.new(0, 0, 1600),
	SlotSpacing = 3200,
	SlotColumns = 8,
	MaxRooms = 60,
	MapFolderName = "Rooms",
	MapTag = "RoomMap",
}
