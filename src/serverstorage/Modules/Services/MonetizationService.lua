--!strict

--[[
	MonetizationService
	Owns gamepass ownership caching, developer product receipts and every reward that needs
	the live run (coin/gem multipliers, revive offer, stain bomb, Newbie Pack boost).

	Gamepass ownership is cached per player. The cache is filled on join, refreshed after a
	gamepass prompt and re-asked lazily once PassCacheSeconds has passed, so a pass bought on
	another server is picked up without hammering UserOwnsGamePassAsync.

	Receipts are idempotent: every granted PurchaseId is stored in Profile.Data.Purchases and
	a repeated ProcessReceipt for the same id answers PurchaseGranted without granting again.
	GrantProduct is the handler table, keyed by the kind ConfigLookup.GetDevProduct returns
	("GemPack", "CoinPack", "Revive", "StainBomb", "NewbiePack"); a handler returns true once
	the reward is delivered.

	Revive: RunService fires RunEvents.TimeUp when a timed run hits zero and keeps the run
	alive MonetizationConfig.ReviveWindow seconds. This service answers with Outbound.ReviveOffer
	(product id, tier index, seconds). A revive receipt fires RunEvents.ReviveActivated so
	RunService adds ReviveSeconds and closes the window. Every revive inside one run moves to
	the next, more expensive tier; the last tier repeats. A revive bought outside a run becomes
	credit that is spent on the next time-up instead of being lost.

	API:
		MonetizationService.HasPass(plr, passKey) -> boolean
		MonetizationService.GetCoinMultiplier(plr) -> number
		MonetizationService.GetGemMultiplier(plr) -> number
		MonetizationService.GrantProduct -> { [kind: string]: (plr, entry, purchaseId) -> boolean }

	Dependencies: MarketplaceService, DataService, RunEvents, Outbound, ConfigLookup, MonetizationConfig
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MonetizationConfig = require(ReplicatedStorage.Modules.Config.MonetizationConfig)

local MonetizationService = {}

type PassCache = { [string]: boolean }

local passCache: { [Player]: PassCache } = {}
local passFetchedAt: { [Player]: number } = {}
local activeRuns: { [Player]: boolean } = {}
local reviveCount: { [Player]: number } = {}
local pendingReviveSeconds: { [Player]: number } = {}
local pendingStainBombs: { [Player]: number } = {}

local function collectOwnedPasses(cache: PassCache): { string }
	local owned = {}
	for passKey, def in MonetizationConfig.Gamepasses do
		if def.Id ~= 0 and cache[passKey] == true then
			table.insert(owned, passKey)
		end
	end
	table.sort(owned)
	return owned
end

local function refreshPasses(plr: Player)
	local cache: PassCache = {}
	for passKey, def in MonetizationConfig.Gamepasses do
		local owns = false
		if def.Id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, def.Id)
			owns = ok and result == true
		end
		cache[passKey] = owns
	end

	if plr.Parent ~= Players then
		return
	end
	passCache[plr] = cache
	passFetchedAt[plr] = os.clock()
	Outbound.PassState(plr, collectOwnedPasses(cache))
end

function MonetizationService.HasPass(plr: Player, passKey: string): boolean
	local def = ConfigLookup.GetPass(passKey)
	if def == nil or def.Id == 0 then
		return false
	end

	local now = os.clock()
	if now - (passFetchedAt[plr] or -math.huge) > MonetizationConfig.PassCacheSeconds then
		passFetchedAt[plr] = now
		task.spawn(refreshPasses, plr)
	end

	local cache = passCache[plr]
	return cache ~= nil and cache[passKey] == true
end

local function getPassMultiplier(plr: Player, passKey: string, field: string): number
	if not MonetizationService.HasPass(plr, passKey) then
		return 1
	end
	local def = ConfigLookup.GetPass(passKey)
	if def == nil then
		return 1
	end
	return (def :: any)[field] or 1
end

function MonetizationService.GetCoinMultiplier(plr: Player): number
	local multiplier = getPassMultiplier(plr, "DoubleCoins", "CoinMultiplier")
	local data = DataService.Get(plr)
	if data ~= nil and (data.CoinBoostUntil or 0) > os.time() then
		multiplier *= MonetizationConfig.DevProducts.NewbiePack.CoinBoostMultiplier
	end
	return multiplier
end

function MonetizationService.GetGemMultiplier(plr: Player): number
	return getPassMultiplier(plr, "DoubleGems", "GemMultiplier")
end

local GrantProduct: { [string]: (Player, any, string) -> boolean } = {}

GrantProduct.GemPack = function(plr: Player, entry: any, _purchaseId: string): boolean
	if entry.Gems <= 0 then
		return false
	end
	DataService.AddGems(plr, entry.Gems)
	return true
end

GrantProduct.CoinPack = function(plr: Player, entry: any, _purchaseId: string): boolean
	if entry.Coins <= 0 then
		return false
	end
	DataService.AddCoins(plr, entry.Coins)
	return true
end

GrantProduct.Revive = function(plr: Player, _entry: any, _purchaseId: string): boolean
	if activeRuns[plr] then
		reviveCount[plr] = (reviveCount[plr] or 0) + 1
		RunEvents.ReviveActivated:Fire(plr, MonetizationConfig.ReviveSeconds)
	else
		pendingReviveSeconds[plr] = (pendingReviveSeconds[plr] or 0) + MonetizationConfig.ReviveSeconds
	end
	Outbound.Notify(
		plr,
		"Success",
		string.format(MonetizationConfig.Messages.ReviveGranted, MonetizationConfig.ReviveSeconds)
	)
	return true
end

GrantProduct.StainBomb = function(plr: Player, _entry: any, _purchaseId: string): boolean
	if activeRuns[plr] then
		RunEvents.StainBomb:Fire(plr)
		Outbound.Notify(plr, "Success", MonetizationConfig.Messages.StainBombUsed)
	else
		pendingStainBombs[plr] = (pendingStainBombs[plr] or 0) + 1
	end
	return true
end

GrantProduct.NewbiePack = function(plr: Player, entry: any, _purchaseId: string): boolean
	DataService.AddGems(plr, entry.Gems)
	DataService.AddCoins(plr, entry.Coins)
	if not DataService.HasGrantedPet(plr, entry.PetId) then
		DataService.GrantPet(plr, entry.PetId)
	end

	local data = DataService.Get(plr)
	local boostUntil = if data ~= nil then math.max(data.CoinBoostUntil or 0, os.time()) else os.time()
	DataService.SetCoinBoostUntil(plr, boostUntil + entry.CoinBoostSeconds)

	Outbound.Notify(plr, "Success", MonetizationConfig.Messages.NewbiePackGranted)
	return true
end

MonetizationService.GrantProduct = GrantProduct

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local plr = Players:GetPlayerByUserId(receipt.PlayerId)
	if plr == nil or DataService.Get(plr) == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataService.HasPurchase(plr, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local kind, entry = ConfigLookup.GetDevProduct(receipt.ProductId)
	local handler = if kind ~= nil then GrantProduct[kind] else nil
	if handler == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not handler(plr, entry, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.RecordPurchase(plr, receipt.PurchaseId, MonetizationConfig.MaxPurchaseHistory)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, gamePassId: number, purchased: boolean)
	if not purchased then
		return
	end

	for passKey, def in MonetizationConfig.Gamepasses do
		if def.Id ~= 0 and def.Id == gamePassId then
			local cache = passCache[plr]
			if cache == nil then
				cache = {}
				passCache[plr] = cache
			end
			cache[passKey] = true
			Outbound.PassState(plr, collectOwnedPasses(cache))
			Outbound.Notify(plr, "Success", string.format(MonetizationConfig.Messages.PassPurchased, def.DisplayName))
			return
		end
	end
end)

RunEvents.RunStarted:Connect(function(plr: Player)
	activeRuns[plr] = true
	reviveCount[plr] = 0

	local bombs = pendingStainBombs[plr] or 0
	if bombs > 0 then
		pendingStainBombs[plr] = bombs - 1
		RunEvents.StainBomb:Fire(plr)
	end
end)

RunEvents.RunEnded:Connect(function(plr: Player)
	activeRuns[plr] = nil
	reviveCount[plr] = nil
end)

RunEvents.TimeUp:Connect(function(plr: Player)
	if not activeRuns[plr] then
		return
	end

	local credit = pendingReviveSeconds[plr] or 0
	if credit > 0 then
		pendingReviveSeconds[plr] = nil
		RunEvents.ReviveActivated:Fire(plr, credit)
		return
	end

	local tier = ConfigLookup.GetReviveTier((reviveCount[plr] or 0) + 1)
	if tier == nil or tier.Id == 0 then
		return
	end
	Outbound.ReviveOffer(plr, tier.Id, tier.Tier, MonetizationConfig.ReviveWindow)
end)

local function onPlayerAdded(plr: Player)
	task.spawn(refreshPasses, plr)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, plr in Players:GetPlayers() do
	task.spawn(refreshPasses, plr)
end

Players.PlayerRemoving:Connect(function(plr: Player)
	passCache[plr] = nil
	passFetchedAt[plr] = nil
	activeRuns[plr] = nil
	reviveCount[plr] = nil
	pendingReviveSeconds[plr] = nil
	pendingStainBombs[plr] = nil
end)

return MonetizationService
