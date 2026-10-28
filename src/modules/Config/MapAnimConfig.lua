--!strict

--[[
	MapAnimConfig
	Client-only ambient animation of map details. A Part or Model in a map with the string
	attribute AnimKind (and optional number AnimPhase) is animated by MapAnimController using
	the kind of the same name below. Pure data, no functions.

	Fields:
		MaxDistance: details farther than this from the camera stop animating (studs)
		CullCheckInterval: how often the camera distance of every detail is re-checked (seconds)
		Kinds: one table per AnimKind value
			Type: "Spin" turns around the vertical axis, "Bob" floats up and down, "Sway" rocks
				around the vertical axis tilt, "Swing" swings from its top edge, "Pulse" fades
				the transparency of parts in and out (text)
			Speed: Spin only, turning speed (degrees/second)
			Amplitude: Bob only, height of the float (studs)
			Angle: Sway and Swing only, largest tilt either way (degrees)
			Frequency: Bob, Sway, Swing and Pulse, full cycles per second (hertz)
			MinTransparency: Pulse only, most visible transparency (0 to 1)
			MaxTransparency: Pulse only, most faded transparency (0 to 1)
]]

local MapAnimConfig = {}

MapAnimConfig.MaxDistance = 450
MapAnimConfig.CullCheckInterval = 0.5

MapAnimConfig.Kinds = {
	Spin = { Type = "Spin", Speed = 160 },
	SpinSlow = { Type = "Spin", Speed = 28 },
	Bob = { Type = "Bob", Amplitude = 0.9, Frequency = 0.45 },
	Jet = { Type = "Bob", Amplitude = 0.6, Frequency = 1.3 },
	Sway = { Type = "Sway", Angle = 3, Frequency = 0.3 },
	Wobble = { Type = "Sway", Angle = 7, Frequency = 0.55 },
	Swing = { Type = "Swing", Angle = 24, Frequency = 0.4 },
	Pulse = { Type = "Pulse", MinTransparency = 0, MaxTransparency = 0.45, Frequency = 0.7 },
}

return MapAnimConfig
