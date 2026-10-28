--!strict

--[[
	LeaderboardService
	Maintains the three "Best Stinker" OrderedDataStore boards (daily, weekly, all-time),
	periodically refreshes rankings, adds every run's score to each period total, renders
	the lobby boards and broadcasts the rankings to clients.

	Daily keys are the UTC date and weekly keys the ISO week, both prefixed to the user id
	inside the period store, so a new day/week starts a fresh board without new stores.
	The main lobby board keeps showing the all-time board; the optional
	LeaderboardDaily/LeaderboardWeekly/LeaderboardAllTime models are rendered when present.

	API:
		LeaderboardService.Refresh()
		LeaderboardService.AddScore(plr: Player, score: number)
		LeaderboardService.SaveScore(plr: Player, score: number)   alias of AddScore

	Dependencies:
		DataStoreService, Players, ReplicatedStorage, ServerStorage, Workspace,
		LeaderboardConfig, RunEvents, Outbound
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LeaderboardConfig = require(ReplicatedStorage.Modules.Config.LeaderboardConfig)
local RunEvents = require(ServerStorage.Modules.Shared.RunEvents)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)

export type LeaderboardEntry = {
	name: string,
	score: number,
}

type PeriodStore = {
	storeName: string,
}

local LeaderboardService = {}

local periodOrder = {
	LeaderboardConfig.PeriodDaily,
	LeaderboardConfig.PeriodWeekly,
	LeaderboardConfig.PeriodAllTime,
}

local periodStores: { [string]: PeriodStore } = {
	[LeaderboardConfig.PeriodDaily] = {
		storeName = LeaderboardConfig.DailyStoreName,
	},
	[LeaderboardConfig.PeriodWeekly] = {
		storeName = LeaderboardConfig.WeeklyStoreName,
	},
	[LeaderboardConfig.PeriodAllTime] = {
		storeName = LeaderboardConfig.StoreName,
	},
}

local stores: { [string]: any } = {}
local storeUnavailable: { [string]: boolean } = {}
local hasWarnedApi: { [string]: boolean } = {}
local nameCache: { [number]: string } = {}
local cachedEntries: { [string]: { LeaderboardEntry } } = {}
local pendingWrites: { [string]: { [string]: number } } = {}

local function daysFromCivil(year: number, month: number, day: number): number
	local y = year - (if month <= 2 then 1 else 0)
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = if month > 2 then month - 3 else month + 9
	local doy = math.floor((153 * mp + 2) / 5) + day - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

local function isoWeekKey(now: number): string
	local t = os.date("!*t", now) :: any
	local isoWday = if t.wday == 1 then 7 else t.wday - 1
	local days = daysFromCivil(t.year, t.month, t.day)
	local thursday = days + (4 - isoWday)
	local isoYear = (os.date("!*t", now + (4 - isoWday) * 86400) :: any).year
	local week = math.floor((thursday - daysFromCivil(isoYear, 1, 1)) / 7) + 1
	return string.format("%04d-W%02d", isoYear, week)
end

local function getStore(period: string): any
	if stores[period] ~= nil then
		return stores[period]
	end
	if storeUnavailable[period] then
		return nil
	end

	local def = periodStores[period]
	if def == nil then
		return nil
	end

	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(def.storeName)
	end)
	if ok and result ~= nil then
		stores[period] = result
		return result
	end

	storeUnavailable[period] = true
	if not hasWarnedApi[period] then
		hasWarnedApi[period] = true
		warn(`LeaderboardService: OrderedDataStore {def.storeName} unavailable: {result}`)
	end
	return nil
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

local function budgetFor(requestType: Enum.DataStoreRequestType): number
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(requestType)
	end)
	if ok and type(budget) == "number" then
		return budget
	end
	return math.huge
end

local function periodKey(period: string, now: number): string
	if period == LeaderboardConfig.PeriodDaily then
		return os.date(LeaderboardConfig.DailyKeyFormat, now) :: string
	end
	if period == LeaderboardConfig.PeriodWeekly then
		return isoWeekKey(now)
	end
	return ""
end

local function storeKey(period: string, userId: number, now: number): string
	local key = periodKey(period, now)
	if key == "" then
		return tostring(userId)
	end
	return string.format("%s:%d", key, userId)
end

local function getSurfaceGui(modelName: string): SurfaceGui?
	local lobby = Workspace:WaitForChild("Lobby", LeaderboardConfig.BoardWaitTimeout)
	if lobby == nil then
		return nil
	end
	local boardModel = lobby:FindFirstChild(modelName)
	if boardModel == nil then
		return nil
	end
	local board = boardModel:FindFirstChild("Board")
	if board == nil then
		return nil
	end
	return board:FindFirstChildOfClass("SurfaceGui")
end

