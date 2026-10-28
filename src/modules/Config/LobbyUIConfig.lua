--!strict

--[[
	LobbyUIConfig
	Look, layout and text of the lobby HUD (side button rail, big PLAY button), the lobby
	station prompts and the feature windows opened from them. Swatch names are
	UIConfig.Swatches keys; sizes are UIConfig design pixels. Pure data, no functions.

	Fields:
		Dock: the single lobby button at the bottom centre; pressing it pops a row of buttons above it
			ButtonSize: diameter of the centre button (design pixels)
			ItemSize: diameter of one row button (design pixels)
			LabelHeight: caption height under a row button (design pixels)
			Gap: space between row buttons (design pixels)
			Lift: space between the row and the centre button (design pixels)
			Margin: space kept free at both screen sides; a wider row shrinks to fit (design pixels)
			Stagger: delay between two row buttons popping out (seconds)
			Icon / OpenIcon: emoji on the centre button when closed / open (text)
			Label: caption on the centre button (text)
			Swatch / OpenSwatch: centre button colour when closed / open (UIConfig.Swatches key)
			BadgeSize: diameter of the red notification dot (design pixels)
			Items: one row per button, left to right
				Id: unique key (string)
				Label: caption under the button (text)
				Icon: emoji on the button face (text)
				Swatch: button colour (UIConfig.Swatches key)
				Route: LobbyState route the button opens (LobbyState.Routes key)
				Big: true draws it larger with a sunburst (true/false)
			BigScale: size of a Big button compared to ItemSize (multiplier)
		Rays: rotating sunburst drawn behind highlighted buttons
			Count: number of rays (count)
			Thickness: width of one ray (design pixels)
			Color: ray colour (RGB)
			Transparency: transparency at the centre of a ray (0 to 1)
			SpinSeconds: time for one full turn (seconds)
			SizeRatio: ray length as a multiple of the button size (multiplier)
		Bounce: idle bounce of highlighted buttons
			Scale: largest extra scale at the top of a bounce (multiplier)
			Seconds: length of one bounce (seconds)
		Badge: notification dot
			Text: text in the dot (text)
			Swatch: dot colour (UIConfig.Swatches key)
			PulseScale: largest scale of the pulse (multiplier)
			PulseSeconds: length of one pulse (seconds)
		Layouts: per UIConfig layout ("PC" / "Mobile"), AnchorPoint + Position of the Dock
		Stations: lobby booths, keyed by the LobbyStation attribute on their Prompt part
			Route: LobbyState route opened by the prompt (LobbyState.Routes key)
			ActionText: prompt action text (text)
			ObjectText: prompt object text (text)
		StationPrompt: ProximityPrompt tuning for every station
			HoldDuration: hold time before it triggers (seconds)
			MaxActivationDistance: how close the player must be (studs)
			KeyCode: keyboard key (Enum.KeyCode)
		Daily: daily reward window
			Width / Height: window size (design pixels)
			Columns: day tiles per row (count)
			TileHeight: height of one day tile (design pixels)
			ClaimHeight: height of the claim button (design pixels)
			RaysRatio: size of the sunburst behind today's tile as a multiple of TileHeight (multiplier)
			Swatch: window header colour (UIConfig.Swatches key)
			KindVisuals: per reward Kind ("Coins", "Gems", "Boost", "Skin"), Icon (emoji) and Swatch
			Title: window title (text)
			DayFormat: caption on each tile (format: day number)
			Claim: claim button text (text)
			NextFormat: button text while waiting (format: hh:mm:ss)
			Claimed: stamp on claimed tiles (text)
			StreakFormat: streak line under the tiles (format: streak, streak length)
		Tabs: tab strip at the top of feature windows
			Height: tab button height (design pixels)
			Gap: space between tabs (design pixels)
		Card: item card used in shop, pets and skins grids
			Width / Height: card size (design pixels)
			IconRatio: share of the card height used by the icon (0 to 1)
			ButtonHeight: height of the action button on a card (design pixels)
		RarityColors: per rarity name, the colour of the rarity strip on cards (RGB)
		Shop: shop window
			Width / Height / Swatch / Title: window size (design pixels), header colour, title (text)
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "Passes", "Gems", "Coins" or "Potions"
			RobuxFormat: price text (format: robux)
			OwnedText / SoonText / UseText: button text when owned / product id not set / potion use (text)
			ActiveFormat: potion card text while active (format: time left)
			TimeFormat: time left on a potion (format: minutes, seconds)
			CountFormat: potion count (format: count)
		Pets: pets window
			Width / Height / Swatch / Title: window size, header colour, title
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "Eggs" or "Inventory"
			EggIcon / PetIcon: emoji shown for eggs / pets (text)
			HatchFormat: hatch button text (format: coin price)
			LockedText: hatch button text while the egg's map is locked (text)
			EquipText / UnequipText / MergeText: pet card buttons (text)
			SlotsFormat: equipped slots line (format: equipped, slots)
			MultiplierFormat: pet bonus line (format: coin multiplier, stink multiplier)
			EmptyText: inventory text when no pets are owned (text)
			LastHatchFormat: banner after a hatch (format: pet name, variant name)
		Skins: skins window
			Width / Height / Swatch / Title: window size, header colour, title
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "Crates", "Skins" or "Trails"
			CrateIcon / SkinIcon / TrailIcon: emoji for crates, skins, trails (text)
			OpenFormat: open button text (format: price, currency icon)
			EquipText / EquippedText / UnequipText / LockedText: cosmetic card buttons (text)
			LastCrateFormat: banner after a crate (format: item name)
		Rebirth: rebirth window
			Width / Height / Swatch / Title: window size, header colour, title
			Icon: big emoji (text)
			Lines: info lines
				Count: rebirth count line (format: count)
				Multiplier: coin bonus comparison line (format: current multiplier, next multiplier)
				Gems: gems reward line (format: gems)
				Cost: coins cost line (format: coins cost)
			Button: rebirth button text (text)
			Warning: line explaining what resets (text)
]]

