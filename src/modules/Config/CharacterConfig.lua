--!strict

--[[
	CharacterConfig
	Tuning for the starter character's walk animation, read by Animate in StarterCharacterScripts.
	The animation id itself is in AssetConfig.Animations.Walk.

	Fields:
		MoveThreshold: surface speed above which the walk animation plays, measured on the
			plane perpendicular to GravityUp so the grounded stick velocity is ignored (studs/s)
		FadeTime: fade in and out time of the animation (seconds)
		PlaybackSpeed: playback speed multiplier while moving (multiplier)
]]

return {

	MoveThreshold = 0.5,

	FadeTime = 0.15,

	PlaybackSpeed = 1,
}
