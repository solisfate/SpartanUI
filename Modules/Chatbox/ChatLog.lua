---@class SUI
local SUI = SUI
local L = SUI.L
---@class SUI.Module.Chatbox
local module = SUI:GetModule('Chatbox')

local chatTypeMap = {
	CHAT_MSG_SAY = 'SAY',
	CHAT_MSG_YELL = 'YELL',
	CHAT_MSG_PARTY = 'PARTY',
	CHAT_MSG_RAID = 'RAID',
	CHAT_MSG_GUILD = 'GUILD',
	CHAT_MSG_OFFICER = 'OFFICER',
	CHAT_MSG_WHISPER = 'WHISPER',
	CHAT_MSG_WHISPER_INFORM = 'WHISPER_INFORM',
	CHAT_MSG_INSTANCE_CHAT = 'INSTANCE_CHAT',
}

function module:EnableChatLog()
	for chatType in pairs(self.CurrentSettings.chatLog.typesToLog) do
		if self.CurrentSettings.chatLog.typesToLog[chatType] then
			self:RegisterEvent(chatType, 'LogChatMessage')
		else
			self:UnregisterEvent(chatType)
		end
	end
	self:RestoreChatHistory()
end

function module:DisableChatLog()
	for chatType in pairs(self.CurrentSettings.chatLog.typesToLog) do
		self:UnregisterEvent(chatType)
	end
end

function module:LogChatMessage(event, message, sender, languageName, channelName, _, _, _, channelIndex, channelBaseName, _, _, guid, _, _, _, _, _)
	if not self.CurrentSettings.chatLog.enabled or SUI.BlizzAPI.issecretvalue(message) then
		return
	end

	if self.CurrentSettings.chatLog.blacklist.enabled then
		for _, blacklistedString in ipairs(self.CurrentSettings.chatLog.blacklist.strings) do
			if message:lower():find(blacklistedString:lower(), 1, true) then
				return
			end
		end
	end

	local entry = {
		timestamp = time(),
		event = event,
		sender = sender,
		message = message,
		guid = guid,
		channelName = channelName,
		channelIndex = channelIndex,
		channelBaseName = channelBaseName,
		languageName = languageName,
	}

	table.insert(module.ChatLog, entry)

	while #module.ChatLog > self.CurrentSettings.chatLog.maxEntries do
		table.remove(module.ChatLog, 1)
	end
end

function module:RestoreChatHistory()
	local chatFrame = DEFAULT_CHAT_FRAME

	for _, entry in ipairs(module.ChatLog) do
		-- Resolve class color from GUID
		local senderClass
		if entry.guid and type(entry.guid) == 'string' and entry.guid:match('^Player%-') then
			local _, className = GetPlayerInfoByGUID(entry.guid)
			if className then
				senderClass = className
			end
		end

		-- Feed entry through the shared prefix system so channel style,
		-- per-channel toggles, level prefix, etc. all apply consistently.
		module.prefixSeq = (module.prefixSeq or 0) + 1
		local seq = module.prefixSeq

		local data = {
			timestamp = entry.timestamp,
			event = entry.event,
			channelIndex = entry.channelIndex,
			channelBaseName = entry.channelBaseName,
			senderName = entry.sender,
			senderClass = senderClass,
		}
		module.lineData[seq] = data

		local metaPrefix, playerLink, charPlaceholder = module.buildPrefix(data)
		local wrapped = module.wrapPrefix(metaPrefix, seq, playerLink, charPlaceholder)

		local chatType = chatTypeMap[entry.event] or 'SYSTEM'
		if entry.event == 'CHAT_MSG_CHANNEL' and entry.channelIndex then
			chatType = 'CHANNEL' .. entry.channelIndex
		end
		local info = ChatTypeInfo[chatType]

		local text = wrapped .. entry.message
		chatFrame:AddMessage(text, info.r, info.g, info.b)
	end
end

function module:ClearChatLog()
	wipe(module.ChatLog)
	SUI:Print(L['Chat log cleared'])
end

function module:CleanupOldChatLog()
	if not module.ChatLog then
		return
	end

	local currentTime = time()
	local expirationTime = currentTime - (self.CurrentSettings.chatLog.expireDays * 24 * 60 * 60)
	local maxEntries = self.CurrentSettings.chatLog.maxEntries

	for i = #module.ChatLog, 1, -1 do
		if module.ChatLog[i].timestamp < expirationTime then
			table.remove(module.ChatLog, i)
		end
	end

	while #module.ChatLog > maxEntries do
		table.remove(module.ChatLog, 1)
	end
end

function module:AddBlacklistString(string)
	if not tContains(self.DB.chatLog.blacklist.strings, string) then
		table.insert(self.DB.chatLog.blacklist.strings, string)
		SUI.DBM:RefreshSettings(self)
	end
end

function module:RemoveBlacklistString(string)
	tDeleteItem(self.DB.chatLog.blacklist.strings, string)
	SUI.DBM:RefreshSettings(self)
end

function module:ToggleBlacklist(enable)
	self.DB.chatLog.blacklist.enabled = enable
	SUI.DBM:RefreshSettings(self)
end

function module:ClearAllChatLogs()
	wipe(module.ChatLog)
	SUI:Print(L['All chat logs cleared'])
end
