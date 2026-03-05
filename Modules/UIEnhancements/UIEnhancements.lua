local SUI, L = SUI, SUI.L
---@class SUI.Module.UIEnhancements : SUI.Module
local module = SUI:NewModule('UIEnhancements')
module.DisplayName = L['UI Enhancements']
module.description = 'Add and improve UI functionality'
----------------------------------------------------------------------------------------------------

---@class SUI.Module.UIEnhancements.DB
local DBDefaults = {
	-- DecorMerchant
	decorMerchantBulkBuy = true,
	-- LootAlertPopup
	lootAlertPopup = true,
	lootAlertChat = true,
	lootAlertSound = false,
	lootAlertSoundName = 'None',
	-- Mouse Ring Settings
	mouseRing = {
		enabled = false,
		circleStyle = 1, -- 1=circle.tga, 2=ChallengeMode-KeystoneSlotFrameGlow, 3=GarrLanding-CircleGlow, 4=ShipMission-RedGlowRing
		size = 32,
		alpha = 0.8,
		color = { mode = 'class', r = 1, g = 1, b = 1 },
		showCenterDot = false,
		centerDotSize = 4,
		combatOnly = false,
		-- GCD Mode
		gcdEnabled = false,
		gcdAlpha = 0.8,
		gcdReverse = false, -- false = swipe empties, true = swipe fills
	},
	-- Mouse Trail Settings
	mouseTrail = {
		enabled = false,
		density = 'medium',
		size = 8,
		alpha = 0.6,
		color = { mode = 'class', r = 1, g = 1, b = 1 },
		combatOnly = false,
	},
}

local DB

function module:OnInitialize()
	module.Database = SUI.SpartanUIDB:RegisterNamespace('UIEnhancements', { profile = DBDefaults })
	DB = module.Database.profile
	module.DB = DB

	-- Register profile change callbacks
	module.Database.RegisterCallback(module, 'OnProfileChanged', function()
		DB = module.Database.profile
		module.DB = DB
	end)
	module.Database.RegisterCallback(module, 'OnProfileCopied', function()
		DB = module.Database.profile
		module.DB = DB
	end)
	module.Database.RegisterCallback(module, 'OnProfileReset', function()
		DB = module.Database.profile
		module.DB = DB
	end)
end

function module:GetDB()
	return DB
end

function module:OnEnable()
	if SUI:IsModuleDisabled(module) then
		return
	end

	-- Initialize sub-modules
	module:InitializeDecorMerchant()
	module:InitializeLootAlertPopup()
	module:InitializeMouseEffects()

	-- Build options
	module:BuildOptions()

	-- Register wizard page
	module:RegisterSetupWizardPage()
end

function module:RegisterSetupWizardPage()
	if not LibAT or not LibAT.SetupWizard then
		return
	end

	LibAT.SetupWizard:AddPage('spartanui', {
		id = 'uienhancements',
		name = L['UI Enhancements'],
		order = 55,
		builder = function(contentFrame)
			local widgets, totalHeight = LibAT.UI.BuildWidgets(contentFrame, {
				mouseRingHeader = {
					type = 'header',
					name = 'Mouse Ring',
					order = 1,
				},
				mouseRingEnabled = {
					type = 'checkbox',
					name = 'Enable mouse ring',
					desc = 'Shows a ring around your mouse cursor',
					order = 2,
					get = function()
						return DB.mouseRing.enabled
					end,
					set = function(val)
						DB.mouseRing.enabled = val
						if module.UpdateMouseRing then
							module:UpdateMouseRing()
						end
					end,
				},
				mouseRingSize = {
					type = 'slider',
					name = 'Ring size',
					min = 16,
					max = 64,
					step = 1,
					order = 3,
					get = function()
						return DB.mouseRing.size
					end,
					set = function(val)
						DB.mouseRing.size = val
						if module.UpdateMouseRing then
							module:UpdateMouseRing()
						end
					end,
				},
				mouseRingAlpha = {
					type = 'slider',
					name = 'Ring opacity',
					min = 0.1,
					max = 1.0,
					step = 0.05,
					order = 4,
					get = function()
						return DB.mouseRing.alpha
					end,
					set = function(val)
						DB.mouseRing.alpha = val
						if module.UpdateMouseRing then
							module:UpdateMouseRing()
						end
					end,
				},
				mouseTrailHeader = {
					type = 'header',
					name = 'Mouse Trail',
					order = 10,
				},
				mouseTrailEnabled = {
					type = 'checkbox',
					name = 'Enable mouse trail',
					desc = 'Shows a particle trail behind your mouse cursor',
					order = 11,
					get = function()
						return DB.mouseTrail.enabled
					end,
					set = function(val)
						DB.mouseTrail.enabled = val
						if module.UpdateMouseTrail then
							module:UpdateMouseTrail()
						end
					end,
				},
				mouseTrailDensity = {
					type = 'dropdown',
					name = 'Trail density',
					order = 12,
					values = {
						['low'] = 'Low',
						['medium'] = 'Medium',
						['high'] = 'High',
					},
					get = function()
						return DB.mouseTrail.density
					end,
					set = function(val)
						DB.mouseTrail.density = val
						if module.UpdateMouseTrail then
							module:UpdateMouseTrail()
						end
					end,
				},
				mouseTrailSize = {
					type = 'slider',
					name = 'Trail particle size',
					min = 4,
					max = 16,
					step = 1,
					order = 13,
					get = function()
						return DB.mouseTrail.size
					end,
					set = function(val)
						DB.mouseTrail.size = val
						if module.UpdateMouseTrail then
							module:UpdateMouseTrail()
						end
					end,
				},
				lootHeader = {
					type = 'header',
					name = 'Loot Alerts',
					order = 20,
				},
				lootAlertPopup = {
					type = 'checkbox',
					name = 'Show loot alert popup',
					desc = 'Display a popup notification when you receive loot',
					order = 21,
					get = function()
						return DB.lootAlertPopup
					end,
					set = function(val)
						DB.lootAlertPopup = val
					end,
				},
				lootAlertChat = {
					type = 'checkbox',
					name = 'Show loot in chat',
					desc = 'Print loot notifications in chat',
					order = 22,
					get = function()
						return DB.lootAlertChat
					end,
					set = function(val)
						DB.lootAlertChat = val
					end,
				},
				lootAlertSound = {
					type = 'checkbox',
					name = 'Play loot sound',
					desc = 'Play a sound when you receive loot',
					order = 23,
					get = function()
						return DB.lootAlertSound
					end,
					set = function(val)
						DB.lootAlertSound = val
					end,
				},
				decorHeader = {
					type = 'header',
					name = 'Decor Merchant',
					order = 30,
				},
				decorMerchantBulkBuy = {
					type = 'checkbox',
					name = 'Enable bulk buy',
					desc = 'Adds a bulk buy option to the decor merchant',
					order = 31,
					get = function()
						return DB.decorMerchantBulkBuy
					end,
					set = function(val)
						DB.decorMerchantBulkBuy = val
					end,
				},
			}, contentFrame:GetWidth())

			contentFrame.totalHeight = totalHeight
		end,
	})

function module:OnDisable()
	-- Restore default behavior for all enhancement elements
	module:RestoreDecorMerchant()
	module:RestoreLootAlertPopup()
	module:RestoreMouseEffects()
end
