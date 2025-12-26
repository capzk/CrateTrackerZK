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
    
    DebugPrint("[通知] 通知模块已初始化");
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
    
    -- 始终发送到聊天框（个人消息）
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. message);
    
    -- 自动检测消息：只在团队中发送，受 teamNotificationEnabled 控制
    -- 注意：如果 teamNotificationEnabled = false，则只发送到聊天框，不发送任何团队消息
    -- 注意：小队中不发送自动消息，只有手动通知才会发送小队消息
    if self.teamNotificationEnabled and IsInRaid() then
        -- 1. 发送普通团队消息（RAID）
        pcall(function()
            SendChatMessage(message, "RAID");
        end);
        -- 2. 发送团队通知（RAID_WARNING）
        pcall(function()
            SendChatMessage(message, "RAID_WARNING");
        end);
    end
    -- 如果不在团队中，或 teamNotificationEnabled = false，只发送到聊天框
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
    local displayName = Data:GetMapDisplayName(mapData);
    if isAirdropActive then
        message = string.format(L["AirdropDetected"], displayName);
    else
        local remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
        if not remaining then
            message = string.format(L["NoTimeRecord"], displayName);
        else
            message = string.format(L["TimeRemaining"], displayName, Data:FormatTime(remaining, true));
        end
    end
    
    -- 手动通知不受 teamNotificationEnabled 控制，始终根据队伍状态发送
    -- 如果在队伍中，发送队伍消息；否则发送到聊天框
    local chatType = self:GetTeamChatType();
    if chatType then
        pcall(function()
            SendChatMessage(message, chatType);
        end);
        return; -- 已发送到队伍，不再发送到聊天框
    end
    
    -- 不在队伍中，发送到聊天框（个人消息）
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. message);
end