local LobbyUIConfig = {}

LobbyUIConfig.Dock = {
	ButtonSize = 118,
	ItemSize = 86,
	LabelHeight = 24,
	Gap = 14,
	Lift = 18,
	Margin = 24,
	Stagger = 0.035,
	Icon = "💩",
	OpenIcon = "✖️",
	Label = "MENU",
	Swatch = "Orange",
	OpenSwatch = "Red",
	BadgeSize = 34,
	BigScale = 1.25,
	Items = {
		{ Id = "Shop", Label = "SHOP", Icon = "🛒", Swatch = "Gold", Route = "Shop", Big = false },
		{ Id = "Pets", Label = "PETS", Icon = "🐶", Swatch = "Blue", Route = "Pets", Big = false },
		{ Id = "Skins", Label = "SKINS", Icon = "🎨", Swatch = "Purple", Route = "Skins", Big = false },
		{ Id = "Play", Label = "PLAY", Icon = "▶️", Swatch = "Green", Route = "Play", Big = true },
		{ Id = "Upgrades", Label = "UPGRADE", Icon = "⚡", Swatch = "Orange", Route = "Upgrades", Big = false },
		{ Id = "Daily", Label = "DAILY", Icon = "🎁", Swatch = "Pink", Route = "Daily", Big = false },
		{ Id = "Rebirth", Label = "REBIRTH", Icon = "🌀", Swatch = "Teal", Route = "Rebirth", Big = false },
		{ Id = "Stats", Label = "STATS", Icon = "🏆", Swatch = "Grey", Route = "Stats", Big = false },
	},
}

LobbyUIConfig.Rays = {
	Count = 10,
	Thickness = 26,
	Color = Color3.fromRGB(255, 244, 160),
	Transparency = 0.35,
	SpinSeconds = 9,
	SizeRatio = 1.7,
}

LobbyUIConfig.Bounce = {
	Scale = 0.06,
	Seconds = 1.1,
}

LobbyUIConfig.Badge = {
	Text = "!",
	Swatch = "Red",
	PulseScale = 1.18,
	PulseSeconds = 0.7,
}

LobbyUIConfig.Layouts = {
	PC = {
		Dock = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24) },
	},
	Mobile = {
		Dock = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12) },
	},
}

LobbyUIConfig.Stations = {
	Upgrades = { Route = "Upgrades", ActionText = "Upgrade", ObjectText = "Upgrade Stand" },
	Eggs = { Route = "Pets", ActionText = "Hatch", ObjectText = "Pet Eggs" },
	Crates = { Route = "Skins", ActionText = "Open", ObjectText = "Skin Crates" },
	Daily = { Route = "Daily", ActionText = "Claim", ObjectText = "Daily Gift" },
	Rebirth = { Route = "Rebirth", ActionText = "Rebirth", ObjectText = "Golden Poop" },
}

LobbyUIConfig.StationPrompt = {
	HoldDuration = 0,
	MaxActivationDistance = 14,
	KeyCode = Enum.KeyCode.E,
}

