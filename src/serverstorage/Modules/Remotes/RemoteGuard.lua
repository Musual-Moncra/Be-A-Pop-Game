--!strict

--[[
	RemoteGuard
	Shared gate for inbound remotes: per-player, per-remote rate limiting and argument type checks.
	Every *Remotes handler wraps its callback with RemoteGuard.Bind so no service ever sees an
	unthrottled or malformed client call.

	API:
		RemoteGuard.Bind(packet, name, argTypes, callback)
			packet: Net packet to listen on
			name: key in RemoteConfig.RateLimits
			argTypes: expected Luau type() of each argument, in order ({} for none); string arguments
				longer than RemoteConfig.MaxStringLength are rejected
			callback(plr, ...): called only when the call passes both checks

	Dependencies: RemoteConfig
]]

local Players = game:GetService("Players")

local RemoteConfig = require(script.Parent.Parent.Config.RemoteConfig)

local RemoteGuard = {}

local lastCalls: { [Player]: { [string]: number } } = {}

local function allow(plr: Player, name: string): boolean
	local now = os.clock()
	local calls = lastCalls[plr]
	if calls == nil then
		calls = {}
		lastCalls[plr] = calls
	end
	local limit = RemoteConfig.RateLimits[name] or RemoteConfig.DefaultRateLimit
	local last = calls[name]
	if last ~= nil and now - last < limit then
		return false
	end
	calls[name] = now
	return true
end

local function validArg(expected: string, value: any): boolean
	if type(value) ~= expected then
		return false
	end
	if expected == "string" and #(value :: string) > RemoteConfig.MaxStringLength then
		return false
	end
	return true
end

function RemoteGuard.Bind(packet: any, name: string, argTypes: { string }, callback: (Player, ...any) -> ())
	packet.OnServerEvent:Connect(function(plr: Player, ...)
		for index, expected in argTypes do
			if not validArg(expected, (select(index, ...))) then
				return
			end
		end
		if not allow(plr, name) then
			return
		end
		callback(plr, ...)
	end)
end

Players.PlayerRemoving:Connect(function(plr)
	lastCalls[plr] = nil
end)

return RemoteGuard
