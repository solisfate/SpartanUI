---@class SUI
local SUI = SUI
local L = SUI.L

if not SUI.IsRetail then
	return
end

---@class SUI.Module.PreyTracker
local module = SUI:GetModule('PreyTracker') ---@type SUI.Module.PreyTracker

function module:BuildOptions()
	---@type AceConfig.OptionsTable
	local options = {
		type = 'group',
		name = L['Prey Tracker'],
		disabled = function()
			return SUI:IsModuleDisabled(module)
		end,
		args = {
			description = {
				type = 'description',
				name = L['Shows a progress bar when a Prey Hunt is active.'],
				order = 0,
				fontSize = 'medium',
			},
			barHeader = {
				type = 'header',
				name = L['Progress Bar'],
				order = 5,
			},
			scale = {
				type = 'range',
				name = L['Scale'],
				order = 10,
				min = 0.5,
				max = 2.0,
				step = 0.05,
				get = function()
					return SUI.DBM:Get(module, 'bar.scale')
				end,
				set = function(_, val)
					SUI.DBM:Set(module, 'bar.scale', val, function()
						if module.progressBar then
							module.progressBar:SetScale(val)
						end
					end)
				end,
			},
			barColor = {
				type = 'color',
				name = L['Bar Color'],
				order = 20,
				hasAlpha = false,
				get = function()
					local c = module.CurrentSettings.bar.barColor
					return c.r, c.g, c.b
				end,
				set = function(_, r, g, b)
					if not module.DB.bar then
						module.DB.bar = {}
					end
					module.DB.bar.barColor = { r = r, g = g, b = b }
					SUI.DBM:RefreshSettings(module)
					module:UpdateProgressBar()
				end,
			},
			audioHeader = {
				type = 'header',
				name = L['Audio Alerts'],
				order = 30,
			},
			audioEnabled = {
				type = 'toggle',
				name = L['Enable'],
				desc = L['Play sounds for ambush and prey found events'],
				order = 31,
				get = function()
					return SUI.DBM:Get(module, 'audio.enabled')
				end,
				set = function(_, val)
					SUI.DBM:Set(module, 'audio.enabled', val)
				end,
			},
			widgetHeader = {
				type = 'header',
				name = L['Blizzard Widget'],
				order = 50,
			},
			hideBlizzardWidget = {
				type = 'toggle',
				name = L['Hide default prey widget'],
				desc = L['Hides the default Blizzard prey hunt progress display when our bar is active'],
				order = 51,
				get = function()
					return SUI.DBM:Get(module, 'hideBlizzardWidget')
				end,
				set = function(_, val)
					SUI.DBM:Set(module, 'hideBlizzardWidget', val, function()
						if module.state.activeQuestID then
							module:SetWidgetSuppression(val)
						end
					end)
				end,
			},
		},
	}

	SUI.Options:AddOptions(options, 'PreyTracker')
end
