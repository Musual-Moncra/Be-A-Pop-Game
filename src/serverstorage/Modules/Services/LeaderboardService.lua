--!strict

--[[
	LeaderboardService
	Maintains the lobby OrderedDataStore leaderboard for best scores, periodically
	refreshes rankings, saves new personal best scores on run completion and disconnect,
	and renders the top rankings into the lobby LeaderboardBoard SurfaceGui.

	API:
		LeaderboardService.Refresh()
		LeaderboardService.SaveScore(plr: Player, score: number)

	Dependencies:
		DataStoreService, Players, ReplicatedStorage, ServerStorage, Workspace,
		LeaderboardConfig, RunEvents, DataService
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LeaderboardConfig = require(ReplicatedStorage.Modules.Config.LeaderboardConfig)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local DataService = require(script.Parent.DataService)

type LeaderboardEntry = {
	name: string,
	score: number,
}

local LeaderboardService = {}

local storeInstance: any = nil
local storeAvailable = true
local hasWarnedApi = false
local lastSavedScore: { [number]: number } = {}
local nameCache: { [number]: string } = {}

local function getStore(): any
	if storeInstance == nil and storeAvailable then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(LeaderboardConfig.StoreName)
		end)
		if ok and result ~= nil then
			storeInstance = result
		else
			storeAvailable = false
			if not hasWarnedApi then
				hasWarnedApi = true
				warn(`LeaderboardService: OrderedDataStore unavailable: {result}`)
			end
		end
	end
	return storeInstance
end

local function formatNumber(n: number): string
	local str = tostring(math.floor(n))
	local formatted = str
	while true do
		local nextFormatted, replacements = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextFormatted
		if replacements == 0 then
			break
		end
	end
	return formatted
end

local function getNameFromUserId(userId: number): string
	if nameCache[userId] ~= nil then
		return nameCache[userId]
	end

	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" and name ~= "" then
		nameCache[userId] = name
		return name
	end

	local fallback = string.format("Player %d", userId)
	nameCache[userId] = fallback
	return fallback
end

local function getSurfaceGui(): SurfaceGui?
	local lobby = Workspace:WaitForChild("Lobby", LeaderboardConfig.BoardWaitTimeout)
	if lobby == nil then
		return nil
	end
	local boardModel = lobby:WaitForChild("LeaderboardBoard", LeaderboardConfig.BoardWaitTimeout)
	if boardModel == nil then
		return nil
	end
	local board = boardModel:WaitForChild("Board", LeaderboardConfig.BoardWaitTimeout)
	if board == nil then
		return nil
	end
	return board:FindFirstChildOfClass("SurfaceGui")
end

local function renderBoard(entries: { LeaderboardEntry })
	local surfaceGui = getSurfaceGui()
	if surfaceGui == nil then
		return
	end

	surfaceGui:ClearAllChildren()

	local container = Instance.new("Frame")
	container.Name = "LeaderboardContainer"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = surfaceGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, LeaderboardConfig.CanvasPadding)
	padding.PaddingBottom = UDim.new(0, LeaderboardConfig.CanvasPadding)
	padding.PaddingLeft = UDim.new(0, LeaderboardConfig.CanvasPadding)
	padding.PaddingRight = UDim.new(0, LeaderboardConfig.CanvasPadding)
	padding.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, LeaderboardConfig.RowSpacing)
	layout.Parent = container

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.LayoutOrder = 0
	titleLabel.Size = UDim2.new(1, 0, 0, LeaderboardConfig.TitleHeight)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = LeaderboardConfig.TitleText
	titleLabel.TextColor3 = LeaderboardConfig.TitleTextColor
	titleLabel.TextSize = LeaderboardConfig.TitleTextSize
	titleLabel.Font = LeaderboardConfig.Font
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = container

	if #entries == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyLabel"
		emptyLabel.LayoutOrder = 1
		emptyLabel.Size = UDim2.new(1, 0, 0, LeaderboardConfig.RowHeight)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = LeaderboardConfig.EmptyText
		emptyLabel.TextColor3 = LeaderboardConfig.RowTextColor
		emptyLabel.TextSize = LeaderboardConfig.RowTextSize
		emptyLabel.Font = LeaderboardConfig.Font
		emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
		emptyLabel.Parent = container
		return
	end

	for rank, entry in ipairs(entries) do
		local rowColor = LeaderboardConfig.RowTextColor
		if rank == 1 then
			rowColor = LeaderboardConfig.Top1Color
		elseif rank == 2 then
			rowColor = LeaderboardConfig.Top2Color
		elseif rank == 3 then
			rowColor = LeaderboardConfig.Top3Color
		end

		local rowFrame = Instance.new("Frame")
		rowFrame.Name = string.format("Row_%d", rank)
		rowFrame.LayoutOrder = rank
		rowFrame.Size = UDim2.new(1, 0, 0, LeaderboardConfig.RowHeight)
		rowFrame.BackgroundTransparency = 1
		rowFrame.Parent = container

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(0.68, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("%d. %s", rank, entry.name)
		nameLabel.TextColor3 = rowColor
		nameLabel.TextSize = LeaderboardConfig.RowTextSize
		nameLabel.Font = LeaderboardConfig.Font
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = rowFrame

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.Size = UDim2.new(0.32, 0, 1, 0)
		scoreLabel.Position = UDim2.new(0.68, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = formatNumber(entry.score)
		scoreLabel.TextColor3 = rowColor
		scoreLabel.TextSize = LeaderboardConfig.RowTextSize
		scoreLabel.Font = LeaderboardConfig.Font
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = rowFrame
	end
end

local function fetchTopScores(): { LeaderboardEntry }
	local store = getStore()
	if store == nil then
		return {}
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, LeaderboardConfig.TopCount)
	end)
	if not ok or pages == nil then
		return {}
	end

	local okPage, currentData = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or type(currentData) ~= "table" then
		return {}
	end

	local entries: { LeaderboardEntry } = {}
	for _, item in ipairs(currentData) do
		local userId = tonumber(item.key)
		local score = tonumber(item.value) or 0
		if userId ~= nil and score > 0 then
			local name = getNameFromUserId(userId)
			table.insert(entries, {
				name = name,
				score = score,
			})
		end
	end
	return entries
end

function LeaderboardService.SaveScore(plr: Player, score: number)
	if score <= 0 then
		return
	end
	local userId = plr.UserId
	if userId <= 0 then
		return
	end
	if lastSavedScore[userId] ~= nil and score <= lastSavedScore[userId] then
		return
	end
	lastSavedScore[userId] = score

	task.spawn(function()
		local store = getStore()
		if store == nil then
			return
		end
		pcall(function()
			store:SetAsync(tostring(userId), math.floor(score))
		end)
	end)
end

function LeaderboardService.Refresh()
	task.spawn(function()
		local entries = fetchTopScores()
		renderBoard(entries)
	end)
end

local function checkAndSavePlayerBest(plr: Player)
	local data = DataService.Get(plr)
	if data ~= nil and data.Stats ~= nil and type(data.Stats.BestScore) == "number" then
		LeaderboardService.SaveScore(plr, data.Stats.BestScore)
	end
end

RunEvents.RunEnded:Connect(function(plr: Player, _summary: any)
	checkAndSavePlayerBest(plr)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	checkAndSavePlayerBest(plr)
	lastSavedScore[plr.UserId] = nil
end)

task.spawn(function()
	task.wait(LeaderboardConfig.FirstRefreshDelay)
	LeaderboardService.Refresh()
	while true do
		task.wait(LeaderboardConfig.RefreshInterval)
		LeaderboardService.Refresh()
	end
end)

return LeaderboardService
