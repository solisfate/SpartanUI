---@class SUI
local SUI = SUI

-- Retail only
if not SUI.IsRetail then
	return
end

---@class SUI.Module.PreyTracker : SUI.Module
local module = SUI:GetModule('PreyTracker') ---@type SUI.Module.PreyTracker

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local PREY_WIDGET_TYPE = 31
local PREY_PROGRESS_FINAL = 3
local STAGE_LABELS = { 'Tracking', 'Stalking', 'Cornered', 'Kill' }

-- Prey-related currency IDs (Midnight expansion)
local CURRENCY_IDS = {
	{ id = 3392, name = 'Remnant of Anguish', abbr = 'Ang' },
}

-- Mission frame pin pool template for hunt scanning
local PIN_POOL_TEMPLATE = 'AdventureMap_QuestOfferPinTemplate'

-- Midnight expansion level (for faction discovery)
local MIDNIGHT_EXPANSION_LEVEL = 11

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

---@class SUI.PreyTracker.State
---@field activeQuestID number|nil
---@field preyName string|nil
---@field preyDifficulty string|nil
---@field preyZone string|nil
---@field preyZoneMapID number|nil
---@field currentStage number
---@field progressPercent number
---@field widgetID number|nil
---@field inPreyZone boolean
---@field ambushPlayed boolean
---@field completionPlayed boolean
module.state = {
	activeQuestID = nil,
	preyName = nil,
	preyDifficulty = nil,
	preyZone = nil,
	preyZoneMapID = nil,
	currentStage = 0,
	progressPercent = 0,
	widgetID = nil,
	inPreyZone = false,
	ambushPlayed = false,
	completionPlayed = false,
}

module.STAGE_LABELS = STAGE_LABELS
module.CURRENCY_IDS = CURRENCY_IDS

-- Hunt scanner cache (populated from mission frame pins)
module.scannedHunts = {} ---@type table[]
module.rewardCache = {} ---@type table<number, string[]>

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---@param title string
---@return string name, string|nil difficulty
local function ParseQuestTitle(title)
	if not title or not canaccessvalue(title) then
		return 'Unknown Prey', nil
	end

	-- Try "Prey: CreatureName (Difficulty)" format
	local name, difficulty = title:match('^Prey:%s*(.-)%s*%((.-)%)%s*$')
	if name and name ~= '' then
		return name, difficulty
	end

	-- Try "Prey: CreatureName" without difficulty
	name = title:match('^Prey:%s*(.+)')
	if name and name ~= '' then
		return name, nil
	end

	return title, nil
end

---Map widget progressState to stage number (1-4)
---@param progressState number
---@return number stage
local function ProgressStateToStage(progressState)
	if progressState == PREY_PROGRESS_FINAL then
		return 4
	end
	if type(progressState) == 'number' and progressState >= 0 and progressState <= 2 then
		return progressState + 1
	end
	return 1
end

---Parse difficulty from pin description text
---@param description string|nil
---@return string difficulty
local function ParseDifficultyFromDescription(description)
	if not description or type(description) ~= 'string' then
		return 'Normal'
	end
	if description:find('Nightmare', 1, true) then
		return 'Nightmare'
	end
	if description:find('Hard', 1, true) then
		return 'Hard'
	end
	return 'Normal'
end

----------------------------------------------------------------------------------------------------
-- Audio Alerts
----------------------------------------------------------------------------------------------------

---Play a sound (supports both sound IDs and file paths)
---@param soundRef number|string Sound ID or file path
local function PlayAlertSound(soundRef)
	if not soundRef then
		return
	end
	if type(soundRef) == 'number' then
		PlaySound(soundRef, 'Master')
	elseif type(soundRef) == 'string' and soundRef ~= '' then
		PlaySoundFile(soundRef, 'Master')
	end
end

---Play the ambush alert sound
function module:PlayAmbushAlert()
	if not self.CurrentSettings or not self.CurrentSettings.audio or not self.CurrentSettings.audio.enabled then
		return
	end
	PlayAlertSound(self.CurrentSettings.audio.ambushSound)
end

