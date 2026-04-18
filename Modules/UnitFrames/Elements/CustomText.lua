local UF = SUI.UF

---@param frame table
---@param DB table
local function Build(frame, DB)
	local element = {}
	element.fontStrings = {}
	frame.CustomText = element

	for key, entry in pairs(DB.entries or {}) do
		if entry.enabled then
			local fs = frame.raised:CreateFontString(nil, 'OVERLAY')
			SUI.Font:Format(fs, entry.size or 10, 'UnitFrames')
			fs:SetJustifyH(entry.SetJustifyH or 'CENTER')
			fs:SetJustifyV(entry.SetJustifyV or 'MIDDLE')

			local pos = entry.position or {}
			local relativeTo = frame
			if pos.relativeTo and pos.relativeTo ~= 'Frame' then
				relativeTo = frame[pos.relativeTo] or frame
			end
			local relativePoint = pos.relativePoint or pos.anchor or 'CENTER'
			fs:SetPoint(pos.anchor or 'CENTER', relativeTo, relativePoint, pos.x or 0, pos.y or 0)

			local text = entry.text or ''
			if entry.color then
				local r, g, b = unpack(entry.color)
				text = ('|cff%02x%02x%02x'):format((r or 1) * 255, (g or 1) * 255, (b or 1) * 255) .. text
			end
			frame:Tag(fs, text)

			element.fontStrings[key] = fs
		end
	end
end

---@param frame table
local function Update(frame)
	local element = frame.CustomText
	if not element then
		return
	end

	local DB = element.DB
	if not DB then
		return
	end

	for key, entry in pairs(DB.entries or {}) do
		local fs = element.fontStrings[key]
		if fs then
			if entry.enabled then
				SUI.Font:Format(fs, entry.size or 10, 'UnitFrames')
				fs:SetJustifyH(entry.SetJustifyH or 'CENTER')
				fs:SetJustifyV(entry.SetJustifyV or 'MIDDLE')

				fs:ClearAllPoints()
				local pos = entry.position or {}
				local relativeTo = frame
				if pos.relativeTo and pos.relativeTo ~= 'Frame' then
					relativeTo = frame[pos.relativeTo] or frame
				end
				local relativePoint = pos.relativePoint or pos.anchor or 'CENTER'
				fs:SetPoint(pos.anchor or 'CENTER', relativeTo, relativePoint, pos.x or 0, pos.y or 0)

				local text = entry.text or ''
				if entry.color then
					local r, g, b = unpack(entry.color)
					text = ('|cff%02x%02x%02x'):format((r or 1) * 255, (g or 1) * 255, (b or 1) * 255) .. text
				end
				frame:Tag(fs, text)
				fs:Show()
			else
				fs:Hide()
			end
		else
			-- New entry added after initial Build - create the FontString
			if entry.enabled then
				local newFs = frame.raised:CreateFontString(nil, 'OVERLAY')
				SUI.Font:Format(newFs, entry.size or 10, 'UnitFrames')
				newFs:SetJustifyH(entry.SetJustifyH or 'CENTER')
				newFs:SetJustifyV(entry.SetJustifyV or 'MIDDLE')

				local pos = entry.position or {}
				local relativeTo = frame
				if pos.relativeTo and pos.relativeTo ~= 'Frame' then
					relativeTo = frame[pos.relativeTo] or frame
				end
				local relativePoint = pos.relativePoint or pos.anchor or 'CENTER'
				newFs:SetPoint(pos.anchor or 'CENTER', relativeTo, relativePoint, pos.x or 0, pos.y or 0)

				local text = entry.text or ''
				if entry.color then
					local r, g, b = unpack(entry.color)
					text = ('|cff%02x%02x%02x'):format((r or 1) * 255, (g or 1) * 255, (b or 1) * 255) .. text
				end
				frame:Tag(newFs, text)

				element.fontStrings[key] = newFs
			end
		end
	end
end

