local UF = SUI.UF
local L = SUI.L

local LCG = LibStub('LibCustomGlow-1.0', true)

-- ============================================================
-- VISUAL BUILDERS
-- ============================================================

local function BuildIconVisual(element, frame, entryKey, entry)
	local iconCfg = entry.icon or {}
	local size = iconCfg.size or 24

	local iconFrame = CreateFrame('Frame', nil, element)
	iconFrame:SetSize(size, size)
	iconFrame:SetFrameLevel(element:GetFrameLevel() + 2)

	local icon = iconFrame:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	iconFrame.icon = icon

	local cooldown = CreateFrame('Cooldown', nil, iconFrame, 'CooldownFrameTemplate')
	cooldown:SetAllPoints()
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(not iconCfg.showDuration)
	iconFrame.cooldown = cooldown

	local count = iconFrame:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
	count:SetPoint('BOTTOMRIGHT', -1, 1)
	iconFrame.count = count

	-- Position standalone icons (grouped icons positioned later by LayoutGroups)
	if not iconCfg.layoutGroup or iconCfg.layoutGroup == '' then
		local pos = iconCfg.position or {}
		iconFrame:SetPoint(pos.anchor or 'TOPLEFT', frame, pos.anchor or 'TOPLEFT', pos.x or 0, pos.y or 0)
	end

	iconFrame:Hide()
	element.visuals[entryKey] = { type = 'icon', frame = iconFrame }
end

local function CreateBorderBar(parent)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetStatusBarTexture('Interface\\Buttons\\WHITE8x8')
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:GetStatusBarTexture():SetBlendMode('BLEND')
	bar:Hide()
	return bar
end

local function LayoutBorderBars(borderFrame, size)
	borderFrame.top:ClearAllPoints()
	borderFrame.top:SetPoint('TOPLEFT', borderFrame, 'TOPLEFT', 0, 0)
	borderFrame.top:SetPoint('TOPRIGHT', borderFrame, 'TOPRIGHT', 0, 0)
	borderFrame.top:SetHeight(size)

	borderFrame.bottom:ClearAllPoints()
	borderFrame.bottom:SetPoint('BOTTOMLEFT', borderFrame, 'BOTTOMLEFT', 0, 0)
	borderFrame.bottom:SetPoint('BOTTOMRIGHT', borderFrame, 'BOTTOMRIGHT', 0, 0)
	borderFrame.bottom:SetHeight(size)

	borderFrame.left:ClearAllPoints()
	borderFrame.left:SetPoint('TOPLEFT', borderFrame, 'TOPLEFT', 0, -size)
	borderFrame.left:SetPoint('BOTTOMLEFT', borderFrame, 'BOTTOMLEFT', 0, size)
	borderFrame.left:SetWidth(size)

	borderFrame.right:ClearAllPoints()
	borderFrame.right:SetPoint('TOPRIGHT', borderFrame, 'TOPRIGHT', 0, -size)
	borderFrame.right:SetPoint('BOTTOMRIGHT', borderFrame, 'BOTTOMRIGHT', 0, size)
	borderFrame.right:SetWidth(size)
end

local function BuildBorderVisual(element, frame, entryKey, entry)
	local borderCfg = entry.border or {}
	local size = borderCfg.size or 2

	local borderFrame = CreateFrame('Frame', nil, element)
	borderFrame:SetAllPoints(frame)
	borderFrame:SetFrameLevel(element:GetFrameLevel() + 1)

	borderFrame.top = CreateBorderBar(borderFrame)
	borderFrame.bottom = CreateBorderBar(borderFrame)
	borderFrame.left = CreateBorderBar(borderFrame)
	borderFrame.right = CreateBorderBar(borderFrame)

	LayoutBorderBars(borderFrame, size)
	borderFrame:Hide()

	element.visuals[entryKey] = { type = 'border', frame = borderFrame }
end

local function BuildVisual(element, frame, entryKey, entry)
	if entry.type == 'icon' then
		BuildIconVisual(element, frame, entryKey, entry)
	elseif entry.type == 'border' then
		BuildBorderVisual(element, frame, entryKey, entry)
	elseif entry.type == 'glow' then
		element.visuals[entryKey] = { type = 'glow', active = false }
	end
end

-- ============================================================
-- SHOW / HIDE VISUALS
-- ============================================================