---Play the prey found (100% completion) alert sound
function module:PlayCompletionAlert()
	if not self.CurrentSettings or not self.CurrentSettings.audio or not self.CurrentSettings.audio.enabled then
		return
	end
	PlayAlertSound(self.CurrentSettings.audio.completionSound)
end

----------------------------------------------------------------------------------------------------
-- Blizzard Widget Suppression
----------------------------------------------------------------------------------------------------

---Hide or show the default Blizzard prey hunt progress widget
---@param suppress boolean
function module:SetWidgetSuppression(suppress)
	-- Find and hide/show the Blizzard prey widget frame
	if not UIWidgetTopCenterContainerFrame then
		return
	end

	-- Iterate children to find prey widget
	local children = { UIWidgetTopCenterContainerFrame:GetChildren() }
	for _, child in ipairs(children) do
		if child.widgetType and child.widgetType == PREY_WIDGET_TYPE then
			if suppress then
				child:Hide()
				child:SetAlpha(0)
			else
				child:Show()
				child:SetAlpha(1)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- API Wrappers (pcall-protected, secret-value safe)
----------------------------------------------------------------------------------------------------

---Get the active prey quest ID
---@return number|nil questID
function module:GetActivePreyQuest()
	if not C_QuestLog or not C_QuestLog.GetActivePreyQuest then
		return nil
	end

	local ok, questID = pcall(C_QuestLog.GetActivePreyQuest)
	if ok and questID and canaccessvalue(questID) then
		return questID
	end
	return nil
end

---Get the quest title for a quest ID
---@param questID number
---@return string|nil title
function module:GetQuestTitle(questID)
	if not C_QuestLog or not C_QuestLog.GetTitleForQuestID then
		return nil
	end

	local ok, titleInfo = pcall(C_QuestLog.GetTitleForQuestID, questID)
	if not ok then
		return nil
	end

	local title = titleInfo
	if type(titleInfo) == 'table' then
		title = titleInfo.title
	end

	if title and canaccessvalue(title) then
		return title
	end
	return nil
end

---Find the prey hunt widget by enumerating active widgets
function module:FindPreyWidget()
	if not C_UIWidgetManager or not C_UIWidgetManager.GetAllWidgetsBySetID or not C_UIWidgetManager.GetTopCenterWidgetSetID then
		self.state.widgetID = nil
		return
	end

	local preyType = PREY_WIDGET_TYPE
	if Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.PreyHuntProgress then
		preyType = Enum.UIWidgetVisualizationType.PreyHuntProgress
	end

	local shownState = 1
	if Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown then
		shownState = Enum.WidgetShownState.Shown
	end

	local ok, setID = pcall(C_UIWidgetManager.GetTopCenterWidgetSetID)
	if not ok or not setID then
		self.state.widgetID = nil
		return
	end

	local ok2, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
	if not ok2 or not widgets then
		self.state.widgetID = nil
		return
	end

	for _, widget in ipairs(widgets) do
		if widget and widget.widgetType == preyType then
			if C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo then
				local ok3, info = pcall(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo, widget.widgetID)
				if ok3 and info and info.shownState == shownState then
					self.state.widgetID = widget.widgetID
					return
				end
			end
		end
	end

	self.state.widgetID = nil
end

---Update progress from widget or quest progress bar fallback
function module:UpdateProgress()
	local state = self.state
	local oldStage = state.currentStage
	local oldPercent = state.progressPercent

	-- Path 1: Widget data
	if state.widgetID and C_UIWidgetManager and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo then
		local ok, info = pcall(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo, state.widgetID)
		if ok and info and info.progressState then
			if canaccessvalue(info.progressState) then
				state.currentStage = ProgressStateToStage(info.progressState)
			end
		end
	end

	-- Path 2: Quest progress bar for percentage
	if state.activeQuestID and C_TaskQuest and C_TaskQuest.GetQuestProgressBarInfo then
		local ok, progress = pcall(C_TaskQuest.GetQuestProgressBarInfo, state.activeQuestID)
		if ok and progress and canaccessvalue(progress) then
			state.progressPercent = progress
		end
	end

	-- If we have no widget but have percentage, estimate stage
	if not state.widgetID and state.progressPercent > 0 then
		if state.progressPercent >= 75 then
			state.currentStage = 4
		elseif state.progressPercent >= 50 then
			state.currentStage = 3
		elseif state.progressPercent >= 25 then
			state.currentStage = 2
		else
			state.currentStage = 1
		end
	end

	-- Audio: completion alert (reached 100%)
	if state.progressPercent >= 100 and oldPercent < 100 and not state.completionPlayed then
		state.completionPlayed = true
		self:PlayCompletionAlert()
	end

	-- Widget suppression (if enabled)
	if self.CurrentSettings and self.CurrentSettings.hideBlizzardWidget then
		self:SetWidgetSuppression(true)
	end
