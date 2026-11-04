--!strict

--[[
	Hitbox
	The poop's one gameplay hitbox: a capsule lying along the body, shaped by CharacterConfig. The
	body is long and its centre sits above the HumanoidRootPart, so measuring from the root
	misses the head and tail. Every catch, pickup and vision test goes through here, on any
	surface the poop stands on, because the capsule follows the root's rotation.

	API:
		Hitbox.Scale(rootPart: BasePart) -> number
			how big the poop is compared to its normal size, 1 = no size buff. Measured from the root
			part because Model:GetScale() is not 1 on the imported model and is not stored by Rojo
		Hitbox.Center(root: CFrame, scale: number) -> Vector3
			middle of the body
		Hitbox.ClosestPoint(root: CFrame, scale: number, point: Vector3) -> Vector3
			point on the capsule's centre line nearest to `point`
		Hitbox.Reach(scale: number) -> number
			capsule radius at this character scale, in studs

	Dependencies: CharacterConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterConfig = require(ReplicatedStorage.Modules.Config.CharacterConfig)

local Hitbox = {}

function Hitbox.Scale(rootPart: BasePart): number
	return rootPart.Size.X / CharacterConfig.RootWidth
end

function Hitbox.Center(root: CFrame, scale: number): Vector3
	return root:PointToWorldSpace(CharacterConfig.HitboxOffset * scale)
end

function Hitbox.ClosestPoint(root: CFrame, scale: number, point: Vector3): Vector3
	local center = Hitbox.Center(root, scale)
	local axis = root.LookVector
	local halfLength = CharacterConfig.HitboxHalfLength * scale
	return center + axis * math.clamp((point - center):Dot(axis), -halfLength, halfLength)
end

function Hitbox.Reach(scale: number): number
	return CharacterConfig.HitboxRadius * scale
end

return Hitbox
