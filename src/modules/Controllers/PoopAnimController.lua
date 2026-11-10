--!strict

--[[
	PoopAnimController
	Client controller: procedural snake-like animation for every poop character in the game,
	the local one and other players. Each frame it reads the character's velocity, its
	GravityUp attribute and its facing, and bends the bone chain from AnimConfig sideways
	through near-critically damped springs, so the body slides and sways and never bobs up
	and down. States (see AnimConfig): idle sway, slither, sprint, turn, stop, air, land and
	splat (the local poop only, from Net.ObjectSoiled).
	Bone.Transform is local-only, so every client animates every poop. Poops beyond
	AnimConfig.CullDistance from the camera are reset and skipped.

	Public API: none (the returned function is spawned by runFramework).
	Dependencies: Players, RunService, Workspace, AnimConfig, Hitbox, Net
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimConfig = require(ReplicatedStorage.Modules.Config.AnimConfig)
local Hitbox = require(ReplicatedStorage.Modules.Shared.Hitbox)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

type Spring = { x: number, v: number }

type Rig = {
	root: BasePart,
	bones: { Bone },
	yaw: { Spring },
	roll: Spring,
	phase: number,
	clock: number,
	speed: number,
	turnRate: number,
	lastLook: Vector3,
	airborne: boolean,
	lastVertical: number,
	active: boolean,
}

local rigs: { [Model]: Rig } = {}

local function newSpring(): Spring
	return { x = 0, v = 0 }
end

local function stepSpring(spring: Spring, target: number, dt: number)
	local force = AnimConfig.SpringStiffness * (target - spring.x) - AnimConfig.SpringDamping * spring.v
	spring.v += force * dt
	spring.x += spring.v * dt
end

local function ease(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function kick(rig: Rig, strength: number)
	for index, spring in rig.yaw do
		local side = if index % 2 == 0 then 1 else -1
		spring.v += strength * side * (AnimConfig.Weights[index] or 1)
	end
end

local function findBone(root: Instance, name: string): Bone?
	local found = root:FindFirstChild(name, true)
	if found ~= nil and found:IsA("Bone") then
		return found
	end
	return nil
end

local function buildRig(character: Model): Rig?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local bones = {}
	local yaw = {}
	for _, name in AnimConfig.BoneNames do
		local bone = findBone(root, name)
		if bone == nil then
			return nil
		end
		table.insert(bones, bone)
		table.insert(yaw, newSpring())
	end
	return {
		root = root,
		bones = bones,
		yaw = yaw,
		roll = newSpring(),
		phase = 0,
		clock = math.random() * 10,
		speed = 0,
		turnRate = 0,
		lastLook = root.CFrame.LookVector,
		airborne = false,
		lastVertical = 0,
		active = true,
	}
end

local function resetRig(rig: Rig)
	for index, bone in rig.bones do
		bone.Transform = CFrame.identity
		rig.yaw[index].x, rig.yaw[index].v = 0, 0
	end
	rig.roll.x, rig.roll.v = 0, 0
	rig.active = false
end

local function signedAngle(from: Vector3, to: Vector3, axis: Vector3): number
	return math.atan2(from:Cross(to):Dot(axis), from:Dot(to))
end

local function animate(character: Model, rig: Rig, dt: number)
	local root = rig.root
	local up = character:GetAttribute("GravityUp")
	if typeof(up) ~= "Vector3" then
		up = Vector3.yAxis
	end

	local scale = Hitbox.Scale(root)
	local velocity = root.AssemblyLinearVelocity
	local vertical = velocity:Dot(up)
	rig.speed = ease(rig.speed, (velocity - up * vertical).Magnitude, AnimConfig.SpeedSmoothing, dt)

	local look = root.CFrame.LookVector
	local rawTurn = math.deg(signedAngle(rig.lastLook, look, up)) / dt
	rig.lastLook = look
	rig.turnRate = ease(rig.turnRate, rawTurn, AnimConfig.TurnSmoothing, dt)

	local airborne = math.abs(vertical) > AnimConfig.AirSpeed
	if rig.airborne and not airborne and rig.lastVertical < -AnimConfig.LandSpeed then
		kick(rig, AnimConfig.LandWiggle)
	end
	rig.airborne = airborne
	rig.lastVertical = vertical

	local ratio = rig.speed / AnimConfig.ReferenceSpeed
	local slither = math.clamp(ratio, 0, 1)
	local sprint = math.clamp((ratio - 1) / math.max(AnimConfig.MaxSpeedRatio - 1, 1e-3), 0, 1)
	local width = AnimConfig.SlitherYaw * slither * (1 + AnimConfig.SprintWidth * sprint)
	if airborne then
		width *= AnimConfig.AirCalm
	end

	rig.clock += dt
	rig.phase += rig.speed * dt / (AnimConfig.WaveStudsPerCycle * math.max(scale, 1e-3)) * 2 * math.pi

	local bend = math.clamp(rig.turnRate * AnimConfig.TurnBend, -AnimConfig.MaxTurnBend, AnimConfig.MaxTurnBend)
	local lean = math.clamp(
		rig.turnRate * AnimConfig.TurnLean * slither,
		-AnimConfig.MaxTurnLean,
		AnimConfig.MaxTurnLean
	) + AnimConfig.SlitherRoll * slither * math.sin(rig.phase)
	stepSpring(rig.roll, lean, dt)

	local idle = 1 - slither
	local idleClock = rig.clock * AnimConfig.IdleRate * 2 * math.pi
	for index, bone in rig.bones do
		local weight = AnimConfig.Weights[index] or 1
		local wave = width * math.sin(rig.phase - (index - 1) * AnimConfig.WavePhaseStep)
		local sway = idle * AnimConfig.IdleSway * math.sin(idleClock - (index - 1) * AnimConfig.IdlePhaseStep)
		stepSpring(rig.yaw[index], (wave + sway - bend) * weight, dt)

		local roll = if index == 1 then rig.roll.x else 0
		bone.Transform = CFrame.fromOrientation(
			0,
			math.rad(roll * AnimConfig.RollSign),
			math.rad(rig.yaw[index].x * AnimConfig.YawSign)
		)
	end
	rig.active = true
end

local function track(character: Model)
	if rigs[character] ~= nil then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or character.Parent == nil then
		return
	end
	local rig = buildRig(character)
	if rig == nil then
		return
	end
	rigs[character] = rig
	character.Destroying:Connect(function()
		rigs[character] = nil
	end)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(Workspace) then
			rigs[character] = nil
		end
	end)
end

local function watch(plr: Player)
	plr.CharacterAdded:Connect(function(character)
		task.spawn(track, character)
	end)
	if plr.Character ~= nil then
		task.spawn(track, plr.Character)
	end
end

return function()
	Players.PlayerAdded:Connect(watch)
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end

	Net.ObjectSoiled.OnClientEvent:Connect(function()
		local character = Players.LocalPlayer.Character
		local rig = if character ~= nil then rigs[character] else nil
		if rig ~= nil then
			kick(rig, AnimConfig.SplatWiggle)
		end
	end)

	RunService.PreRender:Connect(function(frameTime: number)
		local dt = math.min(frameTime, AnimConfig.MaxStep)
		if dt <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		local eye = if camera ~= nil then camera.CFrame.Position else Vector3.zero
		local cullSquared = AnimConfig.CullDistance * AnimConfig.CullDistance
		for character, rig in rigs do
			if rig.root.Parent == nil then
				rigs[character] = nil
			else
				local offset = rig.root.Position - eye
				if offset:Dot(offset) > cullSquared then
					if rig.active then
						resetRig(rig)
					end
				else
					animate(character, rig, dt)
				end
			end
		end
	end)
end