end

----------------------------------------------------------------------------------------------------
-- Ambush Detection
----------------------------------------------------------------------------------------------------

---Check if a chat message indicates an ambush during active prey hunt
---@param message string
---@param sender string|nil
---@return boolean
function module:IsAmbushMessage(message, sender)
	if not self.state.activeQuestID then
		return false
	end
	if type(message) ~= 'string' then
		return false
	end

	local preyName = self.state.preyName
	if not preyName or preyName == '' then
		return false
	end

	local msgLower = string.lower(message)
	local nameLower = string.lower(preyName)

	if string.find(msgLower, nameLower, 1, true) then
		return true
	end

	if sender and type(sender) == 'string' then
		local senderLower = string.lower(sender)
		if string.find(senderLower, nameLower, 1, true) then
			return true
		end
	end

	return false
end

---Handle potential ambush chat message
---@param message string
---@param sender string|nil
function module:HandleAmbushChat(message, sender)
	if not self.state.activeQuestID then
		return
	end
	if self.state.ambushPlayed then
		return
	end

	if self:IsAmbushMessage(message, sender) then
		self.state.ambushPlayed = true
		self:PlayAmbushAlert()

		if module.logger then
			module.logger.info('Ambush detected for ' .. (self.state.preyName or 'unknown'))
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Main Detection
----------------------------------------------------------------------------------------------------

---Check for an active prey quest and update state. Returns true if hunt is active.
---@return boolean active
function module:CheckForActivePrey()
	local questID = self:GetActivePreyQuest()

	if not questID then
		if self.state.activeQuestID then
			self:ClearState()
		end
		return false
	end

	-- New or same quest
	if self.state.activeQuestID ~= questID then
		self.state.activeQuestID = questID
		self.state.currentStage = 1
		self.state.progressPercent = 0
		self.state.widgetID = nil
		self.state.inPreyZone = false
		self.state.ambushPlayed = false
		self.state.completionPlayed = false

		local title = self:GetQuestTitle(questID)
		if title then
			self.state.preyName, self.state.preyDifficulty = ParseQuestTitle(title)
		else
			self.state.preyName = nil
			self.state.preyDifficulty = nil
		end

		self.state.preyZone, self.state.preyZoneMapID = self:GetPreyZoneInfo(questID)
	end

	-- Check if player is in the prey zone
	self.state.inPreyZone = self:IsPlayerInPreyZone(self.state.preyZoneMapID)

	self:FindPreyWidget()

	-- Only update progress if we have widget data or are in zone
	if self.state.widgetID or self.state.inPreyZone then
		self:UpdateProgress()
	end

	-- If widget is found, we're definitely in zone
	if self.state.widgetID then
		self.state.inPreyZone = true
	end

	-- Notify UI
	if self.OnStateChanged then
		self:OnStateChanged()
	end

	return true
end

---Get the zone name and map ID for a prey quest
---@param questID number
---@return string|nil zoneName, number|nil mapID
function module:GetPreyZoneInfo(questID)
	if not C_TaskQuest or not C_TaskQuest.GetQuestZoneID or not C_Map or not C_Map.GetMapInfo then
		return nil, nil
	end

	local ok, zoneID = pcall(C_TaskQuest.GetQuestZoneID, questID)
	if not ok or not zoneID or zoneID == 0 then
		return nil, nil
	end

	local ok2, mapInfo = pcall(C_Map.GetMapInfo, zoneID)
	if ok2 and mapInfo and mapInfo.name then
		return mapInfo.name, zoneID
	end
	return nil, zoneID
end

