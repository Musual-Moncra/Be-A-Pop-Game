--!strict

--[[
	Headless Luau test suite for ConfigLookup, Hitbox, and Config integrity.
	Executed by tools/tests/run.sh via /opt/homebrew/bin/luau with minimal
	Roblox datatype and module-loader stubs.
]]

type Vector3Stub = {
	X: number,
	Y: number,
	Z: number,
	Magnitude: number,
	Unit: Vector3Stub,
	Dot: (self: Vector3Stub, other: Vector3Stub) -> number,
	Cross: (self: Vector3Stub, other: Vector3Stub) -> Vector3Stub,
	Lerp: (self: Vector3Stub, other: Vector3Stub, alpha: number) -> Vector3Stub,
}

type CFrameStub = {
	Position: Vector3Stub,
	X: number,
	Y: number,
	Z: number,
	RightVector: Vector3Stub,
	UpVector: Vector3Stub,
	LookVector: Vector3Stub,
	PointToWorldSpace: (self: CFrameStub, v: Vector3Stub) -> Vector3Stub,
	PointToObjectSpace: (self: CFrameStub, v: Vector3Stub) -> Vector3Stub,
	VectorToWorldSpace: (self: CFrameStub, v: Vector3Stub) -> Vector3Stub,
	VectorToObjectSpace: (self: CFrameStub, v: Vector3Stub) -> Vector3Stub,
}

local Vector3Lib = {}
local vector3Meta = {}

local function newVector3(x: number?, y: number?, z: number?): Vector3Stub
	local vx = x or 0
	local vy = y or 0
	local vz = z or 0
	local self = {
		X = vx,
		Y = vy,
		Z = vz,
	}
	return setmetatable(self, vector3Meta) :: any
end

function vector3Meta.__index(self: any, key: string): any
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local mag = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if mag > 0 then
			return newVector3(self.X / mag, self.Y / mag, self.Z / mag)
		end
		return newVector3(0, 0, 0)
	end
	return Vector3Lib[key]
end

function vector3Meta.__add(a: Vector3Stub, b: Vector3Stub): Vector3Stub
	return newVector3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function vector3Meta.__sub(a: Vector3Stub, b: Vector3Stub): Vector3Stub
	return newVector3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function vector3Meta.__unm(a: Vector3Stub): Vector3Stub
	return newVector3(-a.X, -a.Y, -a.Z)
end

function vector3Meta.__mul(a: any, b: any): Vector3Stub
	if type(a) == "number" then
		return newVector3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return newVector3(a.X * b, a.Y * b, a.Z * b)
	end
	return newVector3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

function vector3Meta.__div(a: any, b: any): Vector3Stub
	if type(b) == "number" then
		return newVector3(a.X / b, a.Y / b, a.Z / b)
	end
	return newVector3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end

function vector3Meta.__eq(a: Vector3Stub, b: Vector3Stub): boolean
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

function vector3Meta.__tostring(a: Vector3Stub): string
	return string.format("(%g, %g, %g)", a.X, a.Y, a.Z)
end

function Vector3Lib.Dot(self: Vector3Stub, other: Vector3Stub): number
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

function Vector3Lib.Cross(self: Vector3Stub, other: Vector3Stub): Vector3Stub
	return newVector3(
		self.Y * other.Z - self.Z * other.Y,
		self.Z * other.X - self.X * other.Z,
		self.X * other.Y - self.Y * other.X
	)
end

