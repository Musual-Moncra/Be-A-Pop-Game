--!strict

--[[
	PetService
	Owns every player's pet inventory, equipped pets, egg hatching, merging and the
	placeholder pet followers that trail the character. Rolls and prices come from
	PetConfig through ConfigLookup; the server never trusts a client roll or price.

	Hatch flow: validate egg -> map unlocked -> inventory cap -> spend coins -> weighted
	pet roll -> weighted variant roll -> add entry -> publish + PetInventory + HatchResult.
	Multipliers are additive around 1: equipped pets contribute (pet * variant bonus - 1).

	API:
		PetService.HatchEgg(plr, eggId) -> boolean
		PetService.Equip(plr, uid) -> boolean
		PetService.Unequip(plr, uid) -> boolean
		PetService.Delete(plr, uid) -> boolean
		PetService.Merge(plr, uid) -> boolean
		PetService.GetMultipliers(plr) -> { Coins: number, Stink: number }
		PetService.Sync(plr)            re-send the PetInventory packet

	Dependencies: DataService, Outbound, ConfigLookup, PetConfig, MessageConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)

local PetService = {}

local followers: { [Player]: { Instance } } = {}
local synced: { [Player]: boolean } = {}
local uidCounter = 0

local function getPets(plr: Player): any
	local data = DataService.Get(plr)
	if data == nil then
		return nil
	end
	local pets = data.Pets
	if type(pets) ~= "table" then
		pets = { Inventory = {}, Equipped = {}, ExtraSlots = 0 }
		data.Pets = pets
	end
	if type(pets.Inventory) ~= "table" then
		pets.Inventory = {}
	end
	if type(pets.Equipped) ~= "table" then
		pets.Equipped = {}
	end
	if type(pets.ExtraSlots) ~= "number" then
		pets.ExtraSlots = 0
	end
	return pets
end

local function findIndex(pets: any, uid: string): number?
	for index, entry in pets.Inventory do
		if type(entry) == "table" and entry.Uid == uid then
			return index
		end
	end
	return nil
end

local function newUid(pets: any): string
	while true do
		uidCounter += 1
		local uid = string.format("pet%d", uidCounter)
		if findIndex(pets, uid) == nil then
			return uid
		end
	end
end

local function buildState(pets: any): any
	local entries = {}
	for _, entry in pets.Inventory do
		if type(entry) == "table" and type(entry.Uid) == "string" then
			table.insert(entries, { Uid = entry.Uid, PetId = entry.PetId, Variant = entry.Variant })
		end
	end
	local equipped = {}
	for _, uid in pets.Equipped do
		if type(uid) == "string" then
			table.insert(equipped, uid)
		end
	end
	return {
		Pets = entries,
		Equipped = equipped,
		Slots = ConfigLookup.GetMaxEquippedSlots(pets.ExtraSlots),
	}
end

local function clearFollowers(plr: Player)
	local list = followers[plr]
	if list == nil then
		return
	end
	for _, instance in list do
		if instance.Parent ~= nil then
			instance:Destroy()
		end
	end
	followers[plr] = nil
end

local function getFolder(): Folder
	local folder = Workspace:FindFirstChild(PetConfig.FollowFolderName)
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = PetConfig.FollowFolderName
	created.Parent = Workspace
	return created
end

local function createFollower(hrp: BasePart, entry: any, slot: number, folder: Instance, instances: { Instance })
	local pet = ConfigLookup.GetPet(entry.PetId)
	if pet == nil then
		return
	end
	local variant = ConfigLookup.GetVariant(entry.Variant)
	local offsets = PetConfig.FollowOffsets
	local offset = offsets[(slot - 1) % #offsets + 1]

	local model = Instance.new("Model")
	model.Name = PetConfig.FollowModelPrefix .. pet.DisplayName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = PetConfig.FollowShape
	body.Material = PetConfig.FollowMaterial
	body.Color = if variant ~= nil then variant.Color else pet.Color
	body.Size = Vector3.new(pet.Size, pet.Size, pet.Size)
	body.Anchored = false
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = hrp.CFrame * CFrame.new(offset)
	body.Parent = model

	local anchor = Instance.new("Attachment")
	anchor.Name = "PetAnchor"
	anchor.Position = offset
	anchor.Parent = hrp

	local bodyAttachment = Instance.new("Attachment")
	bodyAttachment.Name = "BodyAttachment"
	bodyAttachment.Parent = body

	local align = Instance.new("AlignPosition")
	align.Name = "PetAlign"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = anchor
	align.Attachment1 = bodyAttachment
	align.Responsiveness = PetConfig.FollowResponsiveness
	align.MaxForce = PetConfig.FollowMaxForce
	align.ApplyAtCenterOfMass = true
	align.Parent = body

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "PetOrientation"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = anchor
	orientation.Attachment1 = bodyAttachment
	orientation.Responsiveness = PetConfig.FollowResponsiveness
	orientation.MaxTorque = PetConfig.FollowMaxTorque
	orientation.Parent = body

	model.Parent = folder
	table.insert(instances, anchor)
	table.insert(instances, model)
end

local function rebuild(plr: Player)
	clearFollowers(plr)
	if plr.Parent ~= Players then
		return
	end
	local character = plr.Character
	if character == nil then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp == nil or not hrp:IsA("BasePart") then
		return
	end
	local pets = getPets(plr)
	if pets == nil then
		return
	end
	local folder = getFolder()
	local instances = {}
	for slot, uid in pets.Equipped do
		if type(uid) == "string" then
			local index = findIndex(pets, uid)
			if index ~= nil then
				createFollower(hrp, pets.Inventory[index], slot, folder, instances)
			end
		end
	end
	followers[plr] = instances
end

local function publish(plr: Player)
	DataService.MarkChanged(plr)
	PetService.Sync(plr)
end

function PetService.Sync(plr: Player)
	local pets = getPets(plr)
	if pets == nil then
		return
	end
	Outbound.PetInventory(plr, buildState(pets))
end

function PetService.GetMultipliers(plr: Player): ConfigLookup.PetMultipliers
	local pets = getPets(plr)
	if pets == nil then
		return { Coins = 1, Stink = 1 }
	end
	local coins = 0
	local stink = 0
	for _, uid in pets.Equipped do
		if type(uid) == "string" then
			local index = findIndex(pets, uid)
			if index ~= nil then
				local entry = pets.Inventory[index]
				local multipliers = ConfigLookup.GetPetMultipliers(entry.PetId, entry.Variant)
				coins += multipliers.Coins - 1
				stink += multipliers.Stink - 1
			end
		end
	end
	return { Coins = 1 + coins, Stink = 1 + stink }
end

function PetService.HatchEgg(plr: Player, eggId: string): boolean
	local egg = ConfigLookup.GetEgg(eggId)
	local pets = getPets(plr)
	if egg == nil or pets == nil then
		return false
	end

	if not DataService.IsMapUnlocked(plr, egg.MapId) then
		local mapDef = ConfigLookup.GetMap(egg.MapId)
		local mapName = if mapDef ~= nil then mapDef.DisplayName else egg.MapId
		Outbound.Notify(plr, "Error", string.format(MessageConfig.PetEggLocked, mapName))
		return false
	end

	if #pets.Inventory >= egg.InventoryCap then
		Outbound.Notify(plr, "Error", MessageConfig.PetInventoryFull)
		return false
	end

	local pet = ConfigLookup.RollPet(egg.Id, math.random())
	local variant = ConfigLookup.RollVariant(math.random())
	if pet == nil or variant == nil then
		return false
	end

	if not DataService.SpendCoins(plr, egg.Price) then
		Outbound.Notify(plr, "Error", MessageConfig.NotEnoughCoins)
		return false
	end

	table.insert(pets.Inventory, { Uid = newUid(pets), PetId = pet.Id, Variant = variant.Id })
	publish(plr)
	Outbound.HatchResult(plr, pet.Id, variant.Id)

	local text = if variant.Id == "Default"
		then string.format(MessageConfig.PetHatched, pet.DisplayName)
		else string.format(MessageConfig.PetHatchedVariant, pet.DisplayName, variant.DisplayName)
	Outbound.Notify(plr, "Success", text)
	return true
end

function PetService.Equip(plr: Player, uid: string): boolean
	local pets = getPets(plr)
	if pets == nil or findIndex(pets, uid) == nil then
		return false
	end
	for _, equippedUid in pets.Equipped do
		if equippedUid == uid then
			return false
		end
	end
	if #pets.Equipped >= ConfigLookup.GetMaxEquippedSlots(pets.ExtraSlots) then
		Outbound.Notify(plr, "Error", MessageConfig.PetSlotsFull)
		return false
	end
	table.insert(pets.Equipped, uid)
	publish(plr)
	rebuild(plr)
	return true
end

function PetService.Unequip(plr: Player, uid: string): boolean
	local pets = getPets(plr)
	if pets == nil then
		return false
	end
	for index, equippedUid in pets.Equipped do
		if equippedUid == uid then
			table.remove(pets.Equipped, index)
			publish(plr)
			rebuild(plr)
			return true
		end
	end
	return false
end

function PetService.Delete(plr: Player, uid: string): boolean
	local pets = getPets(plr)
	if pets == nil then
		return false
	end
	local index = findIndex(pets, uid)
	if index == nil then
		return false
	end
	table.remove(pets.Inventory, index)
	for equippedIndex = #pets.Equipped, 1, -1 do
		if pets.Equipped[equippedIndex] == uid then
			table.remove(pets.Equipped, equippedIndex)
		end
	end
	publish(plr)
	rebuild(plr)
	return true
end

function PetService.Merge(plr: Player, uid: string): boolean
	local pets = getPets(plr)
	if pets == nil then
		return false
	end
	local index = findIndex(pets, uid)
	if index == nil then
		return false
	end
	local entry = pets.Inventory[index]
	local pet = ConfigLookup.GetPet(entry.PetId)
	local nextVariant = ConfigLookup.GetNextVariant(entry.Variant)
	if pet == nil or nextVariant == nil then
		if pet ~= nil then
			Outbound.Notify(plr, "Error", MessageConfig.PetMaxVariant)
		end
		return false
	end

	local matches = { index }
	for candidateIndex, candidate in pets.Inventory do
		if #matches >= PetConfig.MaxMergedFrom then
			break
		end
		if
			candidateIndex ~= index
			and type(candidate) == "table"
			and candidate.PetId == entry.PetId
			and candidate.Variant == entry.Variant
		then
			table.insert(matches, candidateIndex)
		end
	end
	if #matches < PetConfig.MaxMergedFrom then
		Outbound.Notify(plr, "Error", MessageConfig.PetMergeNeed)
		return false
	end

	table.sort(matches, function(a, b)
		return a > b
	end)
	for _, removeIndex in matches do
		local removed = table.remove(pets.Inventory, removeIndex)
		if type(removed) == "table" then
			for equippedIndex = #pets.Equipped, 1, -1 do
				if pets.Equipped[equippedIndex] == removed.Uid then
					table.remove(pets.Equipped, equippedIndex)
				end
			end
		end
	end
	table.insert(pets.Inventory, { Uid = newUid(pets), PetId = entry.PetId, Variant = nextVariant })
	publish(plr)
	rebuild(plr)

	local variantDef = ConfigLookup.GetVariant(nextVariant)
	local variantName = if variantDef ~= nil then variantDef.DisplayName else nextVariant
	Outbound.Notify(plr, "Success", string.format(MessageConfig.PetMerged, pet.DisplayName, variantName))
	return true
end

local function onCharacterSpawn(plr: Player)
	task.delay(PetConfig.FollowSpawnDelay, function()
		if plr.Parent == Players then
			rebuild(plr)
		end
	end)
end

local function onPlayerAdded(plr: Player)
	plr.CharacterAdded:Connect(function()
		onCharacterSpawn(plr)
	end)
	plr.CharacterRemoving:Connect(function()
		clearFollowers(plr)
	end)
	if plr.Character ~= nil then
		onCharacterSpawn(plr)
	end
	PetService.Sync(plr)
end

DataService.Changed:Connect(function(plr, data)
	if synced[plr] == true then
		return
	end
	if type(data) ~= "table" or type(data.Pets) ~= "table" then
		return
	end
	synced[plr] = true
	PetService.Sync(plr)
	rebuild(plr)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(plr)
	clearFollowers(plr)
	synced[plr] = nil
end)

for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

return PetService