---Check if the player is currently in the prey hunt zone (or a child zone of it)
---@param preyMapID number|nil
---@return boolean
function module:IsPlayerInPreyZone(preyMapID)
	if not preyMapID then
		return false
	end
	if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetMapInfo then
		return false
	end

	local ok, playerMapID = pcall(C_Map.GetBestMapForUnit, 'player')
	if not ok or not playerMapID then
		return false
	end

	-- Direct match
	if playerMapID == preyMapID then
		return true
	end

	-- Walk parent chain (e.g., Silvermoon -> Eversong Woods)
	local currentMapID = playerMapID
	for _ = 1, 20 do
		local ok2, mapInfo = pcall(C_Map.GetMapInfo, currentMapID)
		if not ok2 or not mapInfo or not mapInfo.parentMapID then
			break
		end
		if mapInfo.parentMapID == preyMapID then
			return true
		end
		if mapInfo.parentMapID == 0 then
			break
		end
		currentMapID = mapInfo.parentMapID
	end

	return false
end

---Clear all prey tracking state
function module:ClearState()
	self.state.activeQuestID = nil
	self.state.preyName = nil
	self.state.preyDifficulty = nil
	self.state.preyZone = nil
	self.state.preyZoneMapID = nil
	self.state.currentStage = 0
	self.state.progressPercent = 0
	self.state.widgetID = nil
	self.state.inPreyZone = false
	self.state.ambushPlayed = false
	self.state.completionPlayed = false

	-- Restore Blizzard widget if we were suppressing it
	if self.CurrentSettings and self.CurrentSettings.hideBlizzardWidget then
		self:SetWidgetSuppression(false)
	end

	if self.OnStateChanged then
		self:OnStateChanged()
	end
end

----------------------------------------------------------------------------------------------------
-- Hunt Scanner (Mission Frame Pins + Task Quest fallback)
----------------------------------------------------------------------------------------------------

---Get the adventure map pin pool from CovenantMissionFrame
---@return table|nil pool
local function GetAdventurePinPool()
	local mission = CovenantMissionFrame
	local mapTab = mission and mission.MapTab
	local pinPools = mapTab and mapTab.pinPools
	return pinPools and pinPools[PIN_POOL_TEMPLATE]
end

---Scan hunts from mission frame pins
---@return table[] hunts
function module:ScanHuntsFromPins()
	local hunts = {}
	local pool = GetAdventurePinPool()
	if not pool then
		return hunts
	end

	for pin in pool:EnumerateActive() do
		if pin and pin.questID and pin.title then
			local difficulty = ParseDifficultyFromDescription(pin.description)

			local zone = nil
			if pin.normalizedX and pin.normalizedY then
				-- Infer zone from map coordinates
				if pin.normalizedX > 0.70 then
					zone = 'Harandar'
				elseif pin.normalizedX > 0.40 and pin.normalizedY < 0.40 then
					zone = 'Voidstorm'
				elseif pin.normalizedY > 0.55 then
					zone = "Zul'Aman"
				else
					zone = 'Eversong Woods'
				end
			end

			table.insert(hunts, {
				questID = pin.questID,
				name = pin.title,
				difficulty = difficulty,
				zone = zone,
				source = 'mission_frame',
			})
		end
	end

	return hunts
end

---Scan hunts from task quests on known prey zone maps
---@return table[] hunts
function module:ScanHuntsFromTaskQuests()
	local hunts = {}
	if not C_TaskQuest or not C_TaskQuest.GetQuestsOnMap or not C_QuestLog then
		return hunts
	end

	-- Known Midnight prey zone map IDs (may need updating)
	local preyZoneMaps = { 2369, 2370, 2371, 2372 }

	for _, mapID in ipairs(preyZoneMaps) do
		local ok, quests = pcall(C_TaskQuest.GetQuestsOnMap, mapID)
		if ok and quests then
			for _, quest in ipairs(quests) do
				if quest.questId then
					local title = self:GetQuestTitle(quest.questId)
					if title then
						local name, difficulty = ParseQuestTitle(title)
						-- Only include prey quests (matched by title pattern)
						if name ~= title then
							local zoneName = ''
							if C_Map and C_Map.GetMapInfo then
								local ok2, mapInfo = pcall(C_Map.GetMapInfo, mapID)
								if ok2 and mapInfo then
									zoneName = mapInfo.name or ''
								end
							end
							table.insert(hunts, {
								questID = quest.questId,
								name = name,
								difficulty = difficulty,
								zone = zoneName,
								source = 'task_quest',
							})
						end
					end
				end
			end
		end
	end

	return hunts
