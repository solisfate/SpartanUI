local UF = SUI.UF
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
}

local function groupingOrder()
	local groupingOrder = 'TANK,HEALER,DAMAGER,NONE'

	if UF.CurrentSettings.raid.mode == 'GROUP' then
		groupingOrder = '1,2,3,4,5,6,7,8'
	end
	return groupingOrder
end

-- Determine which raid tier to use based on group member count
local function GetCurrentRaidTier()
	local numMembers = GetNumGroupMembers()
	if numMembers <= 10 then
		return 'small'
	elseif numMembers <= 25 then
		return 'medium'
	else
		return 'large'
	end
end

-- Apply raid tier overrides to the header if tier config is enabled
local function ApplyRaidTierOverrides()
	local settings = UF.CurrentSettings.raid
	if not settings.raidTiers or not settings.raidTiers.enabled then
		return
	end

	local raidUnit = UF.Unit:Get('raid')
	if not raidUnit or not raidUnit.header then
		return
	end

	if InCombatLockdown() then
		return
	end

	local tier = GetCurrentRaidTier()
	local tierConfig = settings.raidTiers[tier]
	if not tierConfig then
		return
	end

	local header = raidUnit.header

	if tierConfig.maxColumns then
		header:SetAttribute('maxColumns', tierConfig.maxColumns)
	end
	if tierConfig.unitsPerColumn then
		header:SetAttribute('unitsPerColumn', tierConfig.unitsPerColumn)
	end
	if tierConfig.columnSpacing then
		header:SetAttribute('columnSpacing', tierConfig.columnSpacing)
	end
	if tierConfig.width then
		local height = UF:CalculateHeight('raid')
		---@diagnostic disable-next-line: undefined-field
		local configFunc = ('self:SetWidth(%d) self:SetHeight(%d)'):format(tierConfig.width, height)
		header:SetAttribute('initialConfigFunction', configFunc)
		-- Resize existing child frames
		for i = 1, 40 do
			local child = header:GetAttribute('child' .. i)
			if child then
				child:SetWidth(tierConfig.width)
			end
		end
	end
	if tierConfig.growthDirection then
		local growthMap = UF.Options.GrowthDirectionMap[tierConfig.growthDirection] or UF.Options.GrowthDirectionMap['DOWN_RIGHT']
		header:SetAttribute('point', growthMap.point)
		header:SetAttribute('columnAnchorPoint', growthMap.columnAnchorPoint)
	end
end

-- Track the current tier to avoid unnecessary updates
local lastAppliedTier = nil

