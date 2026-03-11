---@class SUI
local SUI = SUI
local L = SUI.L
---@class SUI.Module.Chatbox
local module = SUI:GetModule('Chatbox')

local popup

function module:CreateCopyPopup()
	-- Recover existing frame across /rl
	if not popup and _G['SUI_ChatCopyPopup'] then
		popup = _G['SUI_ChatCopyPopup']
		module.popup = popup
		return
	end
	if popup then
		return
	end

	popup = CreateFrame('Frame', 'SUI_ChatCopyPopup', UIParent, 'ButtonFrameTemplate')
	ButtonFrameTemplate_HidePortrait(popup)
	ButtonFrameTemplate_HideButtonBar(popup)
	popup.Inset:Hide()
	popup:SetSize(600, 350)
	popup:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	popup:SetFrameStrata('DIALOG')
	popup:Hide()

	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag('LeftButton')
	popup:SetScript('OnDragStart', popup.StartMoving)
	popup:SetScript('OnDragStop', popup.StopMovingOrSizing)

	popup:SetTitle('|cffffffffSpartan|cffe21f1fUI|r Chat Copy')

	popup.textBox = CreateFrame('Frame', nil, popup, 'ScrollingEditBoxTemplate')
	popup.textBox:SetPoint('TOPLEFT', popup, 'TOPLEFT', 24, -30)
	popup.textBox:SetPoint('BOTTOMRIGHT', popup, 'BOTTOMRIGHT', -24, 12)
	popup.textBox:GetEditBox():SetFontObject('GameFontHighlight')
	popup.textBox:GetEditBox():SetTextColor(1, 1, 1)
	popup.textBox:GetEditBox():SetAutoFocus(false)

	-- Keep backward compat reference
	popup.editBox = popup.textBox:GetEditBox()

	popup.font = popup:CreateFontString(nil, nil, 'GameFontNormal')
	popup.font:Hide()

	module.popup = popup
end

