--!strict

--[[
	SparkleClock
	One shared clock for every cosmetic UI animation (sparkles, breathing, glow, shine, rainbow
	rims). It ticks at UIConfig.Sparkle.TickRate instead of every frame and never allocates while
	ticking, so dozens of animated elements cost one cheap loop. Components subscribe instead of
	running their own loops or tweens; the module also enforces the on-screen caps.

	API:
		SparkleClock.Subscribe(fn) -> disconnect   fn(dt, now) runs once per tick
		SparkleClock.Now() -> seconds since the clock started
		SparkleClock.Reserve(kind, cap, count) -> granted count (never above the cap)
		SparkleClock.Release(kind, count)
		SparkleClock.OnScreen(gui) -> true when gui is visible and inside the screen

	Dependencies: RunService, Workspace, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local SparkleClock = {}

local subscribers: { (number, number) -> () } = {}
local running: { (number, number) -> () } = {}
local alive: { [(number, number) -> ()]: boolean } = {}
local connection: RBXScriptConnection? = nil
local elapsed = 0
local pending = 0
local live: { [string]: number } = {}

local function step(dt: number)
	elapsed += dt
	pending += dt
	local interval = 1 / UIConfig.Sparkle.TickRate
	if pending < interval then
		return
	end
	local tick = math.min(pending, interval * 4)
	pending = 0
	local count = #subscribers
	table.move(subscribers, 1, count, 1, running)
	for index = 1, count do
		local fn = running[index]
		running[index] = nil
		if alive[fn] then
			fn(tick, elapsed)
		end
	end
end

function SparkleClock.Subscribe(fn: (number, number) -> ()): () -> ()
	if alive[fn] then
		return function() end
	end
	alive[fn] = true
	table.insert(subscribers, fn)
	if connection == nil then
		connection = RunService.PreRender:Connect(step)
	end
	local active = true
	return function()
		if not active then
			return
		end
		active = false
		alive[fn] = nil
		local index = table.find(subscribers, fn)
		if index ~= nil then
			table.remove(subscribers, index)
		end
		if #subscribers == 0 and connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end
end

function SparkleClock.Now(): number
	return elapsed
end

function SparkleClock.Reserve(kind: string, cap: number, count: number): number
	local current = live[kind] or 0
	local granted = math.max(0, math.min(count, cap - current))
	if granted > 0 then
		live[kind] = current + granted
	end
	return granted
end

function SparkleClock.Release(kind: string, count: number)
	live[kind] = math.max(0, (live[kind] or 0) - count)
end

function SparkleClock.OnScreen(gui: GuiObject): boolean
	if not gui.Visible or gui.Parent == nil then
		return false
	end
	local size = gui.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return false
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return true
	end
	local position = gui.AbsolutePosition
	local view = camera.ViewportSize
	return position.X + size.X > 0 and position.Y + size.Y > 0 and position.X < view.X and position.Y < view.Y
end

return SparkleClock
