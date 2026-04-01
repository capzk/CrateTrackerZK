-- Notification.lua - 处理空投检测通知和地图刷新通知

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local AirdropEventService = BuildEnv("AirdropEventService");
local Notification = BuildEnv('Notification');
local Area = BuildEnv("Area");
local NotificationSettingsStore = BuildEnv("NotificationSettingsStore");
local NotificationDedupService = BuildEnv("NotificationDedupService");
local NotificationOutputService = BuildEnv("NotificationOutputService");
local NotificationQueryService = BuildEnv("NotificationQueryService");

Notification.isInitialized = false;
Notification.teamNotificationEnabled = true;
Notification.soundAlertEnabled = true;
Notification.autoTeamReportEnabled = false;
Notification.autoTeamReportInterval = 60;
Notification.airdropAlertSoundFile = "Interface\\AddOns\\CrateTrackerZK\\Assets\\Sounds\\ctk_airdrop_detected_v1.ogg";
Notification.NOTIFICATION_WINDOW = 30;
-- 首次通知时间记录（用于30秒限制）
Notification.firstNotificationTime = {};
-- 玩家发送通知记录（防止重复发送）
Notification.playerSentNotification = {};
-- 最近喊话时间记录（用于图标检测去重）
Notification.lastShoutTime = Notification.lastShoutTime or {};
Notification.SHOUT_DEDUP_WINDOW = 20;

local function DebugPrint(msg, ...)
    Logger:Debug("Notification", "调试", msg, ...);
end

function Notification:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true;
    if NotificationSettingsStore and NotificationSettingsStore.Load then
        local settings = NotificationSettingsStore:Load();
        self.teamNotificationEnabled = settings.teamNotificationEnabled;
        self.soundAlertEnabled = settings.soundAlertEnabled;
        self.autoTeamReportEnabled = settings.autoTeamReportEnabled;
        self.autoTeamReportInterval = settings.autoTeamReportInterval;
    end
    if NotificationDedupService and NotificationDedupService.EnsureState then
        NotificationDedupService:EnsureState(self);
    end
    
    DebugPrint("[通知] 通知模块已初始化");
end

function Notification:IsTeamNotificationEnabled()
    return self.teamNotificationEnabled;
end

function Notification:IsSoundAlertEnabled()
    return self.soundAlertEnabled == true;
end

function Notification:SetTeamNotificationEnabled(enabled)
    self.teamNotificationEnabled = enabled;
    
    if NotificationSettingsStore and NotificationSettingsStore.SetTeamNotificationEnabled then
        NotificationSettingsStore:SetTeamNotificationEnabled(enabled);
    end
    
    local statusText = enabled and L["Enabled"] or L["Disabled"];
    Logger:Info("Notification", "状态", statusText);

    if not enabled then
        self.autoTeamReportEnabled = false;
        if NotificationSettingsStore and NotificationSettingsStore.SetAutoTeamReportEnabled then
            NotificationSettingsStore:SetAutoTeamReportEnabled(false);
        end
    end
    if CrateTrackerZK then
        if not enabled and CrateTrackerZK.StopAutoTeamReportTicker then
            CrateTrackerZK:StopAutoTeamReportTicker();
        elseif enabled and self:IsAutoTeamReportEnabled() and CrateTrackerZK.RestartAutoTeamReportTicker then
            CrateTrackerZK:RestartAutoTeamReportTicker();
        end
    end
end

function Notification:SetSoundAlertEnabled(enabled)
    self.soundAlertEnabled = enabled == true;
    if NotificationSettingsStore and NotificationSettingsStore.SetSoundAlertEnabled then
        NotificationSettingsStore:SetSoundAlertEnabled(self.soundAlertEnabled);
    end
end

function Notification:IsAutoTeamReportEnabled()
    return self.autoTeamReportEnabled == true;
end

function Notification:GetAutoTeamReportInterval()
    return self.autoTeamReportInterval or 60;
end

local function NormalizeInterval(value)
    local numberValue = tonumber(value);
    if not numberValue then
        return nil;
    end
    numberValue = math.floor(numberValue);
    if numberValue < 1 then
        return nil;
    end
    return numberValue;
end

function Notification:SetAutoTeamReportEnabled(enabled)
    if enabled and not self:IsTeamNotificationEnabled() then
        self.autoTeamReportEnabled = false;
        if NotificationSettingsStore and NotificationSettingsStore.SetAutoTeamReportEnabled then
            NotificationSettingsStore:SetAutoTeamReportEnabled(false);
        end
        return;
    end
    self.autoTeamReportEnabled = enabled == true;
    if NotificationSettingsStore and NotificationSettingsStore.SetAutoTeamReportEnabled then
        NotificationSettingsStore:SetAutoTeamReportEnabled(self.autoTeamReportEnabled);
    end
    if CrateTrackerZK and CrateTrackerZK.RestartAutoTeamReportTicker then
        CrateTrackerZK:RestartAutoTeamReportTicker();
    end
end

