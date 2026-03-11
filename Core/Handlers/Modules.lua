---@class SUI
local SUI = SUI
local L = SUI.L
local module = SUI:NewModule('Handler.Modules') ---@type SUI.Module

---@param ModuleTable AceAddon
---@return string
function SUI:GetModuleName(ModuleTable)
	local name

	-- Remove SpartanUI_
	name = string.gsub(ModuleTable.name, 'SpartanUI_', '')

	return name
end

---@param moduleName AceAddon|string
---@return boolean
function SUI:IsModuleEnabled(moduleName)
	-- If we are passed a table, we need to get the name from it.
	if type(moduleName) == 'table' then
		if moduleName.Override or moduleName.override then
			return false
		end

		moduleName = SUI:GetModuleName(moduleName)
	else
		-- Fetch the Module
		local moduleObj = SUI:GetModule(moduleName, true)
		if not moduleObj then
			return false
		end
		-- See if the modules has been overridden
		if moduleObj and (moduleObj.Override or moduleObj.override) then
			return false
		end
	end

	if SUI.DB.DisabledModules and SUI.DB.DisabledModules[moduleName] then
		return false
	end

	return true
end

---@param moduleName AceAddon|string
---@return boolean
function SUI:IsModuleDisabled(moduleName)
	return not SUI:IsModuleEnabled(moduleName)
end

-- These override the default Ace3 calls so we can track the status
---@param input AceAddon|string
function SUI:DisableModule(input)
	local moduleToDisable
	if type(input) == 'table' then
		moduleToDisable = input
	else
		moduleToDisable = SUI:GetModule(input, true)
	end

	if moduleToDisable then
		SUI.DB.DisabledModules[SUI:GetModuleName(moduleToDisable)] = true
		return moduleToDisable:Disable()
	end
end

---@param input AceAddon|string
function SUI:EnableModule(input)
	local moduleToDisable
	if type(input) == 'table' then
		moduleToDisable = input
	else
		moduleToDisable = SUI:GetModule(input)
	end

	SUI.DB.DisabledModules[SUI:GetModuleName(moduleToDisable)] = nil
	return moduleToDisable:Enable()
end

local function RegisterSetupWizardPage()
	if not LibAT or not LibAT.SetupWizard then
		return
	end

	if LibAT.SetupWizard:GetPage('spartanui', 'modules') then
		return
	end

	LibAT.SetupWizard:AddPage('spartanui', {
		id = 'modules',
		name = L['Enabled Modules'],
		order = 40,
		builder = function(contentFrame)
			local UI = LibAT.UI

			local desc = UI.CreateLabel(contentFrame, 'Enable or disable SpartanUI modules. Core modules are always enabled.', 'GameFontNormal')
			desc:SetPoint('TOP', contentFrame, 'TOP', 0, -5)
			desc:SetPoint('LEFT', contentFrame, 'LEFT', 20, 0)
			desc:SetPoint('RIGHT', contentFrame, 'RIGHT', -20, 0)
			desc:SetJustifyH('CENTER')
			desc:SetWordWrap(true)

			local cardWidth = contentFrame:GetWidth() - 40
			local cardHeight = 50
			local spacing = 6
			local yOffset = -30

			-- Collect visible modules and sort alphabetically by display name
			local visibleModules = {}
			for _, submodule in pairs(SUI.orderedModules) do
				local name = submodule.name
				if not string.match(name, 'Handler.') and not string.match(name, 'Style.') and not submodule.HideModule then
					local realName = SUI:GetModuleName(submodule)
					local displayName = submodule.DisplayName or realName
					visibleModules[#visibleModules + 1] = { module = submodule, realName = realName, displayName = displayName }
				end
			end
			table.sort(visibleModules, function(a, b)
				return a.displayName < b.displayName
			end)

			for _, entry in ipairs(visibleModules) do
				local submodule = entry.module
				local realName = entry.realName
				local displayName = entry.displayName
				local isCore = submodule.Core or false
				local isOverridden = submodule.override or false
				local isEnabled = SUI:IsModuleEnabled(realName)

				local card = CreateFrame('Button', nil, contentFrame, BackdropTemplateMixin and 'BackdropTemplate')
				card:SetSize(cardWidth, cardHeight)
				card:SetPoint('TOP', contentFrame, 'TOP', 0, yOffset)
				card:SetPoint('LEFT', contentFrame, 'LEFT', 20, 0)
				card:SetPoint('RIGHT', contentFrame, 'RIGHT', -20, 0)
				card:SetBackdrop({
					bgFile = 'Interface\\Buttons\\WHITE8x8',
					edgeFile = 'Interface\\Buttons\\WHITE8x8',
					edgeSize = 1,
				})

				local nameLabel = UI.CreateLabel(card, displayName, 'GameFontNormal')
				nameLabel:SetPoint('TOPLEFT', card, 'TOPLEFT', 10, -8)

				local descLabel = UI.CreateLabel(card, submodule.description or '', 'GameFontHighlightSmall')
				descLabel:SetPoint('TOPLEFT', nameLabel, 'BOTTOMLEFT', 0, -2)
				descLabel:SetPoint('RIGHT', card, 'RIGHT', -50, 0)
				descLabel:SetWordWrap(true)

				local function updateCardAppearance(enabled)
					if enabled then
						card:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
						card:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
						card:SetAlpha(1)
					else
						card:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
						card:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)
						card:SetAlpha(0.6)
					end
				end

				if isOverridden then
					card:SetBackdropColor(0.08, 0.08, 0.1, 0.6)
					card:SetBackdropBorderColor(0.3, 0.3, 0.5, 0.8)
					card:SetAlpha(0.5)
					local overrideLabel = UI.CreateLabel(card, 'Replaced by installed addon', 'GameFontNormalSmall')
					overrideLabel:SetPoint('RIGHT', card, 'RIGHT', -10, 0)
					overrideLabel:SetTextColor(0.5, 0.5, 0.8)
					card:EnableMouse(false)
				else
					local checkbox = CreateFrame('CheckButton', nil, card, 'UICheckButtonTemplate')
					checkbox:SetSize(24, 24)
					checkbox:SetPoint('RIGHT', card, 'RIGHT', -8, 0)
					checkbox:SetChecked(isEnabled)
					checkbox:EnableMouse(false) -- Card handles clicks
					updateCardAppearance(isEnabled)

					card:SetScript('OnClick', function()
						local nowEnabled = not SUI:IsModuleEnabled(realName)
						if nowEnabled then
							SUI:EnableModule(submodule)
						else
							SUI:DisableModule(submodule)
						end
						checkbox:SetChecked(nowEnabled)
						updateCardAppearance(nowEnabled)
					end)
					if isCore then
						local coreLabel = UI.CreateLabel(card, 'Core', 'GameFontNormalSmall')
						coreLabel:SetPoint('RIGHT', checkbox, 'LEFT', -10, 0)
						coreLabel:SetTextColor(0.5, 0.8, 0.5)
					end

					local hl = card:CreateTexture(nil, 'HIGHLIGHT')
					hl:SetAllPoints()
					hl:SetColorTexture(1, 1, 1, 0.05)
					card:SetHighlightTexture(hl)
				end

				yOffset = yOffset - (cardHeight + spacing)
			end

			contentFrame:SetHeight(math.abs(yOffset) + 20)
		end,
	})
end

function module:OnEnable()
	RegisterSetupWizardPage()
end
