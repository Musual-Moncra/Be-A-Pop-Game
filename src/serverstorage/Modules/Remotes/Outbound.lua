--!strict

--[[
	Outbound
	The only server code that fires Net packets to clients. Services call these functions
	instead of touching Net, so every server -> client message is listed in one place and
	sends to players who already left are dropped here.

	State packets (DataSync, QuestState, PowerupState) are coalesced: calling them several
	times in one frame only stores the newest payload, and a single packet per player is
	sent on the next deferred resume. Event packets are sent immediately.

	API:
		Outbound.DataSync(plr, data)                     coalesced
		Outbound.QuestState(plr, quests)                 coalesced
		Outbound.PowerupState(plr, active)               coalesced
		Outbound.SelectionSync(plr, mapId, modeId)
		Outbound.RunState(plr, state, timeLeft, score)
		Outbound.RunEnded(plr, summary)
		Outbound.PowerupPicked(plr, powerupId)
		Outbound.ObjectStained(plr, object, step)
		Outbound.ObjectSoiled(plr, object, bonus)
		Outbound.NpcCaught(plr, penaltySeconds)
		Outbound.Notify(plr, kind, text)
		Outbound.MapProgress(plr, mapId, percent)         coalesced
		Outbound.SpecialEvent(plr, mapId, endsAt)

	Dependencies: Net
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)

local Outbound = {}

type Pending = { [Player]: any }

local pendingByPacket: { [any]: Pending } = {}
local flushScheduled = false

local function connected(plr: Player): boolean
	return plr.Parent == Players
end

local function flush()
	flushScheduled = false
	for packet, pending in pendingByPacket do
		for plr, payload in pending do
			if connected(plr) then
				packet:FireClient(plr, payload)
			end
		end
		table.clear(pending)
	end
end

local function queue(packet: any, plr: Player, payload: any)
	local pending = pendingByPacket[packet]
	if pending == nil then
		pending = {}
		pendingByPacket[packet] = pending
	end
	pending[plr] = payload
	if not flushScheduled then
		flushScheduled = true
		task.defer(flush)
	end
end

function Outbound.DataSync(plr: Player, data: any)
	queue(Net.DataSync, plr, data)
end

function Outbound.QuestState(plr: Player, quests: { any })
	queue(Net.QuestState, plr, quests)
end

function Outbound.PowerupState(plr: Player, active: { any })
	queue(Net.PowerupState, plr, active)
end

function Outbound.SelectionSync(plr: Player, mapId: string, modeId: string)
	if connected(plr) then
		Net.SelectionSync:FireClient(plr, mapId, modeId)
	end
end

function Outbound.RunState(plr: Player, state: string, timeLeft: number, score: number)
	if connected(plr) then
		Net.RunState:FireClient(plr, state, timeLeft, math.max(0, math.floor(score)))
	end
end

function Outbound.RunEnded(plr: Player, summary: any)
	if connected(plr) then
		Net.RunEnded:FireClient(plr, summary)
	end
end

function Outbound.PowerupPicked(plr: Player, powerupId: string)
	if connected(plr) then
		Net.PowerupPicked:FireClient(plr, powerupId)
	end
end

function Outbound.ObjectStained(plr: Player, object: Instance, step: number)
	if connected(plr) then
		Net.ObjectStained:FireClient(plr, object, step)
	end
end

function Outbound.ObjectSoiled(plr: Player, object: Instance, bonus: number)
	if connected(plr) then
		Net.ObjectSoiled:FireClient(plr, object, math.floor(bonus))
	end
end

function Outbound.NpcCaught(plr: Player, penaltySeconds: number)
	if connected(plr) then
		Net.NpcCaught:FireClient(plr, math.ceil(penaltySeconds))
	end
end

function Outbound.Notify(plr: Player, kind: string, text: string)
	if connected(plr) then
		Net.Notify:FireClient(plr, kind, text)
	end
end

function Outbound.MapProgress(plr: Player, mapId: string, percent: number)
	queue(Net.MapProgress, plr, { MapId = mapId, Percent = percent })
end

function Outbound.SpecialEvent(plr: Player, mapId: string, endsAt: number)
	if connected(plr) then
		Net.SpecialEvent:FireClient(plr, { MapId = mapId, EndsAt = endsAt })
	end
end

Players.PlayerRemoving:Connect(function(plr)
	for _, pending in pendingByPacket do
		pending[plr] = nil
	end
end)

return Outbound
