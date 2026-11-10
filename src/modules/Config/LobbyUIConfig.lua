--!strict

--[[
	LobbyUIConfig
	Look, layout and text of the lobby HUD (side button rail, big PLAY button), the lobby
	station prompts and the feature windows opened from them. Swatch names are
	UIConfig.Swatches keys; sizes are UIConfig design pixels. Pure data, no functions.

	Fields:
		Dock: the always-visible lobby layout (no MENU fold-out)
			TileSize / TileGap / TileColumns: left grid tile diameter, gap and column count
			TileLabelHeight / TileLabelSize: caption height and text size under a tile
			PlaySize / PlayIconSize / PlayTextSize: right PLAY button size, icon and label
			PlayIcon / PlayLabel / PlaySwatch: PLAY icon, caption and colour
			PlayPulseScale / PlayPulseSeconds: idle PLAY pulse size and cycle
			TimerWidth / TimerHeight / TimerIconSize / TimerGap / TimerMax / TimerTextSize: active
				potion/boost timer pills under PLAY (design pixels, count)
			TimerFormat: timer text (format: minutes, seconds)
			PotionSwatch / CoinBoostSwatch / BoostSwatch: timer pill colours
			CoinBoostIcon / BoostIcons / BoostFormat: purchased boost icon and daily boost icons/label
			Items: one tile per grid slot, left to right then top to bottom
				Id: unique key (string)
				Label: caption under the tile (text)
				Icon: emoji on the tile (text)
				Swatch: tile colour (UIConfig.Swatches key)
				Route: LobbyState route the tile opens (LobbyState.Routes key)
				Name: optional instance name the onboarding tutorial looks up (string)
			ButtonSize / ItemSize / LabelHeight / Lift / BigScale / Stagger / Margin: legacy fields
				kept for the onboarding hint layout while it catches up (design pixels)
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
		Layouts: per UIConfig layout ("PC" / "Mobile"), AnchorPoint + Position of the Grid, Play, Timers
			and the legacy Dock (kept for the onboarding hint)
		Stations: lobby booths, keyed by the LobbyStation attribute on their Prompt part
			Route: LobbyState route opened by the prompt (LobbyState.Routes key)
			ActionText: prompt action text (text)
			ObjectText: prompt object text (text)
		StationPrompt: ProximityPrompt tuning for every station
			HoldDuration: hold time before it triggers (seconds)
			MaxActivationDistance: how close the player must be (studs)
			KeyCode: keyboard key (Enum.KeyCode)
		Daily: daily reward window
			Width / Height / Icon: window size (design pixels) and header emoji
			Columns / PhoneColumns: day tiles per row on PC / phone (count)
			TileWidth / TileHeight / TileGap: day tile size and gap (design pixels)
			DaySevenScale / DaySevenSwatch: width multiplier and colour of day 7 (multiplier, Swatches key)
			TileIconSize: reward emoji size (design pixels)
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
			Width / Height / Swatch / Title / Icon: window size (design pixels), header colour, title, emoji
			CardWidth / CardHeight / GridGap: product card size and gap between cards (design pixels)
			PassRowHeight: height of one wide pass card (design pixels)
			BestValue: product that gets the BEST VALUE ribbon per tab (pack index or product key)
			BestValueText: ribbon text (text)
			BonusFormat: gem pack bonus line (format: bonus percent)
			CoinBonusText / OneShotText: bonus lines for coin packs and one-shot products (text)
			PotionStatFormat: potion multiplier line (format: multiplier, stat)
			NewbiePackText: Newbie Pack card title (text)
			Perks: pass perk lines and separator (format: value; text)
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
			Width / Height / Swatch / Title / Icon: window size, header colour, title, emoji
			CardWidth / CardHeight / CardGap / Columns / PhoneColumns: pet card size, gap and columns (design pixels / count)
			CardIconSize: emoji size on a pet card (design pixels)
			DetailsWidth / DetailsGap: right details panel width and gap to the grid (design pixels)
			ActionHeight: EQUIP / EVOLVE / DELETE button height (design pixels)
			HeaderLineHeight: equipped / Stink line height (design pixels)
			StackBarHeight: stacks bar height (design pixels)
			SheetHeight / SheetCloseSize: phone bottom sheet height and close button size (design pixels)
			HeaderFormat: equipped / Stink line (format: used, total, stink)
			DetailsEmptyText: details panel placeholder (text)
			DetailsNameSize / DetailsIconSize: pet name and big icon sizes (design pixels)
			EquippedIcon: check mark on an equipped pet card (text)
			VariantSwatches: variant id -> UIConfig.Swatches key for the variant chip
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
				ProgressHeight: progress bar height (design pixels)
				RewardBoxHeight / RewardBoxWidth: exclusive reward box size (design pixels)
				HeaderHeight / SectionGap / RewardHeight: section header, section gap, reward line (design pixels)
				ProgressFormat: discovered / total line (format: found, total)
				OddsFormat: drop odds line (format: drop odds denominator, decimal allowed)
				UnknownName / LockedIcon: undiscovered pet name and icon (text)
				RewardHeader / RewardFormat / RewardGemsFormat: reward preview (format: exclusive pet name, gems)
				ClaimedText / ComingSoonText / NoPetsText: section states (text)
		Skins: skins window
			Width / Height / Swatch / Title / Icon: window size, header colour, title, emoji
			Tabs: tab rows { Id, Label, Icon, Swatch }; Id is "Crates" or "Skins"
			CrateIcon / SkinIcon: emoji for crates and skins (text)
			OpenFormat: open button text (format: price, currency icon)
			EquipText / EquippedText / LockedText: cosmetic card buttons (text)
			LastCrateFormat: banner after a crate (format: item name)
		Upgrade: upgrade window
			Width / Height / Swatch / Title / Icon: window size, header colour, title, emoji
			RowHeight / RowGap / RowPadding: one upgrade row and its gaps (design pixels)
			IconSize: upgrade icon tile diameter (design pixels)
			PipWidth / PipHeight / PipGap / PipRadius: level pips (design pixels)
			BuyWidth / BuyHeight / MaxStampWidth: BUY and MAX control sizes (design pixels)
			LevelFormat: level line (format: level, max level)

		Play: play window header
			Swatch / Title / Icon: header colour, title, emoji
			EditIcon / BrowseIcon / RoomIcon: create, browse and room headers (text)

		RaritySwatches: rarity id -> UIConfig.Swatches key for cards and chips

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
			HeroSize / RowHeight / RowGap: hero icon, info row and row gap (design pixels)
			ButtonWidth / ButtonHeight: REBIRTH button size (design pixels)
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
		TileSize = 84,
		TileLabelHeight = 22,
		TileLabelSize = 18,
		TileGap = 10,
		TileColumns = 2,
		PlaySize = 150,
		PlayIcon = "▶",
		PlayLabel = "PLAY",
		PlaySwatch = "Green",
		PlayIconSize = 40,
		PlayTextSize = 30,
		PlayPulseScale = 1.05,
		PlayPulseSeconds = 1.2,
		TimerWidth = 180,
		TimerHeight = 34,
		TimerIconSize = 42,
		TimerGap = 6,
		TimerMax = 3,
		TimerTextSize = 18,
		TimerFormat = "%d:%02d",
		PotionSwatch = "Teal",
		CoinBoostSwatch = "Gold",
		BoostSwatch = "Purple",
		CoinBoostIcon = "💰",
		BoostIcons = { Coins = "💰", Stacks = "💩" },
		BoostFormat = "x%s %s",
		MobileTileSize = 64,
		MobileTileLabelHeight = 20,
		MobileTileLabelSize = 16,
		MobileTileGap = 8,
		MobilePlaySize = 120,
		MobilePlayIconSize = 34,
		MobilePlayTextSize = 26,
		MobileTimerWidth = 150,
		MobileTimerHeight = 30,
		MobileTimerIconSize = 36,
		MobileTimerTextSize = 16,
		ButtonSize = 150,
		ItemSize = 84,
		LabelHeight = 22,
		Lift = 0,
		BigScale = 1,
		Stagger = 0,
		Margin = 24,
		Items = {
			{ Id = "Shop", Label = "SHOP", Icon = "🛒", Swatch = "Gold", Route = "Shop" },
			{
				Id = "Pets",
				Label = "PETS",
				Icon = "🐶",
				Swatch = "Pink",
				Route = "Pets",
				Name = "OnboardingPetsButton",
			},
			{ Id = "Index", Label = "INDEX", Icon = "📖", Swatch = "Purple", Route = "Pets" },
			{
				Id = "Upgrades",
				Label = "UPGRADES",
				Icon = "⚡",
				Swatch = "Green",
				Route = "Upgrades",
				Name = "OnboardingUpgradesButton",
			},
			{ Id = "Daily", Label = "DAILY", Icon = "🎁", Swatch = "Orange", Route = "Daily" },
			{ Id = "Rebirth", Label = "REBIRTH", Icon = "♻️", Swatch = "Blue", Route = "Rebirth" },
			{ Id = "Skins", Label = "SKINS", Icon = "👕", Swatch = "Teal", Route = "Skins" },
			{ Id = "Rooms", Label = "ROOMS", Icon = "👥", Swatch = "Grey", Route = "Play" },
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
			Dock = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0.32, 0) },
			Grid = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 28, 0, 96) },
			Play = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0.32, 0) },
			Timers = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0.52, 0) },
		},
		Mobile = {
			Dock = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0.24, 0) },
			Grid = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 16, 0, 84) },
			Play = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0.24, 0) },
			Timers = { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0.48, 0) },
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
		Width = 820,
		Height = 560,
		Columns = 7,
		PhoneColumns = 4,
		TileWidth = 96,
		TileHeight = 130,
		TileGap = 6,
		DaySevenScale = 1.3,
		DaySevenSwatch = "Gold",
		TileIconSize = 52,
		ClaimHeight = 76,
		RaysRatio = 1.4,
		Swatch = "Orange",
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
		Height = 52,
		Gap = 8,
	},

	Card = {
		Width = 180,
		Height = 230,
		IconRatio = 0.36,
		ButtonHeight = 48,
		SplitButtonWidth = 0.42,
		SplitButtonInset = 0.07,
	},

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
		Width = 820,
		Height = 560,
		Swatch = "Gold",
		Title = "SHOP",
		Icon = "🛒",
		CardWidth = 180,
		CardHeight = 230,
		GridGap = 12,
		PassRowHeight = 104,
		BestValue = {
			Gems = 4,
			Coins = 4,
			Potions = "StinkPotion",
			Extras = "NewbiePack",
			Passes = "DoubleCoins",
		},
		BestValueText = "BEST VALUE",
		BonusFormat = "+%d%% BONUS",
		CoinBonusText = "POOP COINS",
		OneShotText = "ONE SHOT",
		PotionStatFormat = "%dx %s",
		NewbiePackText = "NEWBIE PACK",
		Perks = {
			Coins = "x%s coins",
			Gems = "x%s gems",
			PetSlots = "+%d pet slots",
			Magnet = "wider snack pickup",
			Vip = "VIP stainer look",
			Separator = "  ·  ",
		},
		Tabs = {
			{ Id = "Gems", Label = "GEMS", Icon = "💎", Swatch = "Purple" },
			{ Id = "Coins", Label = "COINS", Icon = "💰", Swatch = "Orange" },
			{ Id = "Potions", Label = "POTIONS", Icon = "🧪", Swatch = "Teal" },
			{ Id = "Extras", Label = "EXTRAS", Icon = "🧨", Swatch = "Red" },
			{ Id = "Passes", Label = "PASSES", Icon = "⭐", Swatch = "Gold" },
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
		Width = 980,
		Height = 620,
		Swatch = "Pink",
		Title = "PETS",
		Icon = "🐾",
		CardWidth = 120,
		CardHeight = 140,
		CardGap = 10,
		Columns = 5,
		PhoneColumns = 3,
		CardIconSize = 56,
		DetailsWidth = 260,
		DetailsGap = 16,
		ActionHeight = 48,
		HeaderLineHeight = 24,
		StackBarHeight = 16,
		SheetHeight = 300,
		SheetCloseSize = 44,
		HeaderFormat = "Equipped %d/%d  ·  Stink x%s total",
		DetailsEmptyText = "Tap a pet to see it here.",
		DetailsNameSize = 34,
		DetailsIconSize = 130,
		EquippedIcon = "✔",
		VariantSwatches = {
			Golden = "Gold",
			Rainbow = "Purple",
			Stinky = "Brown",
		},
		Tabs = {
			{ Id = "MyPets", Label = "MY PETS", Icon = "🐶", Swatch = "Pink" },
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
			Columns = 4,
			TileWidth = 150,
			TileHeight = 160,
			TileIconSize = 64,
			HeaderHeight = 52,
			SectionGap = 16,
			RewardHeight = 56,
			ProgressHeight = 22,
			RewardBoxHeight = 76,
			RewardBoxWidth = 220,
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

	Upgrade = {
		Width = 820,
		Height = 560,
		Swatch = "Green",
		Title = "UPGRADES",
		Icon = "⚡",
		RowHeight = 96,
		RowGap = 10,
		RowPadding = 12,
		IconSize = 72,
		PipWidth = 6,
		PipHeight = 16,
		PipGap = 3,
		PipRadius = 4,
		BuyWidth = 170,
		BuyHeight = 54,
		MaxStampWidth = 130,
		LevelFormat = "Lv %d / %d",
	},

	Skins = {
		Width = 820,
		Height = 560,
		Swatch = "Teal",
		Title = "SKINS",
		Icon = "🎨",
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

	Play = {
		Swatch = "Green",
		Title = "PLAY",
		Icon = "▶️",
		EditIcon = "⚙️",
		BrowseIcon = "🔎",
		RoomIcon = "👥",
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
		Width = 820,
		Height = 560,
		Swatch = "Blue",
		HeroSize = 120,
		RowHeight = 44,
		RowGap = 6,
		ButtonWidth = 360,
		ButtonHeight = 64,
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
