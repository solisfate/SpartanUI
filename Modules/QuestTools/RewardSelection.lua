local SUI, L = SUI, SUI.L
---@class SUI.Module.QuestTools
local module = SUI:GetModule('QuestTools')
----------------------------------------------------------------------------------------------------

local SLOTS = {
	['INVTYPE_AMMO'] = { 'AmmoSlot' },
	['INVTYPE_HEAD'] = { 'HeadSlot' },
	['INVTYPE_NECK'] = { 'NeckSlot' },
	['INVTYPE_SHOULDER'] = { 'ShoulderSlot' },
	['INVTYPE_CHEST'] = { 'ChestSlot' },
	['INVTYPE_WAIST'] = { 'WaistSlot' },
	['INVTYPE_LEGS'] = { 'LegsSlot' },
	['INVTYPE_FEET'] = { 'FeetSlot' },
	['INVTYPE_WRIST'] = { 'WristSlot' },
	['INVTYPE_HAND'] = { 'HandsSlot' },
	['INVTYPE_FINGER'] = { 'Finger0Slot', 'Finger1Slot' },
	['INVTYPE_TRINKET'] = { 'Trinket0Slot', 'Trinket1Slot' },
	['INVTYPE_CLOAK'] = { 'BackSlot' },
	['INVTYPE_WEAPON'] = { 'MainHandSlot', 'SecondaryHandSlot' },
	['INVTYPE_2HWEAPON'] = { 'MainHandSlot' },
	['INVTYPE_RANGED'] = { 'MainHandSlot' },
	['INVTYPE_RANGEDRIGHT'] = { 'MainHandSlot' },
	['INVTYPE_WEAPONMAINHAND'] = { 'MainHandSlot' },
	['INVTYPE_SHIELD'] = { 'SecondaryHandSlot' },
	['INVTYPE_WEAPONOFFHAND'] = { 'SecondaryHandSlot' },
	['INVTYPE_HOLDABLE'] = { 'SecondaryHandSlot' },
}

local WEAPON_SLOTS = {
	['MainHandSlot'] = true,
	['SecondaryHandSlot'] = true,
}

---@return boolean
local function IsPawnAvailable()
	return PawnIsReady and PawnIsReady() and PawnGetItemData and PawnIsItemAnUpgrade
end

---@param itemLink string
---@return number|nil percentUpgrade Whole number (5 = 5%), 0 if not upgrade, nil if unavailable
---@return string|nil scaleName
---@return boolean usedPawn
local function GetPawnUpgradeInfo(itemLink)
	if not itemLink or not IsPawnAvailable() then
		return nil, nil, false
	end
	local Item = PawnGetItemData(itemLink)
	if not Item then
		return nil, nil, false
	end
	local UpgradeTable = PawnIsItemAnUpgrade(Item)
	if not UpgradeTable or #UpgradeTable == 0 then
		return 0, nil, true
	end
	local bestPercent, bestScaleName = 0, nil
	for _, info in ipairs(UpgradeTable) do
		if info.PercentUpgrade and info.PercentUpgrade > bestPercent then
			bestPercent = info.PercentUpgrade
			bestScaleName = info.LocalizedScaleName
		end
	end
	return math.floor(bestPercent * 100 + 0.5), bestScaleName, true
end

---@param itemLink string|nil
---@return number itemLevel (0 if unavailable, math.huge if heirloom)
local function GetItemLevel(itemLink)
	if not itemLink then
		return 0
	end
	local itemQuality = select(3, C_Item.GetItemInfo(itemLink))
	if itemQuality == 7 then
		return math.huge
	end
	local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
	return type(ilvl) == 'number' and ilvl or 0
end

function module:InitializeRewardSelection()
	-- Nothing special needed, just ensure module functions are available
end

function module:EquipItem(ItemToEquip)
	if InCombatLockdown() then
		return
	end

	local EquipItemName = C_Item.GetItemInfo(ItemToEquip)
	local EquipILvl = C_Item.GetDetailedItemLevelInfo(ItemToEquip)
	local ItemFound = false

	-- Make sure it is in the bags
	for bag = 0, NUM_BAG_SLOTS do
		if ItemFound then
			return
		end
		for slot = 1, C_Container.GetContainerNumSlots(bag), 1 do
			local link = C_Container.GetContainerItemLink(bag, slot)
			if link then
				local slotItemName = C_Item.GetItemInfo(link)
				local SlotILvl = C_Item.GetDetailedItemLevelInfo(link)
				if (slotItemName == EquipItemName) and (SlotILvl == EquipILvl) then
					if module.IsMerchantOpen then
						SUI:Print(L['Unable to equip'] .. ' ' .. link)
						module:CancelAllTimers()
					else
						SUI:Print(L['Equipping reward'] .. ' ' .. link)
						C_Container.UseContainerItem(bag, slot)
						module:CancelAllTimers()
						ItemFound = true
						return
					end
				end
			end
		end
	end
