--!strict

--[[
	CosmeticService
	Manages player cosmetics, crate opening, equipping skins/trails, and character visual attachments.

	API:
		CosmeticService.OpenCrate(plr: Player, crateId: string): boolean
		CosmeticService.Equip(plr: Player, kind: string, id: string): boolean
		CosmeticService.ApplyCosmetics(plr: Player, character: Model?)

	Dependencies: DataService, Outbound, ConfigLookup, MessageConfig, CosmeticConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(ServerStorage.Modules.Services.DataService)
local Outbound = require(ServerStorage.Modules.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.Config.CosmeticConfig)

local CosmeticService = {}

local CharacterCosmeticsApplied: { [Player]: boolean } = {}

local function rollDrop(crateDef: any): { Kind: string, Id: string }?
	local drops = crateDef.Drops
	if drops == nil or #drops == 0 then
		return nil
	end

	local totalWeight = 0
	for _, entry in drops do
		totalWeight += entry.Weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in drops do
		cumulative += entry.Weight
		if roll <= cumulative then
			return { Kind = entry.Kind, Id = entry.Id }
		end
	end

	return drops[#drops]
end

function CosmeticService.OpenCrate(plr: Player, crateId: string): boolean
	local crate = ConfigLookup.GetCrate(crateId)
	local data = DataService.Get(plr)
	if crate == nil or data == nil then
		Outbound.Notify(plr, "Error", MessageConfig.InvalidCrate)
		return false
	end

	if crate.CostType == "Coins" then
		if not DataService.SpendCoins(plr, crate.Cost) then
			Outbound.Notify(plr, "Error", MessageConfig.NotEnoughCoins)
			return false
		end
	elseif crate.CostType == "Gems" then
		if not DataService.SpendGems(plr, crate.Cost) then
			Outbound.Notify(plr, "Error", MessageConfig.NotEnoughGems)
			return false
		end
	else
		return false
	end

	local drop = rollDrop(crate)
	if drop == nil then
		return false
	end

	local isNew = false
	local refund = 0

	if drop.Kind == "Skin" then
		local ownedSkins = data.OwnedSkins or {}
		if ownedSkins[drop.Id] then
			refund = CosmeticConfig.DuplicateCoinRefund
			DataService.AddCoins(plr, refund)
			Outbound.Notify(plr, "Info", string.format(MessageConfig.CosmeticDuplicate, refund))
		else
			ownedSkins[drop.Id] = true
			data.OwnedSkins = ownedSkins
			isNew = true
			local skinDef = ConfigLookup.GetSkin(drop.Id)
			local name = if skinDef ~= nil then skinDef.DisplayName else drop.Id
			Outbound.Notify(plr, "Success", string.format(MessageConfig.CosmeticUnlocked, name))
		end
	elseif drop.Kind == "Trail" then
		local ownedTrails = data.OwnedTrails or {}
		if ownedTrails[drop.Id] then
			refund = CosmeticConfig.DuplicateCoinRefund
			DataService.AddCoins(plr, refund)
			Outbound.Notify(plr, "Info", string.format(MessageConfig.CosmeticDuplicate, refund))
		else
			ownedTrails[drop.Id] = true
			data.OwnedTrails = ownedTrails
			isNew = true
			local trailDef = ConfigLookup.GetTrail(drop.Id)
			local name = if trailDef ~= nil then trailDef.DisplayName else drop.Id
			Outbound.Notify(plr, "Success", string.format(MessageConfig.CosmeticUnlocked, name))
		end
	end

	DataService.MarkChanged(plr)

	Outbound.CrateResult(plr, {
		CrateId = crateId,
		Kind = drop.Kind,
		Id = drop.Id,
		IsNew = isNew,
		Refund = refund,
	})

	return true
end

function CosmeticService.Equip(plr: Player, kind: string, id: string): boolean
	local data = DataService.Get(plr)
	if data == nil then
		return false
	end

	if kind == "Skin" then
		if id == "" or id == "Default" then
			data.EquippedSkin = "Default"
			DataService.MarkChanged(plr)
			CosmeticService.ApplyCosmetics(plr, plr.Character)
			Outbound.Notify(plr, "Success", MessageConfig.CosmeticUnequipped)
			return true
		end

		local owned = data.OwnedSkins or {}
		if not owned[id] then
			Outbound.Notify(plr, "Error", MessageConfig.CosmeticNotOwned)
			return false
		end

		data.EquippedSkin = id
		DataService.MarkChanged(plr)
		CosmeticService.ApplyCosmetics(plr, plr.Character)
		local skinDef = ConfigLookup.GetSkin(id)
		local name = if skinDef ~= nil then skinDef.DisplayName else id
		Outbound.Notify(plr, "Success", string.format(MessageConfig.CosmeticEquipped, name))
		return true

	elseif kind == "Trail" then
		if id == "" then
			data.EquippedTrail = ""
			DataService.MarkChanged(plr)
			CosmeticService.ApplyCosmetics(plr, plr.Character)
			Outbound.Notify(plr, "Success", MessageConfig.CosmeticUnequipped)
			return true
		end

		local owned = data.OwnedTrails or {}
		if not owned[id] then
			Outbound.Notify(plr, "Error", MessageConfig.CosmeticNotOwned)
			return false
		end

		data.EquippedTrail = id
		DataService.MarkChanged(plr)
		CosmeticService.ApplyCosmetics(plr, plr.Character)
		local trailDef = ConfigLookup.GetTrail(id)
		local name = if trailDef ~= nil then trailDef.DisplayName else id
		Outbound.Notify(plr, "Success", string.format(MessageConfig.CosmeticEquipped, name))
		return true
	end

	return false
end

function CosmeticService.ApplyCosmetics(plr: Player, character: Model?)
	character = character or plr.Character
	if character == nil then
		return
	end

	local data = DataService.Get(plr)
	if data == nil then
		return
	end

	local skinId = data.EquippedSkin or "Default"
	local skinDef = ConfigLookup.GetSkin(skinId) or ConfigLookup.GetSkin("Default")

	-- Apply skin to body parts
	local body = character:FindFirstChild("Body")
	if body ~= nil and skinDef ~= nil then
		local tierParts = { "TierBottom", "TierMiddle", "TierTop", "Tip" }
		for _, partName in tierParts do
			local part = body:FindFirstChild(partName) :: BasePart?
			if part ~= nil and part:IsA("BasePart") then
				part.Color = skinDef.Color
				part.Material = skinDef.Material
			end
		end
	end

	-- Apply trail to HumanoidRootPart
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp ~= nil and hrp:IsA("BasePart") then
		local existingTrail = hrp:FindFirstChild("CosmeticTrail")
		if existingTrail ~= nil then
			existingTrail:Destroy()
		end

		local trailId = data.EquippedTrail or ""
		if trailId ~= "" then
			local trailDef = ConfigLookup.GetTrail(trailId)
			if trailDef ~= nil then
				local att0 = hrp:FindFirstChild("TrailAttachment0") :: Attachment?
				if att0 == nil then
					att0 = Instance.new("Attachment")
					att0.Name = "TrailAttachment0"
					att0.Position = Vector3.new(0, 1, 0)
					att0.Parent = hrp
				end

				local att1 = hrp:FindFirstChild("TrailAttachment1") :: Attachment?
				if att1 == nil then
					att1 = Instance.new("Attachment")
					att1.Name = "TrailAttachment1"
					att1.Position = Vector3.new(0, -1, 0)
					att1.Parent = hrp
				end

				local trail = Instance.new("Trail")
				trail.Name = "CosmeticTrail"
				trail.Attachment0 = att0
				trail.Attachment1 = att1
				trail.Color = trailDef.Color
				trail.Lifetime = trailDef.Lifetime
				trail.WidthScale = trailDef.WidthScale
				trail.Transparency = trailDef.Transparency
				trail.Texture = trailDef.Texture
				trail.Parent = hrp
			end
		end
	end
end

local function trackPlayer(plr: Player)
	plr.CharacterAdded:Connect(function(character)
		CosmeticService.ApplyCosmetics(plr, character)
	end)
	if plr.Character ~= nil then
		task.spawn(CosmeticService.ApplyCosmetics, plr, plr.Character)
	end
end

Players.PlayerAdded:Connect(trackPlayer)
for _, plr in Players:GetPlayers() do
	trackPlayer(plr)
end

Players.PlayerRemoving:Connect(function(plr)
	CharacterCosmeticsApplied[plr] = nil
end)

DataService.Changed:Connect(function(plr, data)
	Outbound.CosmeticState(
		plr,
		data.EquippedSkin or "Default",
		data.EquippedTrail or "",
		data.OwnedSkins or {},
		data.OwnedTrails or {}
	)

	if not CharacterCosmeticsApplied[plr] then
		CharacterCosmeticsApplied[plr] = true
		CosmeticService.ApplyCosmetics(plr, plr.Character)
	end
end)

return CosmeticService