function Vector3Lib.Lerp(self: Vector3Stub, other: Vector3Stub, alpha: number): Vector3Stub
	return newVector3(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end

Vector3Lib.new = newVector3
Vector3Lib.zero = newVector3(0, 0, 0)
Vector3Lib.one = newVector3(1, 1, 1)
Vector3Lib.xAxis = newVector3(1, 0, 0)
Vector3Lib.yAxis = newVector3(0, 1, 0)
Vector3Lib.zAxis = newVector3(0, 0, 1)

local CFrameLib = {}
local cframeMeta = {}

local function newCFrameFromMatrix(pos: Vector3Stub, right: Vector3Stub, up: Vector3Stub, back: Vector3Stub): CFrameStub
	local self = {
		Position = pos,
		X = pos.X,
		Y = pos.Y,
		Z = pos.Z,
		RightVector = right,
		UpVector = up,
		LookVector = -back,
		_back = back,
	}
	return setmetatable(self, cframeMeta) :: any
end

function CFrameLib.PointToWorldSpace(self: any, v: Vector3Stub): Vector3Stub
	return self.Position + self.RightVector * v.X + self.UpVector * v.Y + self._back * v.Z
end

function CFrameLib.PointToObjectSpace(self: any, v: Vector3Stub): Vector3Stub
	local d = v - self.Position
	return newVector3(d:Dot(self.RightVector), d:Dot(self.UpVector), d:Dot(self._back))
end

function CFrameLib.VectorToWorldSpace(self: any, v: Vector3Stub): Vector3Stub
	return self.RightVector * v.X + self.UpVector * v.Y + self._back * v.Z
end

function CFrameLib.VectorToObjectSpace(self: any, v: Vector3Stub): Vector3Stub
	return newVector3(v:Dot(self.RightVector), v:Dot(self.UpVector), v:Dot(self._back))
end

cframeMeta.__index = CFrameLib

function cframeMeta.__mul(a: any, b: any): any
	if getmetatable(b) == vector3Meta then
		return a:PointToWorldSpace(b)
	end
	local pos = a:PointToWorldSpace(b.Position)
	local right = a:VectorToWorldSpace(b.RightVector)
	local up = a:VectorToWorldSpace(b.UpVector)
	local back = a:VectorToWorldSpace(b._back)
	return newCFrameFromMatrix(pos, right, up, back)
end

function cframeMeta.__add(a: any, b: Vector3Stub): CFrameStub
	return newCFrameFromMatrix(a.Position + b, a.RightVector, a.UpVector, a._back)
end

function CFrameLib.new(a: any?, b: number?, c: number?): CFrameStub
	if type(a) == "table" and b == nil then
		return newCFrameFromMatrix(a, Vector3Lib.xAxis, Vector3Lib.yAxis, Vector3Lib.zAxis)
	end
	local pos = newVector3(a or 0, b or 0, c or 0)
	return newCFrameFromMatrix(pos, Vector3Lib.xAxis, Vector3Lib.yAxis, Vector3Lib.zAxis)
end

function CFrameLib.fromMatrix(pos: Vector3Stub, vX: Vector3Stub, vY: Vector3Stub, vZ: Vector3Stub?): CFrameStub
	local back = vZ or vX:Cross(vY).Unit
	return newCFrameFromMatrix(pos, vX, vY, back)
end

function CFrameLib.lookAt(at: Vector3Stub, lookAt: Vector3Stub, up: Vector3Stub?): CFrameStub
	local upVec = up or Vector3Lib.yAxis
	local back = (at - lookAt).Unit
	local right = upVec:Cross(back).Unit
	local realUp = back:Cross(right).Unit
	return newCFrameFromMatrix(at, right, realUp, back)
end

function CFrameLib.Angles(rx: number?, ry: number?, rz: number?): CFrameStub
	local ax = rx or 0
	local ay = ry or 0
	local az = rz or 0
	local cx, sx = math.cos(ax), math.sin(ax)
	local cy, sy = math.cos(ay), math.sin(ay)
	local cz, sz = math.cos(az), math.sin(az)

	local rotX =
		newCFrameFromMatrix(Vector3Lib.zero, newVector3(1, 0, 0), newVector3(0, cx, sx), newVector3(0, -sx, cx))
	local rotY =
		newCFrameFromMatrix(Vector3Lib.zero, newVector3(cy, 0, -sy), newVector3(0, 1, 0), newVector3(sy, 0, cy))
	local rotZ =
		newCFrameFromMatrix(Vector3Lib.zero, newVector3(cz, sz, 0), newVector3(-sz, cz, 0), newVector3(0, 0, 1))
	return (rotX * rotY) * rotZ
end

CFrameLib.fromEulerAnglesXYZ = CFrameLib.Angles
CFrameLib.identity = CFrameLib.new(0, 0, 0)

local Vector2Lib = {
	new = function(x: number?, y: number?)
		return { X = x or 0, Y = y or 0 }
	end,
	zero = { X = 0, Y = 0 },
	one = { X = 1, Y = 1 },
}

local Color3Lib = {
	new = function(r: number?, g: number?, b: number?)
		return { R = r or 0, G = g or 0, B = b or 0 }
	end,
	fromRGB = function(r: number?, g: number?, b: number?)
		return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
	end,
	fromHSV = function(h: number?, s: number?, v: number?)
		return { H = h or 0, S = s or 0, V = v or 0 }
	end,
}

local UDimLib = {
	new = function(scale: number?, offset: number?)
		return { Scale = scale or 0, Offset = offset or 0 }
	end,
}

local UDim2Lib = {
	new = function(sx: number?, ox: number?, sy: number?, oy: number?)
		return {
			X = { Scale = sx or 0, Offset = ox or 0 },
			Y = { Scale = sy or 0, Offset = oy or 0 },
		}
	end,
	fromScale = function(sx: number?, sy: number?)
		return {
			X = { Scale = sx or 0, Offset = 0 },
			Y = { Scale = sy or 0, Offset = 0 },
		}
	end,
	fromOffset = function(ox: number?, oy: number?)
		return {
			X = { Scale = 0, Offset = ox or 0 },
			Y = { Scale = 0, Offset = oy or 0 },
		}
	end,
}

local ColorSequenceKeypointLib = {
	new = function(time: number, color: any)
		return { Time = time, Value = color }
	end,
}

local ColorSequenceLib = {
	new = function(keypoints: any)
		return { Keypoints = keypoints }
	end,
}

local NumberSequenceKeypointLib = {
	new = function(time: number, value: number, envelope: number?)
		return { Time = time, Value = value, Envelope = envelope or 0 }
	end,
}

local NumberSequenceLib = {
	new = function(keypoints: any)
		return { Keypoints = keypoints }
	end,
}

local EnumStub = setmetatable({}, {
	__index = function(self, enumType: string)
		local category = setmetatable({}, {
			__index = function(cat, item: string)
				local token = { Name = item, EnumType = enumType }
				rawset(cat, item, token)
				return token
			end,
		})
		rawset(self, enumType, category)
		return category
	end,
})

local rawArgs = { ... }
local sourceMap: { [string]: string } = {}
for i = 1, #rawArgs, 2 do
	local key = rawArgs[i]
	local content = rawArgs[i + 1]
	if type(key) == "string" and type(content) == "string" then
		sourceMap[key] = content
	end
end

type Node = {
	Name: string,
	Parent: Node?,
	__moduleKey: string?,
	[string]: any,
}

local function makeFolder(name: string, parent: Node?): Node
	local node: Node = {
		Name = name,
		Parent = parent,
	}
	if parent ~= nil then
		parent[name] = node
	end
	return node
end

local function makeModule(name: string, parent: Node, key: string): Node
	local node: Node = {
		Name = name,
		Parent = parent,
		__moduleKey = key,
	}
	parent[name] = node
	return node
end

local gameStub: any = { Name = "DataModel" }
local ReplicatedStorageStub = makeFolder("ReplicatedStorage", gameStub)
local RepModules = makeFolder("Modules", ReplicatedStorageStub)
local RepConfig = makeFolder("Config", RepModules)
local RepShared = makeFolder("Shared", RepModules)

local ServerStorageStub = makeFolder("ServerStorage", gameStub)
local ServerModules = makeFolder("Modules", ServerStorageStub)
local ServerConfig = makeFolder("Config", ServerModules)

function gameStub:GetService(serviceName: string): any
	if serviceName == "ReplicatedStorage" then
		return ReplicatedStorageStub
	elseif serviceName == "ServerStorage" then
		return ServerStorageStub
	end
	error(string.format("Unsupported service in headless test stub: %s", tostring(serviceName)))
end

local configNames = {}
for key in sourceMap do
	local configName = string.match(key, "^Config%.([A-Za-z0-9_]+)$")
	if configName ~= nil then
		makeModule(configName, RepConfig, key)
		table.insert(configNames, configName)
	end
	local sharedName = string.match(key, "^Shared%.([A-Za-z0-9_]+)$")
	if sharedName ~= nil then
		makeModule(sharedName, RepShared, key)
	end
	local serverConfigName = string.match(key, "^ServerConfig%.([A-Za-z0-9_]+)$")
	if serverConfigName ~= nil then
		makeModule(serverConfigName, ServerConfig, key)
	end
end
table.sort(configNames)

local loadedModules: { [string]: any } = {}
local baseEnv = getfenv(0)

local function robloxRequire(target: any): any
	local key: string? = nil
	local scriptNode: any = nil
	if type(target) == "table" and type(target.__moduleKey) == "string" then
		key = target.__moduleKey
		scriptNode = target
	elseif type(target) == "string" then
		key = target
	else
		error(string.format("Invalid require target: %s", tostring(target)))
	end

	local resolvedKey = key :: string
	if loadedModules[resolvedKey] ~= nil then
		return loadedModules[resolvedKey]
	end

	local source = sourceMap[resolvedKey]
	assert(type(source) == "string", string.format("Missing module source for %s", resolvedKey))

	local chunk, compileErr = (loadstring :: any)(source, "@" .. resolvedKey)
	assert(chunk ~= nil, string.format("Compile error in %s: %s", resolvedKey, tostring(compileErr)))

	local env = setmetatable({
		game = gameStub,
		script = scriptNode,
		require = robloxRequire,
		Vector3 = Vector3Lib,
		Vector2 = Vector2Lib,
		CFrame = CFrameLib,
		Color3 = Color3Lib,
		UDim = UDimLib,
		UDim2 = UDim2Lib,
		ColorSequence = ColorSequenceLib,
		ColorSequenceKeypoint = ColorSequenceKeypointLib,
		NumberSequence = NumberSequenceLib,
		NumberSequenceKeypoint = NumberSequenceKeypointLib,
		Enum = EnumStub,
	}, { __index = baseEnv })

	setfenv(chunk, env)
	local result = chunk()
	loadedModules[resolvedKey] = result
	return result
end

local totalTests = 0
local passedTests = 0
local failures: { string } = {}

local function runTest(name: string, fn: () -> ())
	totalTests += 1
	local ok, err = pcall(fn)
	if ok then
		passedTests += 1
	else
		local msg = string.format("FAIL [%s]: %s", name, tostring(err))
		table.insert(failures, msg)
		print(msg)
	end
end

local function expect(cond: boolean, message: string?)
	if not cond then
		error(message or "Assertion failed", 2)
	end
end

local function expectNear(actual: number, expected: number, eps: number?, label: string?)
	local tol = eps or 1e-6
	if math.abs(actual - expected) > tol or actual ~= actual then
		error(
			string.format(
				"%s: expected %.8f, got %.8f (diff %.8g)",
				label or "Number mismatch",
				expected,
				actual,
				math.abs(actual - expected)
			),
			2
		)
	end
end

local function expectVec3Near(actual: Vector3Stub, expected: Vector3Stub, eps: number?, label: string?)
	local tol = eps or 1e-5
	local dx = math.abs(actual.X - expected.X)
	local dy = math.abs(actual.Y - expected.Y)
	local dz = math.abs(actual.Z - expected.Z)
	if dx > tol or dy > tol or dz > tol or actual.X ~= actual.X or actual.Y ~= actual.Y or actual.Z ~= actual.Z then
		error(
			string.format("%s: expected %s, got %s", label or "Vector3 mismatch", tostring(expected), tostring(actual)),
			2
		)
	end
end

local function checkNoNanOrInf(value: any, path: string, visited: { [any]: boolean })
	local valueType = type(value)
	if valueType == "number" then
		expect(value == value, string.format("NaN found at %s", path))
		expect(math.abs(value) < math.huge, string.format("Infinite number found at %s", path))
	elseif valueType == "table" then
		if visited[value] then
			return
		end
		visited[value] = true
		for k, v in value do
			expect(k == k, string.format("NaN key in %s", path))
			checkNoNanOrInf(v, string.format("%s.%s", path, tostring(k)), visited)
		end
	end
end

for _, configName in configNames do
	runTest("ConfigLoad_NoNaN_" .. configName, function()
		local mod = robloxRequire(RepConfig[configName])
		expect(type(mod) == "table", configName .. " must return a table")
		expect(next(mod) ~= nil, configName .. " table must not be empty")
		checkNoNanOrInf(mod, configName, {})
	end)
end

runTest("ConfigLoad_NoNaN_DataConfig", function()
	local dataConfig = robloxRequire(ServerConfig.DataConfig)
	expect(type(dataConfig) == "table", "DataConfig must return a table")
	expect(type(dataConfig.Template) == "table", "DataConfig.Template must be a table")
	checkNoNanOrInf(dataConfig, "DataConfig", {})
end)

local ConfigLookup = robloxRequire(RepShared.ConfigLookup)
local Hitbox = robloxRequire(RepShared.Hitbox)
local CharacterConfig = robloxRequire(RepConfig.CharacterConfig)
local CosmeticConfig = robloxRequire(RepConfig.CosmeticConfig)
local DailyRewardConfig = robloxRequire(RepConfig.DailyRewardConfig)
local GameConfig = robloxRequire(RepConfig.GameConfig)
local MapConfig = robloxRequire(RepConfig.MapConfig)
local MessageConfig = robloxRequire(RepConfig.MessageConfig)
local ModeConfig = robloxRequire(RepConfig.ModeConfig)
local MonetizationConfig = robloxRequire(RepConfig.MonetizationConfig)
local ObjectConfig = robloxRequire(RepConfig.ObjectConfig)
local PetConfig = robloxRequire(RepConfig.PetConfig)
local PotionConfig = robloxRequire(RepConfig.PotionConfig)
local PowerupConfig = robloxRequire(RepConfig.PowerupConfig)
local QuestConfig = robloxRequire(RepConfig.QuestConfig)
local RebirthConfig = robloxRequire(RepConfig.RebirthConfig)
local RoomConfig = robloxRequire(RepConfig.RoomConfig)
local RunConfig = robloxRequire(RepConfig.RunConfig)
local RunUIConfig = robloxRequire(RepConfig.RunUIConfig)
local LobbyUIConfig = robloxRequire(RepConfig.LobbyUIConfig)
local UIConfig = robloxRequire(RepConfig.UIConfig)
local UpgradeConfig = robloxRequire(RepConfig.UpgradeConfig)
local DataConfig = robloxRequire(ServerConfig.DataConfig)

runTest("ConfigLookup_GetUpgradeCost_And_Value", function()
	local ids = ConfigLookup.GetSortedUpgradeIds()
	expect(#ids > 0, "Upgrade list must not be empty")
	local prevOrder = -math.huge
	for _, id in ids do
		local def = ConfigLookup.GetUpgrade(id)
		expect(def ~= nil, "Missing upgrade definition for " .. id)
		expect(def.Order > prevOrder, "GetSortedUpgradeIds must sort by ascending Order")
		prevOrder = def.Order

		for level = 0, def.MaxLevel do
			local cost = ConfigLookup.GetUpgradeCost(id, level)
			local expectedCost = math.floor(def.CostBase * def.CostGrowth ^ level)
			expect(cost == expectedCost, string.format("Cost mismatch for %s at level %d", id, level))
			expect(cost > 0 and cost == cost, "Upgrade cost must be positive finite integer")
			if level > 0 then
				local prevCost = ConfigLookup.GetUpgradeCost(id, level - 1)
				expect(cost >= prevCost, "Upgrade cost must be non-decreasing with level")
			end

			local val = ConfigLookup.GetUpgradeValue(id, level)
			local expectedVal = def.Base + def.PerLevel * level
			expectNear(val, expectedVal, 1e-9, string.format("Value mismatch for %s at level %d", id, level))

			local formatted = ConfigLookup.FormatUpgradeValue(id, val)
			expect(type(formatted) == "string" and #formatted > 0, "FormatUpgradeValue must return non-empty string")
			expect(string.find(formatted, "%%s") == nil, "FormatUpgradeValue must replace %s placeholder")
		end
	end

	expectNear(ConfigLookup.GetUpgradeCost("Lifespan", 0), 25, 0, "Lifespan level 0 cost")
	expectNear(ConfigLookup.GetUpgradeCost("Lifespan", 1), math.floor(25 * 1.45), 0, "Lifespan level 1 cost")
	expectNear(ConfigLookup.GetUpgradeValue("Lifespan", 0), 30, 1e-9, "Lifespan level 0 value")
	expectNear(ConfigLookup.GetUpgradeValue("Lifespan", 5), 45, 1e-9, "Lifespan level 5 value")
	expectNear(ConfigLookup.GetUpgradeValue("Speed", 4), 20, 1e-9, "Speed level 4 value")
	expectNear(ConfigLookup.GetUpgradeValue("StainSize", 3), 5.5, 1e-9, "StainSize level 3 value")

	local okCost = pcall(function()
		ConfigLookup.GetUpgradeCost("NonExistentUpgrade", 1)
	end)
	expect(not okCost, "GetUpgradeCost should assert on unknown upgrade id")

	local okVal = pcall(function()
		ConfigLookup.GetUpgradeValue("NonExistentUpgrade", 1)
	end)
	expect(not okVal, "GetUpgradeValue should assert on unknown upgrade id")
end)

runTest("ConfigLookup_GetLevelXp", function()
	expectNear(ConfigLookup.GetLevelXp(0), GameConfig.LevelXpBase, 0, "Level 0 clamps to level 1 XP")
	expectNear(ConfigLookup.GetLevelXp(-5), GameConfig.LevelXpBase, 0, "Negative level clamps to level 1 XP")
	expectNear(ConfigLookup.GetLevelXp(1), GameConfig.LevelXpBase, 0, "Level 1 XP equals LevelXpBase")
	expectNear(
		ConfigLookup.GetLevelXp(2),
		math.floor(GameConfig.LevelXpBase * GameConfig.LevelXpGrowth),
		0,
		"Level 2 XP"
	)

	local prevXp = ConfigLookup.GetLevelXp(1)
	for level = 2, GameConfig.MaxLevel do
		local xp = ConfigLookup.GetLevelXp(level)
		local expected = math.floor(GameConfig.LevelXpBase * GameConfig.LevelXpGrowth ^ (level - 1))
		expect(xp == expected, string.format("GetLevelXp(%d) formula mismatch", level))
		expect(xp > prevXp, string.format("GetLevelXp(%d) must strictly increase", level))
		prevXp = xp
	end
end)

runTest("ConfigLookup_RebirthCost_And_Multiplier", function()
	expectNear(ConfigLookup.GetRebirthCost(0), RebirthConfig.BaseCost, 0, "Rebirth 0 cost")
	expectNear(
		ConfigLookup.GetRebirthCost(1),
		math.floor(RebirthConfig.BaseCost * RebirthConfig.CostGrowth),
		0,
		"Rebirth 1 cost"
	)
	expectNear(ConfigLookup.GetRebirthMultiplier(0), 1.0, 1e-9, "Rebirth 0 multiplier")
	expectNear(
		ConfigLookup.GetRebirthMultiplier(1),
		1 + RebirthConfig.MultiplierPerRebirth,
		1e-9,
		"Rebirth 1 multiplier"
	)
	expectNear(ConfigLookup.GetRebirthMultiplier(4), 2.0, 1e-9, "Rebirth 4 multiplier")

	local prevCost = ConfigLookup.GetRebirthCost(0)
	local prevMult = ConfigLookup.GetRebirthMultiplier(0)
	for r = 1, 15 do
		local cost = ConfigLookup.GetRebirthCost(r)
		local mult = ConfigLookup.GetRebirthMultiplier(r)
		expect(cost > prevCost, "Rebirth cost must strictly grow")
		expect(mult > prevMult, "Rebirth multiplier must strictly grow")
		prevCost = cost
		prevMult = mult
	end
end)

runTest("ConfigLookup_GetMapCellCount_And_ProgressPercent", function()
	local cellSize = GameConfig.StainCellSize
	expect(cellSize > 0, "StainCellSize must be positive")

	expectNear(ConfigLookup.GetMapCellCount(Vector3Lib.new(30, 1, 30)), 100, 0, "30x30 footprint at cellSize=3")
	expectNear(ConfigLookup.GetMapCellCount(Vector3Lib.new(90, 5, 60)), 600, 0, "90x60 footprint at cellSize=3")
	expectNear(
		ConfigLookup.GetMapCellCount(Vector3Lib.new(0.1, 1, 0.1)),
		1,
		0,
		"Tiny footprint clamps to at least 1 cell"
	)
	expectNear(ConfigLookup.GetMapCellCount(Vector3Lib.new(0, 0, 0)), 1, 0, "Zero footprint clamps to at least 1 cell")

	expectNear(ConfigLookup.GetMapProgressPercent(0, 100), 0, 1e-9, "0 stained")
	expectNear(ConfigLookup.GetMapProgressPercent(25, 100), 25, 1e-9, "25% stained")
	expectNear(ConfigLookup.GetMapProgressPercent(100, 100), 100, 1e-9, "100% stained")
	expectNear(ConfigLookup.GetMapProgressPercent(150, 100), 100, 1e-9, "Overflow clamped to 100%")
	expectNear(ConfigLookup.GetMapProgressPercent(-10, 100), 0, 1e-9, "Negative stained clamped to 0%")
	expectNear(ConfigLookup.GetMapProgressPercent(10, 0), 0, 1e-9, "Zero total returns 0%")
	expectNear(ConfigLookup.GetMapProgressPercent(10, -5), 0, 1e-9, "Negative total returns 0%")
end)

runTest("ConfigLookup_GetPreviousMap_Chain", function()
	local sorted = ConfigLookup.GetSortedMaps()
	expect(#sorted >= 4, "Expected at least 4 maps")
	expect(ConfigLookup.GetPreviousMap(sorted[1].Id) == nil, "First map in chain must have no previous map")

	for i = 2, #sorted do
		local prev = ConfigLookup.GetPreviousMap(sorted[i].Id)
		expect(prev ~= nil, string.format("Map %s should have a previous map", sorted[i].Id))
		expect(
			(prev :: any).Id == sorted[i - 1].Id,
			string.format("Previous map of %s should be %s", sorted[i].Id, sorted[i - 1].Id)
		)
	end

	expect(ConfigLookup.GetPreviousMap("UnknownMapId") == nil, "Unknown map id must return nil")
end)

runTest("ConfigLookup_RollPet_Boundaries", function()
	for _, egg in ConfigLookup.GetSortedEggs() do
		local pets = ConfigLookup.GetPetsForEgg(egg.Id)
		expect(#pets > 0, "Egg must have at least one pet: " .. egg.Id)
		local totalWeight = ConfigLookup.GetEggWeight(egg.Id)
		expect(totalWeight > 0, "Egg total weight must be positive: " .. egg.Id)

		local petAtZero = ConfigLookup.RollPet(egg.Id, 0)
		local petAtNeg = ConfigLookup.RollPet(egg.Id, -1)
		local petAtOne = ConfigLookup.RollPet(egg.Id, 1)
		local petAtOver = ConfigLookup.RollPet(egg.Id, 2)

		expect(petAtZero ~= nil and petAtZero.Id == pets[1].Id, "RollPet at 0 must pick first pet in " .. egg.Id)
		expect(petAtNeg ~= nil and petAtNeg.Id == pets[1].Id, "RollPet at <0 must clamp and pick first pet")
		expect(petAtOne ~= nil and petAtOne.Id == pets[#pets].Id, "RollPet at 1 must pick last pet in " .. egg.Id)
		expect(petAtOver ~= nil and petAtOver.Id == pets[#pets].Id, "RollPet at >1 must clamp and pick last pet")

		local cursor = 0
		for idx, pet in pets do
			local rarity = ConfigLookup.GetRarity(pet.Rarity)
			expect(rarity ~= nil, "Missing rarity for pet " .. pet.Id)
			local weight = (rarity :: any).Weight
			local midRoll = (cursor + weight * 0.5) / totalWeight
			local rolledMid = ConfigLookup.RollPet(egg.Id, midRoll)
			expect(
				rolledMid ~= nil and rolledMid.Id == pet.Id,
				string.format("Mid-band roll for %s in %s picked wrong pet", pet.Id, egg.Id)
			)

			local exactBoundaryRoll = cursor / totalWeight
			local rolledAtStart = ConfigLookup.RollPet(egg.Id, exactBoundaryRoll + 1e-12)
			expect(
				rolledAtStart ~= nil and rolledAtStart.Id == pet.Id,
				string.format("Just-above-boundary roll for %s in %s failed", pet.Id, egg.Id)
			)
			if idx > 1 then
				local rolledJustBefore = ConfigLookup.RollPet(egg.Id, exactBoundaryRoll - 1e-12)
				expect(
					rolledJustBefore ~= nil and rolledJustBefore.Id == pets[idx - 1].Id,
					string.format("Just-below-boundary roll before %s in %s failed", pet.Id, egg.Id)
				)
			end
			cursor += weight
		end
	end

	expect(ConfigLookup.RollPet("NonExistentEgg", 0.5) == nil, "RollPet for unknown egg must return nil")
end)

runTest("ConfigLookup_RollVariant_Boundaries", function()
	local vZero = ConfigLookup.RollVariant(0)
	local vNeg = ConfigLookup.RollVariant(-0.5)
	local vOne = ConfigLookup.RollVariant(1)
	local vOver = ConfigLookup.RollVariant(1.5)
	expect(vZero ~= nil and vZero.Id ~= nil, "RollVariant(0) must return a valid variant")
	expect(vNeg ~= nil and vNeg.Id == (vZero :: any).Id, "RollVariant(<0) must match RollVariant(0)")
	expect(vOne ~= nil and vOne.Id ~= nil, "RollVariant(1) must return a valid variant")
	expect(vOver ~= nil and vOver.Id == (vOne :: any).Id, "RollVariant(>1) must match RollVariant(1)")

	local total = 0
	local order: { any } = {}
	for _, variant in PetConfig.Variants do
		total += variant.Weight
		table.insert(order, variant)
	end
	expect(total > 0, "Total variant weight must be positive")

	local cursor = 0
	for idx, variant in order do
		local midRoll = (cursor + variant.Weight * 0.5) / total
		local picked = ConfigLookup.RollVariant(midRoll)
		expect(picked ~= nil and picked.Id == variant.Id, "RollVariant mid-band mismatch for " .. variant.Id)

		if idx > 1 then
			local boundary = cursor / total
			local below = ConfigLookup.RollVariant(boundary - 1e-12)
			local above = ConfigLookup.RollVariant(boundary + 1e-12)
			expect(below ~= nil and below.Id == order[idx - 1].Id, "RollVariant below boundary mismatch")
			expect(above ~= nil and above.Id == variant.Id, "RollVariant above boundary mismatch")
		end
		cursor += variant.Weight
	end
end)

runTest("ConfigLookup_AllOtherAccessors", function()
	for _, map in ConfigLookup.GetSortedMaps() do
		expect(ConfigLookup.GetMap(map.Id) == map, "GetMap round-trip for " .. map.Id)
	end
	expect(ConfigLookup.GetMap("NoSuchMap") == nil, "GetMap unknown returns nil")
	expect(#ConfigLookup.GetEnabledMaps() > 0, "At least one map must be enabled")

	for _, mode in ConfigLookup.GetSortedModes() do
		expect(ConfigLookup.GetMode(mode.Id) == mode, "GetMode round-trip for " .. mode.Id)
	end
	expect(ConfigLookup.GetMode("NoSuchMode") == nil, "GetMode unknown returns nil")

	for _, quest in QuestConfig.Quests do
		expect(ConfigLookup.GetQuest(quest.Id) == quest, "GetQuest round-trip for " .. quest.Id)
		local text = ConfigLookup.FormatQuest(quest)
		expect(string.find(text, tostring(quest.Target), 1, true) ~= nil, "FormatQuest must include target count")
	end

	for day = 1, DailyRewardConfig.StreakLength do
		expect(ConfigLookup.GetDailyReward(day) ~= nil, "Missing DailyReward for day " .. tostring(day))
	end
	expect(ConfigLookup.GetDailyReward(0) == nil, "Day 0 reward should be nil")
	expect(ConfigLookup.GetDailyBoost("Coins") ~= nil, "Coins daily boost must exist")

	expect(ConfigLookup.GetPass("DoubleCoins") ~= nil, "DoubleCoins pass must exist")
	expect(ConfigLookup.GetDevProduct(0) == nil, "ProductId 0 must return nil")
	expect(ConfigLookup.GetReviveTier(1) ~= nil, "Revive tier 1 must exist")
	expect(type(ConfigLookup.IsReviveAvailable()) == "boolean", "IsReviveAvailable must return boolean")

	local potionIds = ConfigLookup.GetSortedPotionIds()
	expect(#potionIds == 3, "Expected 3 potions")
	for _, pid in potionIds do
		expect(ConfigLookup.GetPotion(pid) ~= nil, "GetPotion round-trip for " .. pid)
	end

	expect(ConfigLookup.GetSkin("Default") ~= nil, "Default skin must exist")
	expect(ConfigLookup.GetTrail("Neon") ~= nil, "Neon trail must exist")
	expect(ConfigLookup.GetCrate("StandardCrate") ~= nil, "StandardCrate must exist")

	for _, pet in ConfigLookup.GetSortedPets() do
		expect(ConfigLookup.GetPet(pet.Id) == pet, "GetPet round-trip for " .. pet.Id)
		local mult = ConfigLookup.GetPetMultipliers(pet.Id, "Default")
		expectNear(mult.Coins, pet.CoinMultiplier, 1e-9, "Default variant coin multiplier")
		expectNear(mult.Stink, pet.StinkMultiplier, 1e-9, "Default variant stink multiplier")
		local goldMult = ConfigLookup.GetPetMultipliers(pet.Id, "Golden")
		expectNear(goldMult.Coins, pet.CoinMultiplier * 1.25, 1e-9, "Golden variant coin multiplier")
	end
	local unknownMult = ConfigLookup.GetPetMultipliers("UnknownPet", "Default")
	expectNear(unknownMult.Coins, 1, 1e-9, "Unknown pet neutral coin multiplier")
	expectNear(unknownMult.Stink, 1, 1e-9, "Unknown pet neutral stink multiplier")

	expect(ConfigLookup.GetNextVariant("Default") == "Golden", "Default -> Golden")
	expect(ConfigLookup.GetNextVariant("Golden") == "Rainbow", "Golden -> Rainbow")
	expect(ConfigLookup.GetNextVariant("Rainbow") == nil, "Rainbow is terminal")
	expect(ConfigLookup.GetNextVariant("Unknown") == nil, "Unknown variant returns nil")

	expectNear(ConfigLookup.GetMaxEquippedSlots(0), PetConfig.BaseSlots, 0, "Base slots at 0 extra")
	expectNear(ConfigLookup.GetMaxEquippedSlots(3), PetConfig.BaseSlots + 3, 0, "Base slots + 3 extra")
	expectNear(ConfigLookup.GetMaxEquippedSlots(-2), PetConfig.BaseSlots, 0, "Negative extra slots clamped")
end)

runTest("Hitbox_Center_And_Reach_Scale1_And_Scale2", function()
	local offset = CharacterConfig.HitboxOffset
	local radius = CharacterConfig.HitboxRadius

	local root1 = CFrameLib.new(10, 20, 30)
	expectVec3Near(
		Hitbox.Center(root1, 1),
		newVector3(10 + offset.X, 20 + offset.Y, 30 + offset.Z),
		1e-6,
		"Center scale 1"
	)
	expectVec3Near(
		Hitbox.Center(root1, 2),
		newVector3(10 + offset.X * 2, 20 + offset.Y * 2, 30 + offset.Z * 2),
		1e-6,
		"Center scale 2"
	)

	expectNear(Hitbox.Reach(1), radius, 1e-9, "Reach scale 1")
	expectNear(Hitbox.Reach(2), radius * 2, 1e-9, "Reach scale 2")
end)

runTest("Hitbox_ClosestPoint_Scale1_And_Scale2_Head_Tail_Side_Beyond", function()
	for _, scale in { 1, 2 } do
		local root = CFrameLib.new(100, 5, -50)
		local center = Hitbox.Center(root, scale)
		local look = root.LookVector
		local right = root.RightVector
		local up = root.UpVector
		local halfLen = CharacterConfig.HitboxHalfLength * scale
		local headEnd = center + look * halfLen
		local tailEnd = center - look * halfLen

		expectVec3Near(Hitbox.ClosestPoint(root, scale, center), center, 1e-6, "ClosestPoint at center")
		expectVec3Near(Hitbox.ClosestPoint(root, scale, headEnd), headEnd, 1e-6, "ClosestPoint at head")
		expectVec3Near(Hitbox.ClosestPoint(root, scale, tailEnd), tailEnd, 1e-6, "ClosestPoint at tail")

		local beyondHead = center + look * (halfLen + 15) + right * 4
		expectVec3Near(
			Hitbox.ClosestPoint(root, scale, beyondHead),
			headEnd,
			1e-6,
			"ClosestPoint beyond head clamps to head"
		)

		local beyondTail = center - look * (halfLen + 25) - right * 7
		expectVec3Near(
			Hitbox.ClosestPoint(root, scale, beyondTail),
			tailEnd,
			1e-6,
			"ClosestPoint beyond tail clamps to tail"
		)

		local sideMid = center + right * 12 + up * 3
		expectVec3Near(Hitbox.ClosestPoint(root, scale, sideMid), center, 1e-6, "ClosestPoint directly to the side")

		local quarterForward = center + look * (halfLen * 0.5)
		local sideQuarter = quarterForward - right * 9 + up * 6
		expectVec3Near(
			Hitbox.ClosestPoint(root, scale, sideQuarter),
			quarterForward,
			1e-6,
			"ClosestPoint off to side at +0.5*halfLength"
		)
	end
end)

runTest("Hitbox_RotatedRoots_Yaw_WallPitch_Arbitrary3D", function()
	local rotations = {
		CFrameLib.new(50, 10, -20) * CFrameLib.Angles(0, math.pi * 0.5, 0),
		CFrameLib.new(-30, 40, 15) * CFrameLib.Angles(math.pi * 0.5, 0, 0),
		CFrameLib.new(12, -8, 77) * CFrameLib.Angles(0.6, -1.1, 0.4),
	}

	for idx, root in rotations do
		for _, scale in { 1, 2 } do
			local center = Hitbox.Center(root, scale)
			local expectedCenter = root:PointToWorldSpace(CharacterConfig.HitboxOffset * scale)
			expectVec3Near(center, expectedCenter, 1e-5, string.format("Rotated root #%d center scale %d", idx, scale))

			local look = root.LookVector
			local right = root.RightVector
			local up = root.UpVector
			local halfLen = CharacterConfig.HitboxHalfLength * scale
			local headEnd = center + look * halfLen
			local tailEnd = center - look * halfLen

			expectVec3Near(
				Hitbox.ClosestPoint(root, scale, center + look * (halfLen + 50) + right * 10),
				headEnd,
				1e-5,
				string.format("Rotated root #%d beyond head scale %d", idx, scale)
			)
			expectVec3Near(
				Hitbox.ClosestPoint(root, scale, center - look * (halfLen + 50) - up * 8),
				tailEnd,
				1e-5,
				string.format("Rotated root #%d beyond tail scale %d", idx, scale)
			)
			local t = -0.35 * halfLen
			local onAxis = center + look * t
			local offSide = onAxis + right * 14 - up * 5
			expectVec3Near(
				Hitbox.ClosestPoint(root, scale, offSide),
				onAxis,
				1e-5,
				string.format("Rotated root #%d side projection scale %d", idx, scale)
			)
		end
	end
end)

runTest("ConfigIntegrity_PetEggs_Pets_Rarities_Variants", function()
	for rarityId, rarity in PetConfig.Rarities do
		expect(rarity.Id == rarityId, "Rarity key/Id mismatch: " .. tostring(rarityId))
		expect(rarity.Weight > 0, "Rarity weight must be positive: " .. tostring(rarityId))
	end

	for variantId, variant in PetConfig.Variants do
		expect(variant.Id == variantId, "Variant key/Id mismatch: " .. tostring(variantId))
		expect(variant.Weight > 0, "Variant weight must be positive: " .. tostring(variantId))
		expect(variant.Bonus > 0, "Variant bonus must be positive: " .. tostring(variantId))
		if variant.NextVariant ~= nil then
			expect(
				PetConfig.Variants[variant.NextVariant] ~= nil,
				string.format("Variant %s NextVariant %s does not exist", variantId, tostring(variant.NextVariant))
			)
			expect(variant.NextVariant ~= variantId, "Variant cannot merge into itself: " .. variantId)
		end
	end
	expect(PetConfig.Variants[PetConfig.GrantVariant] ~= nil, "PetConfig.GrantVariant must exist in Variants")

	for eggId, egg in PetConfig.Eggs do
		expect(egg.Id == eggId, "Egg key/Id mismatch: " .. tostring(eggId))
		expect(
			ConfigLookup.GetMap(egg.MapId) ~= nil,
			string.format("Egg %s MapId %s does not exist in MapConfig", eggId, egg.MapId)
		)
		expect(egg.Price > 0, "Egg price must be positive: " .. eggId)
		expect(#ConfigLookup.GetPetsForEgg(eggId) > 0, "Egg has no pets: " .. eggId)
	end

	local seenPetIds: { [string]: boolean } = {}
	for _, pet in PetConfig.Pets do
		expect(not seenPetIds[pet.Id], "Duplicate pet Id: " .. pet.Id)
		seenPetIds[pet.Id] = true
		expect(
			PetConfig.Rarities[pet.Rarity] ~= nil,
			string.format("Pet %s references invalid rarity %s", pet.Id, pet.Rarity)
		)
		if pet.EggId ~= "" then
			expect(
				PetConfig.Eggs[pet.EggId] ~= nil,
				string.format("Pet %s references invalid EggId %s", pet.Id, pet.EggId)
			)
		end
		expect(pet.CoinMultiplier > 0 and pet.StinkMultiplier > 0, "Pet multipliers must be positive: " .. pet.Id)
	end

	local newbie = MonetizationConfig.DevProducts.NewbiePack
	expect(ConfigLookup.GetPet(newbie.PetId) ~= nil, "NewbiePack PetId must exist in PetConfig.Pets")
	expect(ConfigLookup.GetVariant(newbie.PetVariant) ~= nil, "NewbiePack PetVariant must exist in PetConfig.Variants")
end)

runTest("ConfigIntegrity_Maps_And_NpcPatrols", function()
	expect(ConfigLookup.GetMap(MapConfig.DefaultMapId) ~= nil, "DefaultMapId must exist in MapConfig.Maps")
	expect(ConfigLookup.GetMode(ModeConfig.DefaultModeId) ~= nil, "DefaultModeId must exist in ModeConfig.Modes")

	local seenIds: { [string]: boolean } = {}
	local seenOrders: { [number]: boolean } = {}
	for _, map in MapConfig.Maps do
		expect(not seenIds[map.Id], "Duplicate Map Id: " .. map.Id)
		expect(not seenOrders[map.Order], "Duplicate Map Order: " .. tostring(map.Order))
		seenIds[map.Id] = true
		seenOrders[map.Order] = true

		local patrols = RunConfig.NpcPatrols[map.Id]
		expect(type(patrols) == "table" and #patrols > 0, "Map missing NpcPatrols entries: " .. map.Id)
		for _, patrol in patrols do
			expect(type(patrol.name) == "string" and #patrol.name > 0, "Patrol missing name in " .. map.Id)
			expect(patrol.speed > 0, string.format("Patrol %s in %s must have speed > 0", patrol.name, map.Id))
			local dist = (patrol.endPos - patrol.startPos).Magnitude
			expect(dist > 0, string.format("Patrol %s in %s must have non-zero path length", patrol.name, map.Id))
		end
	end
end)

runTest("ConfigIntegrity_RoomConfig", function()
	expect(
		type(RoomConfig.PlayerOptions) == "table" and #RoomConfig.PlayerOptions > 0,
		"RoomConfig.PlayerOptions must be non-empty"
	)
	local foundDefault = false
	local prev = 0
	for _, opt in RoomConfig.PlayerOptions do
		expect(
			type(opt) == "number" and opt > prev and math.floor(opt) == opt,
			"PlayerOptions must be strictly increasing positive integers"
		)
		if opt == RoomConfig.DefaultMaxPlayers then
			foundDefault = true
		end
		prev = opt
	end
	expect(foundDefault, "RoomConfig.DefaultMaxPlayers must be present in RoomConfig.PlayerOptions")
	expect(
		RoomConfig.SlotColumns > 0 and RoomConfig.MaxRooms > 0 and RoomConfig.SlotSpacing > 0,
		"RoomConfig slot geometry must be positive"
	)
end)

runTest("ConfigIntegrity_Potions_Quests_Powerups_Cosmetics_DataTemplate", function()
	local validPotionStats = { Lifespan = true, Speed = true, StainSize = true }
	for potionId, potion in PotionConfig.Potions do
		expect(
			validPotionStats[potion.Stat] == true,
			string.format("Potion %s has invalid Stat %s", potionId, tostring(potion.Stat))
		)
		expect(
			potion.Duration > 0 and potion.Multiplier > 0,
			"Potion Duration and Multiplier must be positive: " .. potionId
		)
	end
	for potionId in DataConfig.Template.PotionInventory do
		expect(
			PotionConfig.Potions[potionId] ~= nil,
			"DataConfig.Template.PotionInventory references unknown potion: " .. tostring(potionId)
		)
	end

	local validQuestKinds = { Score = true, SoilAny = true, SoilType = true, Powerups = true, Cells = true }
	local maxMapOrder = #MapConfig.Maps
	local seenQuestIds: { [string]: boolean } = {}
	for _, quest in QuestConfig.Quests do
		expect(not seenQuestIds[quest.Id], "Duplicate quest Id: " .. quest.Id)
		seenQuestIds[quest.Id] = true
		expect(validQuestKinds[quest.Kind] == true, "Invalid quest Kind: " .. tostring(quest.Kind))
		expect(quest.Target > 0, "Quest target must be positive: " .. quest.Id)
		expect(quest.Weight > 0, "Quest weight must be positive: " .. quest.Id)
		expect(
			quest.MinMapOrder >= 1 and quest.MinMapOrder <= maxMapOrder,
			"Quest MinMapOrder out of range: " .. quest.Id
		)
		if quest.Kind == "SoilType" then
			expect(
				ObjectConfig.Objects[quest.ObjectType] ~= nil,
				string.format(
					"SoilType quest %s references unknown ObjectType %s",
					quest.Id,
					tostring(quest.ObjectType)
				)
			)
		else
			expect(
				quest.ObjectType == "",
				string.format("Non-SoilType quest %s should have empty ObjectType", quest.Id)
			)
		end
	end

	for powerupId, powerup in PowerupConfig.Powerups do
		expect(powerup.Weight > 0, "Powerup weight must be positive: " .. tostring(powerupId))
		expect(
			powerup.CharacterScale > 0 and powerup.CharacterScale <= PowerupConfig.MaxCharacterScale,
			"Powerup scale out of bounds: " .. tostring(powerupId)
		)
	end

	for crateId, crate in CosmeticConfig.Crates do
		expect(crate.Cost > 0, "Crate cost must be positive: " .. tostring(crateId))
		expect(#crate.Drops > 0, "Crate drops must not be empty: " .. tostring(crateId))
		for _, drop in crate.Drops do
			expect(drop.Weight > 0, "Crate drop weight must be positive in " .. tostring(crateId))
			if drop.Kind == "Skin" then
				expect(
					CosmeticConfig.Skins[drop.Id] ~= nil,
					"Crate drop references unknown Skin: " .. tostring(drop.Id)
				)
			elseif drop.Kind == "Trail" then
				expect(
					CosmeticConfig.Trails[drop.Id] ~= nil,
					"Crate drop references unknown Trail: " .. tostring(drop.Id)
				)
			else
				error("Unknown crate drop Kind: " .. tostring(drop.Kind))
			end
		end
	end

	expect(
		#DailyRewardConfig.Days == DailyRewardConfig.StreakLength,
		"DailyRewardConfig.Days count must match StreakLength"
	)
	for idx, day in DailyRewardConfig.Days do
		if day.Kind == "Boost" then
			expect(
				DailyRewardConfig.Boosts[day.BoostId] ~= nil,
				string.format("Daily day %d references unknown BoostId %s", idx, day.BoostId)
			)
		elseif day.Kind == "Skin" then
			expect(
				CosmeticConfig.Skins[day.SkinId] ~= nil,
				string.format("Daily day %d references unknown SkinId %s", idx, day.SkinId)
			)
		end
	end

	for upgradeId in DataConfig.Template.Upgrades do
		expect(
			UpgradeConfig.Upgrades[upgradeId] ~= nil,
			"DataConfig.Template.Upgrades references unknown upgrade: " .. tostring(upgradeId)
		)
	end
	for upgradeId in UpgradeConfig.Upgrades do
		expect(
			DataConfig.Template.Upgrades[upgradeId] ~= nil,
			"UpgradeConfig upgrade missing from DataConfig.Template.Upgrades: " .. tostring(upgradeId)
		)
	end
	for mapId in DataConfig.Template.UnlockedMaps do
		expect(
			ConfigLookup.GetMap(mapId) ~= nil,
			"DataConfig.Template.UnlockedMaps references unknown map: " .. tostring(mapId)
		)
	end
	for skinId in DataConfig.Template.OwnedSkins do
		expect(
			CosmeticConfig.Skins[skinId] ~= nil,
			"DataConfig.Template.OwnedSkins references unknown skin: " .. tostring(skinId)
		)
	end
	expect(
		CosmeticConfig.Skins[DataConfig.Template.EquippedSkin] ~= nil,
		"DataConfig.Template.EquippedSkin must exist in CosmeticConfig.Skins"
	)
end)

runTest("ConfigIntegrity_UI_Swatches_Visuals_And_Rarities", function()
	local swatches = UIConfig.Swatches
	for _, map in MapConfig.Maps do
		local vis = UIConfig.MapVisuals[map.Id]
		expect(vis ~= nil, "UIConfig.MapVisuals missing entry for map " .. map.Id)
		expect(swatches[vis.Swatch] ~= nil, "UIConfig.MapVisuals invalid swatch for map " .. map.Id)
	end
	for _, mode in ModeConfig.Modes do
		local vis = UIConfig.ModeVisuals[mode.Id]
		expect(vis ~= nil, "UIConfig.ModeVisuals missing entry for mode " .. mode.Id)
		expect(swatches[vis.Swatch] ~= nil, "UIConfig.ModeVisuals invalid swatch for mode " .. mode.Id)
	end
	for _, swatchName in UIConfig.UpgradeSwatches do
		expect(swatches[swatchName] ~= nil, "UIConfig.UpgradeSwatches invalid swatch " .. tostring(swatchName))
	end
	expect(swatches[UIConfig.PowerupSwatch] ~= nil, "UIConfig.PowerupSwatch invalid swatch")
	for _, swatchName in UIConfig.ToastSwatches do
		expect(swatches[swatchName] ~= nil, "UIConfig.ToastSwatches invalid swatch " .. tostring(swatchName))
	end
	for _, row in UIConfig.Text.StatRows do
		expect(
			DataConfig.Template.Stats[row.Key] ~= nil,
			"UIConfig.Text.StatRows unknown stat key " .. tostring(row.Key)
		)
	end
	expect(swatches[RunUIConfig.Meter.Swatch] ~= nil, "RunUIConfig.Meter.Swatch invalid")
	expect(swatches[RunUIConfig.Event.Swatch] ~= nil, "RunUIConfig.Event.Swatch invalid")
	expect(swatches[RunUIConfig.Revive.Swatch] ~= nil, "RunUIConfig.Revive.Swatch invalid")

	for rarityId in PetConfig.Rarities do
		expect(LobbyUIConfig.RarityColors[rarityId] ~= nil, "LobbyUIConfig.RarityColors missing rarity " .. rarityId)
	end
	for skinId, skin in CosmeticConfig.Skins do
		expect(
			PetConfig.Rarities[skin.Rarity] ~= nil,
			"Skin " .. skinId .. " references unknown rarity " .. tostring(skin.Rarity)
		)
	end
	for trailId, trail in CosmeticConfig.Trails do
		expect(
			PetConfig.Rarities[trail.Rarity] ~= nil,
			"Trail " .. trailId .. " references unknown rarity " .. tostring(trail.Rarity)
		)
	end
end)

type FakePlayer = {
	UserId: number,
	Name: string,
	DisplayName: string,
	IsFriendsWith: (self: FakePlayer, otherUserId: number) -> boolean,
}

local function newRoomHarness()
	local clockNow = 100
	local delayedTasks: { { due: number, fn: () -> () } } = {}
	local onlinePlayers: { [number]: FakePlayer } = {}
	local friendships: { [number]: { [number]: boolean } } = {}
	local playerData: { [FakePlayer]: { Level: number, UnlockedMaps: { [string]: boolean } } } = {}
	local activeRuns: { [FakePlayer]: { instance: any, modeDef: any } } = {}
	local startRunBehavior: { [FakePlayer]: string } = {}
	local suspendedStarts: { [FakePlayer]: thread } = {}

	local playerRemovingListeners: { (FakePlayer) -> () } = {}
	local runEndedListeners: { (FakePlayer) -> () } = {}

	local acquireCalls = 0
	local releaseCalls = 0
	local releasedInstances: { any } = {}
	local npcSetupCalls = 0
	local npcRemoveCalls = 0
	local nextSlot = 0
	local templateAvailable = true

	local lastRoomState: { [FakePlayer]: any } = {}
	local roomStateCount: { [FakePlayer]: number } = {}
	local lastRoomList: { [FakePlayer]: { any } } = {}
	local notifications: { [FakePlayer]: { { kind: string, text: string } } } = {}
	local invites: { [FakePlayer]: { { roomId: number, hostName: string, mapId: string } } } = {}

	local function makePlayer(
		userId: number,
		name: string,
		level: number?,
		unlockedMaps: { [string]: boolean }?
	): FakePlayer
		local plr: FakePlayer = {
			UserId = userId,
			Name = name,
			DisplayName = name,
			IsFriendsWith = function(self: FakePlayer, otherId: number): boolean
				local row = friendships[self.UserId]
				return row ~= nil and row[otherId] == true
			end,
		}
		onlinePlayers[userId] = plr
		playerData[plr] = {
			Level = level or 50,
			UnlockedMaps = unlockedMaps or { Zone1 = true, Zone2 = true, Zone3 = true, Zone4 = true },
		}
		notifications[plr] = {}
		invites[plr] = {}
		roomStateCount[plr] = 0
		return plr
	end

	local function setFriends(a: FakePlayer, b: FakePlayer, areFriends: boolean)
		friendships[a.UserId] = friendships[a.UserId] or {}
		friendships[b.UserId] = friendships[b.UserId] or {}
		friendships[a.UserId][b.UserId] = areFriends
		friendships[b.UserId][a.UserId] = areFriends
	end

	local function advanceClock(seconds: number)
		local target = clockNow + seconds
		while true do
			local nextIdx: number? = nil
			local earliest = math.huge
			for i, item in delayedTasks do
				if item.due <= target and item.due < earliest then
					earliest = item.due
					nextIdx = i
				end
			end
			if nextIdx == nil then
				break
			end
			local taskItem = table.remove(delayedTasks, nextIdx) :: { due: number, fn: () -> () }
			clockNow = taskItem.due
			taskItem.fn()
		end
		clockNow = target
	end

	local PlayersStub = {
		GetPlayerByUserId = function(_self: any, userId: number): FakePlayer?
			return onlinePlayers[userId]
		end,
		PlayerRemoving = {
			Connect = function(_self: any, fn: (FakePlayer) -> ())
				table.insert(playerRemovingListeners, fn)
				return { Disconnect = function() end }
			end,
		},
	}

	local WorkspaceStub = {
		GetServerTimeNow = function(_self: any): number
			return 1000 + clockNow
		end,
	}

	local DataServiceStub = {
		Get = function(plr: FakePlayer)
			return playerData[plr]
		end,
		IsMapUnlocked = function(plr: FakePlayer, mapId: string): boolean
			local d = playerData[plr]
			return d ~= nil and d.UnlockedMaps[mapId] == true
		end,
	}

	local MapInstanceServiceStub = {
		GetTemplate = function(_mapDef: any)
			return if templateAvailable then { Name = "Template" } else nil
		end,
		Acquire = function(mapDef: any)
			if not templateAvailable then
				return nil
			end
			acquireCalls += 1
			nextSlot += 1
			return {
				model = { Name = mapDef.ModelName .. "_Copy_" .. tostring(nextSlot) },
				mapDef = mapDef,
				offset = Vector3Lib.new(0, 0, nextSlot * 3200),
				slot = nextSlot,
			}
		end,
		Release = function(instance: any)
			releaseCalls += 1
			table.insert(releasedInstances, instance)
		end,
	}

	local NpcServiceStub = {
		SetupInstance = function(_instance: any)
			npcSetupCalls += 1
		end,
		RemoveInstance = function(_model: any)
			npcRemoveCalls += 1
		end,
	}

	local RunEventsStub = {
		RunEnded = {
			Connect = function(_self: any, fn: (FakePlayer) -> ())
				table.insert(runEndedListeners, fn)
				return { Disconnect = function() end }
			end,
			Fire = function(_self: any, plr: FakePlayer)
				for _, fn in runEndedListeners do
					fn(plr)
				end
			end,
		},
	}

	local RunServiceStub: any = nil
	RunServiceStub = {
		IsPlayerInRun = function(plr: FakePlayer): boolean
			return activeRuns[plr] ~= nil
		end,
		StartRun = function(plr: FakePlayer, instance: any, modeDef: any): boolean
			local mode = startRunBehavior[plr] or "ok"
			if mode == "fail" then
				return false
			elseif mode == "yield_ok" or mode == "yield_fail" then
				suspendedStarts[plr] = coroutine.running()
				local resumeResult = coroutine.yield()
				suspendedStarts[plr] = nil
				if resumeResult == false or mode == "yield_fail" then
					return false
				end
			end
			if activeRuns[plr] ~= nil then
				return false
			end
			activeRuns[plr] = { instance = instance, modeDef = modeDef }
			return true
		end,
		EndRun = function(plr: FakePlayer, _outOfTime: boolean)
			if activeRuns[plr] == nil then
				return
			end
			activeRuns[plr] = nil
			RunEventsStub.RunEnded:Fire(plr)
		end,
	}

	local OutboundStub = {
		RoomState = function(plr: FakePlayer, payload: any)
			lastRoomState[plr] = payload
			roomStateCount[plr] = (roomStateCount[plr] or 0) + 1
		end,
		RoomList = function(plr: FakePlayer, entries: { any })
			lastRoomList[plr] = entries
		end,
		RoomInvite = function(plr: FakePlayer, roomId: number, hostName: string, mapId: string)
			table.insert(invites[plr], { roomId = roomId, hostName = hostName, mapId = mapId })
		end,
		Notify = function(plr: FakePlayer, kind: string, text: string)
			table.insert(notifications[plr], { kind = kind, text = text })
		end,
	}

	local customServerModules: { [string]: any } = {
		DataService = DataServiceStub,
		MapInstanceService = MapInstanceServiceStub,
		NpcService = NpcServiceStub,
		RunService = RunServiceStub,
		Outbound = OutboundStub,
		RunEvents = RunEventsStub,
	}

	local customServerStorage = {
		Modules = {
			Services = customServerModules,
			Remotes = { Outbound = OutboundStub },
			Shared = { RunEvents = RunEventsStub },
		},
	}

	local customGame = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return PlayersStub
			elseif name == "Workspace" then
				return WorkspaceStub
			elseif name == "ReplicatedStorage" then
				return ReplicatedStorageStub
			elseif name == "ServerStorage" then
				return customServerStorage
			end
			error("Unsupported service in RoomService harness: " .. tostring(name))
		end,
	}

	local function customRequire(target: any): any
		if customServerModules[target] ~= nil then
			return customServerModules[target]
		end
		for _, v in customServerModules do
			if target == v then
				return v
			end
		end
		return robloxRequire(target)
	end

	local roomSource = sourceMap["ServerServices.RoomService"]
	assert(type(roomSource) == "string", "Missing ServerServices.RoomService source")
	local chunk, err = (loadstring :: any)(roomSource, "@RoomService")
	assert(chunk ~= nil, "Failed to compile RoomService: " .. tostring(err))

	local roomEnv = setmetatable({
		game = customGame,
		require = customRequire,
		os = {
			clock = function(): number
				return clockNow
			end,
		},
		task = {
			spawn = function(fn: (...any) -> (), ...: any)
				local co = coroutine.create(fn)
				local ok, coErr = coroutine.resume(co, ...)
				if not ok then
					error(tostring(coErr))
				end
			end,
			delay = function(sec: number, fn: () -> ())
				table.insert(delayedTasks, {
					due = clockNow + math.max(0, sec),
					fn = function()
						local co = coroutine.create(fn)
						local ok, coErr = coroutine.resume(co)
						if not ok then
							error(tostring(coErr))
						end
					end,
				})
			end,
		},
	}, { __index = baseEnv })

	setfenv(chunk, roomEnv)
	local RoomService = chunk()

	local function resumeStartRun(plr: FakePlayer, succeed: boolean?)
		local co = suspendedStarts[plr]
		assert(co ~= nil, "No suspended StartRun for player " .. plr.Name)
		local ok, coErr = coroutine.resume(co, if succeed == nil then true else succeed)
		if not ok then
			error(tostring(coErr))
		end
	end

	local function removePlayer(plr: FakePlayer)
		onlinePlayers[plr.UserId] = nil
		for _, fn in playerRemovingListeners do
			fn(plr)
		end
		if activeRuns[plr] ~= nil then
			activeRuns[plr] = nil
		end
	end

	return {
		RoomService = RoomService,
		makePlayer = makePlayer,
		setFriends = setFriends,
		advanceClock = advanceClock,
		removePlayer = removePlayer,
		resumeStartRun = resumeStartRun,
		RunService = RunServiceStub,
		RunEvents = RunEventsStub,
		playerData = playerData,
		activeRuns = activeRuns,
		startRunBehavior = startRunBehavior,
		suspendedStarts = suspendedStarts,
		lastRoomState = lastRoomState,
		lastRoomList = lastRoomList,
		notifications = notifications,
		invites = invites,
		getStats = function()
			return {
				acquireCalls = acquireCalls,
				releaseCalls = releaseCalls,
				releasedCount = #releasedInstances,
				npcSetupCalls = npcSetupCalls,
				npcRemoveCalls = npcRemoveCalls,
			}
		end,
	}
end

runTest("RoomService_ThreeMembers_Join_Ready_Start_Countdown_And_Run", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(101, "Alice")
	local p2 = h.makePlayer(102, "Bob")
	local p3 = h.makePlayer(103, "Charlie")

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 4, false)
	local state1 = h.lastRoomState[p1]
	expect(state1 ~= nil and state1.InRoom == true, "Host should be in room")
	local roomId = state1.Id

	h.RoomService.JoinRoom(p2, roomId)
	h.RoomService.JoinRoom(p3, roomId)
	expect(#h.lastRoomState[p1].Members == 3, "Room should have 3 members")

	h.RoomService.StartRoom(p1)
	expect(h.lastRoomState[p1].Status == "Waiting", "Cannot start before non-host members are ready")
	expect(
		#h.notifications[p1] == 1 and h.notifications[p1][1].text == MessageConfig.RoomReadyNeeded,
		"Host notified RoomReadyNeeded"
	)

	h.RoomService.SetReady(p2, true)
	h.RoomService.SetReady(p3, true)
	h.RoomService.StartRoom(p1)
	expect(h.lastRoomState[p1].Status == "Countdown", "Room enters Countdown once all ready")
	expect(h.lastRoomState[p2].Status == "Countdown", "Member 2 sees Countdown")
	expect(h.lastRoomState[p3].Status == "Countdown", "Member 3 sees Countdown")

	h.advanceClock(RoomConfig.StartCountdown - 0.1)
	expect(h.lastRoomState[p1].Status == "Countdown", "Still in Countdown before timer elapses")
	expect(h.getStats().acquireCalls == 0, "Map not acquired before countdown ends")

	h.advanceClock(0.2)
	expect(h.lastRoomState[p1].Status == "Running", "Room transitions to Running after countdown")
	expect(h.getStats().acquireCalls == 1, "MapInstanceService.Acquire called once")
	expect(h.getStats().npcSetupCalls == 1, "NpcService.SetupInstance called once")
	expect(h.RunService.IsPlayerInRun(p1), "p1 is in run")
	expect(h.RunService.IsPlayerInRun(p2), "p2 is in run")
	expect(h.RunService.IsPlayerInRun(p3), "p3 is in run")
end)

runTest("RoomService_HostLeavesDuringCountdown_RevertsToWaiting_And_TransfersHost", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(201, "Host1")
	local p2 = h.makePlayer(202, "Member2")
	local p3 = h.makePlayer(203, "Member3")

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 4, false)
	local roomId = h.lastRoomState[p1].Id
	h.RoomService.JoinRoom(p2, roomId)
	h.RoomService.JoinRoom(p3, roomId)
	h.RoomService.SetReady(p2, true)
	h.RoomService.SetReady(p3, true)
	h.RoomService.StartRoom(p1)
	expect(h.lastRoomState[p1].Status == "Countdown", "Room in Countdown")

	h.advanceClock(1.0)
	h.RoomService.LeaveRoom(p1)

	expect(h.lastRoomState[p1].InRoom == false, "Leaving host receives emptyState")
	local state2 = h.lastRoomState[p2]
	expect(
		state2.InRoom == true and state2.Status == "Waiting",
		"Room reverts to Waiting when host leaves during Countdown"
	)
	expect(state2.HostId == p2.UserId, "Host transfers to next member in order (p2)")
	expect(state2.StartsAt == 0, "StartsAt reset to 0")
	expect(#state2.Members == 2, "2 members remain")
	expect(state2.Members[1].UserId == p2.UserId and state2.Members[1].Ready == true, "New host is Ready")
	expect(
		state2.Members[2].UserId == p3.UserId and state2.Members[2].Ready == false,
		"Remaining non-host Ready flag is reset to false"
	)

	h.advanceClock(RoomConfig.StartCountdown + 5)
	expect(h.lastRoomState[p2].Status == "Waiting", "Cancelled countdown timer does not start run")
	expect(h.getStats().acquireCalls == 0, "No map acquired after cancelled countdown")
end)

runTest("RoomService_KickMember_And_BlockRejoin", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(301, "Host")
	local p2 = h.makePlayer(302, "KickedGuy")

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 4, false)
	local roomId = h.lastRoomState[p1].Id
	h.RoomService.JoinRoom(p2, roomId)
	expect(#h.lastRoomState[p1].Members == 2, "p2 joined")

	h.RoomService.KickMember(p1, p2.UserId)
	expect(h.lastRoomState[p2].InRoom == false, "Kicked player removed from room")
	expect(
		#h.notifications[p2] == 1 and h.notifications[p2][1].text == MessageConfig.RoomKicked,
		"Kicked player notified"
	)
	expect(#h.lastRoomState[p1].Members == 1, "Only host remains")

	h.RoomService.JoinRoom(p2, roomId)
	expect(h.lastRoomState[p2].InRoom == false, "Kicked player blocked from rejoining before KickBlockTime")
	expect(
		h.notifications[p2][#h.notifications[p2]].text == MessageConfig.RoomJoinBlocked,
		"Blocked join notifies RoomJoinBlocked"
	)

	h.advanceClock(RoomConfig.KickBlockTime + 1)
	h.RoomService.JoinRoom(p2, roomId)
	expect(h.lastRoomState[p2].InRoom == true, "Kicked player can rejoin after KickBlockTime expires")
end)

runTest("RoomService_FriendsOnly_RejectsStranger_AllowsFriend", function()
	local h = newRoomHarness()
	local host = h.makePlayer(401, "Host")
	local stranger = h.makePlayer(402, "Stranger")
	local friend = h.makePlayer(403, "Friend")
	h.setFriends(host, friend, true)

	h.RoomService.CreateRoom(host, "Zone1", "Classic", 4, true)
	local roomId = h.lastRoomState[host].Id

	h.RoomService.WatchRooms(stranger, true)
	expect(#h.lastRoomList[stranger] == 0, "Friends-only room hidden from stranger in RoomList")

	h.RoomService.WatchRooms(friend, true)
	expect(
		#h.lastRoomList[friend] == 1 and h.lastRoomList[friend][1].Id == roomId,
		"Friends-only room visible to friend in RoomList"
	)
	expect(h.lastRoomList[friend][1].HostIsFriend == true, "HostIsFriend is true for friend")

	h.RoomService.JoinRoom(stranger, roomId)
	expect(
		h.lastRoomState[stranger] == nil or h.lastRoomState[stranger].InRoom == false,
		"Stranger cannot join friends-only room"
	)
	expect(
		h.notifications[stranger][#h.notifications[stranger]].text == MessageConfig.RoomFriendsOnly,
		"Stranger notified RoomFriendsOnly"
	)

	h.RoomService.JoinRoom(friend, roomId)
	expect(
		h.lastRoomState[friend].InRoom == true and h.lastRoomState[friend].Id == roomId,
		"Friend can join friends-only room"
	)
end)

runTest("RoomService_FullRoom_RejectsExtraJoin", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(501, "P1")
	local p2 = h.makePlayer(502, "P2")
	local p3 = h.makePlayer(503, "P3")

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 2, false)
	local roomId = h.lastRoomState[p1].Id
	h.RoomService.JoinRoom(p2, roomId)
	expect(#h.lastRoomState[p1].Members == 2, "Room at capacity 2/2")

	h.RoomService.WatchRooms(p3, true)
	expect(#h.lastRoomList[p3] == 0, "Full room is hidden from RoomList")

	h.RoomService.JoinRoom(p3, roomId)
	expect(h.lastRoomState[p3] == nil or h.lastRoomState[p3].InRoom == false, "3rd player rejected from 2-player room")
	expect(h.notifications[p3][#h.notifications[p3]].text == MessageConfig.RoomFull, "3rd player notified RoomFull")
end)

runTest("RoomService_StartRunFailsForOneMember_OthersContinueAndReleaseOnce", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(601, "P1")
	local p2 = h.makePlayer(602, "P2_Fails")
	local p3 = h.makePlayer(603, "P3")
	h.startRunBehavior[p2] = "fail"

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 4, false)
	local roomId = h.lastRoomState[p1].Id
	h.RoomService.JoinRoom(p2, roomId)
	h.RoomService.JoinRoom(p3, roomId)
	h.RoomService.SetReady(p2, true)
	h.RoomService.SetReady(p3, true)
	h.RoomService.StartRoom(p1)
	h.advanceClock(RoomConfig.StartCountdown + 0.1)

	expect(h.lastRoomState[p2].InRoom == false, "Failed member detached and sent emptyState")
	expect(
		h.notifications[p2][#h.notifications[p2]].text == MessageConfig.RoomRunFailed,
		"Failed member notified RoomRunFailed"
	)
	expect(h.RunService.IsPlayerInRun(p1) and h.RunService.IsPlayerInRun(p3), "p1 and p3 are running")
	expect(h.lastRoomState[p1].InRoom == true and #h.lastRoomState[p1].Members == 2, "p1 and p3 remain in room")
	expect(h.getStats().releaseCalls == 0, "Map not released while p1 and p3 run")

	h.RunService.EndRun(p1, true)
	h.advanceClock(RoomConfig.EmptyRoomGrace + 1)
	expect(h.getStats().releaseCalls == 0, "Map still not released while p3 runs")

	h.RunService.EndRun(p3, true)
	h.advanceClock(RoomConfig.EmptyRoomGrace + 1)
	expect(h.getStats().releaseCalls == 1, "Map released exactly once after p3 finishes")
end)

runTest("RoomService_MemberLeavesWhileStartRunYielding", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(701, "P1")
	local p2 = h.makePlayer(702, "P2_LeavesWhileYielding")
	local p3 = h.makePlayer(703, "P3")
	h.startRunBehavior[p2] = "yield_ok"

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 4, false)
	local roomId = h.lastRoomState[p1].Id
	h.RoomService.JoinRoom(p2, roomId)
	h.RoomService.JoinRoom(p3, roomId)
	h.RoomService.SetReady(p2, true)
	h.RoomService.SetReady(p3, true)
	h.RoomService.StartRoom(p1)
	h.advanceClock(RoomConfig.StartCountdown + 0.1)

	expect(h.suspendedStarts[p2] ~= nil, "p2 StartRun is yielding")
	expect(h.RunService.IsPlayerInRun(p1) and h.RunService.IsPlayerInRun(p3), "p1 and p3 already started")

	h.RoomService.LeaveRoom(p2)
	expect(h.lastRoomState[p2].InRoom == false, "p2 left room while StartRun was yielding")

	h.resumeStartRun(p2, true)
	expect(not h.RunService.IsPlayerInRun(p2), "p2 run immediately ended when StartRun returned true after leaving")
	expect(h.RunService.IsPlayerInRun(p1) and h.RunService.IsPlayerInRun(p3), "p1 and p3 unaffected")

	h.RunService.EndRun(p1, false)
	h.RunService.EndRun(p3, false)
	h.advanceClock(RoomConfig.EmptyRoomGrace + 1)
	expect(h.getStats().releaseCalls == 1, "Map released exactly once after remaining members finish")
end)

runTest("RoomService_EarlyFinishReturnsToLobby_LastFinishReleasesMapOnce", function()
	local h = newRoomHarness()
	local p1 = h.makePlayer(801, "Host")
	local p2 = h.makePlayer(802, "FastRunner")
	local p3 = h.makePlayer(803, "SlowRunner")

	h.RoomService.CreateRoom(p1, "Zone1", "Classic", 4, false)
	local roomId = h.lastRoomState[p1].Id
	h.RoomService.JoinRoom(p2, roomId)
	h.RoomService.JoinRoom(p3, roomId)
	h.RoomService.SetReady(p2, true)
	h.RoomService.SetReady(p3, true)
	h.RoomService.StartRoom(p1)
	h.advanceClock(RoomConfig.StartCountdown + 0.1)

	h.RunService.EndRun(p2, true)
	expect(h.lastRoomState[p2].InRoom == false, "First finisher (p2) detached from room")
	expect(h.lastRoomState[p1].InRoom == true and h.lastRoomState[p1].Status == "Running", "p1 still in Running room")
	expect(h.lastRoomState[p3].InRoom == true and h.lastRoomState[p3].Status == "Running", "p3 still in Running room")
	expect(#h.lastRoomState[p1].Members == 2, "2 members remain in room")
	h.advanceClock(RoomConfig.EmptyRoomGrace + 1)
	expect(
		h.getStats().releaseCalls == 0 and h.getStats().npcRemoveCalls == 0,
		"Map and NPCs kept alive while p1 and p3 play"
	)

	h.RunService.EndRun(p1, true)
	expect(h.lastRoomState[p1].InRoom == false, "Second finisher (host p1) detached from room")
	expect(
		h.lastRoomState[p3].InRoom == true and h.lastRoomState[p3].HostId == p3.UserId,
		"p3 becomes host and keeps playing"
	)
	h.advanceClock(RoomConfig.EmptyRoomGrace + 1)
	expect(h.getStats().releaseCalls == 0, "Map still kept alive for last runner p3")

	h.RunService.EndRun(p3, true)
	expect(h.lastRoomState[p3].InRoom == false, "Last finisher (p3) detached from room")
	expect(h.getStats().npcRemoveCalls == 1, "NpcService.RemoveInstance called immediately when last run ends")
	expect(h.getStats().releaseCalls == 0, "MapInstanceService.Release waits for EmptyRoomGrace")

	h.advanceClock(RoomConfig.EmptyRoomGrace + 0.1)
	expect(h.getStats().releaseCalls == 1, "MapInstanceService.Release called exactly once after EmptyRoomGrace")
end)

runTest("RoomService_PlayerRemoving_AllStates", function()
	local h = newRoomHarness()

	local w1 = h.makePlayer(901, "WaitHost")
	local w2 = h.makePlayer(902, "WaitGuest")
	h.RoomService.CreateRoom(w1, "Zone1", "Classic", 4, false)
	local waitRoomId = h.lastRoomState[w1].Id
	h.RoomService.JoinRoom(w2, waitRoomId)
	h.removePlayer(w1)
	expect(
		h.lastRoomState[w2].InRoom == true and h.lastRoomState[w2].HostId == w2.UserId,
		"Waiting: host PlayerRemoving transfers host to w2"
	)
	h.removePlayer(w2)

	local c1 = h.makePlayer(903, "CountHost")
	local c2 = h.makePlayer(904, "CountGuest")
	h.RoomService.CreateRoom(c1, "Zone1", "Classic", 4, false)
	local countRoomId = h.lastRoomState[c1].Id
	h.RoomService.JoinRoom(c2, countRoomId)
	h.RoomService.SetReady(c2, true)
	h.RoomService.StartRoom(c1)
	expect(h.lastRoomState[c1].Status == "Countdown", "Room in Countdown")
	h.removePlayer(c1)
	expect(
		h.lastRoomState[c2].Status == "Waiting" and h.lastRoomState[c2].HostId == c2.UserId,
		"Countdown: host PlayerRemoving reverts to Waiting and transfers host"
	)
	h.removePlayer(c2)

	local r1 = h.makePlayer(905, "RunHost")
	local r2 = h.makePlayer(906, "RunGuest")
	h.RoomService.CreateRoom(r1, "Zone1", "Classic", 4, false)
	local runRoomId = h.lastRoomState[r1].Id
	h.RoomService.JoinRoom(r2, runRoomId)
	h.RoomService.SetReady(r2, true)
	h.RoomService.StartRoom(r1)
	h.advanceClock(RoomConfig.StartCountdown + 0.1)
	expect(h.lastRoomState[r1].Status == "Running", "Room in Running")

	h.removePlayer(r1)
	expect(
		h.lastRoomState[r2].InRoom == true and h.lastRoomState[r2].Status == "Running",
		"Running: r1 PlayerRemoving leaves r2 running"
	)
	h.advanceClock(RoomConfig.EmptyRoomGrace + 1)
	expect(h.getStats().releaseCalls == 0, "Map not released while r2 still running")

	h.removePlayer(r2)
	expect(h.getStats().npcRemoveCalls == 1, "NPCs removed when last running player leaves")
	h.advanceClock(RoomConfig.EmptyRoomGrace + 0.1)
	expect(h.getStats().releaseCalls == 1, "Map released exactly once after last running player leaves")
end)

print(string.format("TESTS SUMMARY: %d / %d passed", passedTests, totalTests))
if #failures > 0 then
	error(string.format("%d test(s) failed", #failures))
end