local function ApplyBorderColor(borderFrame, color)
	local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 0.8
	local bars = { borderFrame.top, borderFrame.bottom, borderFrame.left, borderFrame.right }
	for _, bar in ipairs(bars) do
		bar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
		bar:Show()
	end
	borderFrame:Show()
end

local function CheckIsExpiring(entry, auraData, unit)
	if not entry.expiring or not entry.expiring.enabled then
		return false
	end

	local threshold = entry.expiring.threshold or 3

	if SUI.IsRetail and auraData.auraInstanceID then
		if C_UnitAuras.DoesAuraHaveExpirationTime then
			local hasExp = C_UnitAuras.DoesAuraHaveExpirationTime(unit, auraData.auraInstanceID)
			if not hasExp then
				return false
			end
		end
		local remaining
		pcall(function()
			remaining = auraData.expirationTime - GetTime()
		end)
		if remaining and remaining <= threshold and remaining > 0 then
			return true
		end
	else
		if auraData.expirationTime and auraData.expirationTime > 0 then
			local remaining = auraData.expirationTime - GetTime()
			if remaining <= threshold and remaining > 0 then
				return true
			end
		end
	end
	return false
end

local function ShowVisual(element, entryKey, entry, auraData, unit)
	local visual = element.visuals[entryKey]
	if not visual then
		return
	end

	if visual.type == 'icon' then
		local iconFrame = visual.frame
		local iconCfg = entry.icon or {}

		pcall(function()
			iconFrame.icon:SetTexture(auraData.icon)
		end)

		if iconFrame.cooldown and iconCfg.showSwipe ~= false then
			local durationSet = false
			if SUI.IsRetail and C_UnitAuras.GetAuraDuration and auraData.auraInstanceID then
				pcall(function()
					local durationObj = C_UnitAuras.GetAuraDuration(unit, auraData.auraInstanceID)
					if durationObj and iconFrame.cooldown.SetCooldownFromDurationObject then
						iconFrame.cooldown:SetCooldownFromDurationObject(durationObj)
						durationSet = true
					end
				end)
			end

			if not durationSet and iconFrame.cooldown.SetCooldownFromExpirationTime and auraData.expirationTime and auraData.duration then
				pcall(function()
					iconFrame.cooldown:SetCooldownFromExpirationTime(auraData.expirationTime, auraData.duration)
					durationSet = true
				end)
			end

			if C_UnitAuras.DoesAuraHaveExpirationTime and auraData.auraInstanceID then
				local hasExpiration = C_UnitAuras.DoesAuraHaveExpirationTime(unit, auraData.auraInstanceID)
				if iconFrame.cooldown.SetShownFromBoolean then
					iconFrame.cooldown:SetShownFromBoolean(hasExpiration, true, false)
				elseif durationSet then
					iconFrame.cooldown:Show()
				end
			elseif durationSet then
				iconFrame.cooldown:Show()
			end
		elseif iconFrame.cooldown then
			iconFrame.cooldown:Hide()
		end

		if iconFrame.count and iconCfg.showStacks ~= false then
			iconFrame.count:SetText('')
			if C_UnitAuras.GetAuraApplicationDisplayCount and auraData.auraInstanceID then
				pcall(function()
					local stackText = C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraData.auraInstanceID, 2, 99)
					if stackText then
						iconFrame.count:SetText(stackText)
					end
				end)
			end
		elseif iconFrame.count then
			iconFrame.count:SetText('')
		end

		iconFrame:Show()
	elseif visual.type == 'border' then
		local borderCfg = entry.border or {}
		local color = borderCfg.color or { 0, 1, 0, 0.8 }

		if CheckIsExpiring(entry, auraData, unit) then
			color = entry.expiring.color or { 1, 0, 0, 1 }
		end

		ApplyBorderColor(visual.frame, color)
	elseif visual.type == 'glow' then
		if not visual.active then
			local glowCfg = entry.glow or {}
			if LCG then
				local color = glowCfg.color or { 0.95, 0.95, 0.32, 1 }
				local frame = element:GetParent()
				local glowKey = 'AuraDesigner_' .. entryKey

				if glowCfg.glowType == 'autocast' then
					LCG.AutoCastGlow_Start(frame, color, nil, glowCfg.frequency or 0.25, nil, 0, 0, glowKey)
				elseif glowCfg.glowType == 'button' then
					LCG.ButtonGlow_Start(frame, color, glowCfg.frequency or 0.25)
				elseif glowCfg.glowType == 'proc' then
					LCG.ProcGlow_Start(frame, { color = color, key = glowKey })
				else
					LCG.PixelGlow_Start(frame, color, glowCfg.numLines or 8, glowCfg.frequency or 0.25, nil, glowCfg.thickness or 2, 0, 0, false, glowKey)
				end
			end
			visual.active = true
		end
	end
