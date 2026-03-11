---@class SUI
local SUI = SUI
local L = SUI.L
---@class SUI.Module.Chatbox
local module = SUI:GetModule('Chatbox')

local EMOJI_PATH = 'Interface\\AddOns\\SpartanUI\\images\\chatbox\\emojis\\'
local ICON_SIZE = 24
local ICONS_PER_ROW = 8
local PADDING = 3
local PICKER_PADDING = 8

local picker
local pickerButtons = {}

-- Ordered emoji list for the picker grid
-- code = what gets inserted into chat (use shorthand where common ASCII exists)
-- tooltip = what shows on hover (shows both shorthand and shortcode)
local emojiList = {
	{ code = ':)', file = 'SlightSmile.png', tooltip = ':)  :slight_smile:' },
	{ code = ':D', file = 'Grin.png', tooltip = ':D  :grin:' },
	{ code = ':smile:', file = 'Smile.png' },
	{ code = 'XD', file = 'Joy.png', tooltip = 'XD  :joy:' },
	{ code = ';)', file = 'Wink.png', tooltip = ';)  :wink:' },
	{ code = ':blush:', file = 'Blush.png' },
	{ code = ':heart_eyes:', file = 'HeartEyes.png' },
	{ code = ':smirk:', file = 'Smirk.png' },
	{ code = '8)', file = 'Sunglasses.png', tooltip = '8)  :sunglasses:' },
	{ code = ':thinking:', file = 'Thinking.png' },
	{ code = ':(', file = 'SlightFrown.png', tooltip = ':(  :slight_frown:' },
	{ code = ':o', file = 'OpenMouth.png', tooltip = ':o  :open_mouth:' },
	{ code = ':P', file = 'StuckOutTongue.png', tooltip = ':P  :stuck_out_tongue:' },
	{ code = ';P', file = 'StuckOutTongueClosedEyes.png', tooltip = ';P  :stuck_out_tongue_closed_eyes:' },
	{ code = ":'(", file = 'Cry.png', tooltip = ":'(  :cry:" },
	{ code = ':sob:', file = 'Sob.png' },
	{ code = ':@', file = 'Angry.png', tooltip = ':@  :angry:' },
	{ code = 'D:<', file = 'Rage.png', tooltip = 'D:<  :rage:' },
	{ code = ':scream:', file = 'Scream.png' },
	{ code = ':facepalm:', file = 'Facepalm.png' },
	{ code = ':kappa:', file = 'Kappa.png' },
	{ code = ':poop:', file = 'Poop.png' },
	{ code = ':skull:', file = 'Skull.png' },
	{ code = ':zzz:', file = 'ZZZ.png' },
	{ code = '<3', file = 'Heart.png', tooltip = '<3  :heart:' },
	{ code = '</3', file = 'BrokenHeart.png', tooltip = '</3  :broken_heart:' },
	{ code = ':fire:', file = 'Fire.png' },
	{ code = ':party:', file = 'PartyPopper.png' },
	{ code = ':+1:', file = 'ThumbsUp.png', tooltip = ':+1:  :thumbs_up:' },
	{ code = ':thumbs_down:', file = 'ThumbsDown.png' },
	{ code = ':ok_hand:', file = 'OkHand.png' },
	{ code = ':clap:', file = 'Clap.png' },
	{ code = ':wave:', file = 'Wave.png' },
	{ code = ':pray:', file = 'Pray.png' },
	{ code = ':call_me:', file = 'CallMe.png' },
	{ code = ':middle_finger:', file = 'MiddleFinger.png' },
	{ code = ':meaw:', file = 'Meaw.png' },
	{ code = ':scream_cat:', file = 'ScreamCat.png' },
	{ code = ':sadkitty:', file = 'SadKitty.png' },
	{ code = ':murloc:', file = 'Smile.png' },
}

