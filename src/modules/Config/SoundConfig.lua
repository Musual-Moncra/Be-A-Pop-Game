--!strict

--[[
	SoundConfig
	Every sound the client can play and the music track for each place. Pure data, no functions.

	A SoundId of "" means the sound is not ready: SoundController skips it silently, so keys can
	be listed before the audio library is uploaded. Upload a file, paste its rbxassetid:// or
	rbxasset:// id and the same key starts playing.

	Fields:
		FolderName: name of the SoundService folder that holds live Sound instances (string)
		MaxSoundLifetime: safety cleanup for a Sound whose Ended never fires because the asset
			failed to load (seconds)
		Sfx: one entry per sound effect, keyed by the name SoundController.Play takes
			SoundId: asset id, "" = key is not ready and is skipped (asset id)
			Volume: playback volume, 0..1 (linear volume)
			PitchMin: lowest random PlaybackSpeed a play can roll (playback speed)
			PitchMax: highest random PlaybackSpeed a play can roll (playback speed)
			MaxConcurrent: most copies of this key allowed to play at once (count)
			Throttle: shortest time between two accepted plays of this key, 0 = no throttle
				(seconds)
		Music: background music settings
			CrossfadeSeconds: fade time when switching or stopping a track (seconds)
			Lobby: track played in the lobby
				SoundId: asset id, "" = silence (asset id)
				Volume: playback volume, 0..1 (linear volume)
			Maps: one track per map id, keyed by MapConfig id; a map with an empty or missing
				track falls back to Lobby
				SoundId: asset id, "" = silence (asset id)
				Volume: playback volume, 0..1 (linear volume)
]]

local SoundConfig = {}

SoundConfig.FolderName = "Sound"
SoundConfig.MaxSoundLifetime = 10

SoundConfig.Sfx = {
	Stain = {
		SoundId = "rbxasset://sounds/impact_water.mp3",
		Volume = 0.22,
		PitchMin = 0.85,
		PitchMax = 1.15,
		MaxConcurrent = 3,
		Throttle = 0.09,
	},
	Soiled = {
		SoundId = "rbxasset://sounds/snap.wav",
		Volume = 0.5,
		PitchMin = 1,
		PitchMax = 1.15,
		MaxConcurrent = 2,
		Throttle = 0.05,
	},
	FoodEaten = {
		SoundId = "rbxasset://sounds/switch3.wav",
		Volume = 0.45,
		PitchMin = 0.95,
		PitchMax = 1.15,
		MaxConcurrent = 2,
		Throttle = 0.06,
	},
	NpcCaught = {
		SoundId = "rbxasset://sounds/uuhhh.mp3",
		Volume = 0.55,
		PitchMin = 1,
		PitchMax = 1,
		MaxConcurrent = 1,
		Throttle = 0.5,
	},
	RunStart = {
		SoundId = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.55,
		PitchMin = 1,
		PitchMax = 1.1,
		MaxConcurrent = 1,
		Throttle = 1,
	},
	RunEnd = {
		SoundId = "rbxasset://sounds/action_landing.mp3",
		Volume = 0.5,
		PitchMin = 1,
		PitchMax = 1,
		MaxConcurrent = 1,
		Throttle = 1,
	},
	LevelUp = {
		SoundId = "",
		Volume = 0.6,
		PitchMin = 1,
		PitchMax = 1,
		MaxConcurrent = 1,
		Throttle = 1,
	},
	CoinGain = {
		SoundId = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.32,
		PitchMin = 1.3,
		PitchMax = 1.5,
		MaxConcurrent = 2,
		Throttle = 0.25,
	},
	PurchaseSuccess = {
		SoundId = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.5,
		PitchMin = 1.1,
		PitchMax = 1.2,
		MaxConcurrent = 1,
		Throttle = 0.2,
	},
	PurchaseError = {
		SoundId = "rbxasset://sounds/switch3.wav",
		Volume = 0.5,
		PitchMin = 0.75,
		PitchMax = 0.85,
		MaxConcurrent = 1,
		Throttle = 0.2,
	},
	UIButton = {
		SoundId = "rbxasset://sounds/electronicpingshort.wav",
		Volume = 0.35,
		PitchMin = 0.95,
		PitchMax = 1.05,
		MaxConcurrent = 2,
		Throttle = 0.04,
	},
}

SoundConfig.Music = {
	CrossfadeSeconds = 1.5,
	Lobby = {
		SoundId = "",
		Volume = 0.35,
	},
	Maps = {
		Zone1 = { SoundId = "", Volume = 0.35 },
		Zone2 = { SoundId = "", Volume = 0.35 },
		Zone3 = { SoundId = "", Volume = 0.35 },
		Zone4 = { SoundId = "", Volume = 0.35 },
	},
}

return SoundConfig
