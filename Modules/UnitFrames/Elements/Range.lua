local UF, L = SUI.UF, SUI.L
local canAccess = SUI.BlizzAPI.canaccessvalue

-- Elements that should never have per-element alpha applied
local SKIP_ELEMENTS = {
	Range = true,
	Fader = true,
	FrameBackground = true,
	CustomText = true,
	AuraDesigner = true,
}

-- Apply per-element alpha for OOR or dead state
---@param frame table
---@param state string 'oor'|'dead'|'normal'
local function ApplyPerElementAlpha(frame, state)
	if not frame.elementList then
		return
	end

	for _, elementName in pairs(frame.elementList) do
		if not SKIP_ELEMENTS[elementName] then
			local element = frame[elementName]
			if element and element.DB and element.SetAlpha then
				local baseAlpha = element.DB.alpha or 1
				local stateAlpha

				if state == 'oor' and element.DB.oorAlpha then
					stateAlpha = element.DB.oorAlpha
				elseif state == 'dead' and element.DB.deadAlpha then
					stateAlpha = element.DB.deadAlpha
				end

				if stateAlpha then
					element:SetAlpha(stateAlpha)
				else
					element:SetAlpha(baseAlpha)
				end
			end
		end
	end

	frame._elementAlphaState = state
end

---@param frame table
---@param DB table
local function Build(frame, DB)
	frame.Range = {
		insideAlpha = DB.insideAlpha,
		outsideAlpha = DB.outsideAlpha,
	}

	-- Set up PostUpdate to handle per-element OOR alpha
	frame.Range.PostUpdate = function(element, object, inRange, isEligible)
		-- Test mode: skip range alpha changes so forced frames stay visible
		if object.isForced then
			ApplyPerElementAlpha(object, 'normal')
			return
		end
		if isEligible and canAccess(inRange) and not inRange then
			ApplyPerElementAlpha(object, 'oor')
		else
			-- Check if unit is dead before resetting to normal
			local unit = object.unit
			if unit and UnitExists(unit) then
				local isDead = UnitIsDeadOrGhost(unit)
				if isDead and canAccess(isDead) and isDead then
					ApplyPerElementAlpha(object, 'dead')
				else
					ApplyPerElementAlpha(object, 'normal')
				end
			else
				ApplyPerElementAlpha(object, 'normal')
			end
		end
	end

	-- Hook health PostUpdate to detect dead state
	if frame.Health then
		local existingPostUpdate = frame.Health.PostUpdate
		frame.Health.PostUpdate = function(self, unit, cur, max, ...)
			if existingPostUpdate then
				existingPostUpdate(self, unit, cur, max, ...)
			end

			-- Only apply dead state if not already OOR
			if frame._elementAlphaState ~= 'oor' then
				if unit and UnitExists(unit) then
					local isDead = UnitIsDeadOrGhost(unit)
					if isDead and canAccess(isDead) and isDead then
						ApplyPerElementAlpha(frame, 'dead')
					elseif frame._elementAlphaState == 'dead' then
						ApplyPerElementAlpha(frame, 'normal')
					end
				end
			end
		end
	end
end

---@param frame table
local function Update(frame)
	local DB = UF.CurrentSettings[frame.unitOnCreate].elements.Range
	frame.Range.insideAlpha = DB.insideAlpha
	frame.Range.outsideAlpha = DB.outsideAlpha
end

---@param unitName string
---@param OptionSet AceConfig.OptionsTable
local function Options(unitName, OptionSet)
	if unitName == 'player' then
		OptionSet.hidden = true
		return
	end
	OptionSet.args = {
		enabled = {
			name = L['Enabled'],
			type = 'toggle',
			order = 10,
			set = function(info, val)
				UF.CurrentSettings[unitName].elements.Range.enabled = val
				UF.DB.UserSettings[UF:GetPresetForFrame(unitName)][unitName].elements.Range.enabled = val
				if val then
					UF.Unit[unitName]:EnableElement('Range')
				else
					UF.Unit[unitName]:DisableElement('Range')
				end
			end,
		},
		insideAlpha = {
			name = L['In range alpha'],
			type = 'range',
			min = 0,
			max = 1,
			step = 0.1,
		},
		outsideAlpha = {
			name = L['Out of range alpha'],
			type = 'range',
			min = 0,
			max = 1,
			step = 0.1,
		},
	}
end

---@type SUI.UF.Elements.Settings
local Settings = {
	enabled = true,
	insideAlpha = 1,
	outsideAlpha = 0.3,
	config = {
		NoBulkUpdate = true,
	},
}

UF.Elements:Register('Range', Build, Update, Options, Settings)
