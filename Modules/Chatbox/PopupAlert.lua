---@class SUI
local SUI = SUI
local L = SUI.L
---@class SUI.Module.Chatbox
local module = SUI:GetModule('Chatbox')

local alertFrame

local function CreateAlertFrame()
	-- Recover across /rl
	if not alertFrame and _G['SUI_ChatPopupAlert'] then
		alertFrame = _G['SUI_ChatPopupAlert']
		module.alertFrame = alertFrame
		return
	end
	if alertFrame then
		return
	end

	alertFrame = CreateFrame('Frame', 'SUI_ChatPopupAlert', UIParent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
	alertFrame:SetSize(400, 50)
	alertFrame:SetPoint('TOP', UIParent, 'TOP', 0, -200)
	alertFrame:SetFrameStrata('FULLSCREEN_DIALOG')
	alertFrame:SetClampedToScreen(true)
	alertFrame:Hide()

	if alertFrame.SetBackdrop then
		alertFrame:SetBackdrop({
			bgFile = [[Interface\Buttons\WHITE8X8]],
			edgeFile = [[Interface\Buttons\WHITE8X8]],
			tile = true,
			tileSize = 16,
			edgeSize = 2,
		})
		alertFrame:SetBackdropColor(0.08, 0.06, 0.04, 0.85)
		alertFrame:SetBackdropBorderColor(0.9, 0.5, 0.1, 0.9)
	end

	alertFrame.text = alertFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	alertFrame.text:SetPoint('CENTER', alertFrame, 'CENTER', 0, 0)
	alertFrame.text:SetJustifyH('CENTER')
	alertFrame.text:SetWordWrap(true)

	-- Animation: fade in -> hold -> fade out
	local ag = alertFrame:CreateAnimationGroup()
	alertFrame.animGroup = ag

	local fadeIn = ag:CreateAnimation('Alpha')
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.5)
	fadeIn:SetOrder(1)
	alertFrame.fadeIn = fadeIn

	local hold = ag:CreateAnimation('Alpha')
	hold:SetFromAlpha(1)
	hold:SetToAlpha(1)
	hold:SetDuration(0)
	hold:SetEndDelay(4)
	hold:SetOrder(2)
	alertFrame.hold = hold

	local fadeOut = ag:CreateAnimation('Alpha')
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(2)
	fadeOut:SetOrder(3)
	alertFrame.fadeOut = fadeOut

	ag:SetScript('OnFinished', function()
		alertFrame:Hide()
	end)

	ag:SetScript('OnPlay', function()
		alertFrame:SetAlpha(0)
		alertFrame:Show()
	end)

	module.alertFrame = alertFrame
end

function module:ShowPopupAlert(sender, message, r, g, b)
	local db = module.CurrentSettings.popupAlert
	if not db or not db.enabled then
		return
	end

	if db.suppressInCombat and InCombatLockdown() then
		return
	end

	CreateAlertFrame()
	if not alertFrame then
		return
	end

	-- Stop any in-progress animation
	if alertFrame.animGroup:IsPlaying() then
		alertFrame.animGroup:Stop()
	end

	-- Build display text
	local displayText
	if sender and sender ~= '' then
		displayText = sender .. ': ' .. (message or '')
	else
		displayText = message or ''
	end

	-- Set text and color
	alertFrame.text:SetText(displayText)
	if r and g and b then
		alertFrame.text:SetTextColor(r, g, b, 1)
	else
		alertFrame.text:SetTextColor(1, 0.8, 0.3, 1)
	end

	-- Update font size from DB
	local fontSize = db.fontSize or 16
	alertFrame.text:SetFont(alertFrame.text:GetFont(), fontSize, 'OUTLINE')

	-- Resize frame to fit text
	local textWidth = alertFrame.text:GetStringWidth() + 40
	local maxWidth = UIParent:GetWidth() * 0.6
	alertFrame:SetWidth(math.min(math.max(textWidth, 200), maxWidth))
	alertFrame.text:SetWidth(alertFrame:GetWidth() - 30)

	local textHeight = alertFrame.text:GetStringHeight() + 20
	alertFrame:SetHeight(math.max(textHeight, 40))

	-- Update animation durations from DB
	alertFrame.fadeIn:SetDuration(db.fadeInDuration or 0.5)
	alertFrame.hold:SetEndDelay(db.holdDuration or 4)
	alertFrame.fadeOut:SetDuration(db.fadeOutDuration or 2)

	alertFrame.animGroup:Play()
end

function module:SetupPopupAlert()
	if SUI:IsModuleDisabled(module) then
		return
	end

	local db = module.CurrentSettings.popupAlert
	if not db or not db.enabled then
		return
	end

	CreateAlertFrame()

	-- Register whisper filter for popup alerts
	if db.triggerOnWhisper then
		local function WhisperPopupFilter(self, event, msg, sender, ...)
			if not module.CurrentSettings.popupAlert or not module.CurrentSettings.popupAlert.enabled or not module.CurrentSettings.popupAlert.triggerOnWhisper then
				return
			end
			if SUI.BlizzAPI.issecretvalue(msg) then
				return
			end
			if module.CurrentSettings.popupAlert.suppressInCombat and InCombatLockdown() then
				return
			end

			local cleanMsg = msg:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|H[^|]*|h', ''):gsub('|h', ''):gsub('|T[^|]*|t', '')
			local cleanSender = Ambiguate(sender or '', 'none')
			module:ShowPopupAlert(cleanSender, cleanMsg)
		end

		ChatFrame_AddMessageEventFilter('CHAT_MSG_WHISPER', WhisperPopupFilter)
		ChatFrame_AddMessageEventFilter('CHAT_MSG_BN_WHISPER', WhisperPopupFilter)
	end
end