function Notification:SetAutoTeamReportInterval(seconds)
    local value = NormalizeInterval(seconds);
    if not value then
        return nil;
    end
    self.autoTeamReportInterval = value;
    if NotificationSettingsStore and NotificationSettingsStore.SetAutoTeamReportInterval then
        NotificationSettingsStore:SetAutoTeamReportInterval(value);
    end
    if CrateTrackerZK and CrateTrackerZK.RestartAutoTeamReportTicker then
        CrateTrackerZK:RestartAutoTeamReportTicker();
    end
    return value;
end

-- 更新首次通知时间（团队消息同步）
function Notification:UpdateFirstNotificationTime(mapName, notificationTime)
    if NotificationDedupService and NotificationDedupService.UpdateFirstNotificationTime then
        return NotificationDedupService:UpdateFirstNotificationTime(self, mapName, notificationTime);
    end
end

-- 检查30秒限制
function Notification:CanSendNotification(mapName)
    if NotificationDedupService and NotificationDedupService.CanSendNotification then
        return NotificationDedupService:CanSendNotification(self, mapName);
    end
    return false;
end

function Notification:ResetMapNotificationState(mapName)
    if NotificationDedupService and NotificationDedupService.ResetMapNotificationState then
        return NotificationDedupService:ResetMapNotificationState(self, mapName);
    end
    return false;
end

function Notification:MarkPlayerSentNotification(mapName)
    if NotificationDedupService and NotificationDedupService.MarkPlayerSentNotification then
        return NotificationDedupService:MarkPlayerSentNotification(self, mapName);
    end
end

function Notification:HasPlayerSentNotification(mapName)
    if NotificationDedupService and NotificationDedupService.HasPlayerSentNotification then
        return NotificationDedupService:HasPlayerSentNotification(self, mapName);
    end
    return false;
end

function Notification:RecordShout(mapName, timestamp)
    if NotificationDedupService and NotificationDedupService.RecordShout then
        return NotificationDedupService:RecordShout(self, mapName, timestamp);
    end
end

function Notification:IsRecentShout(mapName, windowSeconds, currentTime)
    if NotificationDedupService and NotificationDedupService.IsRecentShout then
        return NotificationDedupService:IsRecentShout(self, mapName, windowSeconds, currentTime);
    end
    return false, nil;
end

function Notification:PlayAirdropAlertSound()
    if NotificationOutputService and NotificationOutputService.PlayAirdropAlertSound then
        return NotificationOutputService:PlayAirdropAlertSound(self);
    end
    return false;
end

function Notification:NotifyAirdropDetected(mapName, detectionSource)
    if not self.isInitialized then self:Initialize() end
    if not mapName then 
        Logger:Debug("Notification", "通知", "通知失败：地图名称为空");
        return 
    end
    
    local chatType = self:GetTeamChatType();
    local currentTime = time();
    -- 记录喊话时间，用于后续图标检测的去重
    if detectionSource == "npc_shout" then
        self:RecordShout(mapName, currentTime);
    end
    local isRecentShout, lastShoutTime = self:IsRecentShout(mapName, self.SHOUT_DEDUP_WINDOW, currentTime);
    local shouldSuppressMapIcon = detectionSource == "map_icon"
        and (
            (AirdropEventService and AirdropEventService.ShouldSuppressMapIconNotification
                and AirdropEventService:ShouldSuppressMapIconNotification(lastShoutTime, currentTime, self.SHOUT_DEDUP_WINDOW))
            or isRecentShout
        );
    if shouldSuppressMapIcon then
        self:UpdateFirstNotificationTime(mapName, lastShoutTime or currentTime);
        self:MarkPlayerSentNotification(mapName);
        Logger:Debug("Notification", "去重", string.format("最近%ds内已由喊话触发，跳过图标二次通知：地图=%s，间隔=%ds",
            self.SHOUT_DEDUP_WINDOW, mapName, currentTime - (lastShoutTime or currentTime)));
        return;
    end
    
    if chatType and self.teamNotificationEnabled then
        -- 个人发送限制检查
        if self:HasPlayerSentNotification(mapName) then
            Logger:Debug("Notification", "通知", string.format("玩家已发送过通知，跳过发送：地图=%s，来源=%s", 
                mapName, detectionSource or "未知"));
            local message = string.format(L["AirdropDetected"], mapName);
            Logger:Info("Notification", "通知", message);
            return;
        end
        
        -- 30秒限制检查
        if not self:CanSendNotification(mapName) then
            Logger:Debug("Notification", "通知", string.format("超过30秒限制，不允许发送：地图=%s，来源=%s", 
                mapName, detectionSource or "未知"));
            local message = string.format(L["AirdropDetected"], mapName);
            Logger:Info("Notification", "通知", message);
            return;
        end
        
        -- 记录首次通知时间
        if not self.firstNotificationTime[mapName] then
            self.firstNotificationTime[mapName] = currentTime;
            Logger:Debug("Notification", "通知", string.format("记录首次通知时间：地图=%s，时间=%s", 
                mapName, UnifiedDataManager:FormatDateTime(currentTime)));
        end
        
        self:MarkPlayerSentNotification(mapName);
    end
    
    local message = string.format(L["AirdropDetected"], mapName);

    if NotificationOutputService and NotificationOutputService.PlayDelayedAlertSound then
        NotificationOutputService:PlayDelayedAlertSound(self);
    else
        self:PlayAirdropAlertSound();
    end
    
    Logger:Debug("Notification", "通知", string.format("发送空投检测通知：地图=%s，来源=%s", mapName, detectionSource or "未知"));
    
    Logger:Debug("Notification", "调试", string.format("团队通知检查：chatType=%s, teamNotificationEnabled=%s, IsInRaid=%s, IsInGroup=%s", 
        tostring(chatType), tostring(self.teamNotificationEnabled), tostring(IsInRaid()), tostring(IsInGroup())));
    
    if NotificationOutputService and NotificationOutputService.SendMessage then
        local sentToTeam = NotificationOutputService:SendMessage(self, message, chatType);
        if chatType and not self.teamNotificationEnabled and not sentToTeam then
            Logger:Debug("Notification", "通知", string.format("团队通知已禁用，仅发送系统消息：地图=%s", mapName));
        end
    end
