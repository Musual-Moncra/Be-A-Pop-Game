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
			Name: instance name of the centre MENU button (string)
			Swatch / OpenSwatch: centre button colour when closed / open (UIConfig.Swatches key)
			BadgeSize: diameter of the red notification dot (design pixels)
			Items: one row per button, left to right
				Id: unique key (string)
				Label: caption under the button (text)
				Icon: emoji on the button face (text)
				Swatch: button colour (UIConfig.Swatches key)
				Route: LobbyState route the button opens (LobbyState.Routes key)
				Big: true draws it larger with a sunburst (true/false)
				Name: optional instance name the onboarding tutorial looks up (string)
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
			Size: dot diameter (design pixels)
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
			LockedIcon: icon on days still locked (text)
			StreakFormat: streak line under the tiles (format: streak, streak length)
		Tabs: tab strip at the top of feature windows
			Height: tab button height (design pixels)
			Gap: space between tabs (design pixels)
		Card: item card used in shop and skins grids
			Width / Height: card size (design pixels)
			IconRatio: share of the card height used by the icon (0 to 1)
			ButtonHeight: height of the action button on a card (design pixels)
			SplitButtonWidth / SplitButtonInset: width and side margin of two side-by-side
				action buttons as a share of the card width (0 to 1)
		RarityColors: per rarity name, the colour of the rarity strip on cards (RGB)
		Shop: shop window
			Width / Height / Swatch / Title: window size (design pixels), header colour, title (text)
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "Passes", "Gems", "Coins", "Potions" or "Extras"
			RobuxFormat: price text (format: robux)
			OwnedText / SoonText / UseText: button text when owned / product id not set / potion use (text)
			ActiveFormat: potion card text while active (format: time left)
			TimeFormat: time left on a potion (format: minutes, seconds)
			CountFormat: potion count (format: count)
			StainBombIcon / NewbiePackIcon: item icons on the Extras tab (text)
			StainBombInfoFormat: Stain Bomb card line (format: area multiplier)
			NewbiePackInfoFormat: Newbie Pack card line (format: pet name, gems, coins, coin boost)
		Pets: pets window
			Width / Height / Swatch / Title: window size, header colour, title
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "MyPets" or "Index"
			PetIcon: emoji shown on every pet card (text)
			EquipText / UnequipText / EvolveText / DeleteText / DeleteConfirmText: pet card buttons (text)
			EvolveNeedFormat / EvolveMaxText: evolve button while short of copies / on a final variant
				(format: copies needed)
			SlotsFormat: equipped slots line (format: used, total)
			StinkFormat / PetStinkFormat: total Stink header and card Stink value (format: multiplier)
			StackFormat / StackOnlyFormat: stacks bar text with / without a known cap (format: stacks, cap)
			TraitFormat: rarity and variant line on a card (format: rarity, variant)
			EmptyText: inventory text when no pets are owned (text)
			DeleteConfirmSeconds: how long the DELETE button stays in its confirm state (seconds)
			Card: pet card and grid cell size, padding, icon share, button, delete, tag and stacks-bar
				heights (design pixels)
			Index: Pet Index section look and text
				Columns / TileWidth / TileHeight / TileIconSize: tile grid (count, design pixels)
				HeaderHeight / SectionGap / RewardHeight: section header, section gap, reward line (design pixels)
				ProgressFormat: discovered / total line (format: found, total)
				OddsFormat: drop odds line (format: drop odds denominator, decimal allowed)
				UnknownName / LockedIcon: undiscovered pet name and icon (text)
				RewardHeader / RewardFormat / RewardGemsFormat: reward preview (format: exclusive pet name, gems)
				ClaimedText / ComingSoonText / NoPetsText: section states (text)
		Skins: skins window
			Width / Height / Swatch / Title: window size, header colour, title
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "Crates" or "Skins"
			CrateIcon / SkinIcon: emoji for crates and skins (text)
			OpenFormat: open button text (format: price, currency icon)
			EquipText / EquippedText / LockedText: cosmetic card buttons (text)
			LastCrateFormat: banner after a crate (format: item name)
		PetReveal: full-screen pet drop reveal (design pixels unless noted)
			Width / Height / Swatch: card size and body colour (UIConfig.Swatches key)
			OverlayTransparency: dimmer behind the card (0 to 1)
			ShakeSeconds: silhouette shake before the pet is shown (seconds)
			RaysSize / IconSize: burst diameter and pet icon diameter (design pixels)
			RaritySwatches: body colour per rarity id (UIConfig.Swatches key)
			LockedIcon: icon shown on the shaking silhouette (text)
			NameFormat / StinkFormat / ConvertedFormat: reveal lines (format: pet name, stink multiplier, gems)
			NewTag / CollectText: NEW badge and collect button (text)
			CollectWidth / CollectHeight / CollectSwatch: collect button size and colour (design pixels, Swatches key)
			QueueToast: run toast when a pet drops and waits for the reveal (text)
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