end

function module:HandleQuestComplete()
	local DB = module:GetDB()

	if not DB.TurnInEnabled then
		return
	end

	local greedID, greedValue, greedLink = nil, 0, nil
	local upgradeID, upgradeLink, upgradeAmount = nil, nil, 0
	local upgradeReason = nil
	local hasWeaponReward = false
	local hasPawn = IsPawnAvailable()

	for i = 1, GetNumQuestChoices() do
		local link = GetQuestItemLink('choice', i)
		module.debug(link)
		if link == nil then
			return
		end
		local _, _, _, _, _, _, _, _, itemEquipLoc, _, itemSellPrice = C_Item.GetItemInfo(link)

		if itemSellPrice and itemSellPrice > greedValue then
			greedValue = itemSellPrice
			greedID = i
			greedLink = link
		end

		local slot = SLOTS[itemEquipLoc]
		if slot then
			if WEAPON_SLOTS[slot[1]] then
				hasWeaponReward = true
			end

			local pawnPercent, scaleName, usedPawn = GetPawnUpgradeInfo(link)
			if usedPawn and pawnPercent and pawnPercent > 0 then
				if pawnPercent > upgradeAmount then
					upgradeID = i
					upgradeLink = link
					upgradeAmount = pawnPercent
					upgradeReason = 'Pawn +' .. pawnPercent .. '% (' .. (scaleName or 'best') .. ')'
				end
			elseif not usedPawn then
				local rewardIlvl = GetItemLevel(link)
				if rewardIlvl == math.huge then
					-- skip heirlooms
				elseif rewardIlvl > 0 then
					local lowestEquipped = math.huge
					for _, slotName in ipairs(slot) do
						local slotID = GetInventorySlotInfo(slotName)
						local equippedLink = GetInventoryItemLink('player', slotID)
						local equippedIlvl = GetItemLevel(equippedLink)
						if equippedIlvl < lowestEquipped then
							lowestEquipped = equippedIlvl
						end
					end
					local delta = rewardIlvl - lowestEquipped
					module.debug('iLVL comparison ' .. link .. ' reward=' .. rewardIlvl .. ' equipped=' .. lowestEquipped)
					if delta > 0 and delta > upgradeAmount then
						upgradeID = i
						upgradeLink = link
						upgradeAmount = delta
						upgradeReason = '+' .. delta .. ' ilvl'
					end
				end
			end
		end
	end

	local numChoices = GetNumQuestChoices()
	module.debug('Choices: ' .. numChoices .. ' weapon=' .. tostring(hasWeaponReward) .. ' pawn=' .. tostring(hasPawn))

	if numChoices > 1 then
		if hasWeaponReward and not hasPawn and not upgradeID then
			SUI:Print('Quest has weapon rewards - install Pawn for smarter selection')
			return
		end

		if not DB.lootreward then
			if upgradeID then
				SUI:Print('Would select upgrade ' .. upgradeLink .. ' (' .. upgradeReason .. ')')
			elseif greedID then
				SUI:Print('Would vendor: ' .. greedLink .. ' worth ' .. SUI:GoldFormattedValue(greedValue))
			end
			return
		end

		if upgradeID then
			SUI:Print('Upgrade found! ' .. upgradeLink .. ' (' .. upgradeReason .. ')')
			module:TurnInQuest(upgradeID)
		elseif greedID then
			SUI:Print('Grabbing item to vendor ' .. greedLink .. ' worth ' .. SUI:GoldFormattedValue(greedValue))
			module:TurnInQuest(greedID)
		end
	else
		if not DB.lootreward then
			if upgradeID then
				SUI:Print('Quest rewards upgrade ' .. upgradeLink .. ' (' .. upgradeReason .. ')')
			elseif greedID then
				SUI:Print('Quest rewards vendor item ' .. greedLink .. ' worth ' .. SUI:GoldFormattedValue(greedValue))
			end
			return
		end

		if upgradeID then
			SUI:Print('Quest rewards upgrade ' .. upgradeLink .. ' (' .. upgradeReason .. ')')
			module:TurnInQuest(upgradeID)
		elseif greedID then
			SUI:Print('Quest rewards vendor item ' .. greedLink .. ' worth ' .. SUI:GoldFormattedValue(greedValue))
			module:TurnInQuest(greedID)
		else
			module.debug(L['No Reward, turning in.'])
			module:TurnInQuest(1)
		end
	end
end
