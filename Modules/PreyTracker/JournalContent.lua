---@class SUI
local SUI = SUI
local L = SUI.L

if not SUI.IsRetail then
	return
end

---@class SUI.Module.PreyTracker
local module = SUI:GetModule('PreyTracker') ---@type SUI.Module.PreyTracker

----------------------------------------------------------------------------------------------------
-- Journal Content Manager
----------------------------------------------------------------------------------------------------

module.JournalContent = {}
local Content = module.JournalContent

Content.sections = {}

----------------------------------------------------------------------------------------------------
-- Layout Constants
----------------------------------------------------------------------------------------------------

local OUTER_PADDING = 10
local COLUMN_GAP = 16
local SECTION_GAP = 12
local CARD_PADDING = 12
local ROW_HEIGHT = 36
local LEFT_COL_WIDTH = 480
local RIGHT_COL_WIDTH = 278

----------------------------------------------------------------------------------------------------
-- Colors
----------------------------------------------------------------------------------------------------

local DIFFICULTY_COLORS = {
	Normal = { r = 0.1, g = 0.8, b = 0.1 },
	Hard = { r = 1.0, g = 0.6, b = 0.0 },
	Nightmare = { r = 0.8, g = 0.1, b = 0.1 },
}
local GOLD = { r = 1, g = 0.82, b = 0 }
local GRAY = { r = 0.5, g = 0.5, b = 0.5 }
local WARM_GOLD = { r = 0.9, g = 0.8, b = 0.5 }

local function ColorText(text, r, g, b)
	return string.format('|cff%02x%02x%02x%s|r', r * 255, g * 255, b * 255, text)
end

local function GetClassColor(classFile)
	if RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile] then
		local c = RAID_CLASS_COLORS[classFile]
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end

----------------------------------------------------------------------------------------------------
-- Hunt Detail Tooltip (with creature model)
----------------------------------------------------------------------------------------------------

local huntTooltipFrame

local function GetHuntTooltip()
	if huntTooltipFrame then
		return huntTooltipFrame
	end

	local f = CreateFrame('Frame', 'SUI_PreyTracker_HuntTooltip', UIParent, 'BackdropTemplate')
	f:SetFrameStrata('TOOLTIP')
	f:SetSize(280, 200)
	f:Hide()

	f:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	-- Creature model (left side)
	f.model = CreateFrame('PlayerModel', nil, f)
	f.model:SetSize(90, 110)
	f.model:SetPoint('TOPLEFT', f, 'TOPLEFT', 8, -8)

	-- Text area (right of model)
	local textLeft = 106

	f.title = f:CreateFontString(nil, 'OVERLAY')
	f.title:SetFontObject(GameFontNormalLarge)
	f.title:SetPoint('TOPLEFT', f, 'TOPLEFT', textLeft, -10)
	f.title:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
	f.title:SetJustifyH('LEFT')
	f.title:SetWordWrap(true)

	f.diffLabel = f:CreateFontString(nil, 'OVERLAY')
	f.diffLabel:SetFontObject(GameFontNormalSmall)
	f.diffLabel:SetPoint('TOPLEFT', f.title, 'BOTTOMLEFT', 0, -2)

	f.zoneLabel = f:CreateFontString(nil, 'OVERLAY')
	f.zoneLabel:SetFontObject(GameFontHighlightSmall)
	f.zoneLabel:SetPoint('TOPLEFT', f.diffLabel, 'BOTTOMLEFT', 0, -2)
	f.zoneLabel:SetTextColor(GRAY.r, GRAY.g, GRAY.b)

	-- Description (below model, full width)
	f.desc = f:CreateFontString(nil, 'OVERLAY')
	f.desc:SetFontObject(GameFontHighlightSmall)
	f.desc:SetPoint('TOPLEFT', f, 'TOPLEFT', 10, -124)
	f.desc:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
	f.desc:SetJustifyH('LEFT')
	f.desc:SetWordWrap(true)
	f.desc:SetTextColor(0.9, 0.9, 0.9)

	-- Rewards line (bottom)
	f.rewardsLabel = f:CreateFontString(nil, 'OVERLAY')
	f.rewardsLabel:SetFontObject(GameFontNormalSmall)
	f.rewardsLabel:SetPoint('BOTTOMLEFT', f, 'BOTTOMLEFT', 10, 8)
	f.rewardsLabel:SetPoint('RIGHT', f, 'RIGHT', -10, 0)
	f.rewardsLabel:SetJustifyH('LEFT')
	f.rewardsLabel:SetTextColor(WARM_GOLD.r, WARM_GOLD.g, WARM_GOLD.b)

	huntTooltipFrame = f
	return f
end

