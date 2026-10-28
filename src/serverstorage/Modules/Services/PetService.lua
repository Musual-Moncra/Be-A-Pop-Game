--!strict

--[[
	PetService
	Owns every player's pet inventory, equipped pets, egg hatching, merging and the
	placeholder pet followers that trail the character. Rolls and prices come from
	PetConfig through ConfigLookup; the server never trusts a client roll or price.

	Hatch flow: validate egg -> map unlocked -> inventory cap -> spend coins -> weighted
	pet roll -> weighted variant roll -> add entry -> publish + PetInventory + HatchResult.
	Multipliers are additive around 1: equipped pets contribute (pet * variant bonus - 1).

	Equip slots are PetConfig.BaseSlots plus Pets.ExtraSlots plus the live Extra Pet Slots
	gamepass, so buying the pass raises the cap without writing anything into the save.

	API:
		PetService.HatchEgg(plr, eggId) -> boolean
		PetService.Equip(plr, uid) -> boolean
		PetService.Unequip(plr, uid) -> boolean
		PetService.Delete(plr, uid) -> boolean
		PetService.Merge(plr, uid) -> boolean
		PetService.GetMultipliers(plr) -> { Coins: number, Stink: number }
		PetService.HasPet(plr, petId, variantId) -> boolean
		PetService.GrantPet(plr, petId, variantId) -> boolean
		PetService.Sync(plr)            re-send the PetInventory packet

	Dependencies: DataService, Outbound, ConfigLookup, PetConfig, MessageConfig, MonetizationService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
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

local function buildState(pets: any, slots: number): any
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
		Slots = slots,
	}
end

local function getSlotCount(plr: Player, pets: any): number
	local extraSlots = pets.ExtraSlots
	local pass = ConfigLookup.GetPass("ExtraPetSlots")
	if pass ~= nil and pass.ExtraPetSlots > 0 and MonetizationService.HasPass(plr, "ExtraPetSlots") then
		extraSlots += pass.ExtraPetSlots
	end
	return ConfigLookup.GetMaxEquippedSlots(extraSlots)
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
	body.Color = if variant ~= nil and variant.Id ~= "Default" then variant.Color else pet.Color
	body.Size = Vector3.new(pet.Size, pet.Size, pet.Size)
	body.Anchored = false
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = hrp.CFrame * CFrame.new(offset)
	body.Parent = model

	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Material = PetConfig.FollowMaterial
		eye.Color = PetConfig.EyeColor
		eye.Size = Vector3.one * pet.Size * PetConfig.EyeSize
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(side * pet.Size * PetConfig.EyeSpread, pet.Size * PetConfig.EyeHeight, -pet.Size * PetConfig.EyeDepth)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = model
	end

	local anchor = Instance.new("Attachment")
	anchor.Name = "PetAnchor"
	anchor.Position = offset
	anchor.Parent = hrp

	local bodyAttachment = Instance.new("Attachment")
	bodyAttachment.Name = "BodyAttachment"
	bodyAttachment.Parent = body

	local align = Instance.new("AlignPosition")
	align.Name = "PetAlign"
	align.Attachment0 = bodyAttachment
	align.Attachment1 = anchor
	align.Responsiveness = PetConfig.FollowResponsiveness
	align.MaxForce = PetConfig.FollowMaxForce
	align.ApplyAtCenterOfMass = true
	align.Parent = body

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "PetOrientation"
	orientation.Attachment0 = bodyAttachment
	orientation.Attachment1 = anchor
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
	Outbound.PetInventory(plr, buildState(pets, getSlotCount(plr, pets)))
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

function PetService.HasPet(plr: Player, petId: string, variantId: string): boolean
	local pets = getPets(plr)
	if pets == nil then
		return false
	end
	for _, entry in pets.Inventory do
		if type(entry) == "table" and entry.PetId == petId and entry.Variant == variantId then
			return true
		end
	end
	return false
end

function PetService.GrantPet(plr: Player, petId: string, variantId: string): boolean
	local pets = getPets(plr)
	if pets == nil then
		return false
	end
	local pet = ConfigLookup.GetPet(petId)
	local variant = ConfigLookup.GetVariant(variantId)
	if pet == nil or variant == nil then
		return false
	end

	table.insert(pets.Inventory, { Uid = newUid(pets), PetId = petId, Variant = variantId })
	publish(plr)
	return true
end

local function migrateGrantedPets(plr: Player, data: any)
	local granted = data.GrantedPets
	if type(granted) ~= "table" or #granted == 0 then
		return
	end

	local remaining = {}
	for _, petId in granted do
		if type(petId) ~= "string" or ConfigLookup.GetPet(petId) == nil then
			table.insert(remaining, petId)
		elseif not PetService.HasPet(plr, petId, PetConfig.GrantVariant) then
			PetService.GrantPet(plr, petId, PetConfig.GrantVariant)
		end
	end
	if #remaining ~= #granted then
		DataService.SetGrantedPets(plr, remaining)
	end
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
	if #pets.Equipped >= getSlotCount(plr, pets) then
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
	if type(data) ~= "table" or type(data.Pets) ~= "table" then
		return
	end
	migrateGrantedPets(plr, data)
	if synced[plr] == true then
		return
	end
	synced[plr] = true
	PetService.Sync(plr)
	rebuild(plr)
end)

MonetizationService.PassStateChanged:Connect(function(plr: Player)
	PetService.Sync(plr)
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
