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
		NeedPreviousComplete: previous map is not 100% stained yet, %s = that map's name (text)
		MapComplete: a map reached 100% for the first time, %s = map name, %d = gems (text)
		SpecialTimeStart: Special Time began, %s = map name, %d = gem multiplier, %d = duration (text)
		NotEnoughGems: not enough gems for a purchase (text)
		RebirthSuccess: player rebirthed successfully, %d = new rebirth count (text)
		CosmeticUnlocked: cosmetic unlocked from crate, %s = cosmetic name (text)
		CosmeticDuplicate: duplicate cosmetic rolled, refunded coins (text)
		CosmeticEquipped: cosmetic equipped, %s = cosmetic name (text)
		CosmeticUnequipped: cosmetic unequipped (text)
		CosmeticNotOwned: player does not own the cosmetic (text)
		InvalidCrate: crate does not exist (text)
		RunUnavailable: the selected map has no world model loaded so a run cannot start (text)
		DataLoading: a run was requested before the player's save finished loading (text)
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
MessageConfig.NeedPreviousComplete = "Stain 100%% of %s first."
MessageConfig.MapComplete = "%s fully stained! +%d gems"
MessageConfig.SpecialTimeStart = "Special Time on %s! x%d gems for %ds"
MessageConfig.NotEnoughGems = "Not enough gems."
MessageConfig.RebirthSuccess = "Rebirth #%d achieved! Multipliers boosted!"
MessageConfig.CosmeticUnlocked = "Unlocked: %s!"
MessageConfig.CosmeticDuplicate = "Duplicate! Refunded %d coins."
MessageConfig.CosmeticEquipped = "%s equipped!"
MessageConfig.CosmeticUnequipped = "Cosmetic unequipped."
MessageConfig.CosmeticNotOwned = "You do not own this cosmetic."
MessageConfig.InvalidCrate = "Invalid crate."
MessageConfig.RunUnavailable = "This map is not ready yet. Try again later."
MessageConfig.DataLoading = "Your save is still loading. Try again in a moment."

return MessageConfig
