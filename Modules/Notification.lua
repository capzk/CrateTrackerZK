-- CrateTrackerZK - 通知模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Notification = BuildEnv('Notification');

Notification.isInitialized = false;
Notification.teamNotificationEnabled = true;

local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

function Notification:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true;
    
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.teamNotificationEnabled ~= nil then
        self.teamNotificationEnabled = CRATETRACKERZK_UI_DB.teamNotificationEnabled;
    else
        self.teamNotificationEnabled = true;
        if CRATETRACKERZK_UI_DB then
            CRATETRACKERZK_UI_DB.teamNotificationEnabled = true;
        end
    end
    
    DebugPrint("通知模块已初始化");
end

function Notification:IsTeamNotificationEnabled()
    return self.teamNotificationEnabled;
end

function Notification:SetTeamNotificationEnabled(enabled)
    self.teamNotificationEnabled = enabled;
    
    if CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB.teamNotificationEnabled = enabled;
    end
    
    local statusText = enabled and L["Enabled"] or L["Disabled"];
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. string.format(L["TeamNotificationStatus"], statusText));
end

function Notification:NotifyAirdropDetected(mapName, detectionSource)
    if not self.isInitialized then self:Initialize() end
    if not mapName then return end
    
    local message = string.format(L["AirdropDetected"], mapName);
    
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. message);
    
    if self.teamNotificationEnabled and IsInRaid() then
        pcall(function()
            SendChatMessage(message, "RAID_WARNING");
        end);
    end
end

function Notification:GetTeamChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil;
end

function Notification:NotifyMapRefresh(mapData)
    if not self.isInitialized then self:Initialize() end
    if not mapData then return end
    
    local isAirdropActive = false;
    if TimerManager and TimerManager.mapIconDetected then
        isAirdropActive = TimerManager.mapIconDetected[mapData.id] == true;
    end
    
    local message;
    if isAirdropActive then
        message = string.format(L["AirdropDetected"], mapData.mapName);
    else
        local remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
        if not remaining then
            message = string.format(L["NoTimeRecord"], mapData.mapName);
        else
            message = string.format(L["TimeRemaining"], mapData.mapName, Data:FormatTime(remaining, true));
        end
    end
    
    local chatType = self:GetTeamChatType();
    if chatType then
        pcall(function()
            SendChatMessage(message, chatType);
        end);
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. message);
    end
end

