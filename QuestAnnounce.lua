local QuestAnnounce = LibStub("AceAddon-3.0"):NewAddon("QuestAnnounce", "AceEvent-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("QuestAnnounce")
local AceTimer = LibStub:GetLibrary("AceTimer-3.0", true)

--[[ The defaults a user without a profile will get. ]]--
local defaults = {
	profile={
		settings = {
			enable = true,
			every = true,
			accepted = true,
			sound = true,
			debug = false
		},
		announceTo = {
			chatFrame = true,
			raidWarningFrame = false,
			uiErrorsFrame = false,
		},
		announceIn = {
			say = false,
			party = true,
			guild = false,
			officer = false,
			whisper = false,
			whisperWho = nil
		}
	}
}

local LastQuestList = {}

local function GetCurrentQuestList()
	local tempTable = {}
	for i = 1, GetNumQuestLogEntries(), 1 do
		local questLogTitleText, _, _, _, _, isComplete = GetQuestLogTitle(i)
		if questLogTitleText then
			tempTable[questLogTitleText] = isComplete
		end
	end
	return tempTable
end

local function SendCompletedNotification()
	local currentQuestLlist = {}
	local timer = AceTimer:ScheduleTimer(function()
		currentQuestLlist = GetCurrentQuestList()
		for key, value in pairs(currentQuestLlist) do
			if LastQuestList then
				if not LastQuestList[key] then
					QuestAnnounce:SendMsg(L["Quest Completed: "]..key)
					break
				end
			end
		end
		LastQuestList = currentQuestLlist
		AceTimer:CancelTimer(timer)
	end, 1)
end

local function delayUpdateQuestLlist()
	if (QuestAnnounce.db.profile.settings.enable) then
		local timer = AceTimer:ScheduleTimer(function()
			LastQuestList = GetCurrentQuestList()
			AceTimer:CancelTimer(timer)
		end, 1)
	end
end


--[[ QuestAnnounce Initialize ]]--
function QuestAnnounce:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("QuestAnnounceDB", defaults, true)
	
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
	self.db.RegisterCallback(self, "OnNewProfile", "OnNewProfile")
	
	self:SetupOptions()
end

function QuestAnnounce:OnEnable()
	--[[ We're looking at the UI_INFO_MESSAGE for quest messages ]]--
	self:RegisterEvent("UI_INFO_MESSAGE")
	self:RegisterEvent("QUEST_ACCEPTED")

	delayUpdateQuestLlist()

	self:SendDebugMsg("Addon Enabled :: "..tostring(QuestAnnounce.db.profile.settings.enable))
end

--[[ QuestAnnounce ZeichenTabelle Chinese]]--
local QUEST_INFO_REGEX = "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$"
local BFQCompletedMatchPattern = "%(Complete%)"
if (GetLocale() == "zhCN") then
	QUEST_INFO_REGEX = "(.*)：%s*([-%d]+)%s*/%s*([-%d]+)%s*$"
	BFQCompletedMatchPattern = "（完成）"
end

--[[ Event handlers ]]--
function QuestAnnounce:UI_INFO_MESSAGE(...)
	local settings = self.db.profile.settings
	
	if (settings.enable) then
		local arg = {...}
		local message = arg[3]
		if message then
			if string.find(message, QUEST_INFO_REGEX) then
				local _, num1, num2 = string.match(message, QUEST_INFO_REGEX)
				if num1 and num1 == num2 then
					QuestAnnounce:SendMsg(L["Progress: "]..message..L["(Completed)"])
					SendCompletedNotification()
				elseif settings.every then
					QuestAnnounce:SendMsg(L["Progress: "]..message)
				end
			elseif string.find(message, BFQCompletedMatchPattern) then
				QuestAnnounce:SendMsg(L["Progress: "]..message)
				SendCompletedNotification()
			end
		end
	end
end

function QuestAnnounce:QUEST_ACCEPTED(...)
	local arg = {...}
	local questIndex = arg[2]
	if self.db.profile.settings.accepted and questIndex then
		local questLogTitleText = GetQuestLogTitle(questIndex)
		QuestAnnounce:SendMsg(L["Accepted Quest: "]..questLogTitleText)
	end
	delayUpdateQuestLlist()
end

function QuestAnnounce:OnProfileChanged(event, db)
 	self.db.profile = db.profile
end

function QuestAnnounce:OnProfileReset(event, db)
	for k, v in pairs(defaults) do
		db.profile[k] = v
	end
	self.db.profile = db.profile
end

function QuestAnnounce:OnNewProfile(event, db)
	for k, v in pairs(defaults) do
		db.profile[k] = v
	end
end

--[[ Sends a debugging message if debug is enabled and we have a message to send ]]--
function QuestAnnounce:SendDebugMsg(msg)
	if(msg ~= nil and self.db.profile.settings.debug) then
		QuestAnnounce:Print("DEBUG :: "..msg)
	end
end

--[[ Sends a chat message to the selected chat channels and frames where applicable,
	if we have a message to send; will also send a debugging message if debug is enabled ]]--
function QuestAnnounce:SendMsg(msg)	
	local announceIn = self.db.profile.announceIn
	local announceTo = self.db.profile.announceTo

	if (msg ~= nil and self.db.profile.settings.enable) then
		if(announceTo.chatFrame) then
			if(announceIn.say) then
				SendChatMessage(msg, "SAY")
				QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg(SAY) :: "..msg)
			end
		
			--[[ GetNumGroupMembers is group-wide; GetNumSubgroupMembers is confined to your group of 5 ]]--
			--[[ Ref: http://www.wowpedia.org/API_GetNumSubgroupMembers or http://www.wowpedia.org/API_GetNumGroupMembers ]]--	
			if(announceIn.party) then
				if(IsInGroup() and GetNumSubgroupMembers(LE_PARTY_CATEGORY_HOME) > 0) then
					SendChatMessage(msg, "PARTY")
				end
				
				QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg(PARTY) :: "..msg)
			end				
		
			if(announceIn.instance) then
				if (IsInInstance() and GetNumSubgroupMembers(LE_PARTY_CATEGORY_INSTANCE) > 0) then
					SendChatMessage(msg, "INSTANCE_CHAT")
				end
				
				QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg(INSTANCE) :: "..msg)
			end				
		
			if(announceIn.guild) then
				if(IsInGuild()) then
					SendChatMessage(msg, "GUILD")
				end
				
				QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg(GUILD) :: "..msg)
			end
			
			if(announceIn.officer) then
				if(IsInGuild()) then
					SendChatMessage(msg, "OFFICER")
				end
				
				QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg(OFFICER) :: "..msg)
			end			
				
			if(announceIn.whisper) then
				local who = announceIn.whisperWho
				if(who ~= nil and who ~= "") then
					SendChatMessage(msg, "WHISPER", nil, who)
					QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg(WHISPER) :: "..who.."-"..msg)
				end
			end
		end
		
		if(announceTo.raidWarningFrame) then
			RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
		end
		
		if(announceTo.uiErrorsFrame) then
			UIErrorsFrame:AddMessage(msg, 1.0, 1.0, 0.0, 7)
		end
		
		if(self.db.profile.settings.sound) then
			PlaySound(PlaySoundKitID and "RAID_WARNING" or 8959)
		end
	end
	
	QuestAnnounce:SendDebugMsg("QuestAnnounce:SendMsg - "..msg)
end