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

	mockDataCache[index] = {
		name = NAME_LIST[nameIdx],
		class = CLASS_LIST[classIdx],
		healthPct = healthPct,
		powerPct = powerPct,
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

---Force a single oUF frame visible with unit='player' and mock data
---@param frame table The oUF frame object
local function ForceShowFrame(frame)
	if not frame or frame.isForced then
		return
	end

	frame.isForced = true
	frame.originalUnit = frame.unit

	-- Assign mock data for this frame
	mockIndex = mockIndex + 1
	frame.testMockData = GetMockData(mockIndex)

	UnregisterUnitWatch(frame)
	frame:SetAttribute('unit', 'player')
	RegisterUnitWatch(frame, true)
	frame:Show()

	-- Update elements with the new unit
	if frame.unit and UnitExists(frame.unit) then
		frame:UpdateAllElements('OnUpdate')
		frame:UpdateTags()
	end

	-- Stop the tag system from overwriting our mock name, then apply it
	UntagName(frame)
	ApplyMockName(frame)
end

---Restore a single oUF frame to its original state
---@param frame table The oUF frame object
local function UnforceShowFrame(frame)
	if not frame or not frame.isForced then
		return
	end

	frame.isForced = false
	frame.testMockData = nil
	local originalUnit = frame.originalUnit
	frame.originalUnit = nil

	-- Restore the tag system
	RetagName(frame)

	-- Fully unregister to clear the forced visibility state
	UnregisterUnitWatch(frame)
	frame:Hide()

	-- Restore original unit and let oUF manage visibility
	frame:SetAttribute('unit', originalUnit)
	RegisterUnitWatch(frame)

	if originalUnit and UnitExists(originalUnit) then
		frame:UpdateAllElements('OnUpdate')
		frame:UpdateTags()
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
