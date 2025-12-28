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
    
    -- 检查是否在小队或团队中
    local chatType = self:GetTeamChatType();
    
    if chatType then
        -- 在小队或团队中：只发送到小队/团队，不发送到聊天框（避免重复）
        if IsInRaid() then
            -- 在团队中：根据权限选择 RAID_WARNING 或 RAID（受 teamNotificationEnabled 控制）
            if self.teamNotificationEnabled then
                local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player");
                local raidChatType = hasPermission and "RAID_WARNING" or "RAID";
                Logger:Debug("Notification", "通知", string.format("发送团队通知：类型=%s，权限=%s", raidChatType, hasPermission and "有" or "无"));
                
                pcall(function()
                    SendChatMessage(message, raidChatType);
                end);
            else
                -- teamNotificationEnabled = false：不发送团队通知，也不发送到聊天框
                Logger:DebugLimited("notification:team_disabled", "Notification", "通知", 
                    string.format("团队通知已禁用，跳过发送：地图=%s", mapName));
            end
        else
            -- 在小队中：发送到小队（不受 teamNotificationEnabled 控制）
            Logger:Debug("Notification", "通知", string.format("发送小队通知：类型=%s", chatType));
            pcall(function()
                SendChatMessage(message, chatType);
            end);
        end
        -- 注意：在小队/团队中时，不发送到聊天框，避免重复
    else
        -- 不在小队/团队中：发送到聊天框
        Logger:Info("Notification", "通知", message);
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
        -- 检查是否处于已处理状态（空投已检测并处理）
        isAirdropActive = (state and state.status == DetectionState.STATES.PROCESSED);
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
    
    -- 检查是否在小队或团队中
    local chatType = self:GetTeamChatType();
    
    if chatType then
        -- 在小队或团队中：只发送到小队/团队，不发送到聊天框（避免重复）
        Logger:Debug("Notification", "通知", string.format("发送小队/团队通知：类型=%s", chatType));
        local success, err = pcall(function()
            SendChatMessage(message, chatType);
        end);
        if not success then
            -- SendChatMessage 失败（可能是速率限制），记录但不影响用户体验
            Logger:Debug("Notification", "调试", "发送团队消息失败:", err or "未知错误");
        end
    else
        -- 不在小队/团队中：发送到聊天框
        Logger:Info("Notification", "通知", message);
    end
end

