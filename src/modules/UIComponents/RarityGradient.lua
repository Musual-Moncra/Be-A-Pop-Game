--!strict

--[[
	RarityGradient
	Rarity card colours and effects from UIConfig. Each rarity maps to a candy gradient
	(Top / Mid / Bottom / Lip) plus optional animated gradient rotation, shine and sparkles.

	API:
		RarityGradient.swatch(rarityId) -> { Top, Mid, Bottom, Lip, Stroke } or nil
		RarityGradient.effects(rarityId) -> { RotateSeconds?, ShineSeconds?, Sparkles? }
		RarityGradient.sparkles(rarityId) -> { { X, Y, Size, Delay } } (none for plain rarities)
	Dependencies: UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local RarityGradient = {}

local gradients: any = UIConfig.RarityGradients
local effects: any = UIConfig.RarityEffects
local sparklePoints: any = UIConfig.RaritySparkles

function RarityGradient.swatch(rarityId: string?): any
	if rarityId == nil then
		return nil
	end
	local colors = gradients[rarityId]
	if colors == nil then
		return nil
	end
	return {
		Top = colors.Top,
		Mid = colors.Mid,
		Bottom = colors.Bottom,
		Lip = colors.Lip,
		Stroke = UIConfig.Palette.Ink,
	}
end

function RarityGradient.effects(rarityId: string?): any
	if rarityId == nil then
		return {}
	end
	return effects[rarityId] or {}
end

function RarityGradient.sparkles(rarityId: string?): { any }
	local effect = RarityGradient.effects(rarityId)
	local count = tonumber(effect.Sparkles) or 0
	local list = {}
	for index = 1, math.min(count, #sparklePoints) do
		list[index] = sparklePoints[index]
	end
	return list
end

return RarityGradient