local function GetActiveEditBox()
	for i = 1, 10 do
		local eb = _G['ChatFrame' .. i .. 'EditBox']
		if eb and eb:IsVisible() and eb:HasFocus() then
			return eb
		end
	end
	-- Fallback: find any visible edit box
	for i = 1, 10 do
		local eb = _G['ChatFrame' .. i .. 'EditBox']
		if eb and eb:IsVisible() then
			return eb
		end
	end
	return nil
end

local function InsertEmoji(code)
	local editBox = module.emojiPickerEditBox or GetActiveEditBox()
	if not editBox then
		editBox = ChatFrame1EditBox
	end
	ChatEdit_ActivateChat(editBox)
	local text = editBox:GetText()
	local insertText = code
	if text ~= '' and not text:match('%s$') then
		insertText = ' ' .. insertText
	end
	editBox:Insert(insertText)
	editBox:SetFocus()
end

local function CreatePicker()
	if picker then
		return
	end

	local numRows = math.ceil(#emojiList / ICONS_PER_ROW)
	local width = (ICONS_PER_ROW * (ICON_SIZE + PADDING)) + PADDING + (PICKER_PADDING * 2)
	local height = (numRows * (ICON_SIZE + PADDING)) + PADDING + (PICKER_PADDING * 2) + 20

	picker = CreateFrame('Frame', 'SUI_EmojiPicker', UIParent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
	picker:SetSize(width, height)
	picker:SetFrameStrata('DIALOG')
	picker:SetFrameLevel(100)
	picker:SetClampedToScreen(true)
	picker:Hide()

	if picker.SetBackdrop then
		picker:SetBackdrop({
			bgFile = [[Interface\Buttons\WHITE8X8]],
			edgeFile = [[Interface\Buttons\WHITE8X8]],
			tile = true,
			tileSize = 16,
			edgeSize = 1,
		})
		picker:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
		picker:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	end

	-- Title
	local title = picker:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	title:SetPoint('TOP', picker, 'TOP', 0, -5)
	title:SetText('Emoji')
	title:SetTextColor(0.7, 0.7, 0.7, 1)

	-- Grid of emoji buttons
	for idx, emoji in ipairs(emojiList) do
		local row = math.floor((idx - 1) / ICONS_PER_ROW)
		local col = (idx - 1) % ICONS_PER_ROW

		local btn = CreateFrame('Frame', nil, picker)
		btn:SetSize(ICON_SIZE, ICON_SIZE)
		btn:SetPoint('TOPLEFT', picker, 'TOPLEFT', PICKER_PADDING + (col * (ICON_SIZE + PADDING)), -(18 + PICKER_PADDING + (row * (ICON_SIZE + PADDING))))
		btn:EnableMouse(true)

		local tex = btn:CreateTexture(nil, 'ARTWORK')
		tex:SetAllPoints()
		tex:SetTexture(EMOJI_PATH .. emoji.file)
		btn.tex = tex

		-- Highlight on hover
		local highlight = btn:CreateTexture(nil, 'HIGHLIGHT')
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.2)

		btn:SetScript('OnMouseDown', function()
			InsertEmoji(emoji.code)
		end)

		btn:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_TOP')
			GameTooltip:AddLine(emoji.tooltip or emoji.code, 1, 1, 1)
			GameTooltip:Show()
		end)
		btn:SetScript('OnLeave', GameTooltip_Hide)

		pickerButtons[idx] = btn
	end

	-- Close when clicking outside
	picker:SetScript('OnShow', function()
		picker:RegisterEvent('GLOBAL_MOUSE_DOWN')
	end)
	picker:SetScript('OnHide', function()
		picker:UnregisterEvent('GLOBAL_MOUSE_DOWN')
	end)
	picker:SetScript('OnEvent', function(self, event)
		if event == 'GLOBAL_MOUSE_DOWN' then
			if not self:IsMouseOver() and not (module.emojiBtn and module.emojiBtn:IsMouseOver()) then
				self:Hide()
			end
		end
	end)

	module.emojiPicker = picker
end

