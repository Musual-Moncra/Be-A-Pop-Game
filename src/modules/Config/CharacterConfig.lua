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
		ColliderName: invisible ball in the StarterCharacter that touches the world; it rolls over small
			floor trims, and the HumanoidRootPart itself does not collide (string)
		RootWidth: X size of the StarterCharacter's HumanoidRootPart at normal size; every size buff is
			measured against it, so update it when the character model changes (studs)
		HitboxOffset: centre of the body measured from the HumanoidRootPart, in its local axes (studs)
		HitboxHalfLength: half of the capsule's centre line, which runs along the body (studs)
		HitboxRadius: capsule radius, so full length = 2 x (HalfLength + Radius) (studs)
]]

return {

	MoveThreshold = 0.5,
	FadeTime = 0.15,
	PlaybackSpeed = 1,
	ColliderName = "Collider",
	RootWidth = 0.18553310632705688,
	HitboxOffset = Vector3.new(0.05, 1.35, -0.28),
	HitboxHalfLength = 4.1,
	HitboxRadius = 1.45,
}
