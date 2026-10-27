--!strict

--[[
	MapConfig
	Pure data tuning for playable map zones and world spawn points.

	Fields:
		DefaultMapId: default map id string used on player join and fallback
		Maps: array of MapDefinition tables
			Id: unique map identifier string
			DisplayName: human-readable name shown in selection UI
			ModelName: name of the Workspace Model containing map geometry
			Spawn: Vector3 world coordinates for character teleportation (studs)
			Enabled: boolean flag whether the map is accessible for selection
			Order: integer sort order for UI presentation
]]

export type MapDefinition = {
	Id: string,
	DisplayName: string,
	ModelName: string,
	Spawn: Vector3,
	Enabled: boolean,
	Order: number,
}

local MapConfig = {}

MapConfig.DefaultMapId = "Zone1"

MapConfig.Maps = {
	{
		Id = "Zone1",
		DisplayName = "Kitchen",
		ModelName = "Zone1",
		Spawn = Vector3.new(500, 5, 0),
		Enabled = true,
		Order = 1,
	},
	{
		Id = "Zone2",
		DisplayName = "Living Room",
		ModelName = "Zone2",
		Spawn = Vector3.new(1000, 5, 0),
		Enabled = false,
		Order = 2,
	},
} :: { MapDefinition }

function MapConfig.GetMap(id: string): MapDefinition?
	for _, map in MapConfig.Maps do
		if map.Id == id then
			return map
		end
	end
	return nil
end

return MapConfig
