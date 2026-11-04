--!strict

--[[
	SoundConfig
	Every sound the client can play and the music track for each place. Pure data, no functions.

	An Asset of "" means the sound is not ready: SoundController skips it silently, so keys can
	be listed before the audio library is uploaded. Upload a file, create its Sound template in
	ReplicatedStorage.Assets.Sounds with the same name and the key starts playing.

	Fields:
		FolderName: name of the SoundService folder that holds live Sound instances (string)
		MaxSoundLifetime: safety cleanup for a Sound whose Ended never fires because the asset
			failed to load (seconds)
		Sfx: one entry per sound effect, keyed by the name SoundController.Play takes
			Asset: name of the Sound template in ReplicatedStorage.Assets.Sounds, "" = key is
				not ready and is skipped (string)
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

return {
	FolderName = "Sound",
	MaxSoundLifetime = 10,

	Sfx = {
		Stain = {
			Asset = "Stain",
			Volume = 0.3,
			PitchMin = 0.8,
			PitchMax = 1.1,
			MaxConcurrent = 3,
			Throttle = 0.09,
		},
		Soiled = {
			Asset = "Soiled",
			Volume = 0.5,
			PitchMin = 1,
			PitchMax = 1.15,
			MaxConcurrent = 2,
			Throttle = 0.05,
		},
		FoodEaten = {
			Asset = "FoodEaten",
			Volume = 0.45,
			PitchMin = 0.95,
			PitchMax = 1.15,
			MaxConcurrent = 2,
			Throttle = 0.06,
		},
		NpcCaught = {
			Asset = "NpcCaught",
			Volume = 0.55,
			PitchMin = 1,
			PitchMax = 1,
			MaxConcurrent = 1,
			Throttle = 0.5,
		},
		RunStart = {
			Asset = "RunStart",
			Volume = 0.55,
			PitchMin = 1,
			PitchMax = 1.1,
			MaxConcurrent = 1,
			Throttle = 1,
		},
		RunEnd = {
			Asset = "RunEnd",
			Volume = 0.5,
			PitchMin = 1,
			PitchMax = 1,
			MaxConcurrent = 1,
			Throttle = 1,
		},
		LevelUp = {
			Asset = "",
			Volume = 0.6,
			PitchMin = 1,
			PitchMax = 1,
			MaxConcurrent = 1,
			Throttle = 1,
		},
		CoinGain = {
			Asset = "CoinGain",
			Volume = 0.32,
			PitchMin = 1.3,
			PitchMax = 1.5,
			MaxConcurrent = 2,
			Throttle = 0.25,
		},
		PurchaseSuccess = {
			Asset = "PurchaseSuccess",
			Volume = 0.5,
			PitchMin = 1.1,
			PitchMax = 1.2,
			MaxConcurrent = 1,
			Throttle = 0.2,
		},
		PurchaseError = {
			Asset = "PurchaseError",
			Volume = 0.5,
			PitchMin = 0.75,
			PitchMax = 0.85,
			MaxConcurrent = 1,
			Throttle = 0.2,
		},
		UIButton = {
			Asset = "UIButton",
			Volume = 0.35,
			PitchMin = 0.95,
			PitchMax = 1.05,
			MaxConcurrent = 2,
			Throttle = 0.04,
		},
	},

	Music = {
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
	},
}
