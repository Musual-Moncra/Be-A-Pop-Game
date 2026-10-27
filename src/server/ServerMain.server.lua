--[[
    @musual - ServerMain Connection
    
    Don't change if you dont know what are you doing!
]]

-- Variables
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Locations = {
    ServerStorage.Modules
}

-- Init
local runFramework = require(ReplicatedStorage.Modules.Shared.runFramework)

runFramework(Locations)
