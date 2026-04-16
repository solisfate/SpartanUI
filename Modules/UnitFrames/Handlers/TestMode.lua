---@class SUI.UF
local UF = SUI.UF
local L = SUI.L

local TestMode = {}
UF.TestMode = TestMode

-- Tracks forced state per frameName: { originalUnit, wasVisible, visibilityDriver }
local forcedFrames = {}
local isGlobalActive = false

---@return boolean
function TestMode:IsActive()
	return isGlobalActive
end

---@param frameName string
---@return boolean
function TestMode:IsFrameForced(frameName)
	return forcedFrames[frameName] ~= nil
end

-- Force a single oUF frame visible with unit='player'
---@param frame table The oUF frame object
local function ForceShowFrame(frame)
	if not frame or frame.isForced then
		return
	end

	frame.isForced = true
	frame.originalUnit = frame.unit

	UnregisterUnitWatch(frame)
	frame:SetAttribute('unit', 'player')
	RegisterUnitWatch(frame, true)
	frame:Show()

	-- Update elements with the new unit
	if frame.unit and UnitExists(frame.unit) then
		frame:UpdateAllElements('OnUpdate')
		frame:UpdateTags()
	end
end

-- Restore a single oUF frame to its original state
---@param frame table The oUF frame object
local function UnforceShowFrame(frame)
	if not frame or not frame.isForced then
		return
	end

	frame.isForced = false
	local originalUnit = frame.originalUnit
	frame.originalUnit = nil

	UnregisterUnitWatch(frame)
	frame:SetAttribute('unit', originalUnit)
	RegisterUnitWatch(frame)

	-- Let oUF handle visibility based on unit existence
	if originalUnit and UnitExists(originalUnit) then
		frame:UpdateAllElements('OnUpdate')
		frame:UpdateTags()
	end
end

-- Force show a single (non-group) frame
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

-- Unforce a single (non-group) frame
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

-- Force show a UnitWatch group (boss, arena) - individually spawned frames
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

	-- Show the holder
	holder:Show()

	for _, frame in pairs(holder.frames) do
		ForceShowFrame(frame)
	end
end

-- Unforce a UnitWatch group
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

	-- Let the normal visibility system handle the holder
	if holder.UpdateAll then
		holder:UpdateAll()
	end
end

-- Force show a header group (party, raid10/25/40)
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

	-- Show the holder
	holder:Show()

	-- Force all active headers visible
	local headers = {}
	if holder.headers then
		for _, h in ipairs(holder.headers) do
			headers[#headers + 1] = h
		end
	elseif holder.header then
		headers[1] = holder.header
	end

	for _, header in ipairs(headers) do
		-- Store the current visibility driver so we can restore it
		if not header._testModeOldVis then
			header._testModeOldVis = true
		end
		RegisterStateDriver(header, 'state-visibility', 'show')
		header:Show()
	end

	-- Force show each child frame in the group
	for _, frame in pairs(holder.frames) do
		ForceShowFrame(frame)
	end
end

-- Unforce a header group
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

	-- Restore headers
	local headers = {}
	if holder.headers then
		for _, h in ipairs(holder.headers) do
			headers[#headers + 1] = h
		end
	elseif holder.header then
		headers[1] = holder.header
	end

	for _, header in ipairs(headers) do
		if header._testModeOldVis then
			header._testModeOldVis = nil
			UnregisterStateDriver(header, 'state-visibility')
		end
	end

	-- Unforce each child frame
	for _, frame in pairs(holder.frames) do
		UnforceShowFrame(frame)
	end

	-- Let the normal visibility system take over
	if holder.UpdateAll then
		holder:UpdateAll()
	end
end

-- Determine the correct ForceShow method for a frame
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

	if self:IsFrameForced(frameName) then
		local frameType = GetFrameType(frameName)
		if frameType == 'unitwatch' then
			self:UnforceShowUnitWatch(frameName)
		elseif frameType == 'header' then
			self:UnforceShowHeader(frameName)
		else
			self:UnforceShowSingle(frameName)
		end
	else
		local frameType = GetFrameType(frameName)
		if frameType == 'unitwatch' then
			self:ForceShowUnitWatch(frameName)
		elseif frameType == 'header' then
			self:ForceShowHeader(frameName)
		else
			self:ForceShowSingle(frameName)
		end
	end

	-- Update global state
	isGlobalActive = next(forcedFrames) ~= nil
end

---Enable test mode for all spawned frames
function TestMode:EnableAll()
	if InCombatLockdown() then
		SUI:Print(L['Cannot toggle test mode during combat'])
		return
	end

	for frameName, config in pairs(UF.Unit:GetBuiltFrameList()) do
		if not self:IsFrameForced(frameName) then
			local frameType = GetFrameType(frameName)
			if frameType == 'unitwatch' then
				self:ForceShowUnitWatch(frameName)
			elseif frameType == 'header' then
				self:ForceShowHeader(frameName)
			else
				self:ForceShowSingle(frameName)
			end
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

	-- Copy keys since we modify during iteration
	local toDisable = {}
	for frameName in pairs(forcedFrames) do
		toDisable[#toDisable + 1] = frameName
	end

	for _, frameName in ipairs(toDisable) do
		local frameType = GetFrameType(frameName)
		if frameType == 'unitwatch' then
			self:UnforceShowUnitWatch(frameName)
		elseif frameType == 'header' then
			self:UnforceShowHeader(frameName)
		else
			self:UnforceShowSingle(frameName)
		end
	end

	isGlobalActive = false
end

-- Combat lockdown safety: auto-disable all test frames after combat ends
-- We can't modify secure frames during combat (PLAYER_REGEN_DISABLED fires too late),
-- so we mark for cleanup and restore when combat ends.
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