local function ShowHuntTooltip(anchor, huntData)
	if not huntData then
		return
	end

	local tip = GetHuntTooltip()
	tip:ClearAllPoints()
	tip:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 4, 0)

	-- Title
	tip.title:SetText(huntData.name or 'Unknown')

	-- Difficulty
	if huntData.difficulty then
		local dc = DIFFICULTY_COLORS[huntData.difficulty]
		if dc then
			tip.diffLabel:SetText(ColorText(huntData.difficulty, dc.r, dc.g, dc.b))
		else
			tip.diffLabel:SetText(huntData.difficulty)
		end
		tip.diffLabel:Show()
	else
		tip.diffLabel:Hide()
	end

	-- Zone
	if huntData.zone and huntData.zone ~= '' then
		tip.zoneLabel:SetText(huntData.zone)
		tip.zoneLabel:Show()
	else
		tip.zoneLabel:Hide()
	end

	-- Creature model
	if huntData.portraitDisplayID then
		tip.model:Show()
		tip.model:ClearModel()
		tip.model:SetDisplayInfo(huntData.portraitDisplayID)
		tip.model:SetPortraitZoom(0.8)
	else
		tip.model:Hide()
	end

	-- Description (contains modifier/debuff info)
	if huntData.description and huntData.description ~= '' then
		tip.desc:SetText(huntData.description)
		tip.desc:Show()
	else
		tip.desc:Hide()
	end

	-- Rewards
	local rewardParts = {}
	if huntData.rewards then
		for _, reward in ipairs(huntData.rewards) do
			if reward.count and reward.count > 1 then
				table.insert(rewardParts, reward.name .. ' x' .. reward.count)
			else
				table.insert(rewardParts, reward.name)
			end
		end
	end
	if #rewardParts > 0 then
		tip.rewardsLabel:SetText('Rewards: ' .. table.concat(rewardParts, ', '))
		tip.rewardsLabel:Show()
	else
		tip.rewardsLabel:Hide()
	end

	-- Resize height based on content
	local height = 130 -- base: model area
	if huntData.description and huntData.description ~= '' then
		tip.desc:SetWidth(260)
		height = height + tip.desc:GetStringHeight() + 8
	end
	if #rewardParts > 0 then
		height = height + 20
	end
	tip:SetHeight(math.max(height, 140))

	tip:Show()
end

local function HideHuntTooltip()
	if huntTooltipFrame then
		huntTooltipFrame:Hide()
	end
end

----------------------------------------------------------------------------------------------------
-- Scroll Helper (plain ScrollFrame + mousewheel + thin visual scrollbar)
----------------------------------------------------------------------------------------------------

local SCROLL_STEP = 30
local SCROLLBAR_WIDTH = 6
local SCROLLBAR_MIN_THUMB = 20

local function UpdateScrollIndicator(scrollFrame)
	local indicator = scrollFrame._scrollIndicator
	if not indicator then
		return
	end

	local childHeight = scrollFrame.scrollChild:GetHeight()
	local frameHeight = scrollFrame:GetHeight()
	if frameHeight <= 0 then
		return
	end

	local maxScroll = math.max(0, childHeight - frameHeight)
	if maxScroll <= 0 then
		indicator.track:Hide()
		indicator.thumb:Hide()
		return
	end

	indicator.track:Show()
	indicator.thumb:Show()

	-- Thumb size proportional to visible area
	local trackHeight = indicator.track:GetHeight()
	local ratio = frameHeight / childHeight
	local thumbHeight = math.max(SCROLLBAR_MIN_THUMB, trackHeight * ratio)
	indicator.thumb:SetHeight(thumbHeight)

	-- Thumb position based on scroll offset
	local scrollOffset = scrollFrame:GetVerticalScroll()
	local scrollRatio = scrollOffset / maxScroll
	local thumbTravel = trackHeight - thumbHeight
	local thumbY = -(scrollRatio * thumbTravel)
	indicator.thumb:SetPoint('TOP', indicator.track, 'TOP', 0, thumbY)
end

local function CreateSimpleScrollFrame(parent)
	local scrollFrame = CreateFrame('ScrollFrame', nil, parent)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollChild:SetHeight(1)
	scrollFrame:SetScrollChild(scrollChild)

	-- Thin scrollbar indicator (track + thumb)
	local indicator = {}

	indicator.track = scrollFrame:CreateTexture(nil, 'OVERLAY')
	indicator.track:SetWidth(SCROLLBAR_WIDTH)
	indicator.track:SetPoint('TOPRIGHT', scrollFrame, 'TOPRIGHT', 0, -2)
	indicator.track:SetPoint('BOTTOMRIGHT', scrollFrame, 'BOTTOMRIGHT', 0, 2)
	indicator.track:SetColorTexture(0.2, 0.2, 0.2, 0.3)
	indicator.track:Hide()

	indicator.thumb = scrollFrame:CreateTexture(nil, 'OVERLAY', nil, 1)
	indicator.thumb:SetWidth(SCROLLBAR_WIDTH)
	indicator.thumb:SetHeight(SCROLLBAR_MIN_THUMB)
	indicator.thumb:SetPoint('TOP', indicator.track, 'TOP', 0, 0)
	indicator.thumb:SetColorTexture(0.6, 0.6, 0.6, 0.5)
	indicator.thumb:Hide()

	scrollFrame._scrollIndicator = indicator

	-- Keep scroll child width synced (leave room for scrollbar)
	scrollFrame:SetScript('OnSizeChanged', function(f, w)
		if w and w > 0 then
			scrollChild:SetWidth(w - SCROLLBAR_WIDTH - 2)
		end
		UpdateScrollIndicator(f)
	end)

	scrollFrame:SetScript('OnMouseWheel', function(f, delta)
		local current = f:GetVerticalScroll()
		local maxScroll = math.max(0, scrollChild:GetHeight() - f:GetHeight())
		local newScroll = math.max(0, math.min(maxScroll, current - (delta * SCROLL_STEP)))
		f:SetVerticalScroll(newScroll)
		UpdateScrollIndicator(f)
	end)

	scrollFrame.scrollChild = scrollChild
	scrollFrame.UpdateIndicator = UpdateScrollIndicator
	return scrollFrame
