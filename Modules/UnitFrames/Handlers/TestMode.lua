---@class SUI.UF
local UF = SUI.UF
local L = SUI.L

local TestMode = {}
UF.TestMode = TestMode

local forcedFrames = {}
local isGlobalActive = false

----------------------------------------------------------------------------------------------------
-- Mock data for varied preview appearance
----------------------------------------------------------------------------------------------------
local CLASS_LIST = { 'WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'DEATHKNIGHT', 'SHAMAN', 'MAGE', 'WARLOCK', 'MONK', 'DRUID', 'DEMONHUNTER', 'EVOKER' }

-- Map each class to its primary power token (used by oUF's colors.power[token])
local CLASS_POWER_TOKEN = {
	WARRIOR = 'RAGE',
	PALADIN = 'HOLY_POWER',
	HUNTER = 'FOCUS',
	ROGUE = 'ENERGY',
	PRIEST = 'MANA',
	DEATHKNIGHT = 'RUNIC_POWER',
	SHAMAN = 'MANA',
	MAGE = 'MANA',
	WARLOCK = 'SOUL_SHARDS',
	MONK = 'ENERGY',
	DRUID = 'MANA',
	DEMONHUNTER = 'FURY',
	EVOKER = 'MANA',
}

-- Mock spells for caster-type classes (name, duration, icon)
local MOCK_CASTS = {
	PRIEST = { name = 'Greater Heal', duration = 2.5, icon = 135915 },
	MAGE = { name = 'Fireball', duration = 2.0, icon = 135812 },
	WARLOCK = { name = 'Shadow Bolt', duration = 1.7, icon = 136197 },
	SHAMAN = { name = 'Lightning Bolt', duration = 1.5, icon = 136048 },
	DRUID = { name = 'Wrath', duration = 1.5, icon = 136006 },
	EVOKER = { name = 'Eternity Surge', duration = 2.5, icon = 4622468 },
	PALADIN = { name = 'Flash of Light', duration = 1.5, icon = 135907 },
}
local NAME_LIST = {
	'Arthas',
	'Jaina',
	'Thrall',
	'Sylvanas',
	'Tyrande',
	'Anduin',
	'Velen',
	'Illidan',
	'Malfurion',
	'Khadgar',
	'Genn',
	'Talanji',
	'Baine',
	"Lor'themar",
	'Alleria',
	'Turalyon',
	'Magni',
	'Mekkatorque',
	'Rokhan',
	'Calia',
	'Alexstrasza',
	'Nozdormu',
	'Wrathion',
	'Ebyssian',
	'Kalecgos',
	'Chromie',
	'Aggra',
	'Yrel',
	'Gazlowe',
	'Thalyssra',
	'Oculeth',
	'Valtrois',
	'Liadrin',
	'Sunwalker',
	'Aponi',
	'Hamuul',
	'Rehgar',
	'Saurfang',
	'Nazgrim',
	'Eitrigg',
}

-- Per-frame mock data, seeded by frame index for consistency
local mockDataCache = {}

---Generate deterministic mock data for a frame based on its index
---@param index number
---@return table mockData
local function GetMockData(index)
	if mockDataCache[index] then
		return mockDataCache[index]
	end

	-- Use index as seed for deterministic but varied results
	local nameIdx = ((index * 7 + 3) % #NAME_LIST) + 1
	local classIdx = ((index * 11 + 5) % #CLASS_LIST) + 1
	local healthPct = 0.3 + ((index * 13 + 7) % 70) / 100 -- 30-100%
	local powerPct = 0.1 + ((index * 17 + 11) % 90) / 100 -- 10-100%

	-- Sprinkle shields and heal absorbs on some frames
	-- Pattern: every 3rd frame gets a damage shield, every 5th gets a heal absorb
	local shieldPct = 0
	local healAbsorbPct = 0
	if index % 3 == 1 then
		shieldPct = 0.10 + ((index * 19 + 3) % 20) / 100 -- 10-30% of max health
	end
	if index % 5 == 0 then
		healAbsorbPct = 0.10 + ((index * 23 + 7) % 20) / 100 -- 10-30% of max health
	end

	local mockClass = CLASS_LIST[classIdx]
	mockDataCache[index] = {
		name = NAME_LIST[nameIdx],
		class = mockClass,
		healthPct = healthPct,
		powerPct = powerPct,
		powerToken = CLASS_POWER_TOKEN[mockClass] or 'MANA',
		shieldPct = shieldPct,
		healAbsorbPct = healAbsorbPct,
		mockCast = MOCK_CASTS[mockClass], -- nil for melee classes (no cast shown)
	}
	return mockDataCache[index]
end

---@return boolean
function TestMode:IsActive()
	return isGlobalActive
end

---@param frameName string
---@return boolean
function TestMode:IsFrameForced(frameName)
	return forcedFrames[frameName] ~= nil
end

---Public wrapper for applying mock castbar data (called by Castbar element on live enable)
---@param frame table
function TestMode:ApplyMockCastbar(frame)
	ApplyMockCastbar(frame)
end

----------------------------------------------------------------------------------------------------
-- Core ForceShow / UnforceShow for individual oUF frames
----------------------------------------------------------------------------------------------------

-- Track a running index for mock data assignment
local mockIndex = 0

---Apply mock name text to a frame's Name element
---@param frame table
local function ApplyMockName(frame)
	if not frame.isForced or not frame.testMockData then
		return
	end
	if frame.Name and frame.Name.SetText then
		local mock = frame.testMockData
		local classColor = (RAID_CLASS_COLORS or {})[mock.class]
		if classColor then
			frame.Name:SetText(('|cff%02x%02x%02x%s|r'):format(classColor.r * 255, classColor.g * 255, classColor.b * 255, mock.name))
		else
			frame.Name:SetText(mock.name)
		end
	end
end

---Untag the Name fontstring to stop oUF's tag system from overwriting mock names
---@param frame table
local function UntagName(frame)
	if not frame.Name or not frame.Untag then
		return
	end
	-- Reconstruct tag string from the Name element's DB
	local nameDB = frame.Name.DB
	if nameDB and not frame._testModeNameTag then
		local text = nameDB.text or ''
		if nameDB.textColor and nameDB.textColor.useCustomColor and nameDB.textColor.color then
			local r, g, b = unpack(nameDB.textColor.color)
			text = ('|cff%02x%02x%02x'):format((r or 1) * 255, (g or 1) * 255, (b or 1) * 255) .. text
		end
		frame._testModeNameTag = text
	end
	frame:Untag(frame.Name)
end

---Retag the Name fontstring to restore oUF's tag system
---@param frame table
local function RetagName(frame)
	if frame.Name and frame.Tag and frame._testModeNameTag then
		frame:Tag(frame.Name, frame._testModeNameTag)
		frame._testModeNameTag = nil
	end
end

---Untag health/power text elements and apply mock text
---@param frame table
local function UntagHealthPowerText(frame)
	if not frame.Untag then
		return
	end

	-- Health text
	if frame.Health and frame.Health.TextElements and frame.Health.DataTable then
		frame._testModeHealthTags = frame._testModeHealthTags or {}
		for i, fs in pairs(frame.Health.TextElements) do
			local tagEntry = frame.Health.DataTable[i]
			if tagEntry and tagEntry.text and tagEntry.text ~= '' then
				frame._testModeHealthTags[i] = tagEntry.text
				frame:Untag(fs)
			end
		end
	end

	-- Power text
	if frame.Power and frame.Power.TextElements and frame.Power.DB and frame.Power.DB.text then
		frame._testModePowerTags = frame._testModePowerTags or {}
		for i, fs in pairs(frame.Power.TextElements) do
			local tagEntry = frame.Power.DB.text[i]
			if tagEntry and tagEntry.text and tagEntry.text ~= '' then
				frame._testModePowerTags[i] = tagEntry.text
				frame:Untag(fs)
			end
		end
	end
end

---Apply mock health/power text values to the untagged fontstrings
---@param frame table
local function ApplyMockHealthPowerText(frame)
	if not frame.isForced or not frame.testMockData then
		return
	end
	local mock = frame.testMockData

	-- Health text: show mock current / mock max
	if frame.Health and frame.Health.TextElements and frame._testModeHealthTags then
		local mockMax = 100
		local mockCur = math.floor(mock.healthPct * mockMax)
		for i, fs in pairs(frame.Health.TextElements) do
			if frame._testModeHealthTags[i] and fs:IsShown() then
				fs:SetText(mockCur .. ' / ' .. mockMax)
			end
		end
	end

	-- Power text: show mock current / mock max
	if frame.Power and frame.Power.TextElements and frame._testModePowerTags then
		local mockMax = 100
		local mockCur = math.floor(mock.powerPct * mockMax)
		for i, fs in pairs(frame.Power.TextElements) do
			if frame._testModePowerTags[i] and fs:IsShown() then
				fs:SetText(mockCur .. ' / ' .. mockMax)
			end
		end
	end
end

---Retag health/power text elements to restore oUF's tag system
---@param frame table
local function RetagHealthPowerText(frame)
	if not frame.Tag then
		return
	end

	if frame.Health and frame.Health.TextElements and frame._testModeHealthTags then
		for i, fs in pairs(frame.Health.TextElements) do
			if frame._testModeHealthTags[i] then
				frame:Tag(fs, frame._testModeHealthTags[i])
			end
		end
		frame._testModeHealthTags = nil
	end

	if frame.Power and frame.Power.TextElements and frame._testModePowerTags then
		for i, fs in pairs(frame.Power.TextElements) do
			if frame._testModePowerTags[i] then
				frame:Tag(fs, frame._testModePowerTags[i])
			end
		end
		frame._testModePowerTags = nil
	end
end

---Apply mock power type color to the power bar after oUF's own color pass
---@param frame table
local function ApplyMockPowerColor(frame)
	if not frame.isForced or not frame.testMockData or not frame.Power then
		return
	end
	local token = frame.testMockData.powerToken
	local colors = frame.colors or (frame.__owner and frame.__owner.colors)
	if not colors or not colors.power then
		return
	end
	local color = colors.power[token] or colors.power.MANA
	if color and color.GetRGB then
		frame.Power:SetStatusBarColor(color:GetRGB())
	elseif color and color.r then
		frame.Power:SetStatusBarColor(color.r, color.g, color.b)
	end
end

---Apply mock castbar data to simulate a cast in progress
---@param frame table
local function ApplyMockCastbar(frame)
	if not frame.isForced or not frame.testMockData or not frame.Castbar then
		return
	end

	local castbar = frame.Castbar
	local castDB = castbar.DB
	if not castDB or not castDB.enabled then
		return
	end

	local mock = frame.testMockData.mockCast
	if not mock then
		-- Melee class: show castbar as empty/hidden
		castbar:Hide()
		return
	end

	-- Simulate a cast in progress at a random-ish point
	local elapsed = mock.duration * (0.3 + ((frame.testMockData.healthPct * 100) % 40) / 100)
	castbar:SetMinMaxValues(0, mock.duration)
	castbar:SetValue(elapsed)
	castbar:Show()

	-- Set spell text
	if castbar.Text then
		castbar.Text:SetText(mock.name)
	end

	-- Set timer text
	if castbar.Time then
		local remaining = mock.duration - elapsed
		castbar.Time:SetFormattedText('%.1f', remaining)
	end

	-- Set spell icon
	if castbar.Icon then
		castbar.Icon:SetTexture(mock.icon)
	end

	-- Set castbar color
	if castDB.customColors and castDB.customColors.useCustom then
		castbar:SetStatusBarColor(unpack(castDB.customColors.barColor))
	else
		castbar:SetStatusBarColor(1, 0.7, 0)
	end

	-- Hide shield and overlay for preview
	if castbar.Shield then
		castbar.Shield:SetAlpha(0)
	end
	if castbar.InterruptibleOverlay then
		castbar.InterruptibleOverlay:SetAlpha(0)
	end
end

---Hide mock castbar and let oUF resume control
---@param frame table
local function ClearMockCastbar(frame)
	if not frame.Castbar then
		return
	end

	local castbar = frame.Castbar
	castbar:SetValue(0)
	castbar:Hide()

	-- Clear text
	if castbar.Text then
		castbar.Text:SetText('')
	end
	if castbar.Time then
		castbar.Time:SetText('')
	end
end

---Apply mock class color to the health bar after oUF's own color pass
---@param frame table
local function ApplyMockHealthColor(frame)
	if not frame.isForced or not frame.testMockData or not frame.Health then
		return
	end
	local classColor = (RAID_CLASS_COLORS or {})[frame.testMockData.class]
	if classColor then
		frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
	end
end

---Force a single oUF frame visible with unit='player' and mock data
---Follows ElvUI's ForceShow pattern: disable mouse, then register with asState=true
---@param frame table The oUF frame object
local function ForceShowFrame(frame)
	if not frame or frame.isForced then
		return
	end

	frame.isForced = true
	frame.oldUnit = frame.unit

	-- Assign mock data for this frame
	mockIndex = mockIndex + 1
	frame.testMockData = GetMockData(mockIndex)

	-- Hook PostUpdateColor so our mock class color persists after oUF's UpdateColor
	if frame.Health and not frame._testModeColorHook then
		frame._testModeColorHook = true
		local origPostUpdateColor = frame.Health.PostUpdateColor
		frame.Health._testModeOrigPostUpdateColor = origPostUpdateColor
		frame.Health.PostUpdateColor = function(element, unit, color)
			if origPostUpdateColor then
				origPostUpdateColor(element, unit, color)
			end
			local parent = element:GetParent()
			if parent and parent.isForced then
				ApplyMockHealthColor(parent)
			end
		end
	end

	-- Hook PostUpdateColor on Power so mock power type color persists after oUF's UpdateColor
	if frame.Power and not frame._testModePowerColorHook then
		frame._testModePowerColorHook = true
		local origPowerPostUpdateColor = frame.Power.PostUpdateColor
		frame.Power._testModeOrigPostUpdateColor = origPowerPostUpdateColor
		frame.Power.PostUpdateColor = function(element, unit, color)
			if origPowerPostUpdateColor then
				origPowerPostUpdateColor(element, unit, color)
			end
			local parent = element:GetParent()
			if parent and parent.isForced then
				ApplyMockPowerColor(parent)
			end
		end
	end

	-- ElvUI pattern: disable mouse during preview, set unit, register with asState=true
	frame:EnableMouse(false)

	frame.unit = 'player'
	frame:SetAttribute('unit', 'player')

	UnregisterUnitWatch(frame)
	RegisterUnitWatch(frame, true)

	frame:Show()

	-- Update elements with the new unit
	if UnitExists('player') then
		frame:UpdateAllElements('OnUpdate')
		frame:UpdateTags()
	end

	-- Apply mock visuals after oUF's initial update pass
	ApplyMockHealthColor(frame)
	ApplyMockPowerColor(frame)
	ApplyMockCastbar(frame)

	-- Stop the tag system from overwriting our mock values, then apply them
	UntagName(frame)
	ApplyMockName(frame)
	UntagHealthPowerText(frame)
	ApplyMockHealthPowerText(frame)
end

---Restore a single oUF frame to its original state
---Follows ElvUI's UnforceShow pattern: re-enable mouse BEFORE unregistering unit watch
---@param frame table The oUF frame object
local function UnforceShowFrame(frame)
	if not frame or not frame.isForced then
		return
	end

	frame.isForced = nil
	frame.testMockData = nil

	-- Clear mock castbar before restoring
	ClearMockCastbar(frame)

	-- Restore the tag system
	RetagName(frame)
	RetagHealthPowerText(frame)

	-- Restore original unit
	local oldUnit = frame.oldUnit
	if oldUnit ~= nil then
		frame.unit = oldUnit
		frame.oldUnit = nil
	end

	-- ElvUI pattern: re-enable mouse BEFORE unregistering unit watch
	-- This ensures the secure state driver sees a consistent state during cleanup
	frame:EnableMouse(true)

	UnregisterUnitWatch(frame)
	RegisterUnitWatch(frame)

	-- Let oUF decide visibility based on unit existence
	if frame.Update then
		frame:Update()
	end
end

----------------------------------------------------------------------------------------------------
-- Collect all oUF child frames from a SecureGroupHeader
----------------------------------------------------------------------------------------------------

---Get all oUF-styled child frames from a header
---@param header table SecureGroupHeader
---@return table[] frames
local function GetHeaderChildren(header)
	local frames = {}
	local i = 1
	while true do
		local child = header:GetAttribute('child' .. i)
		if not child then
			break
		end
		if child.__elements then
			frames[#frames + 1] = child
		end
		i = i + 1
	end
	return frames
end

----------------------------------------------------------------------------------------------------
-- Frame type handlers
----------------------------------------------------------------------------------------------------

---Force show a single (non-group) frame
---@param frameName string
function TestMode:ForceShowSingle(frameName)
	if InCombatLockdown() then
		return
	end

	local frame = UF.Unit:Get(frameName)
	if not frame then
		return
	end

	forcedFrames[frameName] = true
	ForceShowFrame(frame)
end

---Unforce a single (non-group) frame
---@param frameName string
function TestMode:UnforceShowSingle(frameName)
	if InCombatLockdown() then
		return
	end

	local frame = UF.Unit:Get(frameName)
	if not frame then
		return
	end

	forcedFrames[frameName] = nil
	UnforceShowFrame(frame)
end

---Force show a UnitWatch group (boss, arena) - individually spawned frames
---@param frameName string
function TestMode:ForceShowUnitWatch(frameName)
	if InCombatLockdown() then
		return
	end

	local holder = UF.Unit:Get(frameName)
	if not holder or not holder.frames then
		return
	end

	forcedFrames[frameName] = true
	holder.isForced = true
	holder._wasHidden = not holder:IsShown()
	holder:Show()

	for _, frame in pairs(holder.frames) do
		ForceShowFrame(frame)
	end
end

---Unforce a UnitWatch group
---@param frameName string
function TestMode:UnforceShowUnitWatch(frameName)
	if InCombatLockdown() then
		return
	end

	local holder = UF.Unit:Get(frameName)
	if not holder or not holder.frames then
		return
	end

	forcedFrames[frameName] = nil
	holder.isForced = false

	if holder._wasHidden then
		holder:Hide()
		holder._wasHidden = nil
	end

	for _, frame in pairs(holder.frames) do
		UnforceShowFrame(frame)
	end

	if holder.UpdateAll then
		holder:UpdateAll()
	end
end

---Force show a header group (party, raid10/25/40)
---@param frameName string
function TestMode:ForceShowHeader(frameName)
	if InCombatLockdown() then
		return
	end

	local holder = UF.Unit:Get(frameName)
	if not holder then
		return
	end

	forcedFrames[frameName] = true
	holder.isForced = true
	holder._wasHidden = not holder:IsShown()
	holder:Show()

	-- Collect all active headers
	local headers = {}
	if holder.headers then
		for _, h in ipairs(holder.headers) do
			headers[#headers + 1] = h
		end
	elseif holder.header then
		headers[1] = holder.header
	end

	for _, header in ipairs(headers) do
		header._testModeOldVis = true

		-- Suppress OnAttributeChanged from re-running configureChildren
		header:SetAttribute('_ignore', true)

		-- Force header visibility
		RegisterStateDriver(header, 'state-visibility', 'show')
		header:Show()

		-- Force all pre-created child frames visible with mock data
		local children = GetHeaderChildren(header)
		for _, child in ipairs(children) do
			ForceShowFrame(child)
		end

		-- Manually position children replicating SecureGroupHeader configureChildren layout
		local point = header:GetAttribute('point') or 'TOP'
		local xOffset = header:GetAttribute('xoffset') or 0
		local yOffset = header:GetAttribute('yOffset') or 0
		local unitsPerColumn = header:GetAttribute('unitsPerColumn') or #children
		local columnAnchorPoint = header:GetAttribute('columnAnchorPoint') or 'LEFT'
		local columnSpacing = header:GetAttribute('columnSpacing') or 0

		for i, child in ipairs(children) do
			child:ClearAllPoints()

			local colIndex = math.floor((i - 1) / unitsPerColumn) -- 0-based column
			local rowIndex = (i - 1) - (colIndex * unitsPerColumn) -- 0-based row within column

			if rowIndex == 0 and colIndex == 0 then
				-- First frame: anchor to header
				child:SetPoint(point, header, point, 0, 0)
			elseif rowIndex == 0 then
				-- First frame in a new column: anchor to the first frame of the previous column
				local prevColFirst = children[(colIndex - 1) * unitsPerColumn + 1]
				if point == 'TOP' or point == 'BOTTOM' then
					-- Columns go horizontally
					if columnAnchorPoint == 'LEFT' or columnAnchorPoint == 'TOPLEFT' or columnAnchorPoint == 'BOTTOMLEFT' then
						child:SetPoint('LEFT', prevColFirst, 'RIGHT', columnSpacing, 0)
					else
						child:SetPoint('RIGHT', prevColFirst, 'LEFT', -columnSpacing, 0)
					end
				else
					-- Columns go vertically
					if columnAnchorPoint == 'TOP' or columnAnchorPoint == 'TOPLEFT' or columnAnchorPoint == 'TOPRIGHT' then
						child:SetPoint('TOP', prevColFirst, 'BOTTOM', 0, -columnSpacing)
					else
						child:SetPoint('BOTTOM', prevColFirst, 'TOP', 0, columnSpacing)
					end
				end
			else
				-- Stack within column relative to previous frame
				-- Vertical stacking (TOP/BOTTOM): only apply yOffset
				-- Horizontal stacking (LEFT/RIGHT): only apply xOffset
				local prev = children[i - 1]
				if point == 'TOP' then
					child:SetPoint('TOP', prev, 'BOTTOM', 0, yOffset)
				elseif point == 'BOTTOM' then
					child:SetPoint('BOTTOM', prev, 'TOP', 0, yOffset)
				elseif point == 'LEFT' then
					child:SetPoint('LEFT', prev, 'RIGHT', xOffset, 0)
				elseif point == 'RIGHT' then
					child:SetPoint('RIGHT', prev, 'LEFT', xOffset, 0)
				end
			end
		end

		header:SetAttribute('_ignore', nil)
	end

	-- Also force any frames tracked in holder.frames (may overlap, ForceShowFrame is idempotent)
	if holder.frames then
		for _, frame in pairs(holder.frames) do
			if frame.__elements then
				ForceShowFrame(frame)
			end
		end
	end
end

---Unforce a header group
---@param frameName string
function TestMode:UnforceShowHeader(frameName)
	if InCombatLockdown() then
		return
	end

	local holder = UF.Unit:Get(frameName)
	if not holder then
		return
	end

	forcedFrames[frameName] = nil
	holder.isForced = false

	-- Hide the holder if it was hidden before test mode
	if holder._wasHidden then
		holder:Hide()
		holder._wasHidden = nil
	end

	-- Collect all active headers
	local headers = {}
	if holder.headers then
		for _, h in ipairs(holder.headers) do
			headers[#headers + 1] = h
		end
	elseif holder.header then
		headers[1] = holder.header
	end

	for _, header in ipairs(headers) do
		-- Suppress OnAttributeChanged during cleanup
		header:SetAttribute('_ignore', true)

		-- Unforce child frames and clear test-mode anchors
		local children = GetHeaderChildren(header)
		for _, child in ipairs(children) do
			child:ClearAllPoints()
			UnforceShowFrame(child)
		end

		-- Restore visibility driver
		if header._testModeOldVis then
			header._testModeOldVis = nil
			UnregisterStateDriver(header, 'state-visibility')
		end

		header:SetAttribute('_ignore', nil)
	end

	-- Also unforce any frames tracked in holder.frames
	if holder.frames then
		for _, frame in pairs(holder.frames) do
			UnforceShowFrame(frame)
		end
	end

	if holder.UpdateAll then
		holder:UpdateAll()
	end
end

----------------------------------------------------------------------------------------------------
-- Frame type detection and public API
----------------------------------------------------------------------------------------------------

---@param frameName string
---@return string type 'single'|'unitwatch'|'header'
local function GetFrameType(frameName)
	local config = UF.Unit:GetConfig(frameName)
	if not config or not config.config then
		return 'single'
	end

	if config.config.IsGroup then
		if config.config.useUnitWatch then
			return 'unitwatch'
		end
		return 'header'
	end

	return 'single'
end

---Dispatch to the correct ForceShow/UnforceShow based on frame type
---@param frameName string
---@param show boolean
local function SetFrameForced(frameName, show)
	local frameType = GetFrameType(frameName)
	if show then
		if frameType == 'unitwatch' then
			TestMode:ForceShowUnitWatch(frameName)
		elseif frameType == 'header' then
			TestMode:ForceShowHeader(frameName)
		else
			TestMode:ForceShowSingle(frameName)
		end
	else
		if frameType == 'unitwatch' then
			TestMode:UnforceShowUnitWatch(frameName)
		elseif frameType == 'header' then
			TestMode:UnforceShowHeader(frameName)
		else
			TestMode:UnforceShowSingle(frameName)
		end
	end
end

---Toggle test mode for a specific frame
---@param frameName string
function TestMode:Toggle(frameName)
	if InCombatLockdown() then
		SUI:Print(L['Cannot toggle test mode during combat'])
		return
	end

	local frame = UF.Unit:Get(frameName)
	if not frame then
		return
	end

	SetFrameForced(frameName, not self:IsFrameForced(frameName))
	isGlobalActive = next(forcedFrames) ~= nil
end

---Enable test mode for all spawned frames
function TestMode:EnableAll()
	if InCombatLockdown() then
		SUI:Print(L['Cannot toggle test mode during combat'])
		return
	end

	mockIndex = 0
	for frameName in pairs(UF.Unit:GetBuiltFrameList()) do
		-- Skip disabled frames
		local settings = UF.CurrentSettings[frameName]
		if settings and settings.enabled and not self:IsFrameForced(frameName) then
			SetFrameForced(frameName, true)
		end
	end

	isGlobalActive = true
end

---Disable test mode for all forced frames
function TestMode:DisableAll()
	if InCombatLockdown() then
		SUI:Print(L['Cannot toggle test mode during combat'])
		return
	end

	local toDisable = {}
	for frameName in pairs(forcedFrames) do
		toDisable[#toDisable + 1] = frameName
	end

	for _, frameName in ipairs(toDisable) do
		SetFrameForced(frameName, false)
	end

	mockIndex = 0
	isGlobalActive = false
end

----------------------------------------------------------------------------------------------------
-- Combat lockdown safety
----------------------------------------------------------------------------------------------------
local pendingCombatDisable = false

local combatWatcher = CreateFrame('Frame')
combatWatcher:RegisterEvent('PLAYER_REGEN_DISABLED')
combatWatcher:RegisterEvent('PLAYER_REGEN_ENABLED')
combatWatcher:SetScript('OnEvent', function(_, event)
	if event == 'PLAYER_REGEN_DISABLED' then
		if next(forcedFrames) then
			pendingCombatDisable = true
			SUI:Print(L['Test mode will disable after combat ends'])
		end
	elseif event == 'PLAYER_REGEN_ENABLED' then
		if pendingCombatDisable then
			pendingCombatDisable = false
			TestMode:DisableAll()
		end
	end
end)