end

---Fetch extra quest details from C_AdventureMap (only works while mission frame is open)
---@param questID number
---@return string|nil description, number|nil portraitDisplayID, number|nil modelSceneID, string|nil portraitName
local function FetchQuestDetails(questID)
	local description, portraitDisplayID, modelSceneID, portraitName

	-- Quest info: title, description, objective text
	if C_AdventureMap and C_AdventureMap.GetQuestInfo then
		local ok, title, desc, obj = pcall(C_AdventureMap.GetQuestInfo, questID)
		if ok and desc and type(desc) == 'string' then
			description = desc
		end
	end

	-- Portrait info: creature display ID, model scene
	if C_AdventureMap and C_AdventureMap.GetQuestPortraitInfo then
		local ok, info = pcall(C_AdventureMap.GetQuestPortraitInfo, questID)
		if ok and info then
			if info.portraitDisplayID and info.portraitDisplayID ~= 0 then
				portraitDisplayID = info.portraitDisplayID
			end
			modelSceneID = info.modelSceneID
			portraitName = info.name
		end
	end

	return description, portraitDisplayID, modelSceneID, portraitName
end

---Fetch structured reward data for a quest
---@param questID number
---@return table[] rewards Array of { name, icon, count, type }
local function FetchQuestRewards(questID)
	local rewards = {}

	-- XP
	if GetQuestLogRewardXP then
		local ok, xp = pcall(GetQuestLogRewardXP, questID)
		if ok and xp and xp > 0 then
			table.insert(rewards, { name = BreakUpLargeNumbers(xp) .. ' XP', icon = 'Interface\\Icons\\XP_Icon', count = 0, rewardType = 'xp' })
		end
	end

	-- Currencies
	if C_QuestLog and C_QuestLog.GetQuestRewardCurrencies then
		local ok, currencies = pcall(C_QuestLog.GetQuestRewardCurrencies, questID)
		if ok and currencies then
			for _, curr in ipairs(currencies) do
				if curr.name then
					table.insert(rewards, { name = curr.name, icon = curr.texture, count = curr.totalRewardAmount or 0, rewardType = 'currency' })
				end
			end
		end
	end

	-- Items
	if GetNumQuestLogRewards then
		local ok, numItems = pcall(GetNumQuestLogRewards, questID)
		if ok and numItems then
			for i = 1, numItems do
				local ok2, name, texture, count = pcall(GetQuestLogRewardInfo, i, questID)
				if ok2 and name then
					table.insert(rewards, { name = name, icon = texture, count = count or 0, rewardType = 'item' })
				end
			end
		end
	end

	return rewards
end

