--!strict

--[[
	ModeConfig
	Pure data tuning for game modes and gameplay rules.

	Fields:
		DefaultModeId: default mode id string used on player join and fallback
		Modes: array of ModeDefinition tables
			Id: unique mode identifier string
			DisplayName: human-readable title shown in selection UI
			Description: description text explaining mode rules
			UsesTimer: boolean flag whether the run counts down player lifespan
			AwardsCoins: boolean flag whether score converts to coins at run completion
			MaxDuration: maximum allowed duration before session ends (seconds, 0 for timer-driven)
]]

export type ModeDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	UsesTimer: boolean,
	AwardsCoins: boolean,
	MaxDuration: number,
}

local ModeConfig = {}

ModeConfig.DefaultModeId = "Classic"

ModeConfig.Modes = {
	{
		Id = "Classic",
		DisplayName = "Classic",
		Description = "Standard timed run for coins and high scores.",
		UsesTimer = true,
		AwardsCoins = true,
		MaxDuration = 0,
	},
	{
		Id = "Practice",
		DisplayName = "Practice",
		Description = "Untimed exploration with no coin rewards.",
		UsesTimer = false,
		AwardsCoins = false,
		MaxDuration = 600,
	},
} :: { ModeDefinition }

function ModeConfig.GetMode(id: string): ModeDefinition?
	for _, mode in ModeConfig.Modes do
		if mode.Id == id then
			return mode
		end
	end
	return nil
end

return ModeConfig
