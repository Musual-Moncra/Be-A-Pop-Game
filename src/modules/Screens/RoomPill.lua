--!strict

--[[
	RoomPill
	Small lobby prompt in the bottom-left corner while no lobby window is open: a pending
	friend invite with JOIN and dismiss takes priority, otherwise the room this client is in
	with OPEN to reopen the play window. Reads RoomController and LobbyState.

	Props: ui (useUIScale result)
	Dependencies: React, UIConfig, LobbyState, RoomController, ConfigLookup, Net, Primitives, ChunkyButton, Inset
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local RoomController = require(ReplicatedStorage.Modules.Controllers.RoomController)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local Net = require(ReplicatedStorage.Modules.Shared.Net)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Inset = require(Components.Inset)
local Primitives = require(Components.Primitives)

local e = React.createElement
local Shape = UIConfig.Shape
local Sizes = UIConfig.Sizes.Room
local Gap = UIConfig.Sizes.Window.Gap
local Text = UIConfig.Text
local TextSizes = UIConfig.TextSizes

local function pillIcon(mapId: string)
	local visual = UIConfig.MapVisuals[mapId] or {}
	return e(Inset, {
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.fromScale(0, 0.5),
		radius = "Round",
		size = UDim2.fromOffset(Sizes.PillIconSize, Sizes.PillIconSize),
	}, {
		Emoji = Primitives.text({
			Stroke = false,
			Text = visual.Icon or "",
			TextSize = Sizes.PillIconSize * Shape.IconFill,
		}),
	})
end

local function pillText(text: string, rightInset: number)
	return Primitives.text({
		Fit = true,
		Position = UDim2.fromOffset(Sizes.PillIconSize + Gap, 0),
		Size = UDim2.new(1, -(Sizes.PillIconSize + Gap + rightInset), 1, 0),
		Text = text,
		TextSize = TextSizes.Body,
		XAlign = Enum.TextXAlignment.Left,
	})
end

local function InvitePill(props: any)
	local invite = props.invite
	return e(ChunkyButton, {
		layoutOrder = 1,
		size = UDim2.fromOffset(Sizes.PillWidth, Sizes.PillHeight),
		swatch = "Teal",
	}, {
		Padding = Primitives.paddingXY(Gap, 0),
		Icon = pillIcon(invite.MapId),
		Label = pillText(
			string.format(Text.InvitePillFormat, invite.HostName),
			Sizes.PillButtonWidth + Sizes.PillDismissSize + Gap * 2
		),
		Join = e(ChunkyButton, {
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				RoomController.DismissInvite()
				Net.JoinRoom:Fire(invite.RoomId)
				LobbyState.SetActive(LobbyState.Routes.Play)
			end,
			position = UDim2.new(1, -(Sizes.PillDismissSize + Gap), 0.5, 0),
			size = UDim2.fromOffset(Sizes.PillButtonWidth, Sizes.PillButtonHeight),
			swatch = "Green",
			text = Text.InvitePillJoin,
			textSize = TextSizes.Body,
		}),
		Dismiss = e(ChunkyButton, {
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = RoomController.DismissInvite,
			position = UDim2.fromScale(1, 0.5),
			size = UDim2.fromOffset(Sizes.PillDismissSize, Sizes.PillDismissSize),
			swatch = "Grey",
			text = Text.DismissIcon,
			textSize = TextSizes.Body,
		}),
	})
end

local function RoomPillCard(props: any)
	local room = props.room
	local definition = ConfigLookup.GetMap(room.MapId)
	local mapName = if definition ~= nil then definition.DisplayName else room.MapId
	return e(ChunkyButton, {
		layoutOrder = 2,
		size = UDim2.fromOffset(Sizes.PillWidth, Sizes.PillHeight),
		swatch = "Purple",
	}, {
		Padding = Primitives.paddingXY(Gap, 0),
		Icon = pillIcon(room.MapId),
		Label = pillText(
			string.format(Text.RoomPillFormat, mapName, #room.Members, room.MaxPlayers),
			Sizes.PillButtonWidth + Gap
		),
		Open = e(ChunkyButton, {
			anchorPoint = Vector2.new(1, 0.5),
			onActivated = function()
				LobbyState.SetActive(LobbyState.Routes.Play)
			end,
			position = UDim2.fromScale(1, 0.5),
			size = UDim2.fromOffset(Sizes.PillButtonWidth, Sizes.PillButtonHeight),
			swatch = "Green",
			text = Text.RoomPillOpen,
			textSize = TextSizes.Body,
		}),
	})
end

return function(props: any)
	local roomState, setRoomState = React.useState(RoomController.Get())
	React.useEffect(function()
		local connection = RoomController.Changed:Connect(setRoomState)
		return function()
			connection:Disconnect()
		end
	end, {})

	if roomState.Invite == nil and roomState.Room == nil then
		return nil
	end

	local layout = UIConfig.Layouts[if props.ui.mobile then "Mobile" else "PC"].RoomPills
	local children: { [string]: any } = {
		Layout = Primitives.list(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Right),
	}
	if roomState.Invite ~= nil then
		children.Invite = e(InvitePill, { invite = roomState.Invite })
	elseif roomState.Room ~= nil then
		children.Room = e(RoomPillCard, { room = roomState.Room })
	end

	return e("Frame", {
		AnchorPoint = layout.AnchorPoint,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = layout.Position,
		Size = UDim2.fromOffset(Sizes.PillWidth, 0),
	}, children)
end
