local UF = SUI.UF
local L = SUI.L

local elementList = {
	---Basic
	'FrameBackground',
	'Name',
	'Health',
	'Castbar',
	'Power',
	'Portrait',
	'Dispel',
	'SpartanArt',
	'Buffs',
	'Debuffs',
	'ClassIcon',
	'RaidTargetIndicator',
	'TargetIndicator',
	'ThreatIndicator',
	'Range',
	'Fader',
	--Friendly Only
	'AssistantIndicator',
	'GroupRoleIndicator',
	'LeaderIndicator',
	'PhaseIndicator',
	'PvPIndicator',
	'RaidRoleIndicator',
	'ReadyCheckIndicator',
	'ResurrectIndicator',
	'SummonIndicator',
	'StatusText',
	'SUI_RaidGroup',
	'AuraWatch',
	'DefensiveIndicator',
	'RaidDebuffs',
	'CornerIndicators',
	'PrivateAuras',
	'CustomText',
	'AuraDesigner',
}

-- Tier definitions: 3 independent raid frame types with secure visibility conditions
local tierDefs = {
	{
		name = 'raid10',
		maxFrames = 10,
		displayName = 'Raid (1-10)',
		-- Show when in raid AND raid member 11 does NOT exist
		visibility = '[@raid11,exists] hide; [group:raid] show; hide',
	},
	{
		name = 'raid25',
		maxFrames = 25,
		displayName = 'Raid (11-25)',
		-- Show when raid11 exists AND raid26 does NOT exist
		visibility = '[@raid26,exists] hide; [@raid11,exists][group:raid] show; hide',
	},
	{
		name = 'raid40',
		maxFrames = 40,
		displayName = 'Raid (26-40)',
		-- Show when raid26 exists
		visibility = '[@raid26,exists][group:raid] show; hide',
	},
}