end

----------------------------------------------------------------------------------------------------
-- Card Helper
----------------------------------------------------------------------------------------------------

local function CreateCard(parent, width, height)
	local card = CreateFrame('Frame', nil, parent)
	card:SetSize(width, height)

	card.bg = card:CreateTexture(nil, 'BACKGROUND')
	card.bg:SetAllPoints()
	card.bg:SetColorTexture(0.08, 0.08, 0.08, 0.7)

	card.border = card:CreateTexture(nil, 'BORDER')
	card.border:SetHeight(1)
	card.border:SetPoint('BOTTOMLEFT')
	card.border:SetPoint('BOTTOMRIGHT')
	card.border:SetColorTexture(0.3, 0.3, 0.3, 0.5)

	return card
end

local function CreateCardHeader(card, title)
	local header = card:CreateFontString(nil, 'OVERLAY')
	header:SetFontObject(GameFontNormal)
	header:SetPoint('TOPLEFT', card, 'TOPLEFT', CARD_PADDING, -CARD_PADDING)
	header:SetText(title)
	header:SetTextColor(GOLD.r, GOLD.g, GOLD.b)

	local divider = card:CreateTexture(nil, 'ARTWORK')
	divider:SetHeight(1)
	divider:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, -4)
	divider:SetPoint('RIGHT', card, 'RIGHT', -CARD_PADDING, 0)
	divider:SetColorTexture(0.3, 0.3, 0.3, 0.5)

	return header, divider
end

----------------------------------------------------------------------------------------------------
-- Build Content (2-Column Layout)
----------------------------------------------------------------------------------------------------

-- Stats view mode: 'week' or 'lifetime'
Content.statsMode = 'week'

