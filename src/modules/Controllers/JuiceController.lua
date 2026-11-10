--!strict

--[[
	JuiceController
	Client presentation pass that makes a run feel rewarding: combo meter state, floating
	score and target-soil numbers, stain milestone banners, target and Mini Bomb camera
	shake, Speed Boost field-of-view kick, landing and jump squash on the poop mesh, moving
	splat particles and pet poop puffs. Every number, colour and timing lives in JuiceConfig;
	the server owns the combo value, which arrives inside the RunState packet.

	API:
		JuiceController.GetCombo() -> number
		JuiceController.ComboChanged -> Signal (fires with the new combo level)
		JuiceController.MilestoneShown -> Signal (fires with percent, cleared:boolean)

	Dependencies: Players, Workspace, RunService, TweenService, UserInputService, Signal,
		DataController, SoundController, ConfigLookup, GameConfig, Hitbox, CharacterConfig,
		PetConfig, UIConfig, JuiceConfig, Format, Net
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local SoundController = require(ReplicatedStorage.Modules.Controllers.SoundController)
local CharacterConfig = require(ReplicatedStorage.Modules.Config.CharacterConfig)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local JuiceConfig = require(ReplicatedStorage.Modules.Config.JuiceConfig)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Hitbox = require(ReplicatedStorage.Modules.Shared.Hitbox)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Format = require(ReplicatedStorage.Modules.UIComponents.Format)

local player = Players.LocalPlayer

local JuiceController = {}

JuiceController.ComboChanged = Signal.new()
JuiceController.MilestoneShown = Signal.new()

local comboLevel = 1
local runActive = false
local lastScore = 0
local lastMilestone = 0
local previousRunState: string? = nil
local squashToken = 0
local meshRest: { [BasePart]: Vector3 } = {}
local meshTweens: { [BasePart]: Tween } = {}

local function localRoot(): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function gravityUp(): Vector3
	local character = player.Character
	if character ~= nil then
		local value = character:GetAttribute("GravityUp")
		if typeof(value) == "Vector3" and value.Magnitude > 1e-3 then
			return value.Unit
		end
	end
	return Vector3.yAxis
end

local function setCombo(level: number)
	local nextLevel = math.clamp(math.floor(level), 1, #JuiceConfig.ComboColors)
	if nextLevel == comboLevel then
		return
	end
	comboLevel = nextLevel
	if nextLevel > 1 then
		SoundController.Play(JuiceConfig.SoundCombo)
	end
	JuiceController.ComboChanged:Fire(comboLevel)
end

function JuiceController.GetCombo(): number
	return comboLevel
end

local function worldLabel(
	position: Vector3,
	text: string,
	textSize: number,
	color: Color3,
	width: number,
	height: number,
	lifetime: number,
	rise: number
)
	local holder = Instance.new("Part")
	holder.Name = "JuicePopup"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one * JuiceConfig.SplatFxPartSize
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Popup"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = JuiceConfig.FloatMaxDistance
	billboard.Size = UDim2.fromOffset(width, height)
	billboard.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = Font.new(UIConfig.Fonts.Display, UIConfig.Fonts.DisplayWeight)
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIConfig.Palette.Ink
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = UIConfig.Shape.TextStroke
	stroke.Parent = label

	local info = TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(holder, info, { CFrame = CFrame.new(position + Vector3.new(0, rise, 0)) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()

	task.delay(lifetime, function()
		if holder.Parent ~= nil then
			holder:Destroy()
		end
	end)
end

local function tierFor(amount: number): any
	local chosen = JuiceConfig.FloatTiers[1]
	for _, tier in JuiceConfig.FloatTiers do
		if amount >= tier.Min then
			chosen = tier
		end
	end
	return chosen
end

local function spawnScoreFloat(amount: number)
	if amount <= 0 then
		return
	end
	local root = localRoot()
	if root == nil then
		return
	end
	local tier = tierFor(amount)
	local position = root.Position + gravityUp() * (JuiceConfig.FloatHeight * Hitbox.Scale(root))
	worldLabel(
		position,
		string.format(JuiceConfig.FloatFormat, Format.commas(amount)),
		tier.TextSize,
		tier.Color,
		JuiceConfig.FloatGuiWidth,
		JuiceConfig.FloatGuiHeight,
		JuiceConfig.FloatLifetime,
		JuiceConfig.FloatRise
	)
end

local function objectName(object: Instance): string
	local objectType = object:GetAttribute("ObjectType")
	if typeof(objectType) == "string" then
		local definition = ConfigLookup.GetObject(objectType)
		if definition ~= nil then
			return definition.DisplayName
		end
	end
	return object.Name
end

local function objectPosition(object: Instance): Vector3?
	if object:IsA("Model") then
		return object:GetPivot().Position
	end
	if object:IsA("BasePart") then
		return object.Position
	end
	return nil
end

local function spawnSoilFloat(object: Instance, bonus: number)
	local position = objectPosition(object)
	if position == nil then
		local root = localRoot()
		position = if root ~= nil then root.Position else nil
	end
	if position == nil then
		return
	end
	worldLabel(
		position + Vector3.yAxis * JuiceConfig.FloatSoilHeight,
		string.format(JuiceConfig.FloatSoilFormat, Format.commas(bonus), objectName(object)),
		JuiceConfig.FloatSoilTextSize,
		JuiceConfig.FloatSoilColor,
		JuiceConfig.FloatSoilGuiWidth,
		JuiceConfig.FloatSoilGuiHeight,
		JuiceConfig.FloatLifetime,
		JuiceConfig.FloatSoilRise
	)
end

local fxPart = Instance.new("Part")
fxPart.Name = "JuiceSplatEmitter"
fxPart.Anchored = true
fxPart.CanCollide = false
fxPart.CanQuery = false
fxPart.CanTouch = false
fxPart.CastShadow = false
fxPart.Transparency = 1
fxPart.Size = Vector3.one * JuiceConfig.SplatFxPartSize
fxPart.Parent = Workspace

local splatEmitter = Instance.new("ParticleEmitter")
splatEmitter.Name = "Splat"
splatEmitter.Color = ColorSequence.new(JuiceConfig.SplatColor)
splatEmitter.Lifetime = NumberRange.new(JuiceConfig.SplatLifetime.Min, JuiceConfig.SplatLifetime.Max)
splatEmitter.Speed = NumberRange.new(JuiceConfig.SplatSpeed.Min, JuiceConfig.SplatSpeed.Max)
splatEmitter.SpreadAngle = JuiceConfig.SplatSpreadAngle
splatEmitter.Acceleration = JuiceConfig.SplatAcceleration
splatEmitter.Size = JuiceConfig.SplatSize
splatEmitter.Transparency = JuiceConfig.SplatTransparency
splatEmitter.LightEmission = JuiceConfig.SplatLightEmission
splatEmitter.Drag = JuiceConfig.SplatDrag
splatEmitter.Rate = 0
splatEmitter.Parent = fxPart

local function burst(position: Vector3, count: number)
	if count <= 0 then
		return
	end
	fxPart.CFrame = CFrame.new(position)
	splatEmitter:Emit(count)
end

local splatAccumulator = 0
local splatParams = RaycastParams.new()
splatParams.FilterType = Enum.RaycastFilterType.Exclude
splatParams.IgnoreWater = true

local function stepSplats(dt: number)
	if not runActive then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local speed = root.AssemblyLinearVelocity.Magnitude
	if speed < JuiceConfig.SplatMinSpeed then
		splatAccumulator = 0
		return
	end

	local interval =
		math.max(JuiceConfig.SplatMinInterval, JuiceConfig.SplatInterval * (JuiceConfig.SplatSpeedRef / speed))
	splatAccumulator += dt
	if splatAccumulator < interval then
		return
	end
	splatAccumulator = 0

	local scale = Hitbox.Scale(root)
	splatParams.FilterDescendantsInstances = { character }
	local origin = Hitbox.Center(root.CFrame, scale)
	local hit = Workspace:Raycast(origin, -gravityUp() * (JuiceConfig.SplatProbeDistance * scale), splatParams)
	if hit ~= nil then
		burst(hit.Position + hit.Normal * JuiceConfig.SplatSurfaceOffset, JuiceConfig.SplatBurst)
	end
end

local shakeEnd = 0
local shakeDuration = 1
local shakeAmplitude = 0

local function shake(amplitude: number, duration: number)
	local now = os.clock()
	if now < shakeEnd and amplitude < shakeAmplitude then
		return
	end
	shakeAmplitude = amplitude
	shakeDuration = math.max(JuiceConfig.ShakeMinDuration, duration)
	shakeEnd = now + shakeDuration
end

local fovActive = false
local fovBase = 0
local fovToken = 0

local function kickFov()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	fovToken += 1
	local token = fovToken
	if not fovActive then
		fovBase = camera.FieldOfView
	end
	fovActive = true

	local kickIn = TweenInfo.new(JuiceConfig.SpeedFovInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(camera, kickIn, { FieldOfView = fovBase + JuiceConfig.SpeedFovKick }):Play()

	task.delay(JuiceConfig.SpeedFovInTime + JuiceConfig.SpeedFovHoldTime, function()
		if token ~= fovToken then
			return
		end
		local kickOut = TweenInfo.new(JuiceConfig.SpeedFovOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(camera, kickOut, { FieldOfView = fovBase }):Play()
		task.delay(JuiceConfig.SpeedFovOutTime, function()
			if token == fovToken then
				fovActive = false
			end
		end)
	end)
end

local function playSquash(scale: Vector3)
	local character = player.Character
	if character == nil then
		return
	end
	squashToken += 1
	local token = squashToken
	for _, name in JuiceConfig.SquashParts do
		local part = character:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			local active = meshTweens[part]
			local rest = if active ~= nil and meshRest[part] ~= nil then meshRest[part] else part.Size
			if active ~= nil then
				active:Cancel()
			end
			meshTweens[part] = nil
			meshRest[part] = rest
			part.Size = rest

			local goal = Vector3.new(rest.X * scale.X, rest.Y * scale.Y, rest.Z * scale.Z)
			local squashIn =
				TweenInfo.new(JuiceConfig.SquashInTime, JuiceConfig.SquashStyle, JuiceConfig.SquashDirection)
			local tweenIn = TweenService:Create(part, squashIn, { Size = goal })
			meshTweens[part] = tweenIn
			tweenIn:Play()
			tweenIn.Completed:Once(function(state)
				if state ~= Enum.PlaybackState.Completed or token ~= squashToken then
					return
				end
				local squashOut =
					TweenInfo.new(JuiceConfig.SquashOutTime, JuiceConfig.SquashStyle, JuiceConfig.SquashDirection)
				local tweenOut = TweenService:Create(part, squashOut, { Size = rest })
				meshTweens[part] = tweenOut
				tweenOut:Play()
				tweenOut.Completed:Once(function(outState)
					if outState == Enum.PlaybackState.Completed and token == squashToken then
						meshTweens[part] = nil
						meshRest[part] = part.Size
					end
				end)
			end)
		end
	end
end

local bodyParams = RaycastParams.new()
bodyParams.FilterType = Enum.RaycastFilterType.Exclude
bodyParams.IgnoreWater = true

local wasGrounded = true
local airTime = 0

local function stepBody(dt: number)
	local character = player.Character
	if character == nil then
		wasGrounded = true
		airTime = 0
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local scale = Hitbox.Scale(root)
	bodyParams.FilterDescendantsInstances = { character }
	local origin = Hitbox.Center(root.CFrame, scale)
	local hit = Workspace:Raycast(origin, -gravityUp() * (JuiceConfig.SquashProbeDistance * scale), bodyParams)
	local grounded = hit ~= nil

	if grounded then
		if not wasGrounded and airTime >= JuiceConfig.SquashAirTime then
			playSquash(JuiceConfig.SquashLandScale)
		end
		airTime = 0
	else
		airTime += dt
	end
	wasGrounded = grounded
end

player.CharacterAdded:Connect(function()
	table.clear(meshRest)
	table.clear(meshTweens)
	wasGrounded = true
	airTime = 0
end)

UserInputService.JumpRequest:Connect(function()
	playSquash(JuiceConfig.SquashJumpScale)
end)

local function petPosition(uid: string): Vector3?
	local equipped = DataController.Get().Pets.Equipped
	local index = table.find(equipped, uid)
	if index == nil then
		return nil
	end
	local root = localRoot()
	if root == nil then
		return nil
	end
	local offset = CharacterConfig.HitboxOffset + PetConfig.FollowOffsets[(index - 1) % #PetConfig.FollowOffsets + 1]
	local expected = root.CFrame:PointToWorldSpace(offset)

	local folder = Workspace:FindFirstChild(PetConfig.FollowFolderName)
	if folder == nil then
		return expected
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local body = model:FindFirstChild("Body")
			local position = if body ~= nil and body:IsA("BasePart") then body.Position else model:GetPivot().Position
			local distance = (position - expected).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = position
			end
		end
	end
	return best or expected
end

local function spawnPoopPuddle(position: Vector3)
	local puddle = Instance.new("Part")
	puddle.Name = "PetPoop"
	puddle.Shape = Enum.PartType.Ball
	puddle.Material = JuiceConfig.PetPoopMaterial
	puddle.Color = JuiceConfig.PetPoopColor
	puddle.Size = Vector3.new(
		JuiceConfig.PetPoopSize,
		JuiceConfig.PetPoopSize * JuiceConfig.PetPoopHeightRatio,
		JuiceConfig.PetPoopSize
	)
	puddle.CFrame = CFrame.new(position + Vector3.yAxis * JuiceConfig.PetPoopSize * JuiceConfig.PetPoopLiftRatio)
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.CanQuery = false
	puddle.CanTouch = false
	puddle.CastShadow = false
	puddle.Parent = Workspace
	task.delay(JuiceConfig.PetPoopLifetime, function()
		if puddle.Parent ~= nil then
			puddle:Destroy()
		end
	end)
end

local function petPoop(uid: string, gems: number)
	local position = petPosition(uid)
	if position == nil then
		return
	end
	burst(position, JuiceConfig.SplatPetBurst)
	spawnPoopPuddle(position)
	if gems > 0 then
		worldLabel(
			position + Vector3.yAxis * JuiceConfig.PetPoopGemHeight,
			string.format(JuiceConfig.PetPoopGemFormat, gems),
			JuiceConfig.PetPoopGemTextSize,
			JuiceConfig.PetPoopGemColor,
			JuiceConfig.PetPoopGemGuiWidth,
			JuiceConfig.PetPoopGemGuiHeight,
			JuiceConfig.PetPoopGemLifetime,
			JuiceConfig.PetPoopGemRise
		)
	end
	SoundController.Play(JuiceConfig.SoundPetPoop)
end

local function showMilestone(percent: number)
	if not runActive then
		return
	end
	local cleared = percent >= 100 and lastMilestone < 100
	local highest = 0
	for _, threshold in JuiceConfig.Milestones do
		if percent >= threshold and threshold > lastMilestone then
			highest = math.max(highest, threshold)
		end
	end
	if cleared then
		highest = 100
	elseif highest == 0 then
		return
	end
	lastMilestone = highest
	JuiceController.MilestoneShown:Fire(highest, cleared)
	SoundController.Play(if cleared then JuiceConfig.SoundPetReveal else JuiceConfig.SoundMilestone)
end

Net.RunState.OnClientEvent:Connect(function(state: any, _timeLeft: any, score: any, combo: any)
	local running = state == GameConfig.RunStates.Running
	if running and previousRunState ~= GameConfig.RunStates.Running then
		lastScore = 0
		lastMilestone = 0
		setCombo(1)
	end
	runActive = running
	previousRunState = if type(state) == "string" then state else nil

	if running then
		local current = tonumber(score) or 0
		local delta = current - lastScore
		if delta > 0 then
			spawnScoreFloat(delta)
		end
		lastScore = current
		setCombo(tonumber(combo) or 1)
	else
		setCombo(1)
	end
end)

Net.RunEnded.OnClientEvent:Connect(function()
	runActive = false
	previousRunState = GameConfig.RunStates.Idle
	setCombo(1)
end)

Net.MapProgress.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	showMilestone(math.clamp(tonumber(payload.Percent) or 0, 0, 100))
end)

Net.ObjectSoiled.OnClientEvent:Connect(function(object: any, bonus: any)
	if not runActive or typeof(object) ~= "Instance" then
		return
	end
	local amount = math.max(0, math.floor(tonumber(bonus) or 0))
	spawnSoilFloat(object, amount)
	shake(JuiceConfig.ShakeTargetAmplitude, JuiceConfig.ShakeTargetDuration)
	local position = objectPosition(object)
	if position ~= nil then
		burst(position, JuiceConfig.SplatSoilBurst)
	end
end)

Net.PowerupPicked.OnClientEvent:Connect(function(powerupId: any)
	if type(powerupId) ~= "string" then
		return
	end
	if powerupId == JuiceConfig.PowerupShakeId then
		shake(JuiceConfig.ShakeMiniBombAmplitude, JuiceConfig.ShakeMiniBombDuration)
		local root = localRoot()
		if root ~= nil then
			burst(root.Position, JuiceConfig.SplatSoilBurst)
		end
	elseif powerupId == JuiceConfig.PowerupFovId then
		kickFov()
	end
end)

Net.PetPoop.OnClientEvent:Connect(function(uid: any, gems: any)
	if type(uid) ~= "string" then
		return
	end
	petPoop(uid, math.max(0, math.floor(tonumber(gems) or 0)))
end)

RunService.Heartbeat:Connect(stepSplats)
RunService.Heartbeat:Connect(stepBody)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now >= shakeEnd then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local falloff = math.clamp((shakeEnd - now) / shakeDuration, 0, 1)
	local amplitude = shakeAmplitude * falloff
	local offset = Vector3.new(
		(math.random() * 2 - 1) * amplitude,
		(math.random() * 2 - 1) * amplitude,
		(math.random() * 2 - 1) * amplitude
	)
	local roll = math.rad((math.random() * 2 - 1) * JuiceConfig.ShakeRollDegrees * falloff)
	camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
end)

return JuiceController