-- Shared element builder for all tiers
local function Builder(frame)
	local frameName = frame:GetName() or 'Unknown'
	local elementDB = frame.elementDB

	if UF.BuildDebug then
		UF:debug('Raid Builder ENTRY - Frame: ' .. frameName)
		UF:debug('Raid Builder - Element list has ' .. #elementList .. ' elements to build')
	end

	for index, elementName in pairs(elementList) do
		if UF.BuildDebug then
			UF:debug('Raid Builder - Building element [' .. index .. ']: ' .. elementName .. ' for frame: ' .. frameName)
			if not elementDB[elementName] then
				UF:debug('Raid Builder - WARNING: No DB entry for element: ' .. elementName)
			end
		end
		UF.Elements:Build(frame, elementName, elementDB[elementName])
	end

	if UF.BuildDebug then
		UF:debug('Raid Builder EXIT - Completed building all elements for: ' .. frameName)
	end
end

-- Factory: create GroupBuilder for a specific tier
local function CreateGroupBuilder(tierName, maxFrames)
	return function(holder)
		if UF.BuildDebug then
			UF:debug(tierName .. ' GroupBuilder ENTRY - Creating header')
		end

		local settings = UF.CurrentSettings[tierName]
		---@diagnostic disable-next-line: undefined-field
		local configFunc = ('self:SetWidth(%d) self:SetHeight(%d)'):format(settings.width, UF:CalculateHeight(tierName))
		local growthMap = UF.Options.GrowthDirectionMap[settings.growthDirection] or UF.Options.GrowthDirectionMap['DOWN_RIGHT']

		local function groupingOrder()
			local order = 'TANK,HEALER,DAMAGER,NONE'
			if settings.mode == 'GROUP' then
				order = '1,2,3,4,5,6,7,8'
			end
			return order
		end

		local headerName = 'SUI_UF_' .. tierName .. '_Header'

		if SUI.IsRetail then
			holder.header = SUIUF:SpawnHeader(
				headerName,
				nil,
				'showRaid',
				true,
				'showParty',
				false,
				'showPlayer',
				settings.showPlayer,
				'showSolo',
				true,
				'xoffset',
				settings.xOffset,
				'yOffset',
				settings.yOffset,
				'point',
				growthMap.point,
				'groupBy',
				settings.mode,
				'groupingOrder',
				groupingOrder(),
				'sortMethod',
				(settings.sortMethod or 'INDEX'):lower(),
				'sortDir',
				settings.sortDir or 'ASC',
				'maxColumns',
				settings.maxColumns,
				'unitsPerColumn',
				settings.unitsPerColumn,
				'columnSpacing',
				settings.columnSpacing,
				'columnAnchorPoint',
				growthMap.columnAnchorPoint,
				'oUF-initialConfigFunction',
				configFunc,
				'templateType',
				'Button'
			)
		else
			holder.header = SUIUF:SpawnHeader(
				headerName,
				nil,
				'raid',
				'showRaid',
				true,
				'showParty',
				false,
				'showPlayer',
				settings.showPlayer,
				'showSolo',
				true,
				'xoffset',
				settings.xOffset,
				'yOffset',
				settings.yOffset,
				'point',
				growthMap.point,
				'groupBy',
				settings.mode,
				'groupingOrder',
				groupingOrder(),
				'sortMethod',
				(settings.sortMethod or 'INDEX'):lower(),
				'sortDir',
				settings.sortDir or 'ASC',
				'maxColumns',
				settings.maxColumns,
				'unitsPerColumn',
				settings.unitsPerColumn,
				'columnSpacing',
				settings.columnSpacing,
				'columnAnchorPoint',
				growthMap.columnAnchorPoint,
				'oUF-initialConfigFunction',
				configFunc
			)
		end

		holder.header:SetPoint('TOPLEFT', holder, 'TOPLEFT')

		-- Force creation of frames upfront (tier-appropriate count)
		holder.header:SetAttribute('startingIndex', -maxFrames)
		holder.header:Show()
		holder.header.initialized = true
		holder.header:SetAttribute('startingIndex', nil)

		if UF.BuildDebug then
			UF:debug(tierName .. ' GroupBuilder EXIT - Created ' .. maxFrames .. ' frames')
		end
	end
end

-- Factory: create Update function for a specific tier
local function CreateUpdate(tierName)
	return function(frame)
		if frame and frame.header then
			local settings = UF.CurrentSettings[tierName]
			local growthMap = UF.Options.GrowthDirectionMap[settings.growthDirection] or UF.Options.GrowthDirectionMap['DOWN_RIGHT']

			local function groupingOrder()
				local order = 'TANK,HEALER,DAMAGER,NONE'
				if settings.mode == 'GROUP' then
					order = '1,2,3,4,5,6,7,8'
				end
				return order
			end

			---@diagnostic disable-next-line: undefined-field
			local configFunc = ('self:SetWidth(%d) self:SetHeight(%d)'):format(settings.width, UF:CalculateHeight(tierName))
			frame.header:SetAttribute('initialConfigFunction', configFunc)

			frame.header:SetAttribute('xoffset', settings.xOffset)
			frame.header:SetAttribute('yOffset', settings.yOffset)
			frame.header:SetAttribute('maxColumns', settings.maxColumns)
			frame.header:SetAttribute('unitsPerColumn', settings.unitsPerColumn)
			frame.header:SetAttribute('columnSpacing', settings.columnSpacing)
			frame.header:SetAttribute('groupBy', settings.mode)
			frame.header:SetAttribute('groupingOrder', groupingOrder())
			frame.header:SetAttribute('showPlayer', settings.showPlayer)
			frame.header:SetAttribute('sortMethod', (settings.sortMethod or 'INDEX'):lower())
			frame.header:SetAttribute('sortDir', settings.sortDir or 'ASC')
			frame.header:SetAttribute('point', growthMap.point)
			frame.header:SetAttribute('columnAnchorPoint', growthMap.columnAnchorPoint)
		end
	end
end

-- Factory: create Options function for a specific tier
local function CreateOptions(tierName)
	return function(OptionSet)
		UF.Options:AddGroupDisplay(tierName, OptionSet)
		UF.Options:AddGroupLayout(tierName, OptionSet)

		OptionSet.args.General.args.Layout.args.bar2 = { name = 'Offsets', type = 'header', order = 20 }
		OptionSet.args.General.args.Layout.args.mode = {
			name = L['Sort order'],
			type = 'select',
			order = 11,
			values = { ['GROUP'] = 'Groups', ['NAME'] = 'Name', ['ASSIGNEDROLE'] = 'Roles' },
			set = function(info, val)
				UF.CurrentSettings[tierName].mode = val
				UF.DB.UserSettings[UF:GetPresetForFrame(tierName)][tierName].mode = val
				local go = 'TANK,HEALER,DAMAGER,NONE'
				if val == 'GROUP' then
					go = '1,2,3,4,5,6,7,8'
				end
				UF.Unit:Get(tierName).header:SetAttribute('groupBy', val)
				UF.Unit:Get(tierName).header:SetAttribute('groupingOrder', go)
			end,
		}
	end
end

-- Base element settings shared by all tiers
local baseElements = {
	FrameBackground = {
		enabled = false,
		displayLevel = -5,
		background = {
			enabled = false,
			type = 'color',
			color = { 0.1, 0.1, 0.1, 0.8 },
			alpha = 0.8,
			classColor = false,
		},
		border = {
			enabled = false,
			sides = { top = true, bottom = true, left = true, right = true },
			size = 1,
			colors = {
				top = { 1, 1, 1, 1 },
				bottom = { 1, 1, 1, 1 },
				left = { 1, 1, 1, 1 },
				right = { 1, 1, 1, 1 },
			},
			classColors = { top = false, bottom = false, left = false, right = false },
		},
	},
	AuraWatch = {
		enabled = true,
		size = 16,
	},
	ResurrectIndicator = {
		enabled = true,
	},
	SummonIndicator = {
		enabled = true,
	},
	RaidTargetIndicator = {
		size = 16,
		alpha = 0.65,
		position = {
			x = 2,
		},
	},
	RaidRoleIndicator = {
		enabled = true,
		size = 10,
		alpha = 0.7,
		position = {
			anchor = 'BOTTOMLEFT',
			x = 0,
			y = 0,
		},
	},
	ReadyCheckIndicator = {
		size = 15,
		position = {
			anchor = 'RIGHT',
			x = -5,
		},
	},
	ThreatIndicator = {
		enabled = true,
		points = 'Name',
	},
	Name = {
		enabled = true,
		height = 10,
		textSize = 10,
		text = '[SUI_ColorClass][name]',
		position = {
			y = 0,
		},
	},
	SUI_RaidGroup = {
		textSize = 9,
		text = '[group]',
		SetJustifyH = 'CENTER',
		SetJustifyV = 'MIDDLE',
		position = {
			anchor = 'BOTTOMRIGHT',
			x = 0,
			y = 5,
		},
	},
	GroupRoleIndicator = {
		enabled = true,
		size = 15,
		alpha = 0.75,
		ShowDPS = false,
		position = {
			anchor = 'TOPRIGHT',
			x = -1,
			y = 1,
		},
	},
	TargetIndicator = {
		enabled = true,
		ShowTarget = true,
		mode = 'border',
		texture = {
			textureKey = 'DoubleArrow',
			placement = 'sides',
			scale = 1.0,
			color = { 1, 1, 1, 1 },
			alpha = 1.0,
		},
		border = {
			size = 2,
			color = { 0, 1, 0, 1 },
			sides = { top = true, bottom = true, left = true, right = true },
			displayLevel = 5,
		},
	},
	DefensiveIndicator = {
		enabled = true,
		size = 20,
		showSwipe = true,
		showDuration = true,
		showBorder = true,
		borderSize = 2,
		borderColor = { 0, 0.8, 0, 1 },
		position = {
			anchor = 'CENTER',
			x = 0,
			y = 0,
		},
	},
	RaidDebuffs = {
		enabled = true,
		size = 28,
		showDuration = true,
		position = {
			anchor = 'CENTER',
			x = 0,
			y = 0,
		},
	},
	Dispel = {
		enabled = true,
	},
	PrivateAuras = {
		enabled = true,
	},
}

-- Per-tier setting overrides (layout + element differences)
local tierOverrides = {
	raid10 = {
		width = 110,
		maxColumns = 2,
		unitsPerColumn = 5,
		columnSpacing = 2,
		elements = {
			Buffs = {
				enabled = true,
				onlyShowPlayer = true,
				healingMode = true,
				number = 5,
				rows = 3,
				size = 18,
				spacing = 1,
				growthx = 'RIGHT',
				growthy = 'UP',
				position = {
					anchor = 'BOTTOMRIGHT',
					relativePoint = 'BOTTOMRIGHT',
					x = 0,
					y = 2,
				},
				retail = {
					filterMode = 'healing_mode',
				},
			},
			Debuffs = {
				enabled = true,
				rows = 1,
				number = 5,
				size = 18,
				spacing = 1,
				growthy = 'DOWN',
				growthx = 'LEFT',
				position = {
					anchor = 'LEFT',
					relativePoint = 'LEFT',
					x = 0,
					y = -2,
				},
				retail = {
					filterMode = 'raid_debuffs',
					disableInPvP = true,
				},
			},
			Health = {
				height = 35,
				text = {
					['1'] = {
						text = '[SUIHealth(missing,displayDead)] [($>SUIHealth<$)(percentage,hideDead)]',
					},
				},
			},
			Power = {
				height = 4,
				position = {
					y = 0,
				},
				text = {
					['1'] = {
						enabled = false,
					},
				},
			},
		},
	},
	raid25 = {
		width = 95,
		maxColumns = 5,
		unitsPerColumn = 5,
		columnSpacing = 2,
		elements = {
			Buffs = {
				enabled = true,
				onlyShowPlayer = true,
				healingMode = true,
				number = 5,
				rows = 3,
				size = 15,
				spacing = 1,
				growthx = 'RIGHT',
				growthy = 'UP',
				position = {
					anchor = 'BOTTOMRIGHT',
					relativePoint = 'BOTTOMRIGHT',
					x = 0,
					y = 2,
				},
				retail = {
					filterMode = 'healing_mode',
				},
			},
			Debuffs = {
				enabled = true,
				rows = 1,
				number = 5,
				size = 15,
				spacing = 1,
				growthy = 'DOWN',
				growthx = 'LEFT',
				position = {
					anchor = 'LEFT',
					relativePoint = 'LEFT',
					x = 0,
					y = -2,
				},
				retail = {
					filterMode = 'raid_debuffs',
					disableInPvP = true,
				},
			},
			Health = {
				height = 30,
				text = {
					['1'] = {
						text = '[SUIHealth(missing,displayDead)] [($>SUIHealth<$)(percentage,hideDead)]',
					},
				},
			},
			Power = {
				height = 2,
				position = {
					y = 0,
				},
				text = {
					['1'] = {
						enabled = false,
					},
				},
			},
		},
	},
	raid40 = {
		width = 80,
		maxColumns = 4,
		unitsPerColumn = 10,
		columnSpacing = 2,
		elements = {
			Buffs = {
				enabled = true,
				onlyShowPlayer = true,
				healingMode = true,
				number = 3,
				rows = 1,
				size = 12,
				spacing = 1,
				growthx = 'RIGHT',
				growthy = 'UP',
				position = {
					anchor = 'BOTTOMRIGHT',
					relativePoint = 'BOTTOMRIGHT',
					x = 0,
					y = 2,
				},
				retail = {
					filterMode = 'healing_mode',
				},
			},
			Debuffs = {
				enabled = true,
				rows = 1,
				number = 3,
				size = 12,
				spacing = 1,
				growthy = 'DOWN',
				growthx = 'LEFT',
				position = {
					anchor = 'LEFT',
					relativePoint = 'LEFT',
					x = 0,
					y = -2,
				},
				retail = {
					filterMode = 'raid_debuffs',
					disableInPvP = true,
				},
			},
			Health = {
				height = 25,
				text = {
					['1'] = {
						text = '[SUIHealth(missing,displayDead)] [($>SUIHealth<$)(percentage,hideDead)]',
					},
				},
			},
			Power = {
				height = 2,
				position = {
					y = 0,
				},
				text = {
					['1'] = {
						enabled = false,
					},
				},
			},
		},
	},
}

-- Build base settings shared across all tiers
local function BuildBaseSettings()
	return {
		showParty = false,
		showPlayer = true,
		showRaid = true,
		showSolo = false,
		customVisibility = '',
		difficultyVisibility = {
			enabled = false,
		},
		mode = 'ASSIGNEDROLE',
		sortMethod = 'INDEX',
		sortDir = 'ASC',
		growthDirection = 'DOWN_RIGHT',
		xOffset = 2,
		yOffset = -3,
		visibility = {
			showAlways = false,
			showInRaid = true,
			showInParty = false,
		},
		config = {
			IsGroup = true,
			isFriendly = true,
		},
	}
end

-- Register all 3 tiers
for _, tier in ipairs(tierDefs) do
	local settings = BuildBaseSettings()

	-- Apply tier-specific layout overrides
	local overrides = tierOverrides[tier.name]
	settings.width = overrides.width
	settings.maxColumns = overrides.maxColumns
	settings.unitsPerColumn = overrides.unitsPerColumn
	settings.columnSpacing = overrides.columnSpacing

	-- Build elements: start with shared base, then merge tier-specific overrides
	settings.elements = SUI:CopyData({}, baseElements)
	for elementName, elementOverride in pairs(overrides.elements) do
		settings.elements[elementName] = elementOverride
	end

	-- Store the visibility condition in customVisibility so SpawnFrames picks it up
	settings.customVisibility = tier.visibility

	UF.Unit:Add(tier.name, Builder, settings, CreateOptions(tier.name), CreateGroupBuilder(tier.name, tier.maxFrames), CreateUpdate(tier.name))
end