function module:BuildJournalContent(parent)
	-- Stats mode dropdown (top-right area, WowStyle1 matching EJ dropdowns)
	Content.statsDropdown = CreateFrame('DropdownButton', nil, parent, 'WowStyle1DropdownTemplate')
	Content.statsDropdown:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -10, -8)
	Content.statsDropdown:SetWidth(120)

	Content.statsDropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetTag('MENU_SUI_PREY_STATS_MODE')

		local function IsSelected(mode)
			return Content.statsMode == mode
		end

		local function SetSelected(mode)
			Content.statsMode = mode
			Content:Refresh()
		end

		rootDescription:CreateRadio('This Week', IsSelected, SetSelected, 'week')
		rootDescription:CreateRadio('Lifetime', IsSelected, SetSelected, 'lifetime')
	end)

	-- Season info (left of dropdown)
	Content.seasonText = parent:CreateFontString(nil, 'OVERLAY')
	Content.seasonText:SetFontObject(GameFontNormal)
	Content.seasonText:SetPoint('RIGHT', Content.statsDropdown, 'LEFT', -8, 0)
	Content.seasonText:SetJustifyH('RIGHT')
	Content.seasonText:SetTextColor(WARM_GOLD.r, WARM_GOLD.g, WARM_GOLD.b)

	-- Season tooltip on hover
	Content.seasonFrame = CreateFrame('Frame', nil, parent)
	Content.seasonFrame:SetPoint('TOPLEFT', Content.seasonText, 'TOPLEFT', -4, 4)
	Content.seasonFrame:SetPoint('BOTTOMRIGHT', Content.seasonText, 'BOTTOMRIGHT', 4, -4)
	Content.seasonFrame:EnableMouse(true)
	Content.seasonFrame:SetScript('OnEnter', function(f)
		local info = module:GetPreySeasonInfo()
		if not info then
			return
		end
		GameTooltip:SetOwner(f, 'ANCHOR_BOTTOM')
		GameTooltip:AddLine(info.factionName, 1, 1, 1)
		if info.isMaxed then
			GameTooltip:AddLine('Level ' .. info.currentLevel .. ' (Max)', WARM_GOLD.r, WARM_GOLD.g, WARM_GOLD.b)
		else
			GameTooltip:AddLine('Level ' .. info.currentLevel .. ' out of ' .. info.maxLevel, WARM_GOLD.r, WARM_GOLD.g, WARM_GOLD.b)
			GameTooltip:AddLine(info.currentXP .. ' / ' .. info.nextLevelXP .. ' till next level', GRAY.r, GRAY.g, GRAY.b)
		end
		GameTooltip:Show()
	end)
	Content.seasonFrame:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	-- Content starts below the title header (y=-50 matches EJ's ScrollBox offset)
	local CONTENT_TOP = -50

	local leftCol = CreateFrame('Frame', nil, parent)
	leftCol:SetPoint('TOPLEFT', parent, 'TOPLEFT', OUTER_PADDING, CONTENT_TOP)
	leftCol:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', OUTER_PADDING, OUTER_PADDING)
	leftCol:SetWidth(LEFT_COL_WIDTH)

	local rightCol = CreateFrame('Frame', nil, parent)
	rightCol:SetPoint('TOPLEFT', leftCol, 'TOPRIGHT', COLUMN_GAP, 0)
	rightCol:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', -OUTER_PADDING, OUTER_PADDING)

	Content.leftCol = leftCol
	Content.rightCol = rightCol

	Content.sections.activeHunt = self:BuildSection_ActiveHunt(leftCol)
	Content.sections.availableHunts = self:BuildSection_AvailableHunts(leftCol)
	Content.sections.weeklyProgress = self:BuildSection_WeeklyProgress(rightCol)
	Content.sections.altOverview = self:BuildSection_AltOverview(rightCol)
end

----------------------------------------------------------------------------------------------------
-- Section 1: Active Hunt Card (Left, Top)
----------------------------------------------------------------------------------------------------

function module:BuildSection_ActiveHunt(parent)
	local card = CreateCard(parent, LEFT_COL_WIDTH, 110)
	card:SetPoint('TOPLEFT', parent, 'TOPLEFT')
	card:SetPoint('RIGHT', parent, 'RIGHT')

	CreateCardHeader(card, L['Active Hunt'])

	card.preyName = card:CreateFontString(nil, 'OVERLAY')
	card.preyName:SetFontObject(GameFontNormalLarge)
	card.preyName:SetPoint('TOPLEFT', card, 'TOPLEFT', CARD_PADDING, -(CARD_PADDING + 26))

	card.difficulty = card:CreateFontString(nil, 'OVERLAY')
	card.difficulty:SetFontObject(GameFontNormalSmall)
	card.difficulty:SetPoint('LEFT', card.preyName, 'RIGHT', 8, 0)

	card.zoneLabel = card:CreateFontString(nil, 'OVERLAY')
	card.zoneLabel:SetFontObject(GameFontHighlightSmall)
	card.zoneLabel:SetPoint('TOPLEFT', card.preyName, 'BOTTOMLEFT', 0, -3)
	card.zoneLabel:SetTextColor(GRAY.r, GRAY.g, GRAY.b)

	card.stageLabel = card:CreateFontString(nil, 'OVERLAY')
	card.stageLabel:SetFontObject(GameFontNormal)
	card.stageLabel:SetPoint('TOPLEFT', card.zoneLabel, 'BOTTOMLEFT', 0, -3)

	card.bar = CreateFrame('StatusBar', nil, card)
	card.bar:SetHeight(16)
	card.bar:SetPoint('TOPLEFT', card.stageLabel, 'BOTTOMLEFT', 0, -4)
	card.bar:SetPoint('RIGHT', card, 'RIGHT', -CARD_PADDING, 0)
	card.bar:SetMinMaxValues(0, 100)
	card.bar:SetValue(0)
	card.bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')
	card.bar:SetStatusBarColor(0.8, 0.3, 0.1)

	card.bar.bg = card.bar:CreateTexture(nil, 'BACKGROUND')
	card.bar.bg:SetAllPoints()
	card.bar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

	card.bar.text = card.bar:CreateFontString(nil, 'OVERLAY')
	card.bar.text:SetFontObject(GameFontHighlightSmall)
	card.bar.text:SetPoint('CENTER', card.bar)

	card.noHunt = card:CreateFontString(nil, 'OVERLAY')
	card.noHunt:SetFontObject(GameFontDisable)
	card.noHunt:SetPoint('CENTER', card)
	card.noHunt:SetText(L['No Active Hunt'])

	return card
end

function Content:RefreshActiveHunt()
	local card = self.sections.activeHunt
	if not card then
		return
	end

	local state = module.state
	if state.activeQuestID then
		card.noHunt:Hide()
		card.preyName:Show()
		card.stageLabel:Show()
		card.bar:Show()
		card:SetHeight(110)

		card.preyName:SetText(state.preyName or L['Unknown Prey'])

		if state.preyDifficulty then
			card.difficulty:Show()
			card.difficulty:SetText(state.preyDifficulty)
			local dc = DIFFICULTY_COLORS[state.preyDifficulty]
			if dc then
				card.difficulty:SetTextColor(dc.r, dc.g, dc.b)
			end
		else
			card.difficulty:Hide()
		end

		card.zoneLabel:SetText(state.preyZone or '')
		card.zoneLabel:SetShown(state.preyZone ~= nil)

		local stageLabel = module.STAGE_LABELS[state.currentStage] or module.STAGE_LABELS[1] or 'Tracking'
		card.stageLabel:SetText('Stage ' .. (state.currentStage or 1) .. ': ' .. stageLabel)

		card.bar:SetValue(state.progressPercent)
		card.bar.text:SetText(state.progressPercent .. '%')
	else
		card.noHunt:Show()
		card.preyName:Hide()
		card.difficulty:Hide()
		card.zoneLabel:Hide()
		card.stageLabel:Hide()
		card.bar:Hide()
		card:SetHeight(48)
	end
end

----------------------------------------------------------------------------------------------------
-- Section 2: Available Hunts (Left, fills remaining)
----------------------------------------------------------------------------------------------------

function module:BuildSection_AvailableHunts(parent)
	local card = CreateFrame('Frame', nil, parent)
	card:SetPoint('TOPLEFT', Content.sections.activeHunt, 'BOTTOMLEFT', 0, -SECTION_GAP)
	card:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT')

	card.bg = card:CreateTexture(nil, 'BACKGROUND')
	card.bg:SetAllPoints()
	card.bg:SetColorTexture(0.08, 0.08, 0.08, 0.7)

	CreateCardHeader(card, L['Available Hunts'])

	local scrollFrame = CreateSimpleScrollFrame(card)
	scrollFrame:SetPoint('TOPLEFT', card, 'TOPLEFT', CARD_PADDING, -(CARD_PADDING + 24))
	scrollFrame:SetPoint('BOTTOMRIGHT', card, 'BOTTOMRIGHT', -CARD_PADDING, CARD_PADDING)

	card.scrollFrame = scrollFrame
	card.scrollChild = scrollFrame.scrollChild
	card.rows = {}

	card.noData = card:CreateFontString(nil, 'OVERLAY')
	card.noData:SetFontObject(GameFontDisable)
	card.noData:SetPoint('CENTER', card)
	card.noData:SetText(L['No hunt data available'])

	return card
end

local function GetOrCreateHuntRow(card, index)
	if card.rows[index] then
		return card.rows[index]
	end

	local row = CreateFrame('Button', nil, card.scrollChild)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint('TOPLEFT', card.scrollChild, 'TOPLEFT', 0, -((index - 1) * (ROW_HEIGHT + 2)))
	row:SetPoint('RIGHT', card.scrollChild, 'RIGHT')

	row.bg = row:CreateTexture(nil, 'BACKGROUND')
	row.bg:SetAllPoints()
	if index % 2 == 0 then
		row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.4)
	else
		row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.4)
	end

	row.highlight = row:CreateTexture(nil, 'HIGHLIGHT')
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 0.82, 0, 0.08)

	row.name = row:CreateFontString(nil, 'OVERLAY')
	row.name:SetFontObject(GameFontHighlight)
	row.name:SetPoint('TOPLEFT', row, 'TOPLEFT', 8, -4)
	row.name:SetJustifyH('LEFT')

	row.diff = row:CreateFontString(nil, 'OVERLAY')
	row.diff:SetFontObject(GameFontNormalSmall)
	row.diff:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -8, -5)

	row.zone = row:CreateFontString(nil, 'OVERLAY')
	row.zone:SetFontObject(GameFontNormalSmall)
	row.zone:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', 8, 4)
	row.zone:SetTextColor(GRAY.r, GRAY.g, GRAY.b)

	row.rewards = row:CreateFontString(nil, 'OVERLAY')
	row.rewards:SetFontObject(GameFontNormalSmall)
	row.rewards:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', -8, 4)
	row.rewards:SetTextColor(0.7, 0.7, 0.7)

	-- Completed indicator
	row.doneTag = row:CreateFontString(nil, 'OVERLAY')
	row.doneTag:SetFontObject(GameFontNormalSmall)
	row.doneTag:SetPoint('RIGHT', row.diff, 'LEFT', -6, 0)
	row.doneTag:SetText(ColorText('Done', 0.4, 0.8, 0.4))
	row.doneTag:Hide()

	row:SetScript('OnClick', function(f)
		if f.questID and not f.isCompleted and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
			pcall(C_SuperTrack.SetSuperTrackedQuestID, f.questID)
		end
	end)

	row:SetScript('OnEnter', function(f)
		if f.huntData then
			ShowHuntTooltip(f, f.huntData)
		end
	end)

	row:SetScript('OnLeave', function()
		HideHuntTooltip()
	end)

	card.rows[index] = row
	return row
