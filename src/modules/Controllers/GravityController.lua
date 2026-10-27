--!strict

--[[
	GravityController
	Client controller: the local poop sticks to and climbs any surface.
	Builds custom gravity (LinearVelocity), body alignment (AlignOrientation) and surface
	detection (raycasts) on the client-owned character, drives movement from the PlayerModule
	move vector projected onto the current surface plane, handles jump requests, resets
	gravity on teleports, and publishes the current gravity "up" as the GravityUp attribute
	on the character model.

	Public API: none (the returned function is spawned by runFramework at Priority 2).
	Dependencies: ReplicatedStorage.Modules.Config.MovementConfig, Players.LocalPlayer,
		PlayerScripts.PlayerModule when present (Controls:GetMoveVector, the unified
		keyboard/gamepad/touch source), RunService, UserInputService.
	PlayerModule is optional: when the place has no default PlayerModule the controller falls
	back to reading keyboard keys and gamepad thumbstick 1 directly, and to Space/ButtonA for
	jump, so movement still works without it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MovementConfig = require(ReplicatedStorage.Modules.Config.MovementConfig)

local WORLD_UP = Vector3.yAxis
local WORLD_FORWARD = Vector3.new(0, 0, -1)

local player = Players.LocalPlayer

local controls: any = nil

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local attachment: Attachment? = nil
local velocityActuator: LinearVelocity? = nil
local alignActuator: AlignOrientation? = nil
local characterConnections: { RBXScriptConnection } = {}

local up = WORLD_UP
local publishedUp = WORLD_UP
local facing = WORLD_FORWARD
local upVelocity = 0
local grounded = false
local airborneTime = 0
local timeSinceJump = math.huge
local lastPosition: Vector3? = nil
local moveVelocity = Vector3.zero
local jumpQueued = false

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function projectOnPlane(vector: Vector3, normal: Vector3): Vector3
	return vector - normal * vector:Dot(normal)
end

local function smoothUp(current: Vector3, target: Vector3, speed: number, dt: number): Vector3
	local angle = math.acos(math.clamp(current:Dot(target), -1, 1))
	if angle < 1e-4 then
		return target
	end

	local axis = current:Cross(target)
	if axis.Magnitude < 1e-4 then
		axis = current:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-4 then
			axis = current:Cross(Vector3.zAxis)
		end
	end

	local step = angle * (1 - math.exp(-speed * dt))
	return (CFrame.fromAxisAngle(axis.Unit, step) * current).Unit
end

local function cast(origin: Vector3, direction: Vector3, distance: number): RaycastResult?
	local ray = direction * distance
	if ray.Magnitude < 1e-4 then
		return nil
	end
	return workspace:Raycast(origin, ray, raycastParams)
end

local function readGamepadStick(keyCode: Enum.KeyCode): Vector3?
	local state: any = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	if not state then
		return nil
	end

	for _, inputObject in state do
		if inputObject.KeyCode == keyCode then
			local position: Vector3 = inputObject.Position
			return position
		end
	end

	return nil
end

local function readRawMoveVector(): Vector3
	local x = 0
	local z = 0

	for _, input in UserInputService:GetKeysPressed() do
		local code = input.KeyCode
		if code == Enum.KeyCode.W or code == Enum.KeyCode.Up then
			z -= 1
		elseif code == Enum.KeyCode.S or code == Enum.KeyCode.Down then
			z += 1
		elseif code == Enum.KeyCode.A or code == Enum.KeyCode.Left then
			x -= 1
		elseif code == Enum.KeyCode.D or code == Enum.KeyCode.Right then
			x += 1
		end
	end

	local stickPosition = readGamepadStick(Enum.KeyCode.Thumbstick1)
	if stickPosition then
		x += stickPosition.X
		z -= stickPosition.Y
	end

	local vector = Vector3.new(x, 0, z)
	if vector.Magnitude > 1 then
		vector = vector.Unit
	end
	return vector
end

local function hookPlayerModule()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return
	end

	local module = playerScripts:FindFirstChild("PlayerModule")
	if not module or not module:IsA("ModuleScript") then
		return
	end

	local ok, playerModule = pcall(require, module)
	if not ok or typeof(playerModule) ~= "table" then
		return
	end

	local getControls = (playerModule :: any).GetControls
	if typeof(getControls) ~= "function" then
		return
	end

	controls = (playerModule :: any):GetControls()
end

local function refreshExclusions(char: Model)
	local excluded: { Instance } = { char }
	for _, descendant in char:GetDescendants() do
		table.insert(excluded, descendant)
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant ~= char and descendant:FindFirstChildOfClass("Humanoid") then
			table.insert(excluded, descendant)
		end
	end
	raycastParams.FilterDescendantsInstances = excluded
end

local function teardown()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	characterConnections = {}

	if alignActuator then
		alignActuator:Destroy()
	end
	if velocityActuator then
		velocityActuator:Destroy()
	end
	if attachment then
		attachment:Destroy()
	end

	alignActuator = nil
	velocityActuator = nil
	attachment = nil
	character = nil
	humanoid = nil
	root = nil
	lastPosition = nil
end

local function onCharacterAdded(char: Model)
	teardown()

	character = char
	up = WORLD_UP
	publishedUp = WORLD_UP
	facing = WORLD_FORWARD
	upVelocity = 0
	grounded = false
	airborneTime = 0
	timeSinceJump = math.huge
	moveVelocity = Vector3.zero
	jumpQueued = false
	char:SetAttribute("GravityUp", WORLD_UP)

	local foundHumanoid = char:WaitForChild("Humanoid", 10)
	local foundRoot = char:WaitForChild("HumanoidRootPart", 10)
	if not foundHumanoid or not foundHumanoid:IsA("Humanoid") or not foundRoot or not foundRoot:IsA("BasePart") then
		return
	end

	local hum: Humanoid = foundHumanoid
	local part: BasePart = foundRoot
	humanoid = hum
	root = part

	hum.PlatformStand = true
	hum.AutoRotate = false

	refreshExclusions(char)

	local anchor = Instance.new("Attachment")
	anchor.Name = "GravityAttachment"
	anchor.Parent = part

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "GravityVelocity"
	velocity.Attachment0 = anchor
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = 0
	velocity.VectorVelocity = Vector3.zero
	velocity.Enabled = true
	velocity.Parent = part

	local align = Instance.new("AlignOrientation")
	align.Name = "GravityAlignment"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = anchor
	align.RigidityEnabled = false
	align.ReactionTorqueEnabled = false
	align.Responsiveness = MovementConfig.AlignmentResponsiveness
	align.MaxTorque = part.AssemblyMass * MovementConfig.AlignmentTorquePerMass
	align.Parent = part

	attachment = anchor
	velocityActuator = velocity
	alignActuator = align

	table.insert(
		characterConnections,
		hum.Died:Connect(function()
			teardown()
		end)
	)
	table.insert(
		characterConnections,
		char.AncestryChanged:Connect(function()
			if not char:IsDescendantOf(workspace) then
				teardown()
			end
		end)
	)
end

local function update(dt: number)
	local char = character
	local hum = humanoid
	local part = root
	local velocity = velocityActuator
	local align = alignActuator
	if not char or not hum or not part or not velocity or not align or not part.Parent then
		return
	end
	if hum.Health <= 0 then
		return
	end

	if not hum.PlatformStand then
		hum.PlatformStand = true
	end
	if hum.AutoRotate then
		hum.AutoRotate = false
	end

	local position = part.Position
	local previous = lastPosition
	if previous and (position - previous).Magnitude > MovementConfig.TeleportResetDistance then
		up = WORLD_UP
		upVelocity = 0
		grounded = false
		airborneTime = 0
		timeSinceJump = math.huge
		moveVelocity = Vector3.zero
		part.AssemblyLinearVelocity = Vector3.zero
	end
	lastPosition = position

	timeSinceJump += dt

	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else facing

	local lookOnPlane = projectOnPlane(look, up)
	if lookOnPlane.Magnitude > 1e-3 then
		facing = lookOnPlane.Unit
	end

	local cameraRight = facing:Cross(up)

	local moveVector = Vector3.zero
	if controls then
		local raw = controls:GetMoveVector()
		moveVector = Vector3.new(raw.X, 0, raw.Z)
	else
		moveVector = readRawMoveVector()
	end

	local inputMagnitude = math.min(moveVector.Magnitude, 1)
	local moving = inputMagnitude > MovementConfig.MoveInputDeadzone

	local probeDirection = Vector3.zero
	if moving then
		local flat = projectOnPlane(facing * -moveVector.Z + cameraRight * moveVector.X, up)
		if flat.Magnitude > 1e-4 then
			probeDirection = flat.Unit
		end
	end

	local canStick = timeSinceJump > MovementConfig.JumpCooldown
	local candidate: Vector3? = nil
	local fromMovement = false

	if canStick then
		if moving and probeDirection.Magnitude > 0.5 then
			local wallReach = MovementConfig.WallProbeDistance / math.max(MovementConfig.WallClimbHeadOnDot, 0.01)
			local wallHit = cast(position, probeDirection, wallReach)
			if wallHit then
				local headOn = -wallHit.Normal:Dot(probeDirection)
				local perpendicular = wallHit.Distance * headOn
				if headOn >= MovementConfig.WallClimbHeadOnDot and perpendicular <= MovementConfig.WallProbeDistance then
					candidate = wallHit.Normal
					fromMovement = true
				end
			end
		end

		if not candidate then
			local groundHit = cast(position, -up, MovementConfig.GroundProbeDistance)
			if groundHit then
				candidate = groundHit.Normal
			end
		end

		if not candidate and moving and probeDirection.Magnitude > 0.5 then
			local edgeOrigin = position + up * MovementConfig.EdgeProbeUpOffset
			local edgeDirection = probeDirection - up * MovementConfig.EdgeProbeDownBias
			local edgeHit = cast(edgeOrigin, edgeDirection, MovementConfig.EdgeProbeDistance)
			if edgeHit then
				candidate = edgeHit.Normal
				fromMovement = true
			end
		end
	end

	if candidate then
		local angleDegrees = math.deg(math.acos(math.clamp(candidate:Dot(up), -1, 1)))
		local steepnessDegrees = math.deg(math.acos(math.clamp(candidate:Dot(WORLD_UP), -1, 1)))
		local blocked = angleDegrees > MovementConfig.MaxClimbAngleDegrees
			or (fromMovement and steepnessDegrees < MovementConfig.MinWallAngleDegrees)
		if blocked then
			candidate = nil
		end
	end

	local targetUp = up
	if candidate then
		targetUp = candidate
		grounded = true
		airborneTime = 0
	else
		grounded = false
		airborneTime += dt
		if airborneTime >= MovementConfig.AirGravityHoldTime then
			targetUp = WORLD_UP
		end
	end

	up = smoothUp(up, targetUp, MovementConfig.NormalLerpSpeed, dt)

	if jumpQueued then
		jumpQueued = false
		if grounded and timeSinceJump > MovementConfig.JumpCooldown then
			upVelocity = MovementConfig.JumpVelocity
			timeSinceJump = 0
			airborneTime = 0
			grounded = false
		end
	end

	local surfaceFacing = projectOnPlane(look, up)
	if surfaceFacing.Magnitude < 1e-3 then
		surfaceFacing = projectOnPlane(facing, up)
	end
	if surfaceFacing.Magnitude > 1e-3 then
		facing = surfaceFacing.Unit
	end
	cameraRight = facing:Cross(up)

	local drive = Vector3.zero
	if moving then
		local flat = projectOnPlane(facing * -moveVector.Z + cameraRight * moveVector.X, up)
		if flat.Magnitude > 1e-4 then
			drive = flat.Unit * inputMagnitude
		end
	end

	local airFactor = if grounded then 1 else MovementConfig.AirControl
	local targetVelocity = drive * (hum.WalkSpeed * airFactor)
	local smoothing = 1 - math.exp(-MovementConfig.MoveSmoothingSpeed * dt)
	moveVelocity = projectOnPlane(moveVelocity:Lerp(targetVelocity, smoothing), up)

	local desiredVelocity: Vector3
	if grounded then
		upVelocity = -MovementConfig.GroundStickSpeed
		desiredVelocity = moveVelocity - up * MovementConfig.GroundStickSpeed
	else
		upVelocity = math.max(upVelocity - MovementConfig.GravityStrength * dt, -MovementConfig.TerminalFallSpeed)
		desiredVelocity = moveVelocity + up * upVelocity
	end

	velocity.MaxForce = part.AssemblyMass * MovementConfig.MaxAcceleration
	velocity.VectorVelocity = desiredVelocity

	align.MaxTorque = part.AssemblyMass * MovementConfig.AlignmentTorquePerMass
	align.CFrame = CFrame.lookAt(position, position + facing, up)

	local publishedAngle = math.deg(math.acos(math.clamp(up:Dot(publishedUp), -1, 1)))
	if publishedAngle >= MovementConfig.GravityUpPublishMinAngleDegrees then
		publishedUp = up
		char:SetAttribute("GravityUp", up)
	end
end

return function()
	UserInputService.JumpRequest:Connect(function()
		jumpQueued = true
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.ButtonY
		then
			jumpQueued = true
		end
	end)

	task.spawn(function()
		local playerScripts = player:WaitForChild("PlayerScripts", 10)
		if not playerScripts then
			return
		end
		hookPlayerModule()
		playerScripts.ChildAdded:Connect(function(child)
			if child.Name == "PlayerModule" then
				hookPlayerModule()
			end
		end)
	end)

	player.CharacterAdded:Connect(function(char)
		task.spawn(onCharacterAdded, char)
	end)
	player.CharacterRemoving:Connect(function()
		teardown()
	end)

	local current = player.Character
	if current then
		task.spawn(onCharacterAdded, current)
	end

	RunService.Heartbeat:Connect(update)
end