return {
	Dock = {
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
		Name = "OnboardingMenuButton",
		Swatch = "Orange",
		OpenSwatch = "Red",
		BadgeSize = 34,
		BigScale = 1.25,
		Items = {
			{ Id = "Shop", Label = "SHOP", Icon = "🛒", Swatch = "Gold", Route = "Shop", Big = false },
			{
				Id = "Pets",
				Label = "PETS",
				Icon = "🐶",
				Swatch = "Blue",
				Route = "Pets",
				Big = false,
				Name = "OnboardingPetsButton",
			},
			{ Id = "Skins", Label = "SKINS", Icon = "🎨", Swatch = "Purple", Route = "Skins", Big = false },
			{
				Id = "Play",
				Label = "PLAY",
				Icon = "▶️",
				Swatch = "Green",
				Route = "Play",
				Big = true,
				Name = "OnboardingPlayButton",
			},
			{
				Id = "Upgrades",
				Label = "UPGRADE",
				Icon = "⚡",
				Swatch = "Orange",
				Route = "Upgrades",
				Big = false,
				Name = "OnboardingUpgradesButton",
			},
			{ Id = "Daily", Label = "DAILY", Icon = "🎁", Swatch = "Pink", Route = "Daily", Big = false },
			{ Id = "Rebirth", Label = "REBIRTH", Icon = "🌀", Swatch = "Teal", Route = "Rebirth", Big = false },
		},
	},

	Rays = {
		Count = 10,
		Thickness = 26,
		Color = Color3.fromRGB(255, 244, 160),
		Transparency = 0.35,
		SpinSeconds = 9,
		SizeRatio = 1.7,
	},

	Bounce = {
		Scale = 0.06,
		Seconds = 1.1,
	},

	Badge = {
		Size = 26,
		Text = "!",
		Swatch = "Red",
		PulseScale = 1.15,
		PulseSeconds = 1.2,
	},

	Layouts = {
		PC = {
			Dock = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24) },
		},
		Mobile = {
			Dock = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12) },
		},
	},

	Stations = {
		Upgrades = { Route = "Upgrades", ActionText = "Upgrade", ObjectText = "Upgrade Stand" },
		Crates = { Route = "Skins", ActionText = "Open", ObjectText = "Skin Crates" },
		Daily = { Route = "Daily", ActionText = "Claim", ObjectText = "Daily Gift" },
		Rebirth = { Route = "Rebirth", ActionText = "Rebirth", ObjectText = "Golden Poop" },
	},

	StationPrompt = {
		HoldDuration = 0,
		MaxActivationDistance = 14,
		KeyCode = Enum.KeyCode.E,
	},

	Daily = {
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
		LockedIcon = "🔒",
		StreakFormat = "Streak: %d / %d days",
	},

	Tabs = {
		Height = 58,
		Gap = 10,
	},

	Card = {
		Width = 196,
		Height = 236,
		IconRatio = 0.36,
		ButtonHeight = 48,
		SplitButtonWidth = 0.42,
		SplitButtonInset = 0.07,
	},

	RarityColors = {
		Common = Color3.fromRGB(196, 202, 214),
		Uncommon = Color3.fromRGB(96, 200, 120),
		Rare = Color3.fromRGB(80, 150, 255),
		Epic = Color3.fromRGB(170, 95, 240),
		Legendary = Color3.fromRGB(255, 190, 60),
		Mythical = Color3.fromRGB(255, 90, 160),
		Secret = Color3.fromRGB(40, 240, 200),
		Darkness = Color3.fromRGB(60, 40, 90),
	},

	Shop = {
		Width = 1100,
		Height = 720,
		Swatch = "Gold",
		Title = "SHOP",
		Tabs = {
			{ Id = "Passes", Label = "PASSES", Icon = "⭐", Swatch = "Gold" },
			{ Id = "Gems", Label = "GEMS", Icon = "💎", Swatch = "Purple" },
			{ Id = "Coins", Label = "COINS", Icon = "💰", Swatch = "Orange" },
			{ Id = "Potions", Label = "POTIONS", Icon = "🧪", Swatch = "Teal" },
			{ Id = "Extras", Label = "EXTRAS", Icon = "🧨", Swatch = "Red" },
		},
		RobuxFormat = "R$ %d",
		OwnedText = "OWNED",
		SoonText = "SOON",
		UseText = "USE",
		ActiveFormat = "ACTIVE %s",
		TimeFormat = "%d:%02d",
		CountFormat = "x%d",
		StainBombIcon = "💣",
		NewbiePackIcon = "🎁",
		StainBombInfoFormat = "Blasts stain over %sx the area around you",
		NewbiePackInfoFormat = "%s + %s 💎 + %s 💰 + x%s coins",
	},

	Pets = {
		Width = 1100,
		Height = 760,
		Swatch = "Blue",
		Title = "PETS",
		Tabs = {
			{ Id = "MyPets", Label = "MY PETS", Icon = "🐶", Swatch = "Blue" },
			{ Id = "Index", Label = "PET INDEX", Icon = "📖", Swatch = "Purple" },
		},
		PetIcon = "🐾",
		EquipText = "EQUIP",
		UnequipText = "UNEQUIP",
		EvolveText = "EVOLVE",
		EvolveNeedFormat = "%d NEEDED",
		EvolveMaxText = "MAX",
		DeleteText = "DELETE",
		DeleteConfirmText = "SURE?",
		DeleteConfirmSeconds = 2.5,
		SlotsFormat = "Slots %d / %d",
		StinkFormat = "💩 Stink x%s",
		PetStinkFormat = "💩 x%s",
		StackFormat = "%d / %d",
		StackOnlyFormat = "%d stacks",
		TraitFormat = "%s  •  %s",
		EmptyText = "No pets yet. Clear a map to catch one!",
		Card = {
			Width = 240,
			Height = 384,
			IconRatio = 0.28,
			Padding = 14,
			Gap = 10,
			ButtonHeight = 40,
			DeleteHeight = 34,
			TagHeight = 26,
			StackBarHeight = 20,
		},
		Index = {
			Columns = 5,
			TileWidth = 176,
			TileHeight = 174,
			TileIconSize = 62,
			HeaderHeight = 52,
			SectionGap = 18,
			RewardHeight = 40,
			ProgressFormat = "%d/%d",
			OddsFormat = "1/%s",
			UnknownName = "???",
			LockedIcon = "❔",
			RewardHeader = "COMPLETE TO EARN",
			RewardFormat = "%s + %d 💎",
			RewardGemsFormat = "%d 💎",
			ClaimedText = "🎁 CLAIMED",
			ComingSoonText = "COMING SOON",
			NoPetsText = "No pets live here yet",
		},
	},

	Skins = {
		Width = 1100,
		Height = 720,
		Swatch = "Purple",
		Title = "SKINS",
		Tabs = {
			{ Id = "Crates", Label = "CRATES", Icon = "📦", Swatch = "Gold" },
			{ Id = "Skins", Label = "SKINS", Icon = "💩", Swatch = "Purple" },
		},
		CrateIcon = "📦",
		SkinIcon = "💩",
		OpenFormat = "%s %s",
		EquipText = "EQUIP",
		EquippedText = "EQUIPPED",
		LockedText = "🔒",
		LastCrateFormat = "You got %s!",
	},

	PetReveal = {
		Width = 620,
		Height = 540,
		Swatch = "Purple",
		OverlayTransparency = 0.25,
		ShakeSeconds = 1.2,
		RaysSize = 460,
		IconSize = 170,
		RaritySwatches = {
			Common = "Grey",
			Uncommon = "Green",
			Rare = "Blue",
			Epic = "Purple",
			Legendary = "Gold",
			Mythical = "Pink",
			Secret = "Teal",
			Darkness = "Grey",
		},
		LockedIcon = "❔",
		NameFormat = "%s!",
		StinkFormat = "💩 Stink x%s",
		ConvertedFormat = "Bag full! +%d 💎 instead",
		NewTag = "NEW!",
		CollectText = "COLLECT",
		CollectWidth = 360,
		CollectHeight = 72,
		CollectSwatch = "Green",
		QueueToast = "🐾 New pet found! Reveal after the run",
	},

	Rebirth = {
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
	},
}
