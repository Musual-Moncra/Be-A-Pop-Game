--!strict

--[[
	CharacterConfig
	Tuning for the starter character's walk animation, read by Animate in StarterCharacterScripts.

	Fields:
		WalkAnimationAsset: name of the Animation instance under ReplicatedStorage.Assets.Animations
			(string)
		MoveThreshold: surface speed above which the walk animation plays, measured on the
			plane perpendicular to GravityUp so the grounded stick velocity is ignored (studs/s)
		FadeTime: fade in and out time of the animation (seconds)
		PlaybackSpeed: playback speed multiplier while moving (multiplier)
]]

local CharacterConfig = {}

CharacterConfig.WalkAnimationAsset = "Walk"
CharacterConfig.MoveThreshold = 0.5
CharacterConfig.FadeTime = 0.15
CharacterConfig.PlaybackSpeed = 1

return CharacterConfig
