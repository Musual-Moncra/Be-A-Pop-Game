--!strict

--[[
	GravityCamera
	Client controller: scriptable third-person orbit camera whose up vector follows the
	character's GravityUp attribute, so the view rotates with the poop when it walks onto
	walls and ceilings. Mouse drag (right button), touch drag and the gamepad right stick
	orbit around the character; geometry between the focus point and the camera pulls the
	camera in. Direction and distance tuning live in MovementConfig.

	Public API: none (the returned function is spawned by runFramework at Priority 3).
	Dependencies: ReplicatedStorage.Modules.Config.MovementConfig, Players.LocalPlayer,
		character attribute GravityUp (published by GravityController), RunService,
		UserInputService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MovementConfig = require(ReplicatedStorage.Modules.Config.MovementConfig)

local WORLD_UP = Vector3.yAxis
local WORLD_FORWARD = Vector3.new(0, 0, -1)

local player = Players.LocalPlayer

local character: Model? = nil
local root: BasePart? = nil
local characterConnections: { RBXScriptConnection } = {}

local upSmooth = WORLD_UP
local forwardRef = WORLD_FORWARD
local focus: Vector3? = nil
local yaw = math.rad(MovementConfig.CameraDefaultYawDegrees)
local pitch = math.rad(MovementConfig.CameraDefaultPitchDegrees)

local orbitTouch: InputObject? = nil
local dragging = false

local cameraRaycastParams = RaycastParams.new()
cameraRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
cameraRaycastParams.IgnoreWater = true

local function rotateAboutAxis(vector: Vector3, from: Vector3, to: Vector3): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle < 1e-4 then
		return vector
	end

	local axis = from:Cross(to)
	if axis.Magnitude < 1e-4 then
		axis = from:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-4 then
			axis = from:Cross(Vector3.zAxis)
		end
	end

	return CFrame.fromAxisAngle(axis.Unit, angle) * vector
end

local function refreshCameraExclusions()
	local excluded: { Instance } = {}
	local char = character
	if char then
		table.insert(excluded, char)
		for _, descendant in char:GetDescendants() do
			table.insert(excluded, descendant)
		end
	end
	cameraRaycastParams.FilterDescendantsInstances = excluded
end

local function readGravityUp(): Vector3
	local char = character
	if char then
		local value = char:GetAttribute("GravityUp")
		if typeof(value) == "Vector3" and value.Magnitude > 1e-3 then
			return (value :: Vector3).Unit
		end
	end
	return WORLD_UP
end

local function resetView()
	local char = character
	local part = root
	local targetUp = readGravityUp()

	upSmooth = targetUp
	forwardRef = WORLD_FORWARD
	yaw = math.rad(MovementConfig.CameraDefaultYawDegrees)
	pitch = math.rad(MovementConfig.CameraDefaultPitchDegrees)

	local camera = workspace.CurrentCamera
	if camera then
		local flat = camera.CFrame.LookVector - targetUp * camera.CFrame.LookVector:Dot(targetUp)
		if flat.Magnitude > 1e-3 then
			forwardRef = flat.Unit
		end
	end

	if part then
		focus = part.Position + targetUp * MovementConfig.CameraHeightOffset
	elseif char then
		local pivot = char:GetPivot().Position
		focus = pivot + targetUp * MovementConfig.CameraHeightOffset
	end

	refreshCameraExclusions()
end

local function clearCharacterConnections()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	characterConnections = {}
end

local function onCharacterAdded(char: Model)
	clearCharacterConnections()
	character = char
	root = nil
	focus = nil
	resetView()

	task.spawn(function()
		local foundRoot = char:WaitForChild("HumanoidRootPart", 10)
		if character ~= char or not foundRoot or not foundRoot:IsA("BasePart") then
			return
		end
		root = foundRoot
		focus = foundRoot.Position + upSmooth * MovementConfig.CameraHeightOffset
		refreshCameraExclusions()
	end)

	table.insert(
		characterConnections,
		char.AncestryChanged:Connect(function()
			if not char:IsDescendantOf(workspace) and character == char then
				root = nil
			end
		end)
	)
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

local function applyInput(dt: number)
	if dragging then
		local delta = UserInputService:GetMouseDelta()
		yaw -= math.rad(delta.X * MovementConfig.CameraMouseSensitivity)
		pitch += math.rad(delta.Y * MovementConfig.CameraMouseSensitivity)
	end

	local stickPosition = readGamepadStick(Enum.KeyCode.Thumbstick2)
	if stickPosition then
		yaw -= math.rad(MovementConfig.CameraGamepadYawSpeed) * stickPosition.X * dt
		pitch -= math.rad(MovementConfig.CameraGamepadPitchSpeed) * stickPosition.Y * dt
	end

	pitch = math.clamp(
		pitch,
		math.rad(MovementConfig.CameraMinPitchDegrees),
		math.rad(MovementConfig.CameraMaxPitchDegrees)
	)
end

local function render(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local part = root
	if not part or not part.Parent then
		return
	end

	applyInput(dt)

	local targetUp = readGravityUp()
	local blend = 1 - math.exp(-MovementConfig.CameraUpLerpSpeed * dt)
	local nextUp = upSmooth:Lerp(targetUp, blend)
	if nextUp.Magnitude > 1e-3 then
		nextUp = nextUp.Unit
		forwardRef = rotateAboutAxis(forwardRef, upSmooth, nextUp)
		upSmooth = nextUp
	end

	local horizontal = forwardRef - upSmooth * forwardRef:Dot(upSmooth)
	if horizontal.Magnitude > 1e-3 then
		forwardRef = horizontal.Unit
	else
		local fallback = WORLD_FORWARD - upSmooth * WORLD_FORWARD:Dot(upSmooth)
		if fallback.Magnitude < 1e-3 then
			local sideAxis = Vector3.new(1, 0, 0)
			fallback = sideAxis - upSmooth * sideAxis:Dot(upSmooth)
		end
		forwardRef = fallback.Unit
	end

	local targetFocus = part.Position + upSmooth * MovementConfig.CameraHeightOffset
	local currentFocus = focus
	local nextFocus: Vector3
	if currentFocus then
		nextFocus = currentFocus:Lerp(targetFocus, 1 - math.exp(-MovementConfig.CameraFollowLerpSpeed * dt))
	else
		nextFocus = targetFocus
	end
	focus = nextFocus

	local baseForward = CFrame.fromAxisAngle(upSmooth, yaw) * forwardRef
	local lookDirection = baseForward * math.cos(pitch) - upSmooth * math.sin(pitch)

	local desiredOffset = -lookDirection * MovementConfig.CameraDistance
	local distance = MovementConfig.CameraDistance
	local hit = workspace:Raycast(nextFocus, desiredOffset, cameraRaycastParams)
	if hit then
		distance = math.max(hit.Distance - MovementConfig.CameraCollisionPadding, MovementConfig.CameraMinDistance)
	end

	local cameraPosition = nextFocus + desiredOffset.Unit * distance
	camera.CFrame = CFrame.lookAt(cameraPosition, nextFocus, upSmooth)
end

local function beginDrag()
	dragging = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

local function endDrag()
	dragging = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

return function()
	player.CharacterAdded:Connect(onCharacterAdded)
	local current = player.Character
	if current then
		onCharacterAdded(current)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			beginDrag()
		elseif input.UserInputType == Enum.UserInputType.Touch and orbitTouch == nil then
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.zero
			if viewport.X > 0 and input.Position.X <= viewport.X * MovementConfig.CameraTouchOrbitScreenFraction then
				orbitTouch = input
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and input == orbitTouch then
			yaw -= math.rad(input.Delta.X * MovementConfig.CameraTouchSensitivity)
			pitch += math.rad(input.Delta.Y * MovementConfig.CameraTouchSensitivity)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			endDrag()
		elseif input == orbitTouch then
			orbitTouch = nil
		end
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		endDrag()
	end)

	RunService:BindToRenderStep("GravityCamera", Enum.RenderPriority.Camera.Value + 1, render)
end