end

local function HideVisual(element, entryKey, entry)
	local visual = element.visuals[entryKey]
	if not visual then
		return
	end

	if visual.type == 'icon' then
		visual.frame:Hide()
	elseif visual.type == 'border' then
		visual.frame:Hide()
	elseif visual.type == 'glow' then
		if visual.active then
			if LCG then
				local frame = element:GetParent()
				local glowCfg = entry and entry.glow or {}
				local glowKey = 'AuraDesigner_' .. entryKey

				if glowCfg.glowType == 'autocast' then
					LCG.AutoCastGlow_Stop(frame, glowKey)
				elseif glowCfg.glowType == 'button' then
					LCG.ButtonGlow_Stop(frame)
				elseif glowCfg.glowType == 'proc' then
					LCG.ProcGlow_Stop(frame, glowKey)
				else
					LCG.PixelGlow_Stop(frame, glowKey)
				end
			end
			visual.active = false
		end
	end
end

local function HideAll(element)
	local DB = element.DB
	for entryKey, visual in pairs(element.visuals) do
		local entry = DB and DB.entries and DB.entries[entryKey] or {}
		HideVisual(element, entryKey, entry)
	end
end

-- ============================================================
-- LAYOUT GROUPS
-- ============================================================

local function GetGrowthAnchors(direction)
	if direction == 'RIGHT' then
		return 'LEFT', 'RIGHT'
	elseif direction == 'LEFT' then
		return 'RIGHT', 'LEFT'
	elseif direction == 'UP' then
		return 'BOTTOM', 'TOP'
	elseif direction == 'DOWN' then
		return 'TOP', 'BOTTOM'
	end
	return 'LEFT', 'RIGHT'
end

local function GetGrowthOffset(direction, spacing)
	if direction == 'RIGHT' then
		return spacing, 0
	elseif direction == 'LEFT' then
		return -spacing, 0
	elseif direction == 'UP' then
		return 0, spacing
	elseif direction == 'DOWN' then
		return 0, -spacing
	end
	return spacing, 0
end

