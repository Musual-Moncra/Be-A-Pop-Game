--!strict

--[[
	AssetConfig
	Assets that are just an id: animations and textures. Pure data, no functions.
	Paste a new rbxassetid:// here to swap the asset; nothing else has to change.
	Anything that needs a real instance (sounds with their settings, meshes, maps, models) lives
	in ReplicatedStorage.Assets or ServerStorage.Assets instead.

	Fields:
		Animations: animation id per use, "" = the animation is skipped (asset id)
			Walk: the poop's walk cycle, played by Animate in StarterCharacterScripts
		Textures: texture id per use, "" = the texture is skipped (asset id)
			Splat: square stain splat painted on the top face of every stain cell,
				"" = fall back to the flat stained part (asset id)
]]

return {
	Animations = {
		Walk = "rbxassetid://125635267489826",
	},

	Textures = {
		Splat = "",
	},
}