local function GroupBuilder(holder)
	if UF.BuildDebug then
		UF:debug('Raid GroupBuilder ENTRY - Creating raid header')
	end

	---@diagnostic disable-next-line: undefined-field
	local configFunc = ('self:SetWidth(%d) self:SetHeight(%d)'):format(UF.CurrentSettings.raid.width, UF:CalculateHeight('raid'))
	if UF.BuildDebug then
		UF:debug('Raid GroupBuilder - Config function: ' .. configFunc)
		UF:debug(
			'Raid GroupBuilder - Settings: mode='
				.. UF.CurrentSettings.raid.mode
				.. ', maxColumns='
				.. UF.CurrentSettings.raid.maxColumns
				.. ', unitsPerColumn='
				.. UF.CurrentSettings.raid.unitsPerColumn
		)
	end

	local settings = UF.CurrentSettings.raid
	local growthMap = UF.Options.GrowthDirectionMap[settings.growthDirection] or UF.Options.GrowthDirectionMap['DOWN_RIGHT']

	if SUI.IsRetail then
		-- Retail uses templateType
		holder.header = SUIUF:SpawnHeader(
			'SUI_UF_raid_Header',
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
		-- Classic versions use unit string without templateType
		holder.header = SUIUF:SpawnHeader(
			'SUI_UF_raid_Header',
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

	if UF.BuildDebug then
		UF:debug('Raid GroupBuilder - Header spawned, setting up attributes')
	end
	holder.header:SetPoint('TOPLEFT', holder, 'TOPLEFT')

	-- Force creation of all 40 possible raid frames upfront
	-- startingIndex < 0 means "create this many frames immediately"
	-- Setting to -40 creates frames 1-40 which covers the full raid
	-- This ensures all frames go through proper oUF initialization
	holder.header:SetAttribute('startingIndex', -40)
	holder.header:Show()
	holder.header.initialized = true
	holder.header:SetAttribute('startingIndex', nil)

	if UF.BuildDebug then
		UF:debug('Raid GroupBuilder EXIT - Header initialization complete, created 40 frames')
	end
end

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

local function Update(frame)
	-- Force header to update its configuration when settings change
	if frame and frame.header then
		local settings = UF.CurrentSettings.raid
		local growthMap = UF.Options.GrowthDirectionMap[settings.growthDirection] or UF.Options.GrowthDirectionMap['DOWN_RIGHT']

		-- Update the initialConfigFunction with new dimensions
		---@diagnostic disable-next-line: undefined-field
		local configFunc = ('self:SetWidth(%d) self:SetHeight(%d)'):format(settings.width, UF:CalculateHeight('raid'))
		frame.header:SetAttribute('initialConfigFunction', configFunc)

		-- Update header attributes that affect layout and size
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

		-- Register for raid tier detection if not already done
		if not frame._raidTierRegistered then
			local eventFrame = CreateFrame('Frame')
			eventFrame:RegisterEvent('GROUP_ROSTER_UPDATE')
			eventFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
			eventFrame:SetScript('OnEvent', function(_, event)
				local settings = UF.CurrentSettings.raid
				if not settings.raidTiers or not settings.raidTiers.enabled then
					return
				end
				local currentTier = GetCurrentRaidTier()
				if event == 'GROUP_ROSTER_UPDATE' then
					if currentTier ~= lastAppliedTier then
						if InCombatLockdown() then
							lastAppliedTier = 'pending'
						else
							lastAppliedTier = currentTier
							ApplyRaidTierOverrides()
						end
					end
				elseif event == 'PLAYER_REGEN_ENABLED' then
					if lastAppliedTier == 'pending' then
						lastAppliedTier = GetCurrentRaidTier()
						ApplyRaidTierOverrides()
					end
				end
			end)
			frame._raidTierRegistered = true
		end

		-- Apply tier overrides after base settings
		ApplyRaidTierOverrides()
	end
end

local function Options(OptionSet)
	local L = SUI.L
	UF.Options:AddGroupDisplay('raid', OptionSet)
	UF.Options:AddGroupDisplay('raid', OptionSet)
	UF.Options:AddGroupLayout('raid', OptionSet)

	OptionSet.args.General.args.Layout.args.bar2 = { name = 'Offsets', type = 'header', order = 20 }
	OptionSet.args.General.args.Layout.args.mode = {
		name = L['Sort order'],
		type = 'select',
		order = 11,
		values = { ['GROUP'] = 'Groups', ['NAME'] = 'Name', ['ASSIGNEDROLE'] = 'Roles' },
		set = function(info, val)
			UF.CurrentSettings.raid.mode = val
			UF.DB.UserSettings[UF:GetPresetForFrame('raid')]['raid'].mode = val
			local go = 'TANK,HEALER,DAMAGER,NONE'
			if val == 'GROUP' then
				go = '1,2,3,4,5,6,7,8'
			end
			UF.Unit:Get('raid').header:SetAttribute('groupBy', val)
			UF.Unit:Get('raid').header:SetAttribute('groupingOrder', go)
		end,
	}

	-- Raid Tier options
	local function TierUpdate(tierKey, setting, val)
		if not UF.CurrentSettings.raid.raidTiers then
			UF.CurrentSettings.raid.raidTiers = {}
		end
		if tierKey then
			if not UF.CurrentSettings.raid.raidTiers[tierKey] then
				UF.CurrentSettings.raid.raidTiers[tierKey] = {}
			end
			UF.CurrentSettings.raid.raidTiers[tierKey][setting] = val
			local userSettings = UF.DB.UserSettings[UF:GetPresetForFrame('raid')]['raid']
			if not userSettings.raidTiers then
				userSettings.raidTiers = {}
			end
			if not userSettings.raidTiers[tierKey] then
				userSettings.raidTiers[tierKey] = {}
			end
			userSettings.raidTiers[tierKey][setting] = val
		else
			UF.CurrentSettings.raid.raidTiers[setting] = val
			local userSettings = UF.DB.UserSettings[UF:GetPresetForFrame('raid')]['raid']
			if not userSettings.raidTiers then
				userSettings.raidTiers = {}
			end
			userSettings.raidTiers[setting] = val
		end
		ApplyRaidTierOverrides()
	end

	local function BuildTierOptions(tierKey, tierName, sizeDesc, order)
		return {
			name = tierName,
			desc = sizeDesc,
			type = 'group',
			order = order,
			inline = true,
			args = {
				maxColumns = {
					name = L['Max columns'],
					type = 'range',
					order = 1,
					min = 1,
					max = 8,
					step = 1,
					get = function()
						local tiers = UF.CurrentSettings.raid.raidTiers
						return tiers and tiers[tierKey] and tiers[tierKey].maxColumns or 4
					end,
					set = function(_, val)
						TierUpdate(tierKey, 'maxColumns', val)
					end,
				},
				unitsPerColumn = {
					name = L['Units per column'],
					type = 'range',
					order = 2,
					min = 1,
					max = 40,
					step = 1,
					get = function()
						local tiers = UF.CurrentSettings.raid.raidTiers
						return tiers and tiers[tierKey] and tiers[tierKey].unitsPerColumn or 10
					end,
					set = function(_, val)
						TierUpdate(tierKey, 'unitsPerColumn', val)
					end,
				},
				width = {
					name = L['Frame width'],
					type = 'range',
					order = 3,
					min = 40,
					max = 200,
					step = 1,
					get = function()
						local tiers = UF.CurrentSettings.raid.raidTiers
						return tiers and tiers[tierKey] and tiers[tierKey].width or 95
					end,
					set = function(_, val)
						TierUpdate(tierKey, 'width', val)
					end,
				},
				columnSpacing = {
					name = L['Column spacing'],
					type = 'range',
					order = 4,
					min = 0,
					max = 20,
					step = 1,
					get = function()
						local tiers = UF.CurrentSettings.raid.raidTiers
						return tiers and tiers[tierKey] and tiers[tierKey].columnSpacing or 2
					end,
					set = function(_, val)
						TierUpdate(tierKey, 'columnSpacing', val)
					end,
				},
			},
		}
	end

	OptionSet.args.General.args.RaidTiers = {
		name = L['Raid size tiers'],
		desc = L['Use different layouts based on raid group size. Changes apply when group size crosses tier boundaries.'],
		type = 'group',
		order = 30,
		args = {
			enabled = {
				name = L['Enable raid size tiers'],
				desc = L['Automatically adjust raid frame layout based on group size. Small (1-10), Medium (11-25), Large (26-40).'],
				type = 'toggle',
				width = 'double',
				order = 1,
				get = function()
					local tiers = UF.CurrentSettings.raid.raidTiers
					return tiers and tiers.enabled
				end,
				set = function(_, val)
					TierUpdate(nil, 'enabled', val)
				end,
			},
			small = BuildTierOptions('small', L['Small (1-10 players)'], L['Layout for 10-player raids and dungeons'], 10),
			medium = BuildTierOptions('medium', L['Medium (11-25 players)'], L['Layout for 25-player raids'], 20),
			large = BuildTierOptions('large', L['Large (26-40 players)'], L['Layout for 40-player raids'], 30),
		},
	}
end

---@type SUI.UF.Unit.Settings
local Settings = {
	width = 95,
	showParty = false,
	showPlayer = true,
	showRaid = true,
	showSolo = false,
	customVisibility = '',
	mode = 'ASSIGNEDROLE',
	sortMethod = 'INDEX',
	sortDir = 'ASC',
	growthDirection = 'DOWN_RIGHT',
	xOffset = 2,
	yOffset = -3,
	maxColumns = 4,
	unitsPerColumn = 10,
	columnSpacing = 2,
	raidTiers = {
		enabled = false,
		small = {
			maxColumns = 2,
			unitsPerColumn = 5,
			width = 110,
			columnSpacing = 2,
		},
		medium = {
			maxColumns = 5,
			unitsPerColumn = 5,
			width = 95,
			columnSpacing = 2,
		},
		large = {
			maxColumns = 4,
			unitsPerColumn = 10,
			width = 80,
			columnSpacing = 2,
		},
	},
	visibility = {
		showAlways = false,
		showInRaid = true,
		showInParty = false,
	},
	elements = {
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
				filterMode = 'healing_mode', -- Show HoTs and combat-relevant buffs
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
				filterMode = 'raid_debuffs', -- Show all raid-relevant debuffs
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
	},
	config = {
		IsGroup = true,
		isFriendly = true,
	},
}

UF.Unit:Add('raid', Builder, Settings, Options, GroupBuilder, Update)
