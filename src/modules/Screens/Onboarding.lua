--!strict

--[[
	Onboarding
	First-run coaching overlay. Draws the current hint in a dark bottom panel with a small
	Skip button and, when the step has a target, a bouncing arrow plus a pulsing ring on the
	target. GUI targets are found by name through OnboardingController.FindTarget; in-world
	targets are the Park portal and the nearest soilable prop. The panel follows the current
	saved step and the live run / lobby state, so it never blocks a screen that has no hint.

	Props: data (DataController state), ui (useUIScale result), route (LobbyState route)
	Dependencies: React, Players, RunService, Workspace, GameConfig, LobbyState,
		OnboardingConfig, OnboardingController, Primitives, ChunkyButton
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local GameConfig = require(ReplicatedStorage.Modules.Config.GameConfig)
local LobbyState = require(ReplicatedStorage.Modules.UIs.LobbyState)
local LobbyUIConfig = require(ReplicatedStorage.Modules.Config.LobbyUIConfig)
local OnboardingConfig = require(ReplicatedStorage.Modules.Config.OnboardingConfig)
local OnboardingController = require(ReplicatedStorage.Modules.Controllers.OnboardingController)
local Components = ReplicatedStorage.Modules.UIComponents
local ChunkyButton = require(Components.ChunkyButton)
local Primitives = require(Components.Primitives)

local e = React.createElement
local TAU = math.pi * 2

local function buildHint(step: number, data: any, route: string): any
	local inRun = data.RunState == GameConfig.RunStates.Running
	local showResult = not inRun and data.LastRun ~= nil
	local reveal = data.LastPetDrop ~= nil

	if step == OnboardingConfig.StepPlay then
		if inRun or showResult or reveal then
			return nil
		end
		if route == LobbyState.Routes.Play or route == LobbyState.Routes.None then
			return {
				Text = OnboardingConfig.Text.Play,
				TargetKind = "UI",
				TargetKey = "Play",
				Placement = "Dock",
			}
		end
		return nil
	elseif step == OnboardingConfig.StepStain then
		if not inRun then
			return nil
		end
		return { Text = OnboardingConfig.Text.Stain, Placement = "InRun" }
	elseif step == OnboardingConfig.StepSplat then
		if not inRun then
			return nil
		end
		return {
			Text = OnboardingConfig.Text.Splat,
			TargetKind = "World",
			TargetKey = "Soil",
			Placement = "InRun",
		}
	elseif step == OnboardingConfig.StepLifespan then
		if not OnboardingController.HasLowLifespan() then
			return nil
		end
		if showResult then
			return { Text = OnboardingConfig.Text.Lifespan, Placement = "Result" }
		end
		if not inRun and not reveal and route == LobbyState.Routes.None then
			return {
				Text = OnboardingConfig.Text.Lifespan,
				TargetKind = "UI",
				TargetKey = "Upgrades",
				Placement = "Dock",
			}
		end
		return nil
	elseif step == OnboardingConfig.StepPet then
		if inRun or showResult or reveal or route ~= LobbyState.Routes.None then
			return nil
		end
		if not OnboardingController.HasPetSeen() then
			return nil
		end
		return {
			Text = OnboardingConfig.Text.Pet,
			TargetKind = "UI",
			TargetKey = "Pets",
			Placement = "Dock",
		}
	end
	return nil
end

local function screenGui(): any
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil
	end
	return playerGui:FindFirstChild("GameUI")
end

local function uiTargetPoint(target: GuiObject, ui: any): (Vector2?, Vector2?)
	local gui = screenGui()
	if gui == nil then
		return nil, nil
	end
	local center = (target.AbsolutePosition + target.AbsoluteSize * 0.5 - gui.AbsolutePosition) / ui.scale
	local size = target.AbsoluteSize / ui.scale
	return center - Vector2.new(ui.safe.Left, ui.safe.Top), size
end

local function worldTargetPoint(position: Vector3, ui: any): Vector2?
	local gui = screenGui()
	local camera = Workspace.CurrentCamera
	if gui == nil or camera == nil then
		return nil
	end
	local viewport, onScreen = camera:WorldToViewportPoint(position)
	if not onScreen then
		return nil
	end
	local center = (Vector2.new(viewport.X, viewport.Y) - gui.AbsolutePosition) / ui.scale
	return center - Vector2.new(ui.safe.Left, ui.safe.Top)
end

local function fallbackPoint(key: string?, ui: any): Vector2?
	if key == nil then
		return nil
	end
	local fallback = OnboardingConfig.Fallbacks[key]
	if fallback == nil then
		return nil
	end
	return Vector2.new(ui.safeWidth * fallback.X, ui.safeHeight * fallback.Y)
end

local function dockRowOpen(): boolean
	return OnboardingController.FindTarget("Upgrades") ~= nil or OnboardingController.FindTarget("Pets") ~= nil
end

local function playTargetKey(): string
	return if OnboardingController.FindTarget("Play") ~= nil then "Play" else "Menu"
end

local function dockOffset(ui: any, open: boolean): number
	local layout = LobbyUIConfig.Layouts[if ui.mobile then "Mobile" else "PC"].Dock
	local dock = LobbyUIConfig.Dock
	local gap = OnboardingConfig.PanelDockGap
	local lift = dock.Lift
	if not open then
		lift = dock.ButtonSize * LobbyUIConfig.Bounce.Scale
	else
		lift += dock.ItemSize * dock.BigScale + dock.LabelHeight
	end
	return math.abs(layout.Position.Y.Offset) + dock.ButtonSize + lift + gap
end

return function(props: any)
	local data = props.data
	local ui = props.ui
	local route = props.route
	local _, setVersion = React.useState(0)
	local dockOpen, setDockOpen = React.useState(dockRowOpen)
	local playTarget, setPlayTarget = React.useState(playTargetKey)
	local arrowRef = React.useRef(nil)
	local ringRef = React.useRef(nil)
	local ringScaleRef = React.useRef(nil)

	React.useEffect(function()
		local connection = OnboardingController.Changed:Connect(function()
			setVersion(os.clock())
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local lastOpen = dockRowOpen()
		local lastTarget = playTargetKey()
		local lastCheck = 0
		local connection = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - lastCheck < OnboardingConfig.FollowUpdateSeconds then
				return
			end
			lastCheck = now
			local openNow = dockRowOpen()
			if openNow ~= lastOpen then
				lastOpen = openNow
				setDockOpen(openNow)
			end
			local targetNow = playTargetKey()
			if targetNow ~= lastTarget then
				lastTarget = targetNow
				setPlayTarget(targetNow)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local step = OnboardingController.GetStep()
	local hint = buildHint(step, data, route)
	local hintKey = if hint ~= nil
		then string.format(
			"%d:%s:%s:%s",
			step,
			tostring(hint.TargetKind),
			tostring(hint.TargetKey),
			tostring(hint.Placement)
		)
		else ""
	local layoutKey =
		string.format("%.4f:%.2f:%.2f:%.2f:%.2f", ui.scale, ui.safe.Left, ui.safe.Top, ui.safeWidth, ui.safeHeight)

	local panelTop: number? = nil
	local panelBottom: number? = nil
	if hint ~= nil then
		if hint.Placement == "Dock" then
			panelBottom = ui.safeHeight - dockOffset(ui, dockOpen)
			panelTop = panelBottom - OnboardingConfig.PanelHeight
		elseif hint.Placement == "Result" then
			panelBottom = ui.safeHeight * OnboardingConfig.PanelYResult + OnboardingConfig.PanelHeight / 2
			panelTop = panelBottom - OnboardingConfig.PanelHeight
		else
			panelBottom = ui.safeHeight * OnboardingConfig.PanelYInRun + OnboardingConfig.PanelHeight / 2
			panelTop = panelBottom - OnboardingConfig.PanelHeight
		end
	end

	React.useEffect(function()
		if hint == nil or hint.TargetKey == nil then
			return
		end
		local arrow = arrowRef.current
		local ring = ringRef.current
		local ringScale = ringScaleRef.current
		if arrow == nil or ring == nil or ringScale == nil then
			return
		end
		local target: GuiObject? = nil
		local lastLookup = 0
		local function findTarget(key: string): GuiObject?
			local found = OnboardingController.FindTarget(key)
			if found == nil and key ~= "Menu" then
				found = OnboardingController.FindTarget("Menu")
			end
			return found
		end
		local connection = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - lastLookup >= OnboardingConfig.FollowUpdateSeconds then
				lastLookup = now
				target = if hint.TargetKind == "UI" then findTarget(hint.TargetKey) else nil
			end

			local center: Vector2? = nil
			local size = Vector2.new(OnboardingConfig.RingSize, OnboardingConfig.RingSize)
			local worldPosition: Vector3? = nil
			if hint.TargetKind == "World" then
				worldPosition = OnboardingController.GetNearestTargetPosition()
			end

			if hint.TargetKind == "UI" and target ~= nil then
				center, size = uiTargetPoint(target, ui)
			elseif worldPosition ~= nil then
				center = worldTargetPoint(worldPosition, ui)
				size = Vector2.new(OnboardingConfig.RingWorldSize, OnboardingConfig.RingWorldSize)
			end

			if center == nil then
				center = fallbackPoint(hint.TargetKey, ui)
				size = Vector2.new(OnboardingConfig.RingSize, OnboardingConfig.RingSize)
			end
			if center == nil then
				arrow.Visible = false
				ring.Visible = false
				return
			end

			ring.Visible = true
			local bounce = math.sin(now * OnboardingConfig.BounceSpeed * TAU) * OnboardingConfig.BounceHeight
			local arrowBottom = center.Y - OnboardingConfig.ArrowOffsetY + bounce
			local arrowTop = arrowBottom - OnboardingConfig.ArrowBoxSize
			local overlapsPanel = panelBottom ~= nil
				and panelTop ~= nil
				and arrowTop < panelBottom
				and arrowBottom > panelTop
			arrow.Visible = not overlapsPanel
			if not overlapsPanel then
				arrow.Position = UDim2.fromOffset(center.X, arrowBottom)
			end
			ring.Position = UDim2.fromOffset(center.X, center.Y)
			ring.Size =
				UDim2.fromOffset(size.X + OnboardingConfig.RingPadding * 2, size.Y + OnboardingConfig.RingPadding * 2)
			ringScale.Scale = 1
				+ math.sin(now * OnboardingConfig.RingPulseSpeed * TAU) * OnboardingConfig.RingPulseAmount
		end)
		return function()
			connection:Disconnect()
		end
	end, { hintKey .. ":" .. layoutKey .. ":" .. tostring(dockOpen) } :: { any })

	if hint == nil then
		return nil
	end

	local panelWidth = math.min(OnboardingConfig.PanelWidth, ui.safeWidth - OnboardingConfig.PanelMargin * 2)
	local padding = OnboardingConfig.PanelPadding
	local skipWidth = OnboardingConfig.SkipWidth
	local sideReserve = skipWidth + OnboardingConfig.SkipGap
	local labelWidth = math.max(0, panelWidth - padding * 2 - sideReserve * 2)

	local panelAnchor = Vector2.new(0.5, 0.5)
	local panelPosition = UDim2.fromScale(OnboardingConfig.PanelX, OnboardingConfig.PanelYInRun)
	if hint.Placement == "Dock" then
		panelAnchor = Vector2.new(0.5, 1)
		panelPosition = UDim2.new(OnboardingConfig.PanelX, 0, 1, -dockOffset(ui, dockOpen))
	elseif hint.Placement == "Result" then
		panelPosition = UDim2.fromScale(OnboardingConfig.PanelX, OnboardingConfig.PanelYResult)
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Panel = e("Frame", {
			AnchorPoint = panelAnchor,
			BackgroundColor3 = OnboardingConfig.PanelColor,
			BackgroundTransparency = OnboardingConfig.PanelTransparency,
			BorderSizePixel = 0,
			Position = panelPosition,
			Size = UDim2.fromOffset(panelWidth, OnboardingConfig.PanelHeight),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, OnboardingConfig.PanelRadius) }),
			Stroke = e("UIStroke", {
				Color = OnboardingConfig.PanelStrokeColor,
				Thickness = OnboardingConfig.PanelStrokeThickness,
				LineJoinMode = Enum.LineJoinMode.Round,
			}),
			Label = Primitives.text({
				Color = OnboardingConfig.TextColor,
				Position = UDim2.fromOffset(padding + sideReserve, padding),
				Size = UDim2.fromOffset(labelWidth, OnboardingConfig.PanelHeight - padding * 2),
				Text = if step == OnboardingConfig.StepPlay and playTarget == "Menu"
					then OnboardingConfig.Text.PlayMenu
					else hint.Text,
				TextSize = OnboardingConfig.TextSize,
				Wrapped = true,
				XAlign = Enum.TextXAlignment.Center,
				YAlign = Enum.TextYAlignment.Center,
			}),
			Skip = e(ChunkyButton, {
				anchorPoint = Vector2.new(1, 0.5),
				onActivated = function()
					OnboardingController.Skip()
				end,
				position = UDim2.new(1, -padding, 0.5, 0),
				radius = OnboardingConfig.SkipRadius,
				size = UDim2.fromOffset(skipWidth, OnboardingConfig.SkipHeight),
				swatch = "Grey",
				text = OnboardingConfig.Text.Skip,
				textSize = OnboardingConfig.SkipTextSize,
			}),
		}),
		Arrow = if hint.TargetKey ~= nil
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Primitives.displayFont(),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(OnboardingConfig.ArrowBoxSize, OnboardingConfig.ArrowBoxSize),
				Text = OnboardingConfig.ArrowText,
				TextColor3 = OnboardingConfig.ArrowColor,
				TextSize = OnboardingConfig.ArrowTextSize,
				TextStrokeColor3 = OnboardingConfig.ArrowStrokeColor,
				TextStrokeTransparency = 0,
				Visible = false,
				ref = arrowRef,
			})
			else nil,
		Ring = if hint.TargetKey ~= nil
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(OnboardingConfig.RingSize, OnboardingConfig.RingSize),
				Visible = false,
				ref = ringRef,
			}, {
				Scale = e("UIScale", { ref = ringScaleRef }),
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = e("UIStroke", {
					Color = OnboardingConfig.RingColor,
					Thickness = OnboardingConfig.RingThickness,
					Transparency = OnboardingConfig.RingTransparency,
				}),
			})
			else nil,
	})
end
