--!strict

--[[
	Format
	Number formatting for the UI.

	API:
		Format.compact(n) -> "950", "12.5K", "3.2M" (suffixes from UIConfig.Text.ThousandsSuffixes)
		Format.commas(n)  -> "12,345"
		Format.multiplier(n) -> "2", "1.5" (trailing zeros removed)

	Dependencies: UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local Format = {}

function Format.commas(n: number): string
	local separator = UIConfig.Text.ThousandsSeparator
	local whole = tostring(math.floor(math.abs(n)))
	local formatted = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1" .. separator)))
	if string.sub(formatted, 1, #separator) == separator then
		formatted = string.sub(formatted, #separator + 1)
	end
	return if n < 0 then UIConfig.Text.NegativeSign .. formatted else formatted
end

function Format.compact(n: number): string
	local value = math.floor(n)
	if math.abs(value) < 1000 then
		return tostring(value)
	end
	local suffixes = UIConfig.Text.ThousandsSuffixes
	local scaled = value
	local index = 0
	while math.abs(scaled) >= 1000 and index < #suffixes do
		scaled /= 1000
		index += 1
	end
	return string.format(UIConfig.Text.CompactFormat, math.floor(scaled * 10) / 10, suffixes[index])
end

function Format.multiplier(n: number): string
	local rounded = math.round(n * 100) / 100
	if rounded == math.floor(rounded) then
		return string.format(UIConfig.Text.IntegerFormat, rounded)
	end
	return tostring(rounded)
end

return Format