function module:SetPopupText(text)
	if not popup then
		return
	end
	popup.textBox:SetText(text)
	popup:Show()
	C_Timer.After(0, function()
		local eb = popup.textBox:GetEditBox()
		eb:SetFocus()
		eb:HighlightText(0, #eb:GetText())
		C_Timer.After(0, function()
			popup.textBox:GetScrollBox():ScrollToEnd()
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- Collect chat text for copy
----------------------------------------------------------------------------------------------------

local function CollectChatText(chatFrame)
	local text = ''
	for i = 1, chatFrame:GetNumMessages() do
		local line = chatFrame:GetMessageInfo(i)
		if SUI.BlizzAPI.issecretvalue(line) then
			text = text .. '<Secret Message>\n'
		else
			popup.font:SetFormattedText('%s\n', line)
			local cleanLine = popup.font:GetText() or ''
			text = text .. cleanLine
		end
	end
	text = text:gsub('|T[^\\]+\\[^\\]+\\[Uu][Ii]%-[Rr][Aa][Ii][Dd][Tt][Aa][Rr][Gg][Ee][Tt][Ii][Nn][Gg][Ii][Cc][Oo][Nn]_(%d)[^|]+|t', '{rt%1}')
	text = text:gsub('|T13700([1-8])[^|]+|t', '{rt%1}')
	text = text:gsub('|T[^|]+|t', '')
	text = text:gsub('|K[^|]+|k', '<Protected Text>')
	text = text:gsub('|H[^|]+|h%[([^%]]*)%]|h', '%1')
	text = text:gsub('|H[^|]+|h', '')
	text = text:gsub('|h', '')
	text = text:gsub('|c%x%x%x%x%x%x%x%x', '')
	text = text:gsub('|r', '')
	return text
end

-- Expose for the side panel copy button
module.CollectChatText = CollectChatText

local function TabClick(frame)
	local ChatFrameName = format('%s%d', 'ChatFrame', frame:GetID())
	local ChatFrame = _G[ChatFrameName]
	local ChatFrameEdit = _G[ChatFrameName .. 'EditBox']

	if IsShiftKeyDown() and IsControlKeyDown() then
		ChatFrame:Clear()
	elseif IsAltKeyDown() then
		module:SetPopupText(CollectChatText(ChatFrame))
	elseif IsShiftKeyDown() then
		if ChatFrame:IsVisible() then
			ChatFrame:Hide()
		else
			ChatFrame:Show()
		end
	end

	if ChatFrameEdit:IsVisible() then
		ChatFrameEdit:Hide()
	end
end

local function TabHintEnter(frame)
	if not module.CurrentSettings.ChatCopyTip then
		return
	end

	ShowUIPanel(GameTooltip)
	GameTooltip:SetOwner(frame, 'ANCHOR_TOP')
	GameTooltip:AddLine('Alt+Click to copy', 0.8, 0, 0)
	GameTooltip:AddLine('Shift+Click to toggle', 0, 0.1, 1)
	GameTooltip:AddLine('Shift+Ctrl+Click to clear', 0.8, 0.4, 0)
	GameTooltip:Show()
end

local function TabHintLeave(frame)
	if not module.CurrentSettings.ChatCopyTip then
		return
	end
	HideUIPanel(GameTooltip)
end

----------------------------------------------------------------------------------------------------
-- Right-Click timestamp to copy line
----------------------------------------------------------------------------------------------------

local function OnChatHyperlinkClick(chatFrame, link, text, button)
	if button ~= 'RightButton' then
		return
	end
	local linkType, lineStr = strsplit(':', link, 2)
	if linkType ~= 'suicopy' then
		return
	end
	-- Find the message containing this specific suicopy link
	local needle = '|Hsuicopy:' .. lineStr .. '|h'
	local numMessages = chatFrame:GetNumMessages()
	local line
	for i = 1, numMessages do
		local msg = chatFrame:GetMessageInfo(i)
		if msg and not SUI.BlizzAPI.issecretvalue(msg) and msg:find(needle, 1, true) then
			line = msg
			break
		end
	end
	if not line then
		return
	end
	-- Strip SUI hyperlink wrappers before showing
	line = line:gsub('|Hsuicopy:%d+|h', '')
	line = line:gsub('|h', '')
	module:SetPopupText(line)
end

----------------------------------------------------------------------------------------------------
-- Public Functions
----------------------------------------------------------------------------------------------------

function module:ClearChat()
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G['ChatFrame' .. i]
		if chatFrame then
			chatFrame:Clear()
		end
	end

	if module.ChatLog then
		wipe(module.ChatLog)
	end

	if SUI.CharDB.ChatEditHistory then
		wipe(SUI.CharDB.ChatEditHistory)
	end

	SUI:Print(L['Chat cleared'])
end

function module:SetEditBoxMessage(msg)
	if not ChatFrame1EditBox:IsShown() then
		ChatEdit_ActivateChat(ChatFrame1EditBox)
	end

	local editBoxText = ChatFrame1EditBox:GetText()
	if editBoxText and editBoxText ~= '' then
		ChatFrame1EditBox:SetText('')
	end
	ChatFrame1EditBox:Insert(msg)
	ChatFrame1EditBox:HighlightText()
end

----------------------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------------------

function module:SetupCopyChat()
	if SUI:IsModuleDisabled(module) then
		return
	end

	for i = 1, 10 do
		local ChatFrameName = ('%s%d'):format('ChatFrame', i)
		local ChatFrame = _G[ChatFrameName]
		local ChatFrameTab = _G[ChatFrameName .. 'Tab']

		ChatFrameTab:HookScript('OnClick', TabClick)
		ChatFrameTab:HookScript('OnEnter', TabHintEnter)
		ChatFrameTab:HookScript('OnLeave', TabHintLeave)

		ChatFrame:HookScript('OnHyperlinkClick', OnChatHyperlinkClick)
	end
end
