--!strict

--[[
	SparkleClock
	One shared Heartbeat for every sparkle animation. Components subscribe instead of running
	their own loops, and the module enforces the on-screen caps (Twinkle stars, Burst pieces).

	API:
		SparkleClock.Subscribe(fn) -> disconnect   fn(dt, now) runs once per Heartbeat
		SparkleClock.Now() -> seconds since the clock started
		SparkleClock.Reserve(kind, cap, count) -> granted count (never above the cap)
		SparkleClock.Release(kind, count)
	Dependencies: RunService
]]

local RunService = game:GetService("RunService")

local SparkleClock = {}

local subscribers: { [(any) -> ()]: boolean } = {}
local connection: RBXScriptConnection? = nil
local elapsed = 0
local live: { [string]: number } = {}

local function step(dt: number)
	elapsed += dt
	local snapshot = {}
	for fn in subscribers do
		table.insert(snapshot, fn)
	end
	for _, fn in snapshot do
		fn(dt, elapsed)
	end
end

function SparkleClock.Subscribe(fn: (number, number) -> ()): () -> ()
	if subscribers[fn] == nil then
		subscribers[fn] = true
		if connection == nil then
			connection = RunService.Heartbeat:Connect(step)
		end
	end
	local active = true
	return function()
		if not active then
			return
		end
		active = false
		subscribers[fn] = nil
		if next(subscribers) == nil and connection ~= nil then
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

return SparkleClock