local function LayoutGroups(element, DB)
	local groups = DB.layoutGroups or {}
	local entries = DB.entries or {}

	for groupName, groupCfg in pairs(groups) do
		if groupCfg.enabled then
			local groupEntries = {}
			for entryKey, entry in pairs(entries) do
				if entry.enabled and entry.type == 'icon' and entry.icon and entry.icon.layoutGroup == groupName then
					groupEntries[#groupEntries + 1] = { key = entryKey, priority = entry.priority or 50 }
				end
			end
			table.sort(groupEntries, function(a, b)
				return a.priority > b.priority
			end)

			local direction = groupCfg.direction or 'RIGHT'
			local spacing = groupCfg.spacing or 2
			local limit = groupCfg.limit or #groupEntries
			local point, relPoint = GetGrowthAnchors(direction)
			local offsetX, offsetY = GetGrowthOffset(direction, spacing)

			for i, ge in ipairs(groupEntries) do
				if i > limit then
					break
				end
				local visual = element.visuals[ge.key]
				if visual and visual.frame then
					visual.frame:ClearAllPoints()
					if i == 1 then
						visual.frame:SetPoint(groupCfg.anchor or 'TOPLEFT', element:GetParent(), groupCfg.anchor or 'TOPLEFT', groupCfg.x or 0, groupCfg.y or 0)
					else
						local prev = element.visuals[groupEntries[i - 1].key]
						if prev and prev.frame then
							visual.frame:SetPoint(point, prev.frame, relPoint, offsetX, offsetY)
						end
					end
				end
			end
		end
	end
end

-- ============================================================
-- BUILD / UPDATE
-- ============================================================

---@param frame table
---@param DB table
local function Build(frame, DB)
	local element = CreateFrame('Frame', nil, frame)
	element:SetAllPoints(frame)
	element:SetFrameLevel(frame:GetFrameLevel() + 9)
	element.DB = DB
	element.visuals = {}

	for entryKey, entry in pairs(DB.entries or {}) do
		if entry.enabled then
			BuildVisual(element, frame, entryKey, entry)
		end
	end

	LayoutGroups(element, DB)

	element.ShowVisual = ShowVisual
	element.HideVisual = HideVisual
	element.HideAll = HideAll

	frame.AuraDesigner = element
end

---@param frame table
---@param settings? table
local function Update(frame, settings)
	local element = frame.AuraDesigner
	if not element then
		return
	end

	local DB = settings or element.DB
	if not DB then
		return
	end
	element.DB = DB

	if not DB.enabled then
		HideAll(element)
		return
	end

	-- Rebuild visuals for newly added entries
	for entryKey, entry in pairs(DB.entries or {}) do
		if entry.enabled and not element.visuals[entryKey] then
			BuildVisual(element, element:GetParent(), entryKey, entry)
		end
	end

	-- Hide visuals for removed/disabled entries
	for entryKey, visual in pairs(element.visuals) do
		local entry = DB.entries and DB.entries[entryKey]
		if not entry or not entry.enabled then
			HideVisual(element, entryKey, entry or {})
			if visual.frame then
				visual.frame:Hide()
			end
		end
	end

	LayoutGroups(element, DB)

	if element.ForceUpdate then
		element:ForceUpdate()
	end
end

-- ============================================================
-- OPTIONS
-- ============================================================

local function ParseSpellInput(val)
	if not val or val == '' then
		return nil
	end
	val = val:match('^%s*(.-)%s*$')
	local num = tonumber(val)
	if num and num > 0 then
		return num
	end
	local linkId = val:match('|Hspell:(%d+)')
	if linkId then
		return tonumber(linkId)
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(val)
		if info and info.spellID then
			return info.spellID
		end
	end
	return nil
end

---@param frameName string
---@param OptionSet AceConfig.OptionsTable
local function Options(frameName, OptionSet)
	local elementName = 'AuraDesigner'

	local function GetDB()
		return UF.CurrentSettings[frameName].elements[elementName]
	end

	local function EnsureDBPath()
		local preset = UF:GetPresetForFrame(frameName)
		local db = UF.DB.UserSettings[preset][frameName].elements[elementName]
		if not db then
			UF.DB.UserSettings[preset][frameName].elements[elementName] = {}
			db = UF.DB.UserSettings[preset][frameName].elements[elementName]
		end
		if not db.entries then
			db.entries = {}
		end
		return db
	end

	local function SetEntry(key, field, val)
		local entries = GetDB().entries
		if not entries[key] then
			entries[key] = {}
		end
		entries[key][field] = val

		local db = EnsureDBPath()
		if not db.entries[key] then
			db.entries[key] = {}
		end
		db.entries[key][field] = val
		UF.Unit[frameName]:ElementUpdate(elementName)
	end

	local function SetEntryNested(key, path, val)
		local keys = {}
		for k in path:gmatch('[^.]+') do
			keys[#keys + 1] = k
		end
		local entries = GetDB().entries
		if not entries[key] then
			entries[key] = {}
		end
		local t = entries[key]
		for i = 1, #keys - 1 do
			if not t[keys[i]] then
				t[keys[i]] = {}
			end
			t = t[keys[i]]
		end
		t[keys[#keys]] = val

		local db = EnsureDBPath()
		if not db.entries[key] then
			db.entries[key] = {}
		end
		local d = db.entries[key]
		for i = 1, #keys - 1 do
			if not d[keys[i]] then
				d[keys[i]] = {}
			end
			d = d[keys[i]]
		end
		d[keys[#keys]] = val
		UF.Unit[frameName]:ElementUpdate(elementName)
	end

	local function BuildEntryOptions(key, entry)
		local spellName = entry.name or ('Aura ' .. key)
		local iconPath = 'Interface\\Icons\\INV_Misc_QuestionMark'
		if entry.spellId and entry.spellId > 0 and C_Spell and C_Spell.GetSpellInfo then
			local info = C_Spell.GetSpellInfo(entry.spellId)
			if info then
				spellName = info.name or spellName
				iconPath = info.iconID or iconPath
			end
		end

		return {
			name = string.format('|T%s:14:14:0:0|t %s', iconPath, spellName),
			type = 'group',
			inline = true,
			order = 100 - (entry.priority or 50),
			args = {
				enabled = {
					name = L['Enabled'],
					type = 'toggle',
					order = 1,
					width = 'half',
					get = function()
						return entry.enabled
					end,
					set = function(_, val)
						SetEntry(key, 'enabled', val)
					end,
				},
				spellInput = {
					name = L['Spell ID or name'],
					type = 'input',
					order = 2,
					width = 'double',
					get = function()
						if entry.spellId and entry.spellId > 0 then
							return tostring(entry.spellId)
						end
						return entry.spellName or ''
					end,
					set = function(_, val)
						local spellId = ParseSpellInput(val)
						if spellId then
							SetEntry(key, 'spellId', spellId)
							if C_Spell and C_Spell.GetSpellInfo then
								local info = C_Spell.GetSpellInfo(spellId)
								if info then
									SetEntry(key, 'spellName', info.name)
									SetEntry(key, 'name', info.name)
								end
							end
						end
					end,
				},
				indicatorType = {
					name = L['Display type'],
					type = 'select',
					order = 3,
					values = { icon = L['Icon'], border = L['Border'], glow = L['Glow'] },
					get = function()
						return entry.type or 'icon'
					end,
					set = function(_, val)
						SetEntry(key, 'type', val)
					end,
				},
				filter = {
					name = L['Aura type'],
					type = 'select',
					order = 4,
					values = { HELPFUL = L['Buff'], HARMFUL = L['Debuff'] },
					get = function()
						return entry.filter or 'HELPFUL'
					end,
					set = function(_, val)
						SetEntry(key, 'filter', val)
					end,
				},
				onlyMine = {
					name = L['Only show mine'],
					type = 'toggle',
					order = 5,
					get = function()
						return entry.onlyMine
					end,
					set = function(_, val)
						SetEntry(key, 'onlyMine', val)
					end,
				},
				priority = {
					name = L['Priority'],
					type = 'range',
					order = 6,
					min = 1,
					max = 100,
					step = 1,
					get = function()
						return entry.priority or 50
					end,
					set = function(_, val)
						SetEntry(key, 'priority', val)
					end,
				},
				iconOpts = {
					name = L['Icon settings'],
					type = 'group',
					inline = true,
					order = 10,
					hidden = function()
						return entry.type ~= 'icon'
					end,
					args = {
						size = {
							name = L['Size'],
							type = 'range',
							order = 1,
							min = 10,
							max = 64,
							step = 1,
							get = function()
								return entry.icon and entry.icon.size or 24
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.size', val)
							end,
						},
						showSwipe = {
							name = L['Cooldown spiral'],
							type = 'toggle',
							order = 2,
							get = function()
								return entry.icon and entry.icon.showSwipe ~= false
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.showSwipe', val)
							end,
						},
						showStacks = {
							name = L['Stack count'],
							type = 'toggle',
							order = 3,
							get = function()
								return entry.icon and entry.icon.showStacks ~= false
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.showStacks', val)
							end,
						},
						anchor = {
							name = L['Anchor'],
							type = 'select',
							order = 4,
							values = {
								TOPLEFT = L['Top Left'],
								TOP = L['Top'],
								TOPRIGHT = L['Top Right'],
								LEFT = L['Left'],
								CENTER = L['Center'],
								RIGHT = L['Right'],
								BOTTOMLEFT = L['Bottom Left'],
								BOTTOM = L['Bottom'],
								BOTTOMRIGHT = L['Bottom Right'],
							},
							get = function()
								return entry.icon and entry.icon.position and entry.icon.position.anchor or 'TOPLEFT'
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.position.anchor', val)
							end,
						},
						x = {
							name = L['X Offset'],
							type = 'range',
							order = 5,
							min = -200,
							max = 200,
							step = 1,
							get = function()
								return entry.icon and entry.icon.position and entry.icon.position.x or 0
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.position.x', val)
							end,
						},
						y = {
							name = L['Y Offset'],
							type = 'range',
							order = 6,
							min = -200,
							max = 200,
							step = 1,
							get = function()
								return entry.icon and entry.icon.position and entry.icon.position.y or 0
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.position.y', val)
							end,
						},
						layoutGroup = {
							name = L['Layout group'],
							type = 'select',
							order = 7,
							values = function()
								local vals = { [''] = L['None (standalone)'] }
								local groups = GetDB().layoutGroups or {}
								for groupName in pairs(groups) do
									vals[groupName] = groupName
								end
								return vals
							end,
							get = function()
								return entry.icon and entry.icon.layoutGroup or ''
							end,
							set = function(_, val)
								SetEntryNested(key, 'icon.layoutGroup', val)
							end,
						},
					},
				},
				borderOpts = {
					name = L['Border settings'],
					type = 'group',
					inline = true,
					order = 10,
					hidden = function()
						return entry.type ~= 'border'
					end,
					args = {
						size = {
							name = L['Thickness'],
							type = 'range',
							order = 1,
							min = 1,
							max = 6,
							step = 1,
							get = function()
								return entry.border and entry.border.size or 2
							end,
							set = function(_, val)
								SetEntryNested(key, 'border.size', val)
							end,
						},
						color = {
							name = L['Color'],
							type = 'color',
							order = 2,
							hasAlpha = true,
							get = function()
								local c = entry.border and entry.border.color or { 0, 1, 0, 0.8 }
								return c[1], c[2], c[3], c[4]
							end,
							set = function(_, r, g, b, a)
								SetEntryNested(key, 'border.color', { r, g, b, a })
							end,
						},
					},
				},
				glowOpts = {
					name = L['Glow settings'],
					type = 'group',
					inline = true,
					order = 10,
					hidden = function()
						return entry.type ~= 'glow'
					end,
					args = {
						glowType = {
							name = L['Glow style'],
							type = 'select',
							order = 1,
							values = {
								pixel = L['Pixel'],
								autocast = L['Autocast'],
								button = L['Button'],
								proc = L['Proc'],
							},
							get = function()
								return entry.glow and entry.glow.glowType or 'pixel'
							end,
							set = function(_, val)
								SetEntryNested(key, 'glow.glowType', val)
							end,
						},
						color = {
							name = L['Color'],
							type = 'color',
							order = 2,
							hasAlpha = true,
							get = function()
								local c = entry.glow and entry.glow.color or { 0.95, 0.95, 0.32, 1 }
								return c[1], c[2], c[3], c[4]
							end,
							set = function(_, r, g, b, a)
								SetEntryNested(key, 'glow.color', { r, g, b, a })
							end,
						},
						frequency = {
							name = L['Speed'],
							type = 'range',
							order = 3,
							min = 0.05,
							max = 1.0,
							step = 0.05,
							get = function()
								return entry.glow and entry.glow.frequency or 0.25
							end,
							set = function(_, val)
								SetEntryNested(key, 'glow.frequency', val)
							end,
						},
					},
				},
				expiringOpts = {
					name = L['Expiring alert'],
					type = 'group',
					inline = true,
					order = 20,
					args = {
						enabled = {
							name = L['Enabled'],
							type = 'toggle',
							order = 1,
							get = function()
								return entry.expiring and entry.expiring.enabled
							end,
							set = function(_, val)
								SetEntryNested(key, 'expiring.enabled', val)
							end,
						},
						threshold = {
							name = L['Threshold (seconds)'],
							type = 'range',
							order = 2,
							min = 1,
							max = 30,
							step = 1,
							get = function()
								return entry.expiring and entry.expiring.threshold or 3
							end,
							set = function(_, val)
								SetEntryNested(key, 'expiring.threshold', val)
							end,
						},
						color = {
							name = L['Color'],
							type = 'color',
							order = 3,
							hasAlpha = true,
							get = function()
								local c = entry.expiring and entry.expiring.color or { 1, 0, 0, 1 }
								return c[1], c[2], c[3], c[4]
							end,
							set = function(_, r, g, b, a)
								SetEntryNested(key, 'expiring.color', { r, g, b, a })
							end,
						},
					},
				},
				delete = {
					name = L['Delete'],
					type = 'execute',
					order = 99,
					confirm = true,
					confirmText = L['Delete this aura entry?'],
					func = function()
						local entries = GetDB().entries
						entries[key] = nil

						local db = EnsureDBPath()
						db.entries[key] = nil

						UF.Unit[frameName]:ElementUpdate(elementName)
					end,
				},
			},
		}
	end

	-- Build entries section
	OptionSet.args.entries = {
		name = L['Aura indicators'],
		type = 'group',
		order = 10,
		args = (function()
			local args = {}
			local entries = GetDB().entries or {}
			for key, entry in pairs(entries) do
				args['entry_' .. key] = BuildEntryOptions(key, entry)
			end
			if not next(entries) then
				args.empty = {
					name = L['No aura indicators defined. Click "Add aura indicator" below to get started.'],
					type = 'description',
					order = 1,
				}
			end
			return args
		end)(),
	}

	-- Add new entry button
	OptionSet.args.addNew = {
		name = L['Add aura indicator'],
		type = 'execute',
		order = 20,
		func = function()
			local entries = GetDB().entries
			local maxKey = 0
			for key in pairs(entries) do
				local num = tonumber(key)
				if num and num > maxKey then
					maxKey = num
				end
			end
			local nextKey = tostring(maxKey + 1)

			local newEntry = {
				enabled = true,
				name = 'New Aura',
				spellId = 0,
				spellName = '',
				type = 'icon',
				filter = 'HELPFUL',
				onlyMine = false,
				priority = 50,
				icon = {
					size = 24,
					showSwipe = true,
					showStacks = true,
					position = { anchor = 'TOPLEFT', x = 0, y = 0 },
					layoutGroup = '',
				},
				border = { size = 2, color = { 0, 1, 0, 0.8 } },
				glow = { glowType = 'pixel', color = { 0.95, 0.95, 0.32, 1 }, frequency = 0.25, numLines = 8, thickness = 2 },
				expiring = { enabled = false, threshold = 3, color = { 1, 0, 0, 1 } },
			}

			entries[nextKey] = newEntry

			local db = EnsureDBPath()
			db.entries[nextKey] = newEntry

			UF.Unit[frameName]:ElementUpdate(elementName)
		end,
	}

	-- Layout Groups section
	OptionSet.args.layoutGroups = {
		name = L['Layout groups'],
		type = 'group',
		order = 30,
		args = {
			desc = {
				name = L['Group multiple icon indicators together with automatic positioning. Icons in a group are arranged by priority.'],
				type = 'description',
				order = 0,
			},
			addGroup = {
				name = L['Group name'],
				type = 'input',
				order = 1,
				set = function(_, name)
					if not name or name == '' then
						return
					end
					name = name:match('^%s*(.-)%s*$')

					local currentDB = GetDB()
					if not currentDB.layoutGroups then
						currentDB.layoutGroups = {}
					end
					currentDB.layoutGroups[name] = {
						enabled = true,
						direction = 'RIGHT',
						spacing = 2,
						anchor = 'TOPLEFT',
						x = 2,
						y = -2,
						limit = 5,
					}

					local db = EnsureDBPath()
					if not db.layoutGroups then
						db.layoutGroups = {}
					end
					db.layoutGroups[name] = currentDB.layoutGroups[name]

					UF.Unit[frameName]:ElementUpdate(elementName)
				end,
				get = function()
					return ''
				end,
			},
			groups = {
				name = L['Current groups'],
				type = 'group',
				inline = true,
				order = 2,
				args = (function()
					local args = {}
					local groups = GetDB().layoutGroups or {}
					local order = 0
					for groupName, groupCfg in pairs(groups) do
						order = order + 1
						args['group_' .. groupName] = {
							name = groupName,
							type = 'group',
							inline = true,
							order = order,
							args = {
								direction = {
									name = L['Direction'],
									type = 'select',
									order = 1,
									values = { RIGHT = L['Right'], LEFT = L['Left'], UP = L['Up'], DOWN = L['Down'] },
									get = function()
										return groupCfg.direction or 'RIGHT'
									end,
									set = function(_, val)
										local currentDB = GetDB()
										currentDB.layoutGroups[groupName].direction = val
										local db = EnsureDBPath()
										if not db.layoutGroups then
											db.layoutGroups = {}
										end
										if not db.layoutGroups[groupName] then
											db.layoutGroups[groupName] = {}
										end
										db.layoutGroups[groupName].direction = val
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
								spacing = {
									name = L['Spacing'],
									type = 'range',
									order = 2,
									min = 0,
									max = 20,
									step = 1,
									get = function()
										return groupCfg.spacing or 2
									end,
									set = function(_, val)
										local currentDB = GetDB()
										currentDB.layoutGroups[groupName].spacing = val
										local db = EnsureDBPath()
										if not db.layoutGroups then
											db.layoutGroups = {}
										end
										if not db.layoutGroups[groupName] then
											db.layoutGroups[groupName] = {}
										end
										db.layoutGroups[groupName].spacing = val
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
								anchor = {
									name = L['Anchor'],
									type = 'select',
									order = 3,
									values = {
										TOPLEFT = L['Top Left'],
										TOP = L['Top'],
										TOPRIGHT = L['Top Right'],
										LEFT = L['Left'],
										CENTER = L['Center'],
										RIGHT = L['Right'],
										BOTTOMLEFT = L['Bottom Left'],
										BOTTOM = L['Bottom'],
										BOTTOMRIGHT = L['Bottom Right'],
									},
									get = function()
										return groupCfg.anchor or 'TOPLEFT'
									end,
									set = function(_, val)
										local currentDB = GetDB()
										currentDB.layoutGroups[groupName].anchor = val
										local db = EnsureDBPath()
										if not db.layoutGroups then
											db.layoutGroups = {}
										end
										if not db.layoutGroups[groupName] then
											db.layoutGroups[groupName] = {}
										end
										db.layoutGroups[groupName].anchor = val
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
								x = {
									name = L['X Offset'],
									type = 'range',
									order = 4,
									min = -200,
									max = 200,
									step = 1,
									get = function()
										return groupCfg.x or 0
									end,
									set = function(_, val)
										local currentDB = GetDB()
										currentDB.layoutGroups[groupName].x = val
										local db = EnsureDBPath()
										if not db.layoutGroups then
											db.layoutGroups = {}
										end
										if not db.layoutGroups[groupName] then
											db.layoutGroups[groupName] = {}
										end
										db.layoutGroups[groupName].x = val
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
								y = {
									name = L['Y Offset'],
									type = 'range',
									order = 5,
									min = -200,
									max = 200,
									step = 1,
									get = function()
										return groupCfg.y or 0
									end,
									set = function(_, val)
										local currentDB = GetDB()
										currentDB.layoutGroups[groupName].y = val
										local db = EnsureDBPath()
										if not db.layoutGroups then
											db.layoutGroups = {}
										end
										if not db.layoutGroups[groupName] then
											db.layoutGroups[groupName] = {}
										end
										db.layoutGroups[groupName].y = val
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
								limit = {
									name = L['Max icons'],
									type = 'range',
									order = 6,
									min = 1,
									max = 20,
									step = 1,
									get = function()
										return groupCfg.limit or 5
									end,
									set = function(_, val)
										local currentDB = GetDB()
										currentDB.layoutGroups[groupName].limit = val
										local db = EnsureDBPath()
										if not db.layoutGroups then
											db.layoutGroups = {}
										end
										if not db.layoutGroups[groupName] then
											db.layoutGroups[groupName] = {}
										end
										db.layoutGroups[groupName].limit = val
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
								deleteGroup = {
									name = L['Delete group'],
									type = 'execute',
									order = 99,
									confirm = true,
									confirmText = L['Delete this layout group?'],
									func = function()
										local currentDB = GetDB()
										if currentDB.layoutGroups then
											currentDB.layoutGroups[groupName] = nil
										end
										local db = EnsureDBPath()
										if db.layoutGroups then
											db.layoutGroups[groupName] = nil
										end
										UF.Unit[frameName]:ElementUpdate(elementName)
									end,
								},
							},
						}
					end
					if not next(groups) then
						args.empty = {
							name = L['No layout groups defined.'],
							type = 'description',
							order = 1,
						}
					end
					return args
				end)(),
			},
		},
	}
end

-- ============================================================
-- SETTINGS & REGISTRATION
-- ============================================================

---@type SUI.UF.Elements.Settings
local Settings = {
	enabled = false,
	entries = {},
	layoutGroups = {},
	config = {
		NoBulkUpdate = true,
		type = 'Auras',
		DisplayName = 'Aura Designer',
	},
}

UF.Elements:Register('AuraDesigner', Build, Update, Options, Settings)
