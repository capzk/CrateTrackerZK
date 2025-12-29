-- Notification.lua
-- 处理空投检测通知和地图刷新通知

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Notification = BuildEnv('Notification');

Notification.isInitialized = false;
Notification.teamNotificationEnabled = true;

local function DebugPrint(msg, ...)
    Logger:Debug("Notification", "调试", msg, ...);
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
    Logger:Info("Notification", "状态", string.format(L["TeamNotificationStatus"], statusText));
end

function Notification:NotifyAirdropDetected(mapName, detectionSource)
    if not self.isInitialized then self:Initialize() end
    if not mapName then 
        Logger:Debug("Notification", "通知", "通知失败：地图名称为空");
        return 
    end
    
    local message = string.format(L["AirdropDetected"], mapName);
    
    Logger:Debug("Notification", "通知", string.format("发送空投检测通知：地图=%s，来源=%s", mapName, detectionSource or "未知"));
    
    local chatType = self:GetTeamChatType();
    
    Logger:Debug("Notification", "调试", string.format("团队通知检查：chatType=%s, teamNotificationEnabled=%s, IsInRaid=%s, IsInGroup=%s", 
        tostring(chatType), tostring(self.teamNotificationEnabled), tostring(IsInRaid()), tostring(IsInGroup())));
    
    if chatType and self.teamNotificationEnabled then
        if IsInRaid() then
            local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player");
            local raidChatType = hasPermission and "RAID_WARNING" or "RAID";
            Logger:Debug("Notification", "通知", string.format("发送团队通知：类型=%s，权限=%s", raidChatType, hasPermission and "有" or "无"));
            pcall(function()
                SendChatMessage(message, raidChatType);
            end);
        else
            Logger:Debug("Notification", "通知", string.format("发送小队通知：类型=%s", chatType));
            pcall(function()
                SendChatMessage(message, chatType);
            end);
        end
    else
        Logger:Info("Notification", "通知", message);
        if chatType and not self.teamNotificationEnabled then
            Logger:Debug("Notification", "通知", string.format("团队通知已禁用，仅发送系统消息：地图=%s", mapName));
        end
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
    if not mapData then 
        Logger:Debug("Notification", "通知", "通知地图刷新失败：地图数据为空");
        return 
    end
    
    Logger:Debug("Notification", "通知", string.format("用户请求通知地图刷新：地图=%s", 
        Data:GetMapDisplayName(mapData)));
    
    local isAirdropActive = false;
    if DetectionState then
        local state = DetectionState:GetState(mapData.id);
        isAirdropActive = (state and state.status == DetectionState.STATES.PROCESSED);
    end
    
    local message;
    local systemMessage;
    local displayName = Data:GetMapDisplayName(mapData);
    local remaining = nil;
    
    if isAirdropActive then
        message = string.format(L["AirdropDetectedManual"], displayName);
        systemMessage = message;
    else
        remaining = Data:CalculateRemainingTime(mapData.nextRefresh);
        if not remaining then
            message = string.format(L["NoTimeRecord"], displayName);
            systemMessage = message;
        else
            message = string.format(L["TimeRemaining"], displayName, Data:FormatTime(remaining, true));
            systemMessage = message;
        end
    end
    
    local chatType = self:GetTeamChatType();
    
    if chatType then
        Logger:Debug("Notification", "通知", string.format("发送小队/团队通知（手动）：类型=%s", chatType));
        local success, err = pcall(function()
            SendChatMessage(message, chatType);
        end);
        if not success then
            Logger:Debug("Notification", "调试", "发送团队消息失败:", err or "未知错误");
        end
    else
        Logger:Info("Notification", "通知", systemMessage);
    end
end