---@param frameName string
---@param OptionSet AceConfig.OptionsTable
local function Options(frameName, OptionSet)
	local L = SUI.L

	local anchorValues = {
		TOPLEFT = L['Top Left'],
		TOP = L['Top'],
		TOPRIGHT = L['Top Right'],
		LEFT = L['Left'],
		CENTER = L['Center'],
		RIGHT = L['Right'],
		BOTTOMLEFT = L['Bottom Left'],
		BOTTOM = L['Bottom'],
		BOTTOMRIGHT = L['Bottom Right'],
	}

	local relativeToValues = {
		Frame = L['Frame'],
		Health = L['Health'],
		Power = L['Power'],
		Castbar = L['Castbar'],
		Name = L['Name'],
	}

	local function GetEntries()
		return UF.CurrentSettings[frameName].elements.CustomText.entries or {}
	end

	local function SetEntry(key, field, val)
		local entries = UF.CurrentSettings[frameName].elements.CustomText.entries
		if not entries[key] then
			entries[key] = {}
		end
		entries[key][field] = val

		local dbEntries = UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText
		if not dbEntries then
			UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText = {}
			dbEntries = UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText
		end
		if not dbEntries.entries then
			dbEntries.entries = {}
		end
		if not dbEntries.entries[key] then
			dbEntries.entries[key] = {}
		end
		dbEntries.entries[key][field] = val
		UF.Unit[frameName]:ElementUpdate('CustomText')
	end

	local function SetEntryNested(key, path, val)
		local keys = {}
		for k in path:gmatch('[^.]+') do
			keys[#keys + 1] = k
		end
		-- CurrentSettings
		local entries = UF.CurrentSettings[frameName].elements.CustomText.entries
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
		-- DB
		local dbEntries = UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText
		if not dbEntries then
			UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText = {}
			dbEntries = UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText
		end
		if not dbEntries.entries then
			dbEntries.entries = {}
		end
		if not dbEntries.entries[key] then
			dbEntries.entries[key] = {}
		end
		local d = dbEntries.entries[key]
		for i = 1, #keys - 1 do
			if not d[keys[i]] then
				d[keys[i]] = {}
			end
			d = d[keys[i]]
		end
		d[keys[#keys]] = val
		UF.Unit[frameName]:ElementUpdate('CustomText')
	end

	local function BuildEntryOptions(key, entry)
		return {
			name = entry.name or ('Text ' .. key),
			type = 'group',
			inline = true,
			order = tonumber(key) or 1,
			args = {
				enabled = {
					name = L['Enabled'],
					type = 'toggle',
					order = 1,
					get = function()
						return entry.enabled
					end,
					set = function(_, val)
						SetEntry(key, 'enabled', val)
					end,
				},
				text = {
					name = L['Tag string'],
					desc = L['oUF tag string. Examples: [name], [curhp]/[maxhp], [perpp]%, [SUI_ColorClass][name]'],
					type = 'input',
					width = 'double',
					order = 2,
					get = function()
						return entry.text or ''
					end,
					set = function(_, val)
						SetEntry(key, 'text', val)
					end,
				},
				size = {
					name = L['Font size'],
					type = 'range',
					order = 3,
					min = 6,
					max = 32,
					step = 1,
					get = function()
						return entry.size or 10
					end,
					set = function(_, val)
						SetEntry(key, 'size', val)
					end,
				},
				anchor = {
					name = L['Anchor point'],
					type = 'select',
					order = 4,
					values = anchorValues,
					get = function()
						return entry.position and entry.position.anchor or 'CENTER'
					end,
					set = function(_, val)
						SetEntryNested(key, 'position.anchor', val)
					end,
				},
				relativeTo = {
					name = L['Attach to'],
					type = 'select',
					order = 5,
					values = relativeToValues,
					get = function()
						return entry.position and entry.position.relativeTo or 'Frame'
					end,
					set = function(_, val)
						SetEntryNested(key, 'position.relativeTo', val)
					end,
				},
				x = {
					name = L['X Offset'],
					type = 'range',
					order = 6,
					min = -200,
					max = 200,
					step = 1,
					get = function()
						return entry.position and entry.position.x or 0
					end,
					set = function(_, val)
						SetEntryNested(key, 'position.x', val)
					end,
				},
				y = {
					name = L['Y Offset'],
					type = 'range',
					order = 7,
					min = -200,
					max = 200,
					step = 1,
					get = function()
						return entry.position and entry.position.y or 0
					end,
					set = function(_, val)
						SetEntryNested(key, 'position.y', val)
					end,
				},
				color = {
					name = L['Text color'],
					type = 'color',
					order = 8,
					get = function()
						local c = entry.color or { 1, 1, 1 }
						return c[1], c[2], c[3]
					end,
					set = function(_, r, g, b)
						SetEntry(key, 'color', { r, g, b })
					end,
				},
			},
		}
	end

	-- Build options for each existing entry
	local entries = GetEntries()
	for key, entry in pairs(entries) do
		OptionSet.args['entry_' .. key] = BuildEntryOptions(key, entry)
	end

	-- Add new entry button
	OptionSet.args.addNew = {
		name = L['Add custom text'],
		type = 'execute',
		order = 100,
		func = function()
			local currentEntries = UF.CurrentSettings[frameName].elements.CustomText.entries
			local nextKey = tostring(#currentEntries + 1)
			local newEntry = {
				enabled = true,
				name = 'Custom ' .. nextKey,
				text = '[name]',
				size = 10,
				SetJustifyH = 'CENTER',
				SetJustifyV = 'MIDDLE',
				position = {
					anchor = 'CENTER',
					relativeTo = 'Frame',
					relativePoint = 'CENTER',
					x = 0,
					y = 0,
				},
			}
			currentEntries[nextKey] = newEntry

			local dbEntries = UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText
			if not dbEntries then
				UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText = {}
				dbEntries = UF.DB.UserSettings[UF:GetPresetForFrame(frameName)][frameName].elements.CustomText
			end
			if not dbEntries.entries then
				dbEntries.entries = {}
			end
			dbEntries.entries[nextKey] = newEntry

			UF.Unit[frameName]:ElementUpdate('CustomText')
		end,
	}
end

---@type SUI.UF.Elements.Settings
local Settings = {
	enabled = true,
	entries = {},
	config = {
		NoBulkUpdate = true,
		type = 'Text',
	},
}

UF.Elements:Register('CustomText', Build, Update, Options, Settings)
