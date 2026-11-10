--!strict

--[[
	TutorialRemotes
	Inbound first-run tutorial remote and the two server-side action counters that finish
	steps without a client claim: 30 new stain cells and one fully soiled target. The client
	may only save the next step (current + 1) or the skip sentinel, which finishes the whole
	tutorial. Every call is type checked and rate limited by RemoteGuard, and DataService
	republishes the profile so the client sees the new step through DataSync.

	Started by runFramework at Priority 5, after every service has loaded.

	Dependencies: Players, ReplicatedStorage, DataService, RemoteGuard, RunEvents,
		OnboardingConfig, Net
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(ServerStorage.Modules.Services.DataService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local OnboardingConfig = require(ReplicatedStorage.Modules.Config.OnboardingConfig)
local Net = require(ReplicatedStorage.Modules.Shared.Net)

local stainCells: { [Player]: number } = {}

local function currentStep(data: any): number
	return tonumber(data.Tutorial) or OnboardingConfig.FirstStep
end

local function saveStep(plr: Player, nextStep: number)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	data.Tutorial = nextStep
	DataService.MarkChanged(plr)
end

local function bindRemote()
	RemoteGuard.Bind(Net.TutorialStep, "TutorialStep", { "number" }, function(plr, value)
		local data = DataService.Get(plr)
		if data == nil then
			return
		end
		local step = math.floor(value)
		if step ~= value then
			return
		end
		local current = currentStep(data)
		if current >= OnboardingConfig.MaxStep then
			return
		end
		if step == OnboardingConfig.SkipStep then
			saveStep(plr, OnboardingConfig.MaxStep)
		elseif step == current + 1 then
			saveStep(plr, step)
		end
	end)
end

local function bindActions()
	RunEvents.RunStarted:Connect(function(plr: Player)
		stainCells[plr] = 0
	end)

	RunEvents.Stained:Connect(function(plr: Player)
		local data = DataService.Get(plr)
		if data == nil then
			return
		end
		if currentStep(data) ~= OnboardingConfig.StepStain then
			stainCells[plr] = 0
			return
		end
		local count = (stainCells[plr] or 0) + 1
		stainCells[plr] = count
		if count >= OnboardingConfig.StainCells then
			stainCells[plr] = 0
			saveStep(plr, OnboardingConfig.StepSplat)
		end
	end)

	RunEvents.ObjectSoiled:Connect(function(plr: Player)
		local data = DataService.Get(plr)
		if data == nil then
			return
		end
		if currentStep(data) == OnboardingConfig.StepSplat then
			saveStep(plr, OnboardingConfig.StepLifespan)
		end
	end)

	RunEvents.RunEnded:Connect(function(plr: Player)
		stainCells[plr] = 0
	end)

	Players.PlayerRemoving:Connect(function(plr: Player)
		stainCells[plr] = nil
	end)
end

return function()
	bindRemote()
	bindActions()
end
