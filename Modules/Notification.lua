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
    
    -- 使用 Logger 统一输出
    Logger:Info("Notification", "通知", message);
    
    if self.teamNotificationEnabled and IsInRaid() then
        local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player");
        local chatType = hasPermission and "RAID_WARNING" or "RAID";
        Logger:Debug("Notification", "通知", string.format("发送团队通知：类型=%s，权限=%s", chatType, hasPermission and "有" or "无"));
        
        if hasPermission then
            pcall(function()
                SendChatMessage(message, "RAID_WARNING");
            end);
        else
            pcall(function()
                SendChatMessage(message, "RAID");
            end);
        end
    else
        Logger:DebugLimited("notification:team_disabled", "Notification", "通知", 
            string.format("团队通知已禁用或不在团队中：启用=%s，在团队=%s", 
                self.teamNotificationEnabled and "是" or "否",
                IsInRaid() and "是" or "否"));
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
    
    -- 使用 DetectionState 模块检查空投状态
    local isAirdropActive = false;
    if DetectionState then
        local state = DetectionState:GetState(mapData.id);
        isAirdropActive = (state and state.status == "active");
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
    
    -- 使用 Logger 统一输出（始终在聊天框显示消息）
    Logger:Info("Notification", "通知", message);
    
    -- 尝试发送到团队/队伍（如果失败也不影响，因为聊天框已显示）
    local chatType = self:GetTeamChatType();
    if chatType then
        local success, err = pcall(function()
            SendChatMessage(message, chatType);
        end);
        if not success then
            -- SendChatMessage 失败（可能是速率限制），记录但不影响用户体验
            Logger:Debug("Notification", "调试", "发送团队消息失败:", err or "未知错误");
        end
    end
end

