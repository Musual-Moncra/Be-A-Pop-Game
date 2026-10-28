--!strict

--[[
	LeaderboardConfig
	Configuration for the lobby "Best Stinker" leaderboards and their period stores.
	Pure data, no functions.

	Fields:
		StoreName: OrderedDataStore holding all-time totals (text)
		DailyStoreName: OrderedDataStore holding daily totals (text)
		WeeklyStoreName: OrderedDataStore holding weekly totals (text)
		PeriodDaily: period id sent to clients for the daily board (text)
		PeriodWeekly: period id sent to clients for the weekly board (text)
		PeriodAllTime: period id sent to clients for the all-time board (text)
		DailyKeyFormat: os.date UTC format of the daily period key (date format)
		TopCount: maximum number of top players displayed on a board (count)
		RefreshInterval: how often the boards fetch and render top entries (seconds)
		FirstRefreshDelay: wait after server start before the first fetch (seconds)
		BoardWaitTimeout: how long to wait for the lobby board instances to load (seconds)
		BoardModelName: lobby model that keeps showing the all-time board (string)
		BoardModels: optional lobby model per period id, rendered only when present (string)
		PeriodTitles: heading shown on each period board, keyed by period id (text)
		TitleText: heading shown on the main all-time board (text)
		TitleTextColor: color of the header title text (Color3)
		TitleTextSize: font size of the title text (pixels)
		TitleHeight: height allocated to the title label (pixels)
		RowTextColor: default color for ranking rows (Color3)
		RowTextSize: font size for ranking rows (pixels)
		RowHeight: height allocated to each row entry (pixels)
		NameWidth: width ratio for the name column in leaderboard rows (scale 0-1)
		ScoreWidth: width ratio for the score column in leaderboard rows (scale 0-1)
		Top1Color: highlight text color for 1st place (Color3)
		Top2Color: highlight text color for 2nd place (Color3)
		Top3Color: highlight text color for 3rd place (Color3)
		Font: font face used for leaderboard labels (Enum.Font)
		EmptyText: message displayed when no scores have been recorded yet (text)
		CanvasPadding: padding inside the leaderboard frame (pixels)
		RowSpacing: vertical space between consecutive rows (pixels)
		MinRefreshBudget: remaining GetSortedAsync requests needed before a refresh fetch (count)
		MinSaveBudget: remaining SetIncrementAsync requests needed before an immediate write (count)
]]

local LeaderboardConfig = {}

LeaderboardConfig.StoreName = "AllTimeScoreLeaderboard_v1"
LeaderboardConfig.DailyStoreName = "DailyScoreLeaderboard_v1"
LeaderboardConfig.WeeklyStoreName = "WeeklyScoreLeaderboard_v1"

LeaderboardConfig.PeriodDaily = "Daily"
LeaderboardConfig.PeriodWeekly = "Weekly"
LeaderboardConfig.PeriodAllTime = "AllTime"

LeaderboardConfig.DailyKeyFormat = "!%Y-%m-%d"

LeaderboardConfig.TopCount = 10
LeaderboardConfig.RefreshInterval = 60
LeaderboardConfig.FirstRefreshDelay = 1
LeaderboardConfig.BoardWaitTimeout = 5
LeaderboardConfig.BoardModelName = "LeaderboardBoard"
LeaderboardConfig.BoardModels = {
	Daily = "LeaderboardDaily",
	Weekly = "LeaderboardWeekly",
	AllTime = "LeaderboardAllTime",
}
LeaderboardConfig.PeriodTitles = {
	Daily = "TODAY'S BEST",
	Weekly = "THIS WEEK'S BEST",
	AllTime = "ALL-TIME BEST",
}
LeaderboardConfig.TitleText = "TOP POOPERS"
LeaderboardConfig.TitleTextColor = Color3.fromRGB(255, 230, 100)
LeaderboardConfig.TitleTextSize = 42
LeaderboardConfig.TitleHeight = 56
LeaderboardConfig.RowTextColor = Color3.fromRGB(240, 240, 245)
LeaderboardConfig.RowTextSize = 26
LeaderboardConfig.RowHeight = 36
LeaderboardConfig.NameWidth = 0.68
LeaderboardConfig.ScoreWidth = 0.32
LeaderboardConfig.Top1Color = Color3.fromRGB(255, 215, 0)
LeaderboardConfig.Top2Color = Color3.fromRGB(210, 215, 225)
LeaderboardConfig.Top3Color = Color3.fromRGB(215, 145, 80)
LeaderboardConfig.Font = Enum.Font.FredokaOne
LeaderboardConfig.EmptyText = "No scores yet - be the first!"
LeaderboardConfig.CanvasPadding = 16
LeaderboardConfig.RowSpacing = 4
LeaderboardConfig.MinRefreshBudget = 1
LeaderboardConfig.MinSaveBudget = 1

return LeaderboardConfig
