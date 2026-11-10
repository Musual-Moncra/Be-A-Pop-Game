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

	Revive: RunService fires RunEvents.TimeUp when a timed run has ReviveOfferAt seconds left and
	keeps the offer open MonetizationConfig.ReviveWindow seconds. This service answers with Outbound.ReviveOffer
	(product id, tier index, seconds). A revive receipt fires RunEvents.ReviveActivated with that
	tier's Seconds so RunService adds them and closes the window. Every revive inside one run moves
	to the next, more expensive tier; once every tier is used the offer stops. A revive bought
	outside a run becomes credit that is spent on the next offer instead of being lost.

	API:
		MonetizationService.HasPass(plr, passKey) -> boolean
		MonetizationService.GetCoinMultiplier(plr) -> number
		MonetizationService.GetGemMultiplier(plr) -> number
		MonetizationService.CanRevive(plr) -> boolean
		MonetizationService.GrantProduct -> { [kind: string]: (plr, entry, purchaseId) -> boolean }
		MonetizationService.PassStateChanged -> Signal (plr) gamepass cache was refreshed

	PetService is required inside the Newbie Pack handler instead of at the top of the file:
	PetService requires this service for the Extra Pet Slots gamepass, so a top-level require
	on both sides would be a cycle.

	Dependencies: MarketplaceService, DataService, PotionService, RunEvents, Outbound, ConfigLookup,
		MonetizationConfig, Signal, PetService (lazily)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local DataService = require(script.Parent.DataService)
local PotionService = require(script.Parent.PotionService)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MonetizationConfig = require(ReplicatedStorage.Modules.Config.MonetizationConfig)

local MonetizationService = {}

MonetizationService.PassStateChanged = Signal.new()

type PassCache = { [string]: boolean }

local passCache: { [Player]: PassCache } = {}
local passFetchedAt: { [Player]: number } = {}
local activeRuns: { [Player]: boolean } = {}
local reviveCount: { [Player]: number } = {}
local pendingReviveSeconds: { [Player]: number } = {}

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
	MonetizationService.PassStateChanged:Fire(plr)
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

local function getPetService(): any
	return require(script.Parent.PetService)
end

GrantProduct.GemPack = function(plr: Player, entry: any, _purchaseId: string): boolean
	if entry.Gems <= 0 then
		return false
	end
	local data = DataService.Get(plr)
	if data == nil then
		return false
	end
	DataService.AddGems(plr, entry.Gems + math.floor(data.Gems * entry.BonusPercent / 100))
	return true
end

GrantProduct.CoinPack = function(plr: Player, entry: any, _purchaseId: string): boolean
	if entry.Coins <= 0 then
		return false
	end
	DataService.AddCoins(plr, entry.Coins)
	return true
end

GrantProduct.Revive = function(plr: Player, entry: any, _purchaseId: string): boolean
	local seconds = entry.Seconds
	if activeRuns[plr] then
		reviveCount[plr] = (reviveCount[plr] or 0) + 1
		RunEvents.ReviveActivated:Fire(plr, seconds)
	else
		pendingReviveSeconds[plr] = (pendingReviveSeconds[plr] or 0) + seconds
	end
	Outbound.Notify(plr, "Success", string.format(MonetizationConfig.Messages.ReviveGranted, seconds))
	return true
end

GrantProduct.Potion = function(plr: Player, entry: any, _purchaseId: string): boolean
	if not PotionService.GrantPotion(plr, entry.Id) then
		return false
	end
	Outbound.Notify(plr, "Success", string.format(MonetizationConfig.Messages.PotionGranted, entry.DisplayName))
	return true
end

GrantProduct.StainBomb = function(plr: Player, _entry: any, _purchaseId: string): boolean
	if activeRuns[plr] then
		RunEvents.StainBomb:Fire(plr)
		Outbound.Notify(plr, "Success", MonetizationConfig.Messages.StainBombUsed)
	else
		local data = DataService.Get(plr)
		if data == nil then
			return false
		end
		data.StainBombs = (tonumber(data.StainBombs) or 0) + 1
		DataService.MarkChanged(plr)
	end
	return true
end

GrantProduct.NewbiePack = function(plr: Player, entry: any, _purchaseId: string): boolean
	local data = DataService.Get(plr)
	if data == nil then
		return false
	end
	if data.NewbiePackClaimed == true then
		Outbound.Notify(plr, "Info", MonetizationConfig.Messages.NewbiePackOwned)
		return true
	end
	data.NewbiePackClaimed = true

	DataService.AddGems(plr, entry.Gems)
	DataService.AddCoins(plr, entry.Coins)

	local PetService = getPetService()
	if not PetService.HasPet(plr, entry.PetId, entry.PetVariant) then
		PetService.GrantPet(plr, entry.PetId, entry.PetVariant)
	end

	local boostUntil = math.max(data.CoinBoostUntil or 0, os.time())
	DataService.SetCoinBoostUntil(plr, boostUntil + entry.CoinBoostSeconds)
	DataService.MarkChanged(plr)

	Outbound.Notify(plr, "Success", MonetizationConfig.Messages.NewbiePackGranted)
	return true
end

MonetizationService.GrantProduct = GrantProduct

function MonetizationService.CanRevive(plr: Player): boolean
	if not activeRuns[plr] then
		return false
	end
	if (pendingReviveSeconds[plr] or 0) > 0 then
		return true
	end
	local tier = ConfigLookup.GetReviveTier((reviveCount[plr] or 0) + 1)
	return tier ~= nil and tier.Id ~= 0
end

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
			MonetizationService.PassStateChanged:Fire(plr)
			Outbound.Notify(plr, "Success", string.format(MonetizationConfig.Messages.PassPurchased, def.DisplayName))
			return
		end
	end
end)

RunEvents.RunStarted:Connect(function(plr: Player)
	activeRuns[plr] = true
	reviveCount[plr] = 0

	local data = DataService.Get(plr)
	local bombs = if data ~= nil then tonumber(data.StainBombs) or 0 else 0
	if data ~= nil and bombs > 0 then
		data.StainBombs = bombs - 1
		DataService.MarkChanged(plr)
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
end)

return MonetizationService