---Scan and cache available hunts from all sources.
---Called when mission frame opens (pins available). Results are persisted to DBG.
function module:ScanAndCacheHunts()
	local hunts = {}
	local seen = {}

	-- Primary: mission frame pins (only available while frame is open)
	local pinHunts = self:ScanHuntsFromPins()
	for _, hunt in ipairs(pinHunts) do
		if hunt.questID and not seen[hunt.questID] then
			seen[hunt.questID] = true

			-- Enrich with quest details while mission frame is open
			local desc, displayID, sceneID, creatureName = FetchQuestDetails(hunt.questID)
			hunt.description = desc
			hunt.portraitDisplayID = displayID
			hunt.modelSceneID = sceneID
			hunt.creatureName = creatureName
			hunt.rewards = FetchQuestRewards(hunt.questID)

			table.insert(hunts, hunt)
		end
	end

	-- Fallback: task quest scanning (no C_AdventureMap data available)
	local taskHunts = self:ScanHuntsFromTaskQuests()
	for _, hunt in ipairs(taskHunts) do
		if hunt.questID and not seen[hunt.questID] then
			seen[hunt.questID] = true
			table.insert(hunts, hunt)
		end
	end

	-- Cache per-character (different chars see different hunts based on level)
	local charKey = self:GetCharacterKey()
	if self.DBG then
		if not self.DBG.huntCache then
			self.DBG.huntCache = {}
		end
		self.DBG.huntCache[charKey] = {
			hunts = hunts,
			cachedAt = time(),
			weekKey = self:GetCurrentWeekKey(),
		}
	end

	-- Update memory cache with merged view
	self:RebuildMergedHuntCache()

	if module.logger then
		module.logger.info('Scanned hunts for ' .. charKey .. ': ' .. #hunts .. ' found (' .. #pinHunts .. ' pins, ' .. #taskHunts .. ' tasks)')
	end

	return hunts
end

---Merge hunt caches from all characters for the current week.
---Deduplicates by questID, keeping the richest data (pin data over task quest).
---Purges stale week data.
function module:RebuildMergedHuntCache()
	local merged = {}
	local seen = {}
	local currentWeek = self:GetCurrentWeekKey()

	if self.DBG and self.DBG.huntCache then
		-- Purge stale weeks
		for charKey, charCache in pairs(self.DBG.huntCache) do
			if charCache.weekKey ~= currentWeek then
				self.DBG.huntCache[charKey] = nil
			end
		end

		-- Merge current week data from all characters
		for _, charCache in pairs(self.DBG.huntCache) do
			if charCache.hunts then
				for _, hunt in ipairs(charCache.hunts) do
					if hunt.questID and not seen[hunt.questID] then
						seen[hunt.questID] = true
						table.insert(merged, hunt)
					elseif hunt.questID and seen[hunt.questID] then
						-- If this entry has richer data (portrait etc.), replace
						if hunt.portraitDisplayID then
							for j, existing in ipairs(merged) do
								if existing.questID == hunt.questID and not existing.portraitDisplayID then
									merged[j] = hunt
									break
								end
							end
						end
					end
				end
			end
		end
	end

	-- Also migrate old flat cache format if present
	if self.DBG and self.DBG.cachedHunts then
		self.DBG.cachedHunts = nil
	end

	self.scannedHunts = merged
end

---Get available hunts for display, filtered for the current character.
---Merges all character caches but filters Hard/Nightmare for non-max-level chars.
---Marks completed hunts.
---@return table[] hunts
function module:GetAvailableHunts()
	-- Rebuild from DB if memory is empty
	if not self.scannedHunts or #self.scannedHunts == 0 then
		self:RebuildMergedHuntCache()
	end

	if not self.scannedHunts or #self.scannedHunts == 0 then
		return {}
	end

	-- Check current character level for filtering
	local playerLevel = UnitLevel('player') or 0
	local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 90
	local isMaxLevel = playerLevel >= maxLevel

	local filtered = {}
	for _, hunt in ipairs(self.scannedHunts) do
		-- Non-max-level characters can only see Normal hunts
		local diffLower = hunt.difficulty and string.lower(hunt.difficulty) or 'normal'
		if isMaxLevel or diffLower == 'normal' then
			-- Check if completed this week
			local completed = false
			if hunt.questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
				local ok, result = pcall(C_QuestLog.IsQuestFlaggedCompleted, hunt.questID)
				if ok and result then
					completed = true
				end
			end

			local entry = {}
			for k, v in pairs(hunt) do
				entry[k] = v
			end
			entry.completed = completed

			table.insert(filtered, entry)
		end
	end

	return filtered
end

---Hook the mission frame to scan hunts when it opens
function module:HookMissionFrame()
	if self._missionFrameHooked then
		return
	end

	hooksecurefunc('ShowUIPanel', function(frame)
		if not frame then
			return
		end

		local name = frame.GetName and frame:GetName()
		if name ~= 'CovenantMissionFrame' then
			return
		end

		if module.logger then
			module.logger.info('Hunt Table opened, starting pin poll')
		end

		-- Poll pin pool until stable, then scan
		local lastCount = -1
		local stableCount = 0
		local elapsed = 0
		local ticker
		ticker = C_Timer.NewTicker(0.15, function()
			elapsed = elapsed + 0.15
			local count = 0
			local pool = GetAdventurePinPool()
			if pool then
				for _ in pool:EnumerateActive() do
					count = count + 1
				end
			end

			if module.logger then
				module.logger.debug('Pin poll: count=' .. count .. ' stable=' .. stableCount .. ' elapsed=' .. string.format('%.1f', elapsed))
			end

			if count > 0 and count == lastCount then
				stableCount = stableCount + 1
				if stableCount >= 3 then
					module:ScanAndCacheHunts()
					ticker:Cancel()
				end
			else
				stableCount = 0
				lastCount = count
			end

			if elapsed >= 6.0 then
				module:ScanAndCacheHunts()
				ticker:Cancel()
			end
		end)
	end)

	self._missionFrameHooked = true

	if module.logger then
		module.logger.info('Mission frame hook installed')
	end
end

----------------------------------------------------------------------------------------------------
-- Character Data Snapshots
----------------------------------------------------------------------------------------------------

---Get current prey currency balances
---@return table<number, number> currencyAmounts keyed by currency ID
function module:GetCurrencyData()
	local amounts = {}
	if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then
		return amounts
	end

	for _, entry in ipairs(CURRENCY_IDS) do
		local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, entry.id)
		if ok and info and info.quantity and canaccessvalue(info.quantity) then
			amounts[entry.id] = info.quantity
		end
	end

	return amounts
