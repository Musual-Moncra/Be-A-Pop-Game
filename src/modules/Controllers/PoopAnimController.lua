--!strict

--[[
	PoopAnimController
	Client controller: procedural animation for every poop character in the game, the local one
	and other players. Each frame it reads the character's velocity, its GravityUp attribute
	and its facing, and poses the bone chain from AnimConfig through springs, so the body
	wobbles like jelly:
		idle      slow breathing hump on the tail half
		crawl     a hump that travels head to tail, a side squirm and segment stretch, all
		          paced by distance crawled, so speed boosts crawl faster, not just further
		turn      the body bends into the turn and leans with it
		speed up  the head lifts; braking dips it and the springs overshoot
		air       the tail droops with vertical speed
		landing   a splat kick to every pitch spring
	Bone.Transform is local-only, so every client animates every poop. Poops beyond
	AnimConfig.CullDistance from the camera are reset and skipped.

	Public API: none (the returned function is spawned by runFramework).
	Dependencies: Players, RunService, Workspace, AnimConfig, Hitbox
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimConfig = require(ReplicatedStorage.Modules.Config.AnimConfig)
local Hitbox = require(ReplicatedStorage.Modules.Shared.Hitbox)

type Spring = { x: number, v: number }

type Rig = {
	root: BasePart,
	bones: { Bone },
	pitch: { Spring },
	yaw: { Spring },
	roll: Spring,
	phase: number,
	clock: number,
	lastLook: Vector3,
	lastSpeed: number,
	accel: number,
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
	local pitch = {}
	local yaw = {}
	for _, name in AnimConfig.BoneNames do
		local bone = findBone(root, name)
		if bone == nil then
			return nil
		end
		table.insert(bones, bone)
		table.insert(pitch, newSpring())
		table.insert(yaw, newSpring())
	end
	return {
		root = root,
		bones = bones,
		pitch = pitch,
		yaw = yaw,
		roll = newSpring(),
		phase = 0,
		clock = math.random() * 10,
		lastLook = root.CFrame.LookVector,
		lastSpeed = 0,
		accel = 0,
		airborne = false,
		lastVertical = 0,
		active = true,
	}
end

local function resetRig(rig: Rig)
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
	for index in rig.bones do
		rig.pitch[index].x, rig.pitch[index].v = 0, 0
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
	local speed = (velocity - up * vertical).Magnitude
	local crawl = math.clamp(speed / AnimConfig.ReferenceSpeed, 0, 1)

	local look = root.CFrame.LookVector
	local turnRate = math.deg(signedAngle(rig.lastLook, look, up)) / dt
	rig.lastLook = look

	local rawAccel = (speed - rig.lastSpeed) / dt
	rig.lastSpeed = speed
	rig.accel += (rawAccel - rig.accel) * (1 - math.exp(-AnimConfig.AccelSmoothing * dt))

	local airborne = math.abs(vertical) > AnimConfig.AirSpeed
	if rig.airborne and not airborne and rig.lastVertical < -AnimConfig.LandSpeed then
		for _, spring in rig.pitch do
			spring.v += AnimConfig.LandKick
		end
	end
	rig.airborne = airborne
	rig.lastVertical = vertical

	rig.clock += dt
	rig.phase += speed * dt / (AnimConfig.WaveStudsPerCycle * math.max(scale, 1e-3)) * 2 * math.pi

	local breath = (1 - crawl) * AnimConfig.BreathPitch * math.sin(rig.clock * AnimConfig.BreathRate * 2 * math.pi)
	local bend = math.clamp(turnRate * AnimConfig.TurnBend, -AnimConfig.MaxTurnBend, AnimConfig.MaxTurnBend)
	local lean = math.clamp(turnRate * AnimConfig.TurnRoll * crawl, -AnimConfig.MaxTurnRoll, AnimConfig.MaxTurnRoll)
	local lift = math.clamp(rig.accel * AnimConfig.AccelPitch, -AnimConfig.MaxAccelPitch, AnimConfig.MaxAccelPitch)
	local droop = if airborne
		then math.clamp(-vertical * AnimConfig.AirPitch, -AnimConfig.MaxAirPitch, AnimConfig.MaxAirPitch)
		else 0

	stepSpring(rig.roll, lean, dt)

	local last = #rig.bones
	for index, bone in rig.bones do
		local weight = AnimConfig.Weights[index] or 1
		local offset = rig.phase - (index - 1) * AnimConfig.WavePhaseStep
		local wave = crawl * AnimConfig.WavePitch * math.sin(offset)
		local wiggle = crawl * AnimConfig.WiggleYaw * math.sin(offset * AnimConfig.WiggleRate)
		local tailShare = (index - 1) / math.max(last - 1, 1)

		local pitchTarget = (wave + droop * tailShare + breath * tailShare) * weight
		if index == 1 then
			pitchTarget += lift
		end
		local yawTarget = (wiggle + bend) * weight

		stepSpring(rig.pitch[index], pitchTarget, dt)
		stepSpring(rig.yaw[index], yawTarget, dt)

		local stretch = if index > 1 then crawl * AnimConfig.StretchStuds * scale * math.sin(offset * 2) else 0
		local roll = if index == 1 then rig.roll.x else 0
		bone.Transform = CFrame.new(0, stretch, 0)
			* CFrame.fromOrientation(
				math.rad(rig.pitch[index].x * AnimConfig.PitchSign),
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
