--!strict

--[[
	SoundController
	Client audio for every sound effect and the background music. Each play spawns a short
	lived Sound instance in a SoundService folder, rolls a random pitch from the config range
	and is dropped when the per-key concurrency or throttle limit is reached, so a run full
	of stains can never flood the mixer.

	Music switches by track key: "Lobby" or a map id. The new track crossfades in over
	Music.CrossfadeSeconds while the old one fades out. A missing or empty map track falls
	back to the lobby track and an empty SoundId means silence, so the game runs before the
	audio library ids are filled in.

	Event sources are DataController signals and state: run start and end, level up, coin gain
	and the toast feed drive the run-level sounds, while Stained, Soiled, PowerupPicked and
	NpcCaught fire for the moment-to-moment gameplay sounds. Buttons call PlayUI.

	API:
		SoundController.Play(key)       play one key from SoundConfig.Sfx
		SoundController.PlayUI(key)     alias for button clicks and UI feedback
		SoundController.SetMusic(key)   "Lobby" or a map id, crossfades the track

	Dependencies: SoundService, TweenService, ReplicatedStorage, DataController, GameConfig, SoundConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local DataController = require(ReplicatedStorage.Modules.Controllers.DataController)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local SoundConfig = require(ReplicatedStorage.Modules.Config.SoundConfig)

local SoundController = {}

local soundFolder = Instance.new("Folder")
soundFolder.Name = SoundConfig.FolderName
soundFolder.Parent = SoundService

local activeSfx: { [string]: { Sound } } = {}
local lastPlayed: { [string]: number } = {}

local function pruneActive(key: string)
	local active = activeSfx[key]
	if active == nil then
		return
	end
	for index = #active, 1, -1 do
		local sound = active[index]
		if sound.Parent == nil then
			table.remove(active, index)
		end
	end
end

function SoundController.Play(key: string)
	local definition = SoundConfig.Sfx[key]
	if definition == nil or definition.SoundId == "" then
		return
	end

	local now = os.clock()
	if definition.Throttle > 0 and now - (lastPlayed[key] or 0) < definition.Throttle then
		return
	end

	local active = activeSfx[key]
	if active == nil then
		active = {}
		activeSfx[key] = active
	end
	pruneActive(key)
	if #active >= definition.MaxConcurrent then
		return
	end

	lastPlayed[key] = now
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = definition.SoundId
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.PitchMin + math.random() * (definition.PitchMax - definition.PitchMin)
	table.insert(active, sound)

	sound.Ended:Connect(function()
		local index = table.find(active, sound)
		if index ~= nil then
			table.remove(active, index)
		end
		sound:Destroy()
	end)

	sound.Parent = soundFolder
	sound:Play()

	task.delay(SoundConfig.MaxSoundLifetime, function()
		if sound.Parent ~= nil then
			sound:Destroy()
		end
	end)
end

function SoundController.PlayUI(key: string)
	SoundController.Play(key)
end

local currentTrack: Sound? = nil
local currentMusicId = ""

local function trackDefinition(key: string): any
	if key == "Lobby" then
		return SoundConfig.Music.Lobby
	end
	local definition = SoundConfig.Music.Maps[key]
	if definition == nil or definition.SoundId == "" then
		return SoundConfig.Music.Lobby
	end
	return definition
end

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(SoundConfig.Music.CrossfadeSeconds), { Volume = 0 })
	tween:Play()
	tween.Completed:Once(function()
		sound:Destroy()
	end)
end

function SoundController.SetMusic(key: string)
	local definition = trackDefinition(key)
	if definition == nil or definition.SoundId == currentMusicId then
		return
	end

	local previous = currentTrack
	currentTrack = nil
	currentMusicId = definition.SoundId
	if previous ~= nil then
		fadeOut(previous)
	end
	if definition.SoundId == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = definition.SoundId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = soundFolder
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(SoundConfig.Music.CrossfadeSeconds), { Volume = definition.Volume }):Play()
	currentTrack = sound
end

local previousState = DataController.Get()
local lastToastId = 0
local sawFirstPublish = false

DataController.Changed:Connect(function(state)
	local previous = previousState
	previousState = state
	local isFirstPublish = not sawFirstPublish
	sawFirstPublish = true

	if state.RunState ~= previous.RunState then
		if state.RunState == GameConfig.RunStates.Running then
			SoundController.Play("RunStart")
			SoundController.SetMusic(state.MapId)
		elseif state.RunState == GameConfig.RunStates.Idle then
			SoundController.SetMusic("Lobby")
		end
	end

	if state.LastRun ~= nil and state.LastRun ~= previous.LastRun then
		SoundController.Play("RunEnd")
		if state.LastRun.LeveledUp > 0 then
			SoundController.Play("LevelUp")
		end
	end

	if not isFirstPublish and state.Coins > previous.Coins then
		SoundController.Play("CoinGain")
	end

	for _, toast in state.Toasts do
		if toast.Id > lastToastId then
			lastToastId = toast.Id
			if toast.Kind == "Success" then
				SoundController.Play("PurchaseSuccess")
			elseif toast.Kind == "Error" then
				SoundController.Play("PurchaseError")
			end
		end
	end
end)

DataController.Stained:Connect(function()
	SoundController.Play("Stain")
end)

DataController.Soiled:Connect(function()
	SoundController.Play("Soiled")
end)

DataController.PowerupPicked:Connect(function()
	SoundController.Play("FoodEaten")
end)

DataController.NpcCaught:Connect(function()
	SoundController.Play("NpcCaught")
end)

SoundController.SetMusic("Lobby")

return SoundController
