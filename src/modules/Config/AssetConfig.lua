--!strict

--[[
	AssetConfig
	Assets that are just an id: animations and textures. Pure data, no functions.
	Paste a new rbxassetid:// here to swap the asset; nothing else has to change.
	Anything that needs a real instance (sounds with their settings, meshes, maps, models) lives
	in ReplicatedStorage.Assets or ServerStorage.Assets instead.

	Fields:
		Animations: animation id per use, "" = the animation is skipped (asset id)
			none today: the poop is animated procedurally by PoopAnimController (AnimConfig)
		Textures: texture id per use, "" = the texture is skipped (asset id)
			Splat: square stain splat painted on the top face of every stain cell,
				"" = fall back to the flat stained part (asset id)
]]

return {
	Animations = {},

	Textures = {
		Splat = "rbxassetid://137899280",
	},
}
