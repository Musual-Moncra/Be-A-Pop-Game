--[[
	Animate
	Plays the walk animation on the poop while it moves and fades it out when it stops.
	Reads the Animation template and tuning from CharacterConfig, and measures speed on the
	surface plane so GravityController's grounded stick velocity does not count as movement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterConfig = require(ReplicatedStorage.Modules.Config.CharacterConfig)

local player = Players.LocalPlayer
local animationAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")

local function trackCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	if not humanoid:IsA("Humanoid") or not root:IsA("BasePart") then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local template = animationAssets:FindFirstChild(CharacterConfig.WalkAnimationAsset)
	if template == nil or not template:IsA("Animation") then
		return
	end

	local track = animator:LoadAnimation(template)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement

	local playing = false
	local connection = RunService.Heartbeat:Connect(function()
		if not character:IsDescendantOf(workspace) or humanoid.Health <= 0 then
			if playing then
				playing = false
				track:Stop(CharacterConfig.FadeTime)
			end
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local up = character:GetAttribute("GravityUp")
		if typeof(up) ~= "Vector3" then
			up = Vector3.yAxis
		end
		local surfaceSpeed = (velocity - up * velocity:Dot(up)).Magnitude
		local moving = surfaceSpeed > CharacterConfig.MoveThreshold

		if moving and not playing then
			playing = true
			track:Play(CharacterConfig.FadeTime, 1, CharacterConfig.PlaybackSpeed)
		elseif not moving and playing then
			playing = false
			track:Stop(CharacterConfig.FadeTime)
		end
	end)

	character.Destroying:Connect(function()
		connection:Disconnect()
		track:Stop()
	end)
end

if player.Character ~= nil then
	task.spawn(trackCharacter, player.Character)
end
player.CharacterAdded:Connect(trackCharacter)
