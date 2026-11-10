--!strict

--[[
	ErrorBoundary
	Catches a render error in one UI layer so the rest of the UI keeps working: the failed layer
	renders nothing, the error is warned once with the layer name, and onError runs (the App
	closes the lobby window so reopening it mounts a fresh copy). The boundary resets itself
	when resetKey changes.

	Props: name (layer name for the warning), resetKey (any; a change clears the error),
		onError (optional callback), children
	Dependencies: React
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local ErrorBoundary = React.Component:extend("ErrorBoundary")

function ErrorBoundary:init()
	self.state = { failed = false }
end

function ErrorBoundary.getDerivedStateFromError(_error: any)
	return { failed = true }
end

function ErrorBoundary:componentDidCatch(err: any)
	warn(string.format("[UI] %s failed and was hidden: %s", tostring(self.props.name), tostring(err)))
	if self.props.onError ~= nil then
		task.defer(self.props.onError)
	end
end

function ErrorBoundary:componentDidUpdate(previous: any)
	if self.state.failed and previous.resetKey ~= self.props.resetKey then
		self:setState({ failed = false })
	end
end

function ErrorBoundary:render()
	if self.state.failed then
		return nil
	end
	return React.createElement(React.Fragment, nil, self.props.children)
end

return ErrorBoundary