end

---Get character key for current player
---@return string charKey
function module:GetCharacterKey()
	local name = UnitName('player')
	local realm = GetRealmName()
	if not name or not canaccessvalue(name) then
		name = 'Unknown'
	end
	if not realm or not canaccessvalue(realm) then
		realm = 'Unknown'
	end
	return name .. '-' .. realm
end

---Save a snapshot of current character data to global DB
function module:SaveCharacterSnapshot()
	if not self.DBG or not self.DBG.characters then
		return
	end

	local charKey = self:GetCharacterKey()
	local _, classFile = UnitClass('player')
	if classFile and not canaccessvalue(classFile) then
		classFile = nil
	end

	if not self.DBG.characters[charKey] then
		self.DBG.characters[charKey] = {}
	end

	local charData = self.DBG.characters[charKey]
	charData.classFile = classFile
	charData.realm = GetRealmName() or 'Unknown'
	charData.level = UnitLevel('player') or 0
	charData.lastSeen = time()
	charData.currencies = self:GetCurrencyData()

	-- Ensure weekly table exists
	if not charData.weekly then
		charData.weekly = {}
	end
end

---Record a prey hunt completion for the current character
---@param difficulty string|nil "Normal", "Hard", or "Nightmare"
function module:RecordCompletion(difficulty)
	if not self.DBG or not self.DBG.characters then
		return
	end

	local charKey = self:GetCharacterKey()
	if not self.DBG.characters[charKey] then
		self:SaveCharacterSnapshot()
	end

	local charData = self.DBG.characters[charKey]
	if not charData.weekly then
		charData.weekly = {}
	end

	-- Use weekly reset detection
	local weekKey = self:GetCurrentWeekKey()
	if not charData.weekly[weekKey] then
		charData.weekly[weekKey] = { normal = 0, hard = 0, nightmare = 0 }
	end

	local week = charData.weekly[weekKey]
	local diffKey = difficulty and string.lower(difficulty) or 'normal'
	if week[diffKey] then
		week[diffKey] = week[diffKey] + 1
	end

	if module.logger then
		module.logger.info('Recorded ' .. (difficulty or 'Normal') .. ' prey completion for ' .. charKey)
	end
end

---Get the current week key based on WoW's actual weekly reset.
---Uses C_DateAndTime.GetSecondsUntilWeeklyReset() which is region-aware
---(NA resets Tuesday, EU resets Wednesday). Derives the reset-start
---timestamp as a stable key for the entire reset period.
---@return string weekKey
function module:GetCurrentWeekKey()
	local serverTime = GetServerTime and GetServerTime() or time()
	local secondsPerWeek = 604800

	if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
		local ok, secondsUntil = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
		if ok and secondsUntil and secondsUntil > 0 then
			local nextReset = serverTime + secondsUntil
			local resetStart = nextReset - secondsPerWeek
			return tostring(resetStart)
		end
	end

	-- Fallback: epoch-based Tuesday estimate (less accurate for EU)
	local tuesdayEpoch = 1704153600
	local weeksSinceEpoch = math.floor((serverTime - tuesdayEpoch) / secondsPerWeek)
	return tostring(weeksSinceEpoch)
