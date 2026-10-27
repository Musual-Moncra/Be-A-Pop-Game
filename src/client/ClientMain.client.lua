--[[
    @musual - Client Connection
    
    Don't change if you dont know what are you doing!
]]

-- Variables
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locations = {
    ReplicatedStorage.Modules.Controllers,
    ReplicatedStorage.Modules.UIs
}

-- Init
local runFramework = require(ReplicatedStorage.Modules.Shared.runFramework)
runFramework(Locations)
