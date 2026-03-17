---@class SUI
local SUI = SUI
local L = SUI.L

---@class SUI.Module.PreyTracker : SUI.Module
local module = SUI:NewModule('PreyTracker')
module.DisplayName = L['Prey Tracker']
module.description = 'Track active Prey Hunt progress with an Encounter Journal tab'

-- Retail only (Prey Hunts are a Midnight feature)
if not SUI.IsRetail then
	return
end

----------------------------------------------------------------------------------------------------
-- Database Defaults
----------------------------------------------------------------------------------------------------

---@class SUI.Module.PreyTracker.DB
local DBDefaults = {
	enabled = true,
	bar = {
		scale = 1.0,
		barColor = { r = 0.8, g = 0.3, b = 0.1 },
	},
	audio = {
		enabled = true,
		ambushSound = 568016, -- SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING (dramatic alert)
		completionSound = 567412, -- SOUNDKIT.ACHIEVEMENT_EARNED (celebratory)
	},
	hideBlizzardWidget = false,
}

---@class SUI.Module.PreyTracker.DBGlobal
local DBGlobalDefaults = {
	characters = {},
	weeklyReset = 0,
}

----------------------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------------------

function module:OnInitialize()
	SUI.DBM:SetupModule(self, DBDefaults, DBGlobalDefaults, {
		autoCalculateDepth = true,
	})

	if SUI.logger then
		module.logger = SUI.logger:RegisterCategory('PreyTracker')
	end
end

function module:OnEnable()
	if SUI:IsModuleDisabled('PreyTracker') then
		return
	end

	-- Register events for prey tracking
	self:RegisterEvent('QUEST_LOG_UPDATE', 'OnEvent_QuestLogUpdate')
	self:RegisterEvent('UPDATE_UI_WIDGET', 'OnEvent_UpdateUIWidget')
	self:RegisterEvent('UPDATE_ALL_UI_WIDGETS', 'OnEvent_UpdateAllWidgets')
	self:RegisterEvent('QUEST_TURNED_IN', 'OnEvent_QuestTurnedIn')
	self:RegisterEvent('ZONE_CHANGED_NEW_AREA', 'OnEvent_ZoneChanged')
	self:RegisterEvent('PLAYER_ENTERING_WORLD', 'OnEvent_PlayerEnteringWorld')
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', 'OnEvent_CurrencyUpdate')

	-- Ambush detection via chat messages
	self:RegisterEvent('CHAT_MSG_MONSTER_SAY', 'OnEvent_AmbushChat')
	self:RegisterEvent('CHAT_MSG_MONSTER_YELL', 'OnEvent_AmbushChat')
	self:RegisterEvent('CHAT_MSG_MONSTER_EMOTE', 'OnEvent_AmbushChat')
	self:RegisterEvent('RAID_BOSS_EMOTE', 'OnEvent_AmbushChat')

	-- Hook for EJ tab injection when Encounter Journal loads
	self:RegisterEvent('ADDON_LOADED', 'OnEvent_AddonLoaded')

	-- Hook mission frame for hunt scanning
	if self.HookMissionFrame then
		self:HookMissionFrame()
	end

	-- Rebuild merged hunt cache from all character scans
	if self.RebuildMergedHuntCache then
		self:RebuildMergedHuntCache()
	end

	-- Create progress bar
	if self.CreateProgressBar then
		self:CreateProgressBar()
	end

	-- Build options
	if self.BuildOptions then
		self:BuildOptions()
	end

	if module.logger then
		module.logger.info('PreyTracker enabled')
	end
end

function module:OnDisable()
	self:UnregisterAllEvents()
	self:CancelAllTimers()

	if self.progressBar then
		self.progressBar:Hide()
	end

	if module.logger then
		module.logger.info('PreyTracker disabled')
	end
end

----------------------------------------------------------------------------------------------------
-- State Change Callback (called by Core.lua)
----------------------------------------------------------------------------------------------------

function module:OnStateChanged()
	if self.UpdateProgressBar then
		self:UpdateProgressBar()
	end
	if self.JournalContent and self.JournalContent.Refresh then
		self.JournalContent:Refresh()
	end
end

----------------------------------------------------------------------------------------------------
-- Event Handlers
----------------------------------------------------------------------------------------------------

function module:OnEvent_QuestLogUpdate()
	self:CheckForActivePrey()
end

function module:OnEvent_UpdateUIWidget(_, widgetInfo)
	if not widgetInfo then
		return
	end

	local preyType = 31
	if Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.PreyHuntProgress then
		preyType = Enum.UIWidgetVisualizationType.PreyHuntProgress
	end

	if widgetInfo.widgetType == preyType then
		self:UpdateProgress()
		if self.OnStateChanged then
			self:OnStateChanged()
		end
	end
end

function module:OnEvent_UpdateAllWidgets()
	self:FindPreyWidget()
	self:UpdateProgress()
	if self.OnStateChanged then
		self:OnStateChanged()
	end
end

function module:OnEvent_QuestTurnedIn(_, questID)
	if not questID or not canaccessvalue(questID) then
		return
	end

	-- Check if this was our active prey quest
	if self.state.activeQuestID and questID == self.state.activeQuestID then
		self:RecordCompletion(self.state.preyDifficulty)
		self:SaveCharacterSnapshot()
		self:ClearState()
	else
		self:CheckForActivePrey()
	end
end

function module:OnEvent_ZoneChanged()
	self:CheckForActivePrey()
end

function module:OnEvent_PlayerEnteringWorld()
	C_Timer.After(2, function()
		self:CheckForActivePrey()
		self:SaveCharacterSnapshot()

		-- Try to hook EJ if already loaded
		if EncounterJournal and self.HookEncounterJournal then
			self:HookEncounterJournal()
		end
	end)
end

function module:OnEvent_CurrencyUpdate()
	self:SaveCharacterSnapshot()
end

function module:OnEvent_AmbushChat(_, message, sender)
	if self.HandleAmbushChat then
		self:HandleAmbushChat(message, sender)
	end
end

function module:OnEvent_AddonLoaded(_, addonName)
	if addonName == 'Blizzard_EncounterJournal' then
		C_Timer.After(0.1, function()
			if self.HookEncounterJournal then
				self:HookEncounterJournal()
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Expose
----------------------------------------------------------------------------------------------------

SUI.PreyTracker = module