end

function Notification:GetTeamChatType()
    if NotificationOutputService and NotificationOutputService.GetTeamChatType then
        return NotificationOutputService:GetTeamChatType();
    end
    return nil;
end

function Notification:GetNearestAirdropInfo()
    if NotificationQueryService and NotificationQueryService.GetNearestAirdropInfo then
        return NotificationQueryService:GetNearestAirdropInfo();
    end
    return nil;
end

function Notification:SendAutoTeamReport()
    if not self.isInitialized then self:Initialize() end
    if not self:IsAutoTeamReportEnabled() then
        return false;
    end
    if not self:IsTeamNotificationEnabled() then
        return false;
    end

    if Area and Area.IsActive and not Area:IsActive() then
        return false;
    end

    local mapData, remaining = self:GetNearestAirdropInfo();
    if not mapData or remaining == nil then
        return false;
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or nil;
    if not mapName or mapName == "" then
        return false;
    end

    local message = NotificationQueryService and NotificationQueryService.BuildAutoTeamReportMessage
        and NotificationQueryService:BuildAutoTeamReportMessage(mapName, remaining)
        or string.format((L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!", mapName, UnifiedDataManager:FormatTime(remaining, true));
    local chatType = self:GetTeamChatType();
    if chatType then
        -- 自动通知固定使用普通团队/小队频道，避免触发团队警告音效
        if NotificationOutputService and NotificationOutputService.SendManualMessage then
            NotificationOutputService:SendManualMessage(message, chatType);
        end
    else
        if Logger and Logger.Info then
            Logger:Info("Notification", "通知", message);
        elseif DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(message);
        end
    end
    return true;
end

function Notification:NotifyMapRefresh(mapData, isAirdropActive, clickButton)
    if not self.isInitialized then self:Initialize() end
    if not mapData then 
        Logger:Debug("Notification", "通知", "通知地图刷新失败：地图数据为空");
        return 
    end
    
    if isAirdropActive == nil then
        isAirdropActive = false;
        Logger:Debug("Notification", "通知", string.format("未传递空投状态参数，默认发送剩余时间：地图=%s", 
            Data:GetMapDisplayName(mapData)));
    end
    
    Logger:Debug("Notification", "通知", string.format("用户请求通知地图刷新：地图=%s，空投进行中=%s", 
        Data:GetMapDisplayName(mapData), isAirdropActive and "是" or "否"));
    
    local message;
    local systemMessage;
    local displayName = Data:GetMapDisplayName(mapData);
    local remaining = nil;
    
    if isAirdropActive then
        message = string.format(L["AirdropDetectedManual"], displayName);
        systemMessage = message;
    else
        remaining = UnifiedDataManager:GetRemainingTime(mapData.id);
        if not remaining then
            message = string.format(L["NoTimeRecord"], displayName);
            systemMessage = message;
        else
            if clickButton == "RightButton" then
                message = NotificationQueryService and NotificationQueryService.BuildAutoTeamReportMessage
                    and NotificationQueryService:BuildAutoTeamReportMessage(displayName, remaining)
                    or string.format((L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!", displayName, UnifiedDataManager:FormatTime(remaining, true));
            else
                message = string.format(L["TimeRemaining"], displayName, UnifiedDataManager:FormatTime(remaining, true));
            end
            systemMessage = message;
        end
    end
    
    local chatType = self:GetTeamChatType();
    
    if chatType then
        Logger:Debug("Notification", "通知", string.format("发送小队/团队通知（手动）：类型=%s", chatType));
        local success, err = false, nil;
        if NotificationOutputService and NotificationOutputService.SendManualMessage then
            success, err = NotificationOutputService:SendManualMessage(message, chatType);
        end
        if not success then
            Logger:Debug("Notification", "调试", "发送团队消息失败:", err or "未知错误");
        end
    else
        Logger:Info("Notification", "通知", systemMessage);
    end
end