end

---Get weekly completion data for all characters
---@return table<string, table> weeklyData keyed by charKey
function module:GetAllCharacterData()
	if not self.DBG or not self.DBG.characters then
		return {}
	end
	return self.DBG.characters
end

---Get warband currency totals across all characters
---@return table<number, number> totals keyed by currency ID
function module:GetWarbandCurrencyTotals()
	local totals = {}
	local allChars = self:GetAllCharacterData()

	for _, charData in pairs(allChars) do
		if charData.currencies then
			for currID, amount in pairs(charData.currencies) do
				totals[currID] = (totals[currID] or 0) + amount
			end
		end
	end

	return totals
end

----------------------------------------------------------------------------------------------------
-- Prey Season (Major Faction / Renown)
----------------------------------------------------------------------------------------------------

module._preyFactionID = nil

---Find the Prey Season major faction ID by scanning Midnight expansion factions
---@return number|nil factionID
function module:FindPreyFactionID()
	if self._preyFactionID then
		return self._preyFactionID
	end

	if not C_MajorFactions or not C_MajorFactions.GetMajorFactionIDs or not C_MajorFactions.GetMajorFactionData then
		return nil
	end

	local ok, factionIDs = pcall(C_MajorFactions.GetMajorFactionIDs, MIDNIGHT_EXPANSION_LEVEL)
	if not ok or not factionIDs then
		return nil
	end

	for _, factionID in ipairs(factionIDs) do
		local ok2, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
		if ok2 and data and data.name then
			-- Look for "Prey" in the faction name (case-insensitive)
			local nameLower = string.lower(data.name)
			if string.find(nameLower, 'prey', 1, true) then
				self._preyFactionID = factionID
				if module.logger then
					module.logger.info('Found Prey faction: ' .. data.name .. ' (ID ' .. factionID .. ')')
				end
				return factionID
			end
		end
	end

	return nil
end

---@class SUI.PreyTracker.SeasonInfo
---@field factionName string
---@field currentLevel number
---@field maxLevel number
---@field currentXP number
---@field nextLevelXP number
---@field isMaxed boolean

---Get Prey Season renown progress
---@return SUI.PreyTracker.SeasonInfo|nil
function module:GetPreySeasonInfo()
	local factionID = self:FindPreyFactionID()
	if not factionID then
		return nil
	end

	local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
	if not ok or not data then
		return nil
	end

	local ok2, renownInfo = pcall(C_MajorFactions.GetMajorFactionRenownInfo, factionID)

	local currentLevel = 0
	if C_MajorFactions.GetCurrentRenownLevel then
		local ok3, level = pcall(C_MajorFactions.GetCurrentRenownLevel, factionID)
		if ok3 and level then
			currentLevel = level
		end
	end

	local isMaxed = false
	if C_MajorFactions.HasMaximumRenown then
		local ok4, maxed = pcall(C_MajorFactions.HasMaximumRenown, factionID)
		if ok4 then
			isMaxed = maxed
		end
	end

	-- Get max level from renown levels table
	local maxLevel = 0
	if C_MajorFactions.GetRenownLevels then
		local ok5, levels = pcall(C_MajorFactions.GetRenownLevels, factionID)
		if ok5 and levels then
			maxLevel = #levels
		end
	end

	-- Current/next XP from renown info
	local currentXP = 0
	local nextLevelXP = 0
	if ok2 and renownInfo then
		currentXP = renownInfo.renownReputationEarned or 0
		nextLevelXP = renownInfo.renownLevelThreshold or 0
	end

	return {
		factionName = data.name or 'Prey',
		currentLevel = currentLevel,
		maxLevel = maxLevel,
		currentXP = currentXP,
		nextLevelXP = nextLevelXP,
		isMaxed = isMaxed,
	}
end