end

function Content:RefreshAvailableHunts()
	local card = self.sections.availableHunts
	if not card then
		return
	end

	local hunts = module:GetAvailableHunts()

	for _, row in ipairs(card.rows) do
		row:Hide()
	end

	if #hunts == 0 then
		card.noData:Show()
		return
	end
	card.noData:Hide()

	for i, hunt in ipairs(hunts) do
		local row = GetOrCreateHuntRow(card, i)
		row.questID = hunt.questID
		row.huntData = hunt
		row.name:SetText(hunt.name or 'Unknown')
		row.zone:SetText(hunt.zone or '')

		if hunt.difficulty then
			local dc = DIFFICULTY_COLORS[hunt.difficulty]
			if dc then
				row.diff:SetText(ColorText(hunt.difficulty, dc.r, dc.g, dc.b))
			else
				row.diff:SetText(hunt.difficulty)
			end
		else
			row.diff:SetText('')
		end

		-- Show first reward as summary text on the row
		local rewardSummary = ''
		if hunt.rewards and #hunt.rewards > 0 then
			local parts = {}
			for _, reward in ipairs(hunt.rewards) do
				if reward.count and reward.count > 1 then
					table.insert(parts, reward.name .. ' x' .. reward.count)
				else
					table.insert(parts, reward.name)
				end
			end
			rewardSummary = table.concat(parts, ', ')
		elseif module.rewardCache[hunt.questID] then
			rewardSummary = table.concat(module.rewardCache[hunt.questID], ', ')
		end
		row.rewards:SetText(rewardSummary)

		-- Completed state
		row.isCompleted = hunt.completed
		if hunt.completed then
			row.doneTag:Show()
			row.name:SetAlpha(0.5)
			row.zone:SetAlpha(0.5)
			row.diff:SetAlpha(0.5)
			row.rewards:SetAlpha(0.5)
		else
			row.doneTag:Hide()
			row.name:SetAlpha(1)
			row.zone:SetAlpha(1)
			row.diff:SetAlpha(1)
			row.rewards:SetAlpha(1)
		end

		row:Show()
	end

	card.scrollChild:SetHeight(#hunts * (ROW_HEIGHT + 2))
	if card.scrollFrame.UpdateIndicator then
		card.scrollFrame:UpdateIndicator()
	end
end

----------------------------------------------------------------------------------------------------
-- Section 3: Weekly Progress (Right, Top)
----------------------------------------------------------------------------------------------------

function module:BuildSection_WeeklyProgress(parent)
	local card = CreateCard(parent, RIGHT_COL_WIDTH, 120)
	card:SetPoint('TOPLEFT', parent, 'TOPLEFT')
	card:SetPoint('RIGHT', parent, 'RIGHT')

	local header = CreateCardHeader(card, L['Weekly Progress'])
	card.headerText = header

	local startY = -(CARD_PADDING + 28)
	local difficulties = { 'Normal', 'Hard', 'Nightmare' }
	card.diffRows = {}

	for i, diff in ipairs(difficulties) do
		local dc = DIFFICULTY_COLORS[diff]
		local yOff = startY - ((i - 1) * 22)

		local dot = card:CreateTexture(nil, 'OVERLAY')
		dot:SetSize(8, 8)
		dot:SetPoint('TOPLEFT', card, 'TOPLEFT', CARD_PADDING, yOff)
		dot:SetColorTexture(dc.r, dc.g, dc.b, 1)

		local label = card:CreateFontString(nil, 'OVERLAY')
		label:SetFontObject(GameFontNormal)
		label:SetPoint('LEFT', dot, 'RIGHT', 8, 0)
		label:SetText(diff)
		label:SetTextColor(dc.r, dc.g, dc.b)

		local count = card:CreateFontString(nil, 'OVERLAY')
		count:SetFontObject(GameFontHighlight)
		count:SetPoint('RIGHT', card, 'RIGHT', -CARD_PADDING, 0)
		count:SetPoint('TOP', dot, 'TOP', 0, 2)

		card.diffRows[diff] = { dot = dot, label = label, count = count }
	end

	card.totalLabel = card:CreateFontString(nil, 'OVERLAY')
	card.totalLabel:SetFontObject(GameFontHighlightSmall)
	card.totalLabel:SetPoint('BOTTOMLEFT', card, 'BOTTOMLEFT', CARD_PADDING, CARD_PADDING)
	card.totalLabel:SetTextColor(GRAY.r, GRAY.g, GRAY.b)

	return card
end

function Content:RefreshWeeklyProgress()
	local card = self.sections.weeklyProgress
	if not card then
		return
	end

	local charKey = module:GetCharacterKey()
	local charData = module.DBG and module.DBG.characters and module.DBG.characters[charKey]
	local isLifetime = Content.statsMode == 'lifetime'

	-- Update header to reflect mode
	if card.headerText then
		card.headerText:SetText(isLifetime and 'Lifetime Progress' or L['Weekly Progress'])
	end

	local counts
	if isLifetime then
		-- Character lifetime stats
		local lt = charData and charData.lifetime
		counts = {
			Normal = lt and lt.normal or 0,
			Hard = lt and lt.hard or 0,
			Nightmare = lt and lt.nightmare or 0,
		}
	else
		-- Current week stats
		local weekKey = module:GetCurrentWeekKey()
		local weekly = charData and charData.weekly and charData.weekly[weekKey]
		counts = {
			Normal = weekly and weekly.normal or 0,
			Hard = weekly and weekly.hard or 0,
			Nightmare = weekly and weekly.nightmare or 0,
		}
	end

	for diff, row in pairs(card.diffRows) do
		row.count:SetText(tostring(counts[diff] or 0))
	end

	local total = counts.Normal + counts.Hard + counts.Nightmare
	local label = isLifetime and 'Lifetime total: ' or 'Total: '
	card.totalLabel:SetText(label .. total .. ' hunts')
end

----------------------------------------------------------------------------------------------------
-- Section 4: Alt Overview (Right, fills remaining)
----------------------------------------------------------------------------------------------------

function module:BuildSection_AltOverview(parent)
	local card = CreateFrame('Frame', nil, parent)
	card:SetPoint('TOPLEFT', Content.sections.weeklyProgress, 'BOTTOMLEFT', 0, -SECTION_GAP)
	card:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT')

	card.bg = card:CreateTexture(nil, 'BACKGROUND')
	card.bg:SetAllPoints()
	card.bg:SetColorTexture(0.08, 0.08, 0.08, 0.7)

	card.borderLine = card:CreateTexture(nil, 'BORDER')
	card.borderLine:SetHeight(1)
	card.borderLine:SetPoint('BOTTOMLEFT')
	card.borderLine:SetPoint('BOTTOMRIGHT')
	card.borderLine:SetColorTexture(0.3, 0.3, 0.3, 0.5)

	CreateCardHeader(card, L['Alt Overview'])

	-- Account cumulative stats (hunts total across all chars)
	card.accountStats = card:CreateFontString(nil, 'OVERLAY')
	card.accountStats:SetFontObject(GameFontHighlightSmall)
	card.accountStats:SetPoint('TOPLEFT', card, 'TOPLEFT', CARD_PADDING, -(CARD_PADDING + 24))

	-- Warband currency totals
	card.warbandLabel = card:CreateFontString(nil, 'OVERLAY')
	card.warbandLabel:SetFontObject(GameFontHighlightSmall)
	card.warbandLabel:SetPoint('TOPLEFT', card.accountStats, 'BOTTOMLEFT', 0, -2)
	card.warbandLabel:SetTextColor(WARM_GOLD.r, WARM_GOLD.g, WARM_GOLD.b)

	-- Scroll frame for character list
	local scrollFrame = CreateSimpleScrollFrame(card)
	scrollFrame:SetPoint('TOPLEFT', card, 'TOPLEFT', CARD_PADDING, -(CARD_PADDING + 58))
	scrollFrame:SetPoint('BOTTOMRIGHT', card, 'BOTTOMRIGHT', -CARD_PADDING, CARD_PADDING)

	card.scrollFrame = scrollFrame
	card.scrollChild = scrollFrame.scrollChild
	card.rows = {}

	card.noData = card:CreateFontString(nil, 'OVERLAY')
	card.noData:SetFontObject(GameFontDisable)
	card.noData:SetPoint('CENTER', scrollFrame)
	card.noData:SetText(L['No hunt data available'])

	return card
end

local ROW_ALT_HEIGHT = 34

local function GetOrCreateAltRow(card, index)
	if card.rows[index] then
		return card.rows[index]
	end

	local row = CreateFrame('Frame', nil, card.scrollChild)
	row:SetHeight(ROW_ALT_HEIGHT)
	row:SetPoint('TOPLEFT', card.scrollChild, 'TOPLEFT', 0, -((index - 1) * (ROW_ALT_HEIGHT + 2)))
	row:SetPoint('RIGHT', card.scrollChild, 'RIGHT')

	row.bg = row:CreateTexture(nil, 'BACKGROUND')
	row.bg:SetAllPoints()
	if index % 2 == 0 then
		row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.4)
	else
		row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.4)
	end

	-- Line 1: name (left, capped width) + weekly (right)
	row.weekly = row:CreateFontString(nil, 'OVERLAY')
	row.weekly:SetFontObject(GameFontNormalSmall)
	row.weekly:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -4, -2)

	row.name = row:CreateFontString(nil, 'OVERLAY')
	row.name:SetFontObject(GameFontHighlightSmall)
	row.name:SetPoint('TOPLEFT', row, 'TOPLEFT', 4, -2)
	row.name:SetPoint('RIGHT', row.weekly, 'LEFT', -4, 0)
	row.name:SetJustifyH('LEFT')
	row.name:SetWordWrap(false)

	-- Line 2: abbreviated currencies (all on one line)
	row.currencies = row:CreateFontString(nil, 'OVERLAY')
	row.currencies:SetFontObject(GameFontNormalSmall)
	row.currencies:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', 4, 2)
	row.currencies:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', -4, 2)
	row.currencies:SetTextColor(GRAY.r, GRAY.g, GRAY.b)
	row.currencies:SetJustifyH('LEFT')

	-- Tooltip for full currency names
	row:EnableMouse(true)
	row:SetScript('OnEnter', function(f)
		if f.currencyTooltip and f.currencyTooltip ~= '' then
			GameTooltip:SetOwner(f, 'ANCHOR_RIGHT')
			GameTooltip:AddLine(f.charName or '', 1, 1, 1)
			GameTooltip:AddLine(f.currencyTooltip, GRAY.r, GRAY.g, GRAY.b, true)
			GameTooltip:Show()
		end
	end)
	row:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	card.rows[index] = row
	return row
