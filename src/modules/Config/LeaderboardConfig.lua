--!strict

--[[
	LeaderboardConfig
	Configuration for the lobby top score leaderboard. Pure data, no functions.

	Fields:
		StoreName: name of the OrderedDataStore used for best scores (text)
		TopCount: maximum number of top players displayed on the board (count)
		RefreshInterval: how often the leaderboard fetches and renders top entries (seconds)
		FirstRefreshDelay: wait after server start before the first fetch (seconds)
		BoardWaitTimeout: how long to wait for the lobby board instances to load (seconds)
		TitleText: heading shown at the top of the board (text)
		TitleTextColor: color of the header title text (Color3)
		TitleTextSize: font size of the title text (pixels)
		TitleHeight: height allocated to the title label (pixels)
		RowTextColor: default color for ranking rows (Color3)
		RowTextSize: font size for ranking rows (pixels)
		RowHeight: height allocated to each row entry (pixels)
		Top1Color: highlight text color for 1st place (Color3)
		Top2Color: highlight text color for 2nd place (Color3)
		Top3Color: highlight text color for 3rd place (Color3)
		Font: font face used for leaderboard labels (Enum.Font)
		EmptyText: message displayed when no scores have been recorded yet (text)
		CanvasPadding: padding inside the leaderboard frame (pixels)
		RowSpacing: vertical space between consecutive rows (pixels)
]]

local LeaderboardConfig = {}

LeaderboardConfig.StoreName = "BestScoreLeaderboard_v1"
LeaderboardConfig.TopCount = 10
LeaderboardConfig.RefreshInterval = 60
LeaderboardConfig.FirstRefreshDelay = 1
LeaderboardConfig.BoardWaitTimeout = 5
LeaderboardConfig.TitleText = "TOP POOPERS"
LeaderboardConfig.TitleTextColor = Color3.fromRGB(255, 230, 100)
LeaderboardConfig.TitleTextSize = 42
LeaderboardConfig.TitleHeight = 56
LeaderboardConfig.RowTextColor = Color3.fromRGB(240, 240, 245)
LeaderboardConfig.RowTextSize = 26
LeaderboardConfig.RowHeight = 36
LeaderboardConfig.Top1Color = Color3.fromRGB(255, 215, 0)
LeaderboardConfig.Top2Color = Color3.fromRGB(210, 215, 225)
LeaderboardConfig.Top3Color = Color3.fromRGB(215, 145, 80)
LeaderboardConfig.Font = Enum.Font.FredokaOne
LeaderboardConfig.EmptyText = "No scores yet - be the first!"
LeaderboardConfig.CanvasPadding = 16
LeaderboardConfig.RowSpacing = 4

return LeaderboardConfig
