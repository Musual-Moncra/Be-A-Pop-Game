--!strict

--[[
	OnboardingController
	Client owner of the five-step first-run tutorial. Reads the saved step from every
	DataSync snapshot, notices the real actions that finish a step, asks the server to
	save the next one, and exposes the GUI / world targets the Onboarding screen points at.

	Steps (OnboardingConfig numbers): 1 tap PLAY, 2 stain 30 cells, 3 soil one target,
	4 upgrade Lifespan after a low-lifespan run, 5 equip a pet after a first drop.
	Steps 2 and 3 advance on the server from RunEvents.Stained / RunEvents.ObjectSoiled;
	the client advances steps 1, 4 and 5 through Net.TutorialStep. Skip sends the sentinel
	and the server finishes the tutorial.

	API:
		OnboardingController.Changed -> Signal
		OnboardingController.GetStep() -> number
		OnboardingController.CompleteCurrentStep()
		OnboardingController.Skip()
		OnboardingController.HasLowLifespan() -> boolean
		OnboardingController.HasPetSeen() -> boolean
		OnboardingController.FindTarget(key) -> GuiObject?   "Play" | "Upgrades" | "Pets" | "Menu"
		OnboardingController.GetNearestTargetPosition() -> Vector3?

	Dependencies: Players, Workspace, Signal, DataController, GameConfig, LobbyState,
		Net, OnboardingConfig, RoomConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local OnboardingConfig = require(ReplicatedStorage.Modules.Config.OnboardingConfig)
local RoomConfig = require(ReplicatedStorage.Modules.Config.RoomConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

local player = Players.LocalPlayer
local OnboardingController = {}

OnboardingController.Changed = Signal.new()

local step = OnboardingConfig.FirstStep
local pendingStep: number? = nil
local pendingAt = 0
local skipping = false
local lowLifespan = false
local petSeen = false
local dataLoaded = false
local lifespanLevel = 0
local equipBaseline = 0
local nearestPosition: Vector3? = nil
local nearestRefresh = 0
local currentRoute = LobbyState.Get()

local function fire()
	OnboardingController.Changed:Fire()
end

local function currentLifespan(): number
	local data = DataController.Get()
	if data.Upgrades == nil then
		return 0
	end
	return tonumber(data.Upgrades.Lifespan) or 0
end

local function currentEquipped(): number
	local data = DataController.Get()
	return #data.Pets.Equipped
end

local function setStep(value: number)
	local nextStep = math.clamp(math.floor(value), OnboardingConfig.FirstStep, OnboardingConfig.MaxStep)
	if skipping then
		if nextStep < OnboardingConfig.MaxStep then
			return
		end
		skipping = false
	end
	if nextStep == step then
		return
	end
	step = nextStep
	pendingStep = nil
	pendingAt = 0
	if step == OnboardingConfig.StepLifespan then
		lifespanLevel = currentLifespan()
	elseif step == OnboardingConfig.StepPet then
		equipBaseline = currentEquipped()
	end
	fire()
end

local function setLowLifespan()
	if lowLifespan then
		return
	end
	lowLifespan = true
	fire()
end

local function setPetSeen()
	if petSeen then
		return
	end
	petSeen = true
	fire()
end

function OnboardingController.GetStep(): number
	return step
end

function OnboardingController.HasLowLifespan(): boolean
	return lowLifespan
end

function OnboardingController.HasPetSeen(): boolean
	return petSeen
end

function OnboardingController.CompleteCurrentStep()
	if step >= OnboardingConfig.MaxStep then
		return
	end
	local now = os.clock()
	if pendingStep == step and now - pendingAt < OnboardingConfig.RemoteRetrySeconds then
		return
	end
	pendingStep = step
	pendingAt = now
	Net.TutorialStep:Fire(step + 1)
end

function OnboardingController.Skip()
	if step >= OnboardingConfig.MaxStep then
		return
	end
	skipping = true
	step = OnboardingConfig.MaxStep
	pendingStep = OnboardingConfig.MaxStep
	fire()
	Net.TutorialStep:Fire(OnboardingConfig.SkipStep)
end

local function onData(state: any)
	local lifespan = if state.Upgrades ~= nil then tonumber(state.Upgrades.Lifespan) or 0 else 0
	if not dataLoaded then
		if state.Upgrades ~= nil and next(state.Upgrades) ~= nil then
			dataLoaded = true
			lifespanLevel = lifespan
		end
	else
		if step == OnboardingConfig.StepLifespan and lifespan > lifespanLevel then
			OnboardingController.CompleteCurrentStep()
		end
		lifespanLevel = lifespan
	end

	if state.RunState == GameConfig.RunStates.Running then
		if step == OnboardingConfig.StepPlay then
			OnboardingController.CompleteCurrentStep()
		end
		if state.TimeLeft >= 0 and state.TimeLeft < OnboardingConfig.LifespanSeconds then
			setLowLifespan()
		end
	end

	if not petSeen and ((state.PetDropQueue ~= nil and #state.PetDropQueue > 0) or #state.Pets.Pets > 0) then
		setPetSeen()
	end

	if petSeen and step == OnboardingConfig.StepPet and #state.Pets.Equipped > equipBaseline then
		OnboardingController.CompleteCurrentStep()
	end

	if
		(step == OnboardingConfig.StepLifespan and currentRoute == LobbyState.Routes.Upgrades)
		or (petSeen and step == OnboardingConfig.StepPet and currentRoute == LobbyState.Routes.Pets)
	then
		OnboardingController.CompleteCurrentStep()
	end
end

local function onRoute(route: string)
	currentRoute = route
	if
		(step == OnboardingConfig.StepLifespan and route == LobbyState.Routes.Upgrades)
		or (petSeen and step == OnboardingConfig.StepPet and route == LobbyState.Routes.Pets)
	then
		OnboardingController.CompleteCurrentStep()
	end
end

local function onDataSync(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	local value = tonumber(snapshot.Tutorial)
	if value ~= nil then
		setStep(value)
	end
end

local function gameScreen(): Instance?
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil
	end
	return playerGui:FindFirstChild("GameUI")
end

local function isShown(instance: GuiObject): boolean
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return instance.AbsoluteSize.X > 0 and instance.AbsoluteSize.Y > 0
end

function OnboardingController.FindTarget(key: string): GuiObject?
	local names = OnboardingConfig.InterfaceNames[key]
	local screen = gameScreen()
	if names == nil or screen == nil then
		return nil
	end
	for _, name in names do
		local instance = screen:FindFirstChild(name, true)
		if instance ~= nil and instance:IsA("GuiObject") and isShown(instance) then
			return instance
		end
	end
	return nil
end

local function characterRoot(): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function refreshNearestPosition()
	local now = os.clock()
	if now - nearestRefresh < OnboardingConfig.WorldTargetRefresh then
		return
	end
	nearestRefresh = now
	nearestPosition = nil

	local root = characterRoot()
	local rooms = Workspace:FindFirstChild(RoomConfig.MapFolderName)
	if root == nil or rooms == nil then
		return
	end

	local origin = root.Position
	local bestDistance = math.huge
	for _, map in rooms:GetChildren() do
		if map:IsA("Model") then
			local props = map:FindFirstChild("Props")
			if props ~= nil then
				for _, prop in props:GetChildren() do
					if prop:IsA("Model") and prop:GetAttribute("ObjectType") ~= nil then
						local position = prop:GetPivot().Position
						local distance = (position - origin).Magnitude
						if distance < bestDistance then
							bestDistance = distance
							nearestPosition = position
						end
					end
				end
			end
		end
	end
end

function OnboardingController.GetNearestTargetPosition(): Vector3?
	refreshNearestPosition()
	return nearestPosition
end

DataController.Changed:Connect(onData)
LobbyState.Changed:Connect(onRoute)
Net.DataSync.OnClientEvent:Connect(onDataSync)

onData(DataController.Get())

return OnboardingController