end

function Content:RefreshAltOverview()
	local card = self.sections.altOverview
	if not card then
		return
	end

	local allChars = module:GetAllCharacterData()
	local weekKey = module:GetCurrentWeekKey()
	local isLifetime = Content.statsMode == 'lifetime'

	-- Account cumulative hunt stats (sum across all characters)
	local acctN, acctH, acctNm = 0, 0, 0
	for _, data in pairs(allChars) do
		if isLifetime then
			local lt = data.lifetime
			if lt then
				acctN = acctN + (lt.normal or 0)
				acctH = acctH + (lt.hard or 0)
				acctNm = acctNm + (lt.nightmare or 0)
			end
		else
			local weekly = data.weekly and data.weekly[weekKey]
			if weekly then
				acctN = acctN + (weekly.normal or 0)
				acctH = acctH + (weekly.hard or 0)
				acctNm = acctNm + (weekly.nightmare or 0)
			end
		end
	end
	local nc = DIFFICULTY_COLORS.Normal
	local hc = DIFFICULTY_COLORS.Hard
	local nmc = DIFFICULTY_COLORS.Nightmare
	local acctTotal = acctN + acctH + acctNm
	local modeLabel = isLifetime and 'All-time' or 'This week'
	card.accountStats:SetText(
		modeLabel
			.. ': '
			.. ColorText(acctN .. 'N', nc.r, nc.g, nc.b)
			.. ' / '
			.. ColorText(acctH .. 'H', hc.r, hc.g, hc.b)
			.. ' / '
			.. ColorText(acctNm .. 'Ni', nmc.r, nmc.g, nmc.b)
			.. '  ('
			.. acctTotal
			.. ' total)'
	)

	-- Warband currency totals (abbreviated)
	local totals = module:GetWarbandCurrencyTotals()
	local totalParts = {}
	for _, currDef in ipairs(module.CURRENCY_IDS) do
		local amount = totals[currDef.id]
		if amount and amount > 0 then
			table.insert(totalParts, ColorText(currDef.abbr, WARM_GOLD.r, WARM_GOLD.g, WARM_GOLD.b) .. ':' .. amount)
		end
	end
	card.warbandLabel:SetText(#totalParts > 0 and table.concat(totalParts, '  ') or '')

	-- Character list
	for _, row in ipairs(card.rows) do
		row:Hide()
	end

	local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 90

	-- Filter: only show max-level chars OR chars that have done at least one hunt
	local sorted = {}
	for charKey, data in pairs(allChars) do
		local isMax = (data.level or 0) >= maxLevel
		local totalHunts = 0
		if isLifetime then
			local lt = data.lifetime
			if lt then
				totalHunts = (lt.normal or 0) + (lt.hard or 0) + (lt.nightmare or 0)
			end
		else
			local weekly = data.weekly and data.weekly[weekKey]
			if weekly then
				totalHunts = (weekly.normal or 0) + (weekly.hard or 0) + (weekly.nightmare or 0)
			end
		end
		local hasAnguish = data.currencies and data.currencies[3392] and data.currencies[3392] > 0

		if isMax or totalHunts > 0 then
			table.insert(sorted, {
				key = charKey,
				data = data,
				isMax = isMax,
				totalHunts = totalHunts,
				hasAnguish = hasAnguish,
			})
		end
	end

	-- Sort: current char first, then 90s with activity, then 90s without, then rest
	local currentChar = module:GetCharacterKey()
	table.sort(sorted, function(a, b)
		-- Current character always first
		if a.key == currentChar then
			return true
		end
		if b.key == currentChar then
			return false
		end

		-- Score: max level + hunts done + has anguish
		local scoreA = (a.isMax and 1000 or 0) + (a.totalHunts * 10) + (a.hasAnguish and 1 or 0)
		local scoreB = (b.isMax and 1000 or 0) + (b.totalHunts * 10) + (b.hasAnguish and 1 or 0)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end

		return (a.data.lastSeen or 0) > (b.data.lastSeen or 0)
	end)

	if #sorted == 0 then
		card.noData:Show()
		return
	end
	card.noData:Hide()

	for i, entry in ipairs(sorted) do
		local row = GetOrCreateAltRow(card, i)
		local data = entry.data

		if entry.key == currentChar then
			row.bg:SetColorTexture(0.15, 0.12, 0.05, 0.5)
		elseif i % 2 == 0 then
			row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.4)
		else
			row.bg:SetColorTexture(0.06, 0.06, 0.06, 0.4)
		end

		local cr, cg, cb = GetClassColor(data.classFile)
		row.name:SetText(ColorText(entry.key, cr, cg, cb))
		row.charName = entry.key

		-- Completions (weekly or lifetime based on mode)
		local n, h, nm
		if Content.statsMode == 'lifetime' then
			local lt = data.lifetime
			n = lt and lt.normal or 0
			h = lt and lt.hard or 0
			nm = lt and lt.nightmare or 0
		else
			local weekly = data.weekly and data.weekly[weekKey]
			n = weekly and weekly.normal or 0
			h = weekly and weekly.hard or 0
			nm = weekly and weekly.nightmare or 0
		end
		local nc = DIFFICULTY_COLORS.Normal
		local hc = DIFFICULTY_COLORS.Hard
		local nmc = DIFFICULTY_COLORS.Nightmare
		row.weekly:SetText(ColorText(n .. 'N', nc.r, nc.g, nc.b) .. '/' .. ColorText(h .. 'H', hc.r, hc.g, hc.b) .. '/' .. ColorText(nm .. 'Ni', nmc.r, nmc.g, nmc.b))

		-- Abbreviated currencies on one line
		local abbrParts = {}
		local fullParts = {}
		if data.currencies then
			for _, currDef in ipairs(module.CURRENCY_IDS) do
				local amount = data.currencies[currDef.id]
				if amount and amount > 0 then
					table.insert(abbrParts, currDef.abbr .. ':' .. amount)
					table.insert(fullParts, currDef.name .. ': ' .. amount)
				end
			end
		end
		row.currencies:SetText(table.concat(abbrParts, '  '))
		row.currencyTooltip = table.concat(fullParts, '\n')

		row:Show()
	end

	card.scrollChild:SetHeight(#sorted * (ROW_ALT_HEIGHT + 2))
	if card.scrollFrame.UpdateIndicator then
		card.scrollFrame:UpdateIndicator()
	end
end

----------------------------------------------------------------------------------------------------
-- Refresh All
----------------------------------------------------------------------------------------------------

function Content:RefreshSeasonInfo()
	if not Content.seasonText then
		return
	end

	local info = module:GetPreySeasonInfo()
	if not info then
		Content.seasonText:SetText('')
		Content.seasonFrame:Hide()
		return
	end

	if info.isMaxed then
		Content.seasonText:SetText('Season 1: Level ' .. info.currentLevel .. ' (Max)')
	else
		Content.seasonText:SetText('Season 1: Level ' .. info.currentLevel .. ', ' .. info.currentXP .. '/' .. info.nextLevelXP)
	end
	Content.seasonFrame:Show()

	-- Resize the hover frame to match text
	Content.seasonFrame:ClearAllPoints()
	Content.seasonFrame:SetPoint('TOPLEFT', Content.seasonText, 'TOPLEFT', -4, 4)
	Content.seasonFrame:SetPoint('BOTTOMRIGHT', Content.seasonText, 'BOTTOMRIGHT', 4, -4)
end

function Content:Refresh()
	if not Content.sections or not Content.sections.activeHunt then
		return
	end

	self:RefreshSeasonInfo()
	self:RefreshActiveHunt()
	self:RefreshAvailableHunts()
	self:RefreshWeeklyProgress()
	self:RefreshAltOverview()
end
