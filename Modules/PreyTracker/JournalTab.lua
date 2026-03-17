---@class SUI
local SUI = SUI
local L = SUI.L

if not SUI.IsRetail then
	return
end

---@class SUI.Module.PreyTracker
local module = SUI:GetModule('PreyTracker') ---@type SUI.Module.PreyTracker

----------------------------------------------------------------------------------------------------
-- Journal Tab State
----------------------------------------------------------------------------------------------------

module.JournalTab = {}
local JournalTab = module.JournalTab

JournalTab.isActive = false
JournalTab.hooked = false
JournalTab.contentFrame = nil
JournalTab.tabButton = nil

----------------------------------------------------------------------------------------------------
-- Hook the Encounter Journal
----------------------------------------------------------------------------------------------------

function module:HookEncounterJournal()
	if JournalTab.hooked then
		return
	end
	if not EncounterJournal then
		return
	end

	local alreadyHooked = EncounterJournal._SUI_PreyTabHooked

	-- Recover existing frames after /rl
	if not JournalTab.contentFrame and _G['SUI_PreyTracker_JournalContent'] then
		JournalTab.contentFrame = _G['SUI_PreyTracker_JournalContent']
	end
	if not JournalTab.tabButton and _G['SUI_PreyTracker_JournalTab'] then
		JournalTab.tabButton = _G['SUI_PreyTracker_JournalTab']
	end

	-- Create content frame anchored to inset (same as instanceSelect)
	if not JournalTab.contentFrame then
		local inset = EncounterJournal.inset
		local contentFrame = CreateFrame('Frame', 'SUI_PreyTracker_JournalContent', EncounterJournal)
		contentFrame:SetPoint('TOPLEFT', inset, 'TOPLEFT', 0, -2)
		contentFrame:SetPoint('BOTTOMRIGHT', inset, 'BOTTOMRIGHT', -3, 0)
		contentFrame:Hide()

		-- Background atlas at same position as instanceSelect.bg
		-- Alternative: 'UI-EJ-BattleforAzeroth'
		contentFrame.bg = contentFrame:CreateTexture(nil, 'BACKGROUND')
		contentFrame.bg:SetPoint('TOPLEFT', contentFrame, 'TOPLEFT', 3, -1)
		contentFrame.bg:SetAtlas('UI-EJ-Cataclysm', true)

		-- Title header (matches instanceSelect.Title positioning)
		contentFrame.title = contentFrame:CreateFontString(nil, 'OVERLAY')
		contentFrame.title:SetFontObject(GameFontNormalLarge2)
		contentFrame.title:SetPoint('TOPLEFT', contentFrame, 'TOPLEFT', 20, -15)
		contentFrame.title:SetText(L['Prey Hunts'])
		contentFrame.title:SetJustifyH('LEFT')

		-- Refresh content when frame becomes visible (catches layout settling)
		contentFrame:SetScript('OnShow', function()
			C_Timer.After(0.1, function()
				if module.JournalContent and module.JournalContent.Refresh then
					module.JournalContent:Refresh()
				end
			end)
		end)

		JournalTab.contentFrame = contentFrame
	end

	-- Create tab button (managed independently, not via PanelTemplates_SetNumTabs
	-- which re-anchors ALL tabs with 3px gaps destroying Blizzard's -15 overlap)
	if not JournalTab.tabButton then
		local tabButton = CreateFrame('Button', 'SUI_PreyTracker_JournalTab', EncounterJournal, 'PanelTabButtonTemplate')
		tabButton:SetText(L['Prey Hunts'])

		-- Anchor to last Blizzard tab (Blizzard XML tabs use -15 between
		-- themselves but that accounts for their XML anchor context; from
		-- Lua-created tabs 0 produces the correct flush spacing)
		if EncounterJournal.TutorialsTab then
			tabButton:SetPoint('LEFT', EncounterJournal.TutorialsTab, 'RIGHT', 3, 0)
		end

		PanelTemplates_TabResize(tabButton, 0)
		PanelTemplates_DeselectTab(tabButton)

		JournalTab.tabButton = tabButton
	end

	-- Click handler (reset after /rl)
	JournalTab.tabButton:SetScript('OnClick', function()
		module:ActivatePreyTab()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)

	-- Hook tab system (once)
	if not alreadyHooked then
		self:HookTabSystem()

		-- Refresh our content when the EJ is shown (data may have changed while closed)
		EncounterJournal:HookScript('OnShow', function()
			if JournalTab.isActive and module.JournalContent and module.JournalContent.Refresh then
				C_Timer.After(0.1, function()
					if JournalTab.isActive then
						module.JournalContent:Refresh()
					end
				end)
			end
		end)

		EncounterJournal._SUI_PreyTabHooked = true
	end

	-- Build content if needed
	if self.BuildJournalContent and not JournalTab.contentFrame._SUI_ContentBuilt then
		self:BuildJournalContent(JournalTab.contentFrame)
		JournalTab.contentFrame._SUI_ContentBuilt = true
	end

	JournalTab.hooked = true

	if module.logger then
		module.logger.info('Encounter Journal Prey tab injected')
	end
end

----------------------------------------------------------------------------------------------------
-- Tab System Integration
----------------------------------------------------------------------------------------------------

---Hide all Blizzard content panels (comprehensive)
local function HideAllBlizzardContent()
	if not EncounterJournal then
		return
	end

	-- Main panels
	if EncounterJournal.encounter then
		EncounterJournal.encounter:Hide()
	end
	if EncounterJournal.instanceSelect then
		EncounterJournal.instanceSelect:Hide()
	end

	-- Suggested content
	if EncounterJournal.suggestFrame then
		EncounterJournal.suggestFrame:Hide()
	end

	-- Loot journal
	if EncounterJournal.LootJournal then
		EncounterJournal.LootJournal:Hide()
	end
	if EncounterJournal.LootJournalItems then
		EncounterJournal.LootJournalItems:Hide()
	end

	-- Monthly activities
	if EncounterJournal.MonthlyActivitiesFrame then
		EncounterJournal.MonthlyActivitiesFrame:Hide()
	end

	-- Tutorials
	if EncounterJournal.TutorialsFrame then
		EncounterJournal.TutorialsFrame:Hide()
	end

	-- Journeys (Midnight)
	if EncounterJournal.JourneysFrame then
		EncounterJournal.JourneysFrame:Hide()
	end

	-- Great Vault button (shown by Journeys tab)
	if EncounterJournal.instanceSelect and EncounterJournal.instanceSelect.GreatVaultButton then
		EncounterJournal.instanceSelect.GreatVaultButton:Hide()
	end

	-- Navigation, search, and expansion dropdown
	if EncounterJournal.navBar then
		EncounterJournal.navBar:Hide()
	end
	if EncounterJournal.searchBox then
		EncounterJournal.searchBox:Hide()
	end
	if EncounterJournal.instanceSelect and EncounterJournal.instanceSelect.ExpansionDropdown then
		EncounterJournal.instanceSelect.ExpansionDropdown:Hide()
	end
end

---Deselect all Blizzard bottom tabs using their parentKey references
local function DeselectAllBlizzardTabs()
	local tabs = {
		EncounterJournal.JourneysTab,
		EncounterJournal.MonthlyActivitiesTab,
		EncounterJournal.suggestTab,
		EncounterJournal.dungeonsTab,
		EncounterJournal.raidsTab,
		EncounterJournal.LootJournalTab,
		EncounterJournal.TutorialsTab,
	}
	for _, tab in ipairs(tabs) do
		if tab then
			PanelTemplates_DeselectTab(tab)
		end
	end
end

function module:HookTabSystem()
	hooksecurefunc('EJ_ContentTab_Select', function()
		if JournalTab.contentFrame then
			JournalTab.contentFrame:Hide()
		end
		if JournalTab.tabButton then
			PanelTemplates_DeselectTab(JournalTab.tabButton)
		end
		JournalTab.isActive = false
	end)
end

---Activate the Prey tab
function module:ActivatePreyTab()
	if not EncounterJournal then
		return
	end

	-- Hide ALL Blizzard content panels
	HideAllBlizzardContent()

	-- Deselect all Blizzard tabs by their actual frame references
	DeselectAllBlizzardTabs()

	-- Clear Blizzard's internal selectedTab so PanelTemplates_UpdateTabs
	-- won't re-select a Blizzard tab on the next update cycle
	EncounterJournal.selectedTab = nil

	-- Show our content and select our tab
	if JournalTab.contentFrame then
		JournalTab.contentFrame:Show()
	end
	if JournalTab.tabButton then
		PanelTemplates_SelectTab(JournalTab.tabButton)
	end

	JournalTab.isActive = true

	-- Set the main EJ title bar text
	if EncounterJournal.TitleText then
		EncounterJournal.TitleText:SetText(L['Prey Hunts'])
	end

	-- Refresh content (immediate + deferred to catch layout settling)
	if module.JournalContent and module.JournalContent.Refresh then
		module.JournalContent:Refresh()
		-- Deferred refresh ensures scroll child widths have resolved
		-- after the frame becomes visible and OnSizeChanged fires
		C_Timer.After(0.05, function()
			if JournalTab.isActive and module.JournalContent then
				module.JournalContent:Refresh()
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Open Prey Tab (from progress bar click or slash command)
----------------------------------------------------------------------------------------------------

function module:OpenPreyTab()
	if not C_AddOns then
		return
	end

	local loaded = C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('Blizzard_EncounterJournal')
	if not loaded then
		local ok = pcall(C_AddOns.LoadAddOn, 'Blizzard_EncounterJournal')
		if not ok then
			if module.logger then
				module.logger.warning('Failed to load Blizzard_EncounterJournal')
			end
			return
		end
	end

	if not JournalTab.hooked then
		self:HookEncounterJournal()
	end

	if EncounterJournal and not EncounterJournal:IsShown() then
		ShowUIPanel(EncounterJournal)
	end

	self:ActivatePreyTab()
end
