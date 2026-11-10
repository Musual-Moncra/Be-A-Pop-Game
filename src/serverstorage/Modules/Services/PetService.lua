--!strict

--[[
	PetService
	Owns every player's pet inventory, equipped pets, map-clear drops, stink stacks, merging,
	the Pet Index and the placeholder followers that trail the character. Rolls, odds and every
	price come from PetConfig through ConfigLookup; the server never trusts a client roll.

	Drop flow: a run reaches 100% map stain -> RollDrop -> weighted pet roll by 1/DropOdds ->
	weighted variant roll by 1/DropOdds -> add entry or pay FullInventoryGems when the
	inventory is full -> PetDrop. Pet poop during a run adds Stacks and pays PoopGems.

	Pet Index: every obtained pet marks its variant discovered. When all non-exclusive pets of a
	map are discovered, the map's exclusive pet and IndexGems are paid once.

	Equip slots are PetConfig.BaseSlots plus Pets.ExtraSlots plus the live Extra Pet Slots
	gamepass, so buying the pass raises the cap without writing anything into the save.

	API:
		PetService.RollDrop(plr, mapId) -> boolean
		PetService.Equip(plr, uid) -> boolean
		PetService.Unequip(plr, uid) -> boolean
		PetService.Delete(plr, uid) -> boolean
		PetService.Merge(plr, uid) -> boolean
		PetService.GetMultipliers(plr) -> { Stink: number }
		PetService.HasPet(plr, petId, variantId) -> boolean
		PetService.GrantPet(plr, petId, variantId) -> boolean
		PetService.Sync(plr)            re-send the PetInventory packet

	Dependencies: DataService, MonetizationService, PotionService, Outbound, RunEvents,
		ConfigLookup, CharacterConfig, PetConfig, MessageConfig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Heartbeat = game:GetService("RunService").Heartbeat

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PotionService = require(script.Parent.PotionService)
local Outbound = require(script.Parent.Parent.Remotes.Outbound)
local RunEvents = require(script.Parent.Parent.Shared.RunEvents)
local ConfigLookup = require(ReplicatedStorage.Modules.Shared.ConfigLookup)
local CharacterConfig = require(ReplicatedStorage.Modules.Config.CharacterConfig)
local MessageConfig = require(ReplicatedStorage.Modules.Config.MessageConfig)
local PetConfig = require(ReplicatedStorage.Modules.Config.PetConfig)

local PetService = {}

local NEUTRAL_MULTIPLIERS: ConfigLookup.PetMultipliers = table.freeze({ Stink = 1 })

local followers: { [Player]: { Instance } } = {}
local synced: { [Player]: boolean } = {}
local legacyChecked: { [Player]: boolean } = {}
local poopPlayers: { [Player]: boolean } = {}
local poopAccumulator = 0
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
	for _, entry in pets.Inventory do
		if type(entry) == "table" and type(entry.Stacks) ~= "number" then
			entry.Stacks = 0
		end
	end
	return pets
end

local function getIndex(data: any): (any, any)
	local index = data.PetIndex
	if type(index) ~= "table" then
		index = {}
		data.PetIndex = index
	end
	local claimed = data.PetIndexClaimed
	if type(claimed) ~= "table" then
		claimed = {}
		data.PetIndexClaimed = claimed
	end
	return index, claimed
end

local function markDiscovered(index: any, petId: string, variantId: string)
	local variants = index[petId]
	if type(variants) ~= "table" then
		variants = {}
		index[petId] = variants
	end
	variants[variantId] = true
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
	for _, entry in pets.Inventory do
		if type(entry) == "table" and type(entry.Uid) == "string" then
			local num = tonumber(string.match(entry.Uid, "^pet(%d+)$"))
			if num ~= nil and num > uidCounter then
				uidCounter = num
			end
		end
	end
	uidCounter += 1
	return string.format("pet%d", uidCounter)
end

local function addPet(pets: any, petId: string, variantId: string, stacks: number): any
	local entry = { Uid = newUid(pets), PetId = petId, Variant = variantId, Stacks = stacks }
	table.insert(pets.Inventory, entry)
	return entry
end

local function recordIndex(plr: Player, pets: any, petId: string, variantId: string)
	local data = DataService.Get(plr)
	if data == nil then
		return
	end
	local index, claimed = getIndex(data)
	markDiscovered(index, petId, variantId)

	local pet = ConfigLookup.GetPet(petId)
	if pet == nil or pet.MapId == "" or pet.Exclusive then
		return
	end
	if claimed[pet.MapId] == true then
		return
	end

	for _, poolPet in ConfigLookup.GetPetsForMap(pet.MapId) do
		local variants = index[poolPet.Id]
		if type(variants) ~= "table" or next(variants) == nil then
			return
		end
	end

	claimed[pet.MapId] = true
	local exclusive = ConfigLookup.GetExclusivePet(pet.MapId)
	if exclusive ~= nil then
		addPet(pets, exclusive.Id, PetConfig.GrantVariant, 0)
		markDiscovered(index, exclusive.Id, PetConfig.GrantVariant)
	end
	if PetConfig.IndexGems > 0 then
		DataService.AddGems(plr, PetConfig.IndexGems)
	end
	if exclusive ~= nil then
		Outbound.Notify(
			plr,
			"Success",
			string.format(MessageConfig.PetIndexComplete, exclusive.DisplayName, PetConfig.IndexGems)
		)
	end
end

local function buildState(plr: Player, pets: any, slots: number, stink: number): any
	local entries = {}
	for _, entry in pets.Inventory do
		if type(entry) == "table" and type(entry.Uid) == "string" then
			table.insert(entries, {
				Uid = entry.Uid,
				PetId = entry.PetId,
				Variant = entry.Variant,
				Stacks = math.max(0, math.floor(entry.Stacks or 0)),
			})
		end
	end
	local equipped = {}
	for _, uid in pets.Equipped do
		if type(uid) == "string" then
			table.insert(equipped, uid)
		end
	end

	local indexPayload = {}
	local claimedPayload = {}
	local data = DataService.Get(plr)
	if data ~= nil then
		local index, claimed = getIndex(data)
		for petId, variants in pairs(index) do
			if type(petId) == "string" and type(variants) == "table" then
				for variantId in pairs(variants) do
					if type(variantId) == "string" then
						table.insert(indexPayload, { PetId = petId, Variant = variantId })
					end
				end
			end
		end
		for mapId in pairs(claimed) do
			if type(mapId) == "string" then
				table.insert(claimedPayload, mapId)
			end
		end
	end

	return {
		Pets = entries,
		Equipped = equipped,
		Slots = slots,
		Stink = stink,
		Index = indexPayload,
		IndexClaimed = claimedPayload,
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

local function getPetModelTemplate(pet: any): Model?
	if pet.ModelName == "" then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = if assets ~= nil then assets:FindFirstChild("Models") else nil
	local folder = if models ~= nil then models:FindFirstChild("Pets") else nil
	local template = if folder ~= nil then folder:FindFirstChild(pet.ModelName) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end
	return template
end

local function preparePetModel(template: Model, pet: any): Model?
	local model = template:Clone()
	if model.PrimaryPart == nil then
		model:Destroy()
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
			local joint = descendant :: any
			local part0 = joint.Part0
			local part1 = joint.Part1
			if part0 == nil or part1 == nil or not (part0:IsDescendantOf(model) and part1:IsDescendantOf(model)) then
				joint:Destroy()
			end
		end
	end

	local extents = model:GetExtentsSize()
	local longest = math.max(extents.X, extents.Y, extents.Z)
	if longest > 0 and pet.Size > 0 then
		model:ScaleTo(model:GetScale() * pet.Size / longest)
	end
	return model
end

local function tintVariant(model: Model, variant: any)
	if variant == nil or variant.Id == "Default" then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = variant.Color
			local surface = descendant:FindFirstChildOfClass("SurfaceAppearance")
			if surface ~= nil then
				surface.Color = variant.Color
			end
		end
	end
end

local function addVariantVfx(primary: BasePart, variant: any)
	if variant == nil or variant.VfxRate <= 0 then
		return
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "VariantSparkle"
	emitter.Texture = PetConfig.VfxParticleTexture
	emitter.Color = ColorSequence.new(variant.VfxColor)
	emitter.Rate = variant.VfxRate
	emitter.Lifetime = NumberRange.new(PetConfig.VfxParticleLifetime.Min, PetConfig.VfxParticleLifetime.Max)
	emitter.Speed = NumberRange.new(PetConfig.VfxParticleSpeed.Min, PetConfig.VfxParticleSpeed.Max)
	emitter.Size = PetConfig.VfxParticleSize
	emitter.Transparency = PetConfig.VfxParticleTransparency
	emitter.LightEmission = PetConfig.VfxParticleLightEmission
	emitter.SpreadAngle = PetConfig.VfxParticleSpreadAngle
	emitter.Parent = primary
end

local function attachFollower(hrp: BasePart, model: Model, primary: BasePart, offset: Vector3, instances: { Instance })
	local anchor = Instance.new("Attachment")
	anchor.Name = "PetAnchor"
	anchor.Position = offset
	anchor.Parent = hrp

	local bodyAttachment = Instance.new("Attachment")
	bodyAttachment.Name = "BodyAttachment"
	bodyAttachment.Parent = primary

	local align = Instance.new("AlignPosition")
	align.Name = "PetAlign"
	align.Attachment0 = bodyAttachment
	align.Attachment1 = anchor
	align.Responsiveness = PetConfig.FollowResponsiveness
	align.MaxForce = PetConfig.FollowMaxForce
	align.ApplyAtCenterOfMass = true
	align.Parent = primary

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "PetOrientation"
	orientation.Attachment0 = bodyAttachment
	orientation.Attachment1 = anchor
	orientation.Responsiveness = PetConfig.FollowResponsiveness
	orientation.MaxTorque = PetConfig.FollowMaxTorque
	orientation.Parent = primary

	table.insert(instances, anchor)
	table.insert(instances, model)
end

local function createPlaceholder(pet: any, variant: any): (Model, BasePart)
	local model = Instance.new("Model")
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
		eye.CFrame = body.CFrame
			* CFrame.new(
				side * pet.Size * PetConfig.EyeSpread,
				pet.Size * PetConfig.EyeHeight,
				-pet.Size * PetConfig.EyeDepth
			)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = model
	end

	return model, body
end

local function createFollower(hrp: BasePart, entry: any, slot: number, folder: Instance, instances: { Instance })
	local pet = ConfigLookup.GetPet(entry.PetId)
	if pet == nil then
		return
	end
	local variant = ConfigLookup.GetVariant(entry.Variant)
	local offsets = PetConfig.FollowOffsets
	local offset = CharacterConfig.HitboxOffset + offsets[(slot - 1) % #offsets + 1]

	local template = getPetModelTemplate(pet)
	if template ~= nil then
		local model = preparePetModel(template, pet)
		local primary = if model ~= nil then model.PrimaryPart else nil
		if model ~= nil and primary ~= nil then
			model.Name = PetConfig.FollowModelPrefix .. pet.DisplayName
			tintVariant(model, variant)
			addVariantVfx(primary, variant)
			attachFollower(hrp, model, primary, offset, instances)
			model.Parent = folder
			model:PivotTo(hrp.CFrame * CFrame.new(offset))
			return
		end
		if model ~= nil then
			model:Destroy()
		end
	end

	local model, body = createPlaceholder(pet, variant)
	model.Name = PetConfig.FollowModelPrefix .. pet.DisplayName
	body.CFrame = hrp.CFrame * CFrame.new(offset)
	addVariantVfx(body, variant)
	attachFollower(hrp, model, body, offset, instances)
	model.Parent = folder
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
	local stink = PetService.GetMultipliers(plr).Stink
	Outbound.PetInventory(plr, buildState(plr, pets, getSlotCount(plr, pets), stink))
end

function PetService.GetMultipliers(plr: Player): ConfigLookup.PetMultipliers
	local pets = getPets(plr)
	if pets == nil then
		return NEUTRAL_MULTIPLIERS
	end
	local stink = 1
	for _, uid in pets.Equipped do
		if type(uid) == "string" then
			local index = findIndex(pets, uid)
			if index ~= nil then
				local entry = pets.Inventory[index]
				stink *= ConfigLookup.GetPetMultipliers(entry.PetId, entry.Variant, entry.Stacks).Stink
			end
		end
	end
	stink *= PotionService.GetMultiplier(plr, "Stink")
	return { Stink = stink }
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

	addPet(pets, petId, variantId, 0)
	recordIndex(plr, pets, petId, variantId)
	publish(plr)
	return true
end

local function migrateLegacyPets(plr: Player)
	local pets = getPets(plr)
	if pets == nil or legacyChecked[plr] == true then
		return
	end
	legacyChecked[plr] = true

	local removed = 0
	for index = #pets.Inventory, 1, -1 do
		local entry = pets.Inventory[index]
		if type(entry) ~= "table" or type(entry.PetId) ~= "string" or ConfigLookup.GetPet(entry.PetId) == nil then
			table.remove(pets.Inventory, index)
			removed += 1
		end
	end
	if removed == 0 then
		return
	end

	local equippedChanged = false
	for index = #pets.Equipped, 1, -1 do
		local uid = pets.Equipped[index]
		if type(uid) ~= "string" or findIndex(pets, uid) == nil then
			table.remove(pets.Equipped, index)
			equippedChanged = true
		end
	end

	local gems = removed * PetConfig.LegacyPetGems
	if gems > 0 then
		DataService.AddGems(plr, gems)
	end
	Outbound.Notify(plr, "Info", string.format(MessageConfig.LegacyPetsRemoved, removed, gems))
	DataService.MarkChanged(plr)
	if equippedChanged then
		rebuild(plr)
	end
	PetService.Sync(plr)
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

function PetService.RollDrop(plr: Player, mapId: string): boolean
	local pets = getPets(plr)
	if pets == nil then
		return false
	end
	local pet = ConfigLookup.RollPet(mapId, math.random())
	local variant = ConfigLookup.RollVariant(math.random())
	if pet == nil or variant == nil then
		return false
	end

	local converted = 0
	local isNew = false
	if #pets.Inventory >= PetConfig.InventoryCap then
		converted = PetConfig.FullInventoryGems
		if converted > 0 then
			DataService.AddGems(plr, converted)
		end
		Outbound.Notify(plr, "Info", string.format(MessageConfig.PetConverted, converted))
	else
		isNew = not PetService.HasPet(plr, pet.Id, variant.Id)
		addPet(pets, pet.Id, variant.Id, 0)
		recordIndex(plr, pets, pet.Id, variant.Id)
		DataService.MarkChanged(plr)
	end

	Outbound.PetDrop(plr, pet.Id, variant.Id, isNew, converted)
	PetService.Sync(plr)
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
	local equippedChanged = false
	for equippedIndex = #pets.Equipped, 1, -1 do
		if pets.Equipped[equippedIndex] == uid then
			table.remove(pets.Equipped, equippedIndex)
			equippedChanged = true
		end
	end
	if equippedChanged then
		publish(plr)
		rebuild(plr)
	else
		DataService.MarkChanged(plr)
		PetService.Sync(plr)
	end
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
	local equippedChanged = false
	for _, removeIndex in matches do
		local removed = table.remove(pets.Inventory, removeIndex)
		if type(removed) == "table" then
			for equippedIndex = #pets.Equipped, 1, -1 do
				if pets.Equipped[equippedIndex] == removed.Uid then
					table.remove(pets.Equipped, equippedIndex)
					equippedChanged = true
				end
			end
		end
	end
	addPet(pets, entry.PetId, nextVariant, 0)
	recordIndex(plr, pets, entry.PetId, nextVariant)
	if equippedChanged then
		publish(plr)
		rebuild(plr)
	else
		DataService.MarkChanged(plr)
		PetService.Sync(plr)
	end

	local variantDef = ConfigLookup.GetVariant(nextVariant)
	local variantName = if variantDef ~= nil then variantDef.DisplayName else nextVariant
	Outbound.Notify(plr, "Success", string.format(MessageConfig.PetMerged, pet.DisplayName, variantName))
	return true
end

local function poop(plr: Player)
	local pets = getPets(plr)
	if pets == nil then
		return
	end
	local gain = math.max(1, math.floor(DataService.GetBoostMultiplier(plr, "Stacks")))
	local changed = false
	for _, uid in pets.Equipped do
		if type(uid) == "string" then
			local index = findIndex(pets, uid)
			if index ~= nil then
				local entry = pets.Inventory[index]
				local stacks = (tonumber(entry.Stacks) or 0) + gain
				entry.Stacks = math.min(stacks, PetConfig.StackCap)
				local gems = 0
				if math.random() < PetConfig.PoopGemChance then
					gems = PetConfig.PoopGems
					if gems > 0 then
						DataService.AddGems(plr, gems)
					end
				end
				Outbound.PetPoop(plr, uid, gems)
				Outbound.PetStacks(plr, uid, entry.Stacks)
				changed = true
			end
		end
	end
	if changed then
		DataService.MarkChanged(plr)
	end
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

RunEvents.RunStarted:Connect(function(plr: Player)
	poopPlayers[plr] = true
end)

RunEvents.RunEnded:Connect(function(plr: Player)
	poopPlayers[plr] = nil
end)

Heartbeat:Connect(function(dt)
	if next(poopPlayers) == nil then
		poopAccumulator = 0
		return
	end
	poopAccumulator += dt
	if poopAccumulator < PetConfig.PoopInterval then
		return
	end
	poopAccumulator %= PetConfig.PoopInterval
	for plr in pairs(poopPlayers) do
		if plr.Parent == Players then
			poop(plr)
		end
	end
end)

DataService.Changed:Connect(function(plr, data)
	if type(data) ~= "table" or type(data.Pets) ~= "table" then
		return
	end
	migrateLegacyPets(plr)
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
	legacyChecked[plr] = nil
	poopPlayers[plr] = nil
end)

for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

return PetService
