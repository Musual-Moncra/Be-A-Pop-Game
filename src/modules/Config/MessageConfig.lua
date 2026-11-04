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
		PetHatched: a pet came out of an egg, %s = pet name (text)
		PetHatchedVariant: a variant pet came out of an egg, first %s = pet name, second %s = variant name (text)
		PetInventoryFull: hatching blocked because the pet inventory is full (text)
		PetEggLocked: egg map is not unlocked, %s = map name (text)
		PetSlotsFull: equipping blocked because every slot is taken (text)
		PetMergeNeed: merging blocked because there are not enough identical pets (text)
		PetMaxVariant: merging blocked because the pet is already at its final variant (text)
		PetMerged: merge succeeded, first %s = pet name, second %s = new variant name (text)
		GoldenSoiled: a golden target was fully soiled, %s = object name, %d = gems paid (text)
]]

return {
	MapUnlocked = "%s unlocked!",

	AlreadyUnlocked = "You already own this map.",

	NeedPreviousMap = "Unlock %s first.",

	NeedLevel = "Requires level %d.",

	NotEnoughCoins = "Not enough coins.",

	MapUnavailable = "This map is coming soon.",

	MapLocked = "Unlock this map first.",

	ModeLocked = "Requires level %d.",

	MaxLevelReached = "Already at max level.",

	UpgradeBought = "%s upgraded!",

	QuestCompleted = "Quest complete: %s",

	TargetReached = "Target reached!",

	LevelUp = "Level up! You are now level %d.",

	NpcCaught = "Caught! -%ds",

	NeedPreviousComplete = "Stain 100%% of %s first.",

	MapComplete = "%s fully stained! +%d gems",

	SpecialTimeStart = "Special Time on %s! x%d gems for %ds",

	NotEnoughGems = "Not enough gems.",

	RebirthSuccess = "Rebirth #%d achieved! Multipliers boosted!",

	CosmeticUnlocked = "Unlocked: %s!",

	CosmeticDuplicate = "Duplicate! Refunded %d coins.",

	CosmeticEquipped = "%s equipped!",

	CosmeticUnequipped = "Cosmetic unequipped.",

	CosmeticNotOwned = "You do not own this cosmetic.",

	InvalidCrate = "Invalid crate.",

	RunUnavailable = "This map is not ready yet. Try again later.",

	DataLoading = "Your save is still loading. Try again in a moment.",

	PetHatched = "%s hatched!",

	PetHatchedVariant = "%s hatched! (%s)",

	PetInventoryFull = "Pet inventory is full.",

	PetEggLocked = "Unlock %s first.",

	PetSlotsFull = "All pet slots are full.",

	PetMergeNeed = "You need 5 identical pets to merge.",

	PetMaxVariant = "This pet is already at its final variant.",

	PetMerged = "%s merged into a %s!",

	GoldenSoiled = "Golden %s! +%d gems",
}
