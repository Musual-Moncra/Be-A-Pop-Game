--!strict

--[[
	MessageConfig
	Popup (toast) texts the server sends to players. Pure data, no functions.
	%s is replaced by a name, %d by a whole number.

	Fields:
		MapUnlocked: map bought successfully, %s = map name (text)
		AlreadyUnlocked: player already owns the map (text)
		NeedPreviousMap: previous map in the chain is not owned yet, %s = that map's name (text)
		NeedLevel: player level too low for a map or mode, %d = required level (text)
		NotEnoughCoins: not enough coins for a purchase (text)
		MapUnavailable: map is disabled / coming soon (text)
		MapLocked: map is not owned so it cannot be selected (text)
		ModeLocked: player level too low for the mode, %d = required level (text)
		MaxLevelReached: upgrade is already at max level (text)
		UpgradeBought: upgrade bought, %s = upgrade name (text)
		QuestCompleted: a quest was finished, %s = quest text (text)
		TargetReached: Challenge target score reached (text)
		LevelUp: player reached a new level, %d = new level (text)
		NpcCaught: an NPC caught the poop, %d = seconds lost (text)
]]

local MessageConfig = {}

MessageConfig.MapUnlocked = "%s unlocked!"
MessageConfig.AlreadyUnlocked = "You already own this map."
MessageConfig.NeedPreviousMap = "Unlock %s first."
MessageConfig.NeedLevel = "Requires level %d."
MessageConfig.NotEnoughCoins = "Not enough coins."
MessageConfig.MapUnavailable = "This map is coming soon."
MessageConfig.MapLocked = "Unlock this map first."
MessageConfig.ModeLocked = "Requires level %d."
MessageConfig.MaxLevelReached = "Already at max level."
MessageConfig.UpgradeBought = "%s upgraded!"
MessageConfig.QuestCompleted = "Quest complete: %s"
MessageConfig.TargetReached = "Target reached!"
MessageConfig.LevelUp = "Level up! You are now level %d."
MessageConfig.NpcCaught = "Caught! -%ds"

return MessageConfig