LobbyUIConfig.Daily = {
	Width = 980,
	Height = 600,
	Columns = 4,
	TileHeight = 170,
	ClaimHeight = 80,
	RaysRatio = 1.4,
	Swatch = "Pink",
	KindVisuals = {
		Coins = { Icon = "💰", Swatch = "Gold" },
		Gems = { Icon = "💎", Swatch = "Purple" },
		Boost = { Icon = "🚀", Swatch = "Blue" },
		Skin = { Icon = "👑", Swatch = "Pink" },
	},
	Title = "DAILY GIFTS",
	DayFormat = "DAY %d",
	Claim = "CLAIM!",
	NextFormat = "NEXT IN %s",
	Claimed = "✅",
	StreakFormat = "Streak: %d / %d days",
}

LobbyUIConfig.Tabs = {
	Height = 58,
	Gap = 10,
}

LobbyUIConfig.Card = {
	Width = 196,
	Height = 236,
	IconRatio = 0.36,
	ButtonHeight = 48,
}

LobbyUIConfig.RarityColors = {
	Common = Color3.fromRGB(196, 202, 214),
	Uncommon = Color3.fromRGB(96, 200, 120),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(170, 95, 240),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythical = Color3.fromRGB(255, 90, 160),
	Secret = Color3.fromRGB(40, 240, 200),
	Darkness = Color3.fromRGB(60, 40, 90),
}

LobbyUIConfig.Shop = {
	Width = 1100,
	Height = 720,
	Swatch = "Gold",
	Title = "SHOP",
	Tabs = {
		{ Id = "Passes", Label = "PASSES", Icon = "⭐", Swatch = "Gold" },
		{ Id = "Gems", Label = "GEMS", Icon = "💎", Swatch = "Purple" },
		{ Id = "Coins", Label = "COINS", Icon = "💰", Swatch = "Orange" },
		{ Id = "Potions", Label = "POTIONS", Icon = "🧪", Swatch = "Teal" },
	},
	RobuxFormat = "R$ %d",
	OwnedText = "OWNED",
	SoonText = "SOON",
	UseText = "USE",
	ActiveFormat = "ACTIVE %s",
	TimeFormat = "%d:%02d",
	CountFormat = "x%d",
}

LobbyUIConfig.Pets = {
	Width = 1100,
	Height = 720,
	Swatch = "Blue",
	Title = "PETS",
	Tabs = {
		{ Id = "Eggs", Label = "EGGS", Icon = "🥚", Swatch = "Gold" },
		{ Id = "Inventory", Label = "MY PETS", Icon = "🐶", Swatch = "Blue" },
	},
	EggIcon = "🥚",
	PetIcon = "🐾",
	HatchFormat = "💰 %s",
	LockedText = "🔒 LOCKED",
	EquipText = "EQUIP",
	UnequipText = "UNEQUIP",
	MergeText = "MERGE x5",
	SlotsFormat = "Equipped %d / %d",
	MultiplierFormat = "💰 x%s   💩 x%s",
	EmptyText = "No pets yet. Hatch an egg!",
	LastHatchFormat = "You hatched %s (%s)!",
}

LobbyUIConfig.Skins = {
	Width = 1100,
	Height = 720,
	Swatch = "Purple",
	Title = "SKINS & TRAILS",
	Tabs = {
		{ Id = "Crates", Label = "CRATES", Icon = "📦", Swatch = "Gold" },
		{ Id = "Skins", Label = "SKINS", Icon = "💩", Swatch = "Purple" },
		{ Id = "Trails", Label = "TRAILS", Icon = "✨", Swatch = "Pink" },
	},
	CrateIcon = "📦",
	SkinIcon = "💩",
	TrailIcon = "✨",
	OpenFormat = "%s %s",
	EquipText = "EQUIP",
	EquippedText = "EQUIPPED",
	UnequipText = "TAKE OFF",
	LockedText = "🔒",
	LastCrateFormat = "You got %s!",
}

LobbyUIConfig.Rebirth = {
	Width = 640,
	Height = 600,
	Swatch = "Teal",
	Title = "REBIRTH",
	Icon = "🌀",
	Lines = {
		Count = "Rebirths: %d",
		Multiplier = "Coin bonus now: x%s  ➡️  x%s",
		Gems = "Reward: +%d 💎",
		Cost = "Cost: %s 💰",
	},
	Button = "REBIRTH!",
	Warning = "Resets your coins and upgrades. Pets, skins and gems stay.",
}

return LobbyUIConfig