local function renderBoard(modelName: string, title: string, entries: { LeaderboardEntry })
	local surfaceGui = getSurfaceGui(modelName)
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
	titleLabel.Text = title
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
		nameLabel.Size = UDim2.new(LeaderboardConfig.NameWidth, 0, 1, 0)
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
		scoreLabel.Size = UDim2.new(LeaderboardConfig.ScoreWidth, 0, 1, 0)
		scoreLabel.Position = UDim2.new(LeaderboardConfig.NameWidth, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = formatNumber(entry.score)
		scoreLabel.TextColor3 = rowColor
		scoreLabel.TextSize = LeaderboardConfig.RowTextSize
		scoreLabel.Font = LeaderboardConfig.Font
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = rowFrame
	end
end

local function renderPeriod(period: string, entries: { LeaderboardEntry })
	local modelName = LeaderboardConfig.BoardModels[period]
	if modelName == nil then
		return
	end
	local title = LeaderboardConfig.PeriodTitles[period]
	renderBoard(modelName, if title ~= nil then title else LeaderboardConfig.TitleText, entries)
end

local function toPayload(entries: { LeaderboardEntry }): { any }
	local payload = {}
	for rank, entry in ipairs(entries) do
		table.insert(payload, { Rank = rank, Name = entry.name, Value = math.floor(entry.score) })
	end
	return payload
end

local function broadcast(period: string, entries: { LeaderboardEntry })
	local payload = toPayload(entries)
	for _, plr in Players:GetPlayers() do
		Outbound.LeaderboardData(plr, period, payload)
	end
end

local function fetchTopScores(period: string): { LeaderboardEntry }
	local store = getStore(period)
	if store == nil then
		return cachedEntries[period] or {}
	end
	if budgetFor(Enum.DataStoreRequestType.GetSortedAsync) < LeaderboardConfig.MinRefreshBudget then
		return cachedEntries[period] or {}
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, LeaderboardConfig.TopCount)
	end)
	if not ok or pages == nil then
		return cachedEntries[period] or {}
	end

	local okPage, currentData = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or type(currentData) ~= "table" then
		return cachedEntries[period] or {}
	end

	local entries: { LeaderboardEntry } = {}
	for _, item in ipairs(currentData) do
		local rawKey = tostring(item.key)
		local userId = tonumber((string.match(rawKey, "(%d+)$")))
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

local function flushPending(period: string)
	local store = getStore(period)
	local queue = pendingWrites[period]
	if store == nil or queue == nil then
		return
	end

	for key, delta in queue do
		if budgetFor(Enum.DataStoreRequestType.SetIncrementAsync) < LeaderboardConfig.MinSaveBudget then
			return
		end
		local ok = pcall(function()
			store:IncrementAsync(key, delta)
		end)
		if ok then
			queue[key] = nil
		end
	end
end

local function queueWrite(period: string, key: string, delta: number)
	local queue = pendingWrites[period]
	if queue == nil then
		queue = {}
		pendingWrites[period] = queue
	end
	queue[key] = (queue[key] or 0) + delta
end

local function addPeriodScore(period: string, userId: number, score: number, now: number)
	local store = getStore(period)
	local key = storeKey(period, userId, now)
	local delta = math.floor(score)
	if delta <= 0 then
		return
	end

	if store ~= nil and budgetFor(Enum.DataStoreRequestType.SetIncrementAsync) >= LeaderboardConfig.MinSaveBudget then
		local ok = pcall(function()
			store:IncrementAsync(key, delta)
		end)
		if ok then
			return
		end
	end
	queueWrite(period, key, delta)
end

function LeaderboardService.AddScore(plr: Player, score: number)
	if score <= 0 or plr.UserId <= 0 then
		return
	end
	local now = os.time()
	for _, period in periodOrder do
		addPeriodScore(period, plr.UserId, score, now)
	end
end

function LeaderboardService.SaveScore(plr: Player, score: number)
	LeaderboardService.AddScore(plr, score)
end

function LeaderboardService.Refresh()
	task.spawn(function()
		for _, period in periodOrder do
			flushPending(period)
			local entries = fetchTopScores(period)
			cachedEntries[period] = entries
			renderPeriod(period, entries)
			broadcast(period, entries)
		end

		local allTime = cachedEntries[LeaderboardConfig.PeriodAllTime] or {}
		renderBoard(LeaderboardConfig.BoardModelName, LeaderboardConfig.TitleText, allTime)
	end)
end

RunEvents.RunEnded:Connect(function(plr: Player, summary: any)
	if type(summary) ~= "table" or type(summary.Score) ~= "number" then
		return
	end
	LeaderboardService.AddScore(plr, summary.Score)
end)

Players.PlayerAdded:Connect(function(plr: Player)
	for _, period in periodOrder do
		local entries = cachedEntries[period]
		if entries ~= nil then
			Outbound.LeaderboardData(plr, period, toPayload(entries))
		end
	end
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
