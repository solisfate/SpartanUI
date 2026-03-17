---@class SUI
local SUI = SUI
local L = SUI.L

if not SUI.IsRetail then
	return
end

---@class SUI.Module.PreyTracker
local module = SUI:GetModule('PreyTracker') ---@type SUI.Module.PreyTracker

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local BAR_WIDTH = 220
local BAR_HEIGHT = 42
local BAR_TEXTURE = 'Interface\\AddOns\\SpartanUI\\images\\statusbars\\Smoothv2'

-- Orange (0%) -> Red (100%) gradient
local function GetBarColor(percent)
	local t = (percent or 0) / 100
	-- Orange: r=1.0 g=0.6 b=0.0 -> Red: r=0.8 g=0.1 b=0.0
	local r = 1.0 - (0.2 * t)
	local g = 0.6 - (0.5 * t)
	local b = 0.0
	return r, g, b
end

----------------------------------------------------------------------------------------------------
-- Progress Bar Creation
----------------------------------------------------------------------------------------------------

function module:CreateProgressBar()
	-- Recover existing frame after /rl
	if not self.progressBar and _G['SUI_PreyTracker'] then
		self.progressBar = _G['SUI_PreyTracker']
		self.progressBar:Hide() -- Start hidden, UpdateProgressBar will show if appropriate
		return
	end
	if self.progressBar then
		return
	end

	local frame = CreateFrame('Frame', 'SUI_PreyTracker', UIParent, 'BackdropTemplate')
	frame:SetSize(BAR_WIDTH, BAR_HEIGHT)
	frame:SetPoint('TOP', UIParent, 'TOP', 0, -180)
	frame:SetFrameStrata('MEDIUM')
	frame:Hide()

	-- Apply scale
	local scale = self.CurrentSettings and self.CurrentSettings.bar and self.CurrentSettings.bar.scale or 1.0
	frame:SetScale(scale)

	-- Background
	frame:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.7)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

	-- Prey name + difficulty text (top area)
	frame.nameText = frame:CreateFontString(nil, 'OVERLAY')
	frame.nameText:SetFontObject(GameFontNormalSmall)
	frame.nameText:SetPoint('TOP', frame, 'TOP', 0, -4)
	frame.nameText:SetText('')

	-- Status bar
	frame.bar = CreateFrame('StatusBar', nil, frame)
	frame.bar:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 4, 4)
	frame.bar:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -4, 4)
	frame.bar:SetHeight(16)
	frame.bar:SetMinMaxValues(0, 100)
	frame.bar:SetValue(0)
	frame.bar:SetStatusBarTexture(BAR_TEXTURE)
	frame.bar:SetStatusBarColor(GetBarColor(0))

	-- Bar background
	frame.bar.bg = frame.bar:CreateTexture(nil, 'BACKGROUND')
	frame.bar.bg:SetAllPoints()
	frame.bar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

	-- Stage + percent text (centered on bar)
	frame.stageText = frame.bar:CreateFontString(nil, 'OVERLAY')
	frame.stageText:SetFontObject(GameFontHighlightSmall)
	frame.stageText:SetPoint('CENTER', frame.bar, 'CENTER', 0, 0)
	frame.stageText:SetText('')

	-- Click handler: open Encounter Journal to Prey tab
	frame:EnableMouse(true)
	frame:SetScript('OnMouseUp', function(_, button)
		if button == 'LeftButton' then
			if module.OpenPreyTab then
				module:OpenPreyTab()
			end
		end
	end)

	-- Tooltip
	frame:SetScript('OnEnter', function(f)
		GameTooltip:SetOwner(f, 'ANCHOR_BOTTOM')
		GameTooltip:AddLine(L['Prey Tracker'], 1, 1, 1)
		GameTooltip:AddLine(L['Click to open Prey Hunts journal tab'], 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	frame:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	self.progressBar = frame

	-- MoveIt integration
	if SUI.MoveIt and SUI.MoveIt.CreateMover then
		frame.dirtyWidth = BAR_WIDTH
		frame.dirtyHeight = BAR_HEIGHT
		SUI.MoveIt:CreateMover(frame, 'PreyTracker', L['Prey Tracker'], nil, 'PreyTracker')
	end
end

----------------------------------------------------------------------------------------------------
-- Progress Bar Update
----------------------------------------------------------------------------------------------------

function module:UpdateProgressBar()
	if not self.progressBar then
		return
	end

	local state = self.state
	-- Only show bar when in the prey zone with an active hunt
	if not state.activeQuestID or not state.inPreyZone then
		self.progressBar:Hide()
		return
	end

	-- Update name text
	local nameStr = state.preyName or L['Unknown Prey']
	if state.preyDifficulty then
		nameStr = nameStr .. ' (' .. state.preyDifficulty .. ')'
	end
	self.progressBar.nameText:SetText(nameStr)

	-- Update bar value
	self.progressBar.bar:SetValue(state.progressPercent)

	-- Update stage text
	local stageLabel = self.STAGE_LABELS[state.currentStage] or self.STAGE_LABELS[1] or 'Tracking'
	local stageStr = stageLabel
	if state.progressPercent > 0 then
		stageStr = string.format('%s - %d%%', stageLabel, state.progressPercent)
	end
	self.progressBar.stageText:SetText(stageStr)

	-- Apply color gradient based on progress
	self.progressBar.bar:SetStatusBarColor(GetBarColor(state.progressPercent))

	-- Apply scale
	if self.CurrentSettings and self.CurrentSettings.bar then
		local scale = self.CurrentSettings.bar.scale or 1.0
		self.progressBar:SetScale(scale)
	end

	self.progressBar:Show()
end