function module:ToggleEmojiPicker(anchorFrame)
	if not picker then
		CreatePicker()
	end

	if picker:IsShown() then
		picker:Hide()
		return
	end

	-- Anchor above the edit box button
	picker:ClearAllPoints()
	if anchorFrame then
		picker:SetPoint('BOTTOMRIGHT', anchorFrame, 'TOPRIGHT', 0, 2)
	else
		picker:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 60)
	end
	picker:Show()
end

----------------------------------------------------------------------------------------------------
-- Emoji button on the edit box
----------------------------------------------------------------------------------------------------

local emojiButtons = {}

local function CreateEmojiButton(editBox, index)
	local btnName = 'SUI_EmojiPickerBtn' .. index
	local overlayName = btnName .. 'Overlay'
	if _G[btnName] and _G[overlayName] then
		local existingIcon = _G[btnName]
		local existingOverlay = _G[overlayName]
		existingIcon:SetParent(editBox)
		existingOverlay.editBox = editBox
		return existingIcon, existingOverlay
	end

	-- Visual icon (no mouse interaction, parented to edit box so it shows/hides with it)
	local icon = CreateFrame('Frame', btnName, editBox)
	icon:SetSize(18, 18)
	icon:EnableMouse(false)

	local tex = icon:CreateTexture(nil, 'ARTWORK')
	tex:SetAllPoints()
	tex:SetTexture(EMOJI_PATH .. 'Smile.png')
	tex:SetDesaturated(true)
	tex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
	icon.icon = tex

	-- Clickable overlay (parented to UIParent so clicks don't affect edit box focus)
	local btn = CreateFrame('Button', btnName .. 'Overlay', UIParent)
	btn:SetSize(18, 18)
	btn:SetFrameStrata('TOOLTIP')
	btn.editBox = editBox
	btn.icon = tex
	btn.iconFrame = icon
	btn:RegisterForClicks('RightButtonUp')

	btn:SetScript('OnClick', function(self)
		module.emojiPickerEditBox = self.editBox
		module:ToggleEmojiPicker(self.iconFrame)
	end)

	btn:SetScript('OnEnter', function(self)
		self.icon:SetDesaturated(false)
		self.icon:SetVertexColor(1, 1, 1, 1)
		GameTooltip:SetOwner(self, 'ANCHOR_TOP')
		GameTooltip:AddLine('Emoji', 1, 1, 1)
		GameTooltip:AddLine('Right-click to open', 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)

	btn:SetScript('OnLeave', function(self)
		self.icon:SetDesaturated(true)
		self.icon:SetVertexColor(0.7, 0.7, 0.7, 0.8)
		GameTooltip_Hide()
	end)

	btn:SetPoint('CENTER', icon, 'CENTER')
	btn:Hide()

	return icon, btn
end

function module:SetupEmojiPicker()
	if SUI:IsModuleDisabled(module) then
		return
	end
	if not module.CurrentSettings.emoji or not module.CurrentSettings.emoji.enabled then
		return
	end

	-- Skip edit box emoji buttons when header buttons provide one
	if module.CurrentSettings.headerButtons and module.CurrentSettings.headerButtons.enabled then
		return
	end

	for i = 1, 10 do
		local editBox = _G['ChatFrame' .. i .. 'EditBox']
		if editBox then
			local icon, overlay = CreateEmojiButton(editBox, i)
			local counter = _G['SUI_ChatCharCounter' .. i]
			if counter then
				icon:SetPoint('RIGHT', counter, 'LEFT', -4, 0)
			else
				icon:SetPoint('RIGHT', editBox, 'RIGHT', -5, 0)
			end

			emojiButtons[i] = overlay
			module.emojiBtn = overlay

			editBox:HookScript('OnShow', function()
				if module.CurrentSettings.emoji and module.CurrentSettings.emoji.enabled then
					overlay:Show()
				else
					overlay:Hide()
				end
			end)

			editBox:HookScript('OnHide', function()
				overlay:Hide()
				module.emojiPickerEditBox = nil
				if picker and picker:IsShown() then
					picker:Hide()
				end
			end)
		end
	end
end
