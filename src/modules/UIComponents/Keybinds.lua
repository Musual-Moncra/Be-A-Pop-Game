--!strict

--[[
	Keybinds
	PC keyboard shortcuts for the UI. Actions and keys come from KeybindConfig. Each action keeps
	a stack of handlers and only the newest one fires, so a pet reveal opened over the result
	window takes Enter first. Keys are ignored while the player types (chat or any TextBox) or
	when Roblox already handled the input.

	API:
		Keybinds.bind(action, fn) -> unbind
		Keybinds.use(action, fn, active?)        React hook: binds while mounted and active ~= false
		Keybinds.label(action) -> string         text for the key hint
		Keybinds.useHints() -> boolean           React hook: true while keyboard and mouse is the input

	Dependencies: UserInputService, React, KeybindConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local KeybindConfig = require(ReplicatedStorage.Modules.Config.KeybindConfig)

local Keybinds = {}

local stacks: { [string]: { () -> () } } = {}
local keyToAction: { [Enum.KeyCode]: string } = {}
local connection: RBXScriptConnection? = nil

for action, definition in KeybindConfig.Actions do
	for _, key in definition.Keys do
		keyToAction[key] = action
	end
end

local function onInput(input: InputObject, processed: boolean)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	local action = keyToAction[input.KeyCode]
	local stack = if action ~= nil then stacks[action] else nil
	if stack ~= nil and #stack > 0 then
		stack[#stack]()
	end
end

function Keybinds.bind(action: string, fn: () -> ()): () -> ()
	local stack = stacks[action]
	if stack == nil then
		stack = {}
		stacks[action] = stack
	end
	table.insert(stack, fn)
	if connection == nil then
		connection = UserInputService.InputBegan:Connect(onInput)
	end
	return function()
		local index = table.find(stack, fn)
		if index ~= nil then
			table.remove(stack, index)
		end
	end
end

function Keybinds.use(action: string, fn: () -> (), active: boolean?)
	local latest = React.useRef(fn)
	latest.current = fn
	React.useEffect(function()
		if active == false then
			return
		end
		return Keybinds.bind(action, function()
			latest.current()
		end)
	end, { action, active } :: { any })
end

function Keybinds.label(action: string): string
	local definition = KeybindConfig.Actions[action]
	return if definition ~= nil then definition.Label else ""
end

local function keyboardPreferred(): boolean
	local ok, preferred = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	if ok and typeof(preferred) == "EnumItem" then
		return preferred.Name == "KeyboardAndMouse"
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Keyboard or string.find(last.Name, "Mouse") ~= nil then
		return true
	end
	return UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
end

function Keybinds.useHints(): boolean
	local shown, setShown = React.useState(keyboardPreferred)
	React.useEffect(function()
		local function refresh()
			setShown(keyboardPreferred())
		end
		local connections = { UserInputService.LastInputTypeChanged:Connect(refresh) }
		local ok, signal = pcall(function()
			return UserInputService:GetPropertyChangedSignal("PreferredInput" :: any)
		end)
		if ok and signal ~= nil then
			table.insert(connections, signal:Connect(refresh))
		end
		return function()
			for _, item in connections do
				item:Disconnect()
			end
		end
	end, {})
	return shown
end

return Keybinds
