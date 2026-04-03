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
local TeamCommListener = BuildEnv("TeamCommListener");

Notification.isInitialized = false;
Notification.teamNotificationEnabled = true;
Notification.soundAlertEnabled = true;
Notification.autoTeamReportEnabled = false;
Notification.autoTeamReportInterval = 60;
Notification.airdropAlertSoundFile = "Interface\\AddOns\\CrateTrackerZK\\Assets\\Sounds\\ctk_airdrop_detected_v1.ogg";
-- 同地图同一空投事件的自动通知统一窗口（秒）
Notification.NOTIFICATION_WINDOW = 15;
-- 最近喊话时间记录（用于图标检测去重）
Notification.lastShoutTime = Notification.lastShoutTime or {};
-- 同地图同一空投事件收到隐藏同步后的可见自动团队消息窗口
Notification.RECEIVED_SYNC_VISIBLE_WINDOW = Notification.NOTIFICATION_WINDOW;
-- 同地图同一空投事件的可见自动消息门禁状态
Notification.visibleAutoEventStateByMap = Notification.visibleAutoEventStateByMap or {};
Notification.SHOUT_DEDUP_WINDOW = 20;

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

local function BuildVisibleAutoDispatchState(notification, mapRef, eventContext, outboundChatType, currentTime)
    if NotificationDedupService and NotificationDedupService.ResolveVisibleAutoDispatchState then
        return NotificationDedupService:ResolveVisibleAutoDispatchState(
            notification,
            mapRef,
            eventContext,
            outboundChatType,
            currentTime
        );
    end

    return {
        outboundChatType = outboundChatType,
        shouldAbortNotification = false,
        shouldTrackVisibleSend = false,
        blockReason = nil,
    };
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

-- 检查同地图同一空投事件是否仍在自动通知窗口内
function Notification:CanSendNotification(mapRef, eventContext, currentTime)
    if NotificationDedupService and NotificationDedupService.CanSendNotification then
        return NotificationDedupService:CanSendNotification(self, mapRef, eventContext, currentTime);
    end
    return false;
end

function Notification:ResetMapNotificationState(mapRef, eventContext)
    if NotificationDedupService and NotificationDedupService.ResetMapNotificationState then
        return NotificationDedupService:ResetMapNotificationState(self, mapRef, eventContext);
    end
    return false;
end

function Notification:MarkPlayerSentNotification(mapRef, eventContext, currentTime)
    if NotificationDedupService and NotificationDedupService.MarkPlayerSentNotification then
        return NotificationDedupService:MarkPlayerSentNotification(self, mapRef, eventContext, currentTime);
    end
end

function Notification:HasPlayerSentNotification(mapRef, eventContext)
    if NotificationDedupService and NotificationDedupService.HasPlayerSentNotification then
        return NotificationDedupService:HasPlayerSentNotification(self, mapRef, eventContext);
    end
    return false;
end

function Notification:RecordShout(mapRef, timestamp)
    if NotificationDedupService and NotificationDedupService.RecordShout then
        return NotificationDedupService:RecordShout(self, mapRef, timestamp);
    end
end

function Notification:IsRecentShout(mapRef, windowSeconds, currentTime)
    if NotificationDedupService and NotificationDedupService.IsRecentShout then
        return NotificationDedupService:IsRecentShout(self, mapRef, windowSeconds, currentTime);
    end
    return false, nil;
end

function Notification:RecordReceivedSync(mapRef, timestamp, eventContext)
    if NotificationDedupService and NotificationDedupService.RecordReceivedSync then
        return NotificationDedupService:RecordReceivedSync(self, mapRef, timestamp, eventContext);
    end
end

function Notification:ClearExpiredTransientState(currentTime)
    if NotificationDedupService and NotificationDedupService.ClearExpiredTransientState then
        return NotificationDedupService:ClearExpiredTransientState(self, currentTime);
    end
    return 0;
end

function Notification:HasRecentReceivedSync(mapRef, windowSeconds, currentTime, eventContext)
    if NotificationDedupService and NotificationDedupService.HasRecentReceivedSync then
        return NotificationDedupService:HasRecentReceivedSync(self, mapRef, windowSeconds, currentTime, eventContext);
    end
    return false, nil;
end

function Notification:CommitVisibleAutoDispatch(mapRef, eventContext, currentTime)
    if NotificationDedupService and NotificationDedupService.CommitVisibleAutoDispatch then
        return NotificationDedupService:CommitVisibleAutoDispatch(self, mapRef, eventContext, currentTime);
    end
    return false;
end

function Notification:NoteSuppressedVisibleAutoDispatch(mapRef, eventContext, timestamp)
    if NotificationDedupService and NotificationDedupService.NoteSuppressedVisibleAutoDispatch then
        return NotificationDedupService:NoteSuppressedVisibleAutoDispatch(self, mapRef, eventContext, timestamp);
    end
    return false;
end

function Notification:PlayAirdropAlertSound()
    if NotificationOutputService and NotificationOutputService.PlayAirdropAlertSound then
        return NotificationOutputService:PlayAirdropAlertSound(self);
    end
    return false;
end

function Notification:SendAirdropSync(syncState)
    if not self.isInitialized then
        self:Initialize();
    end
    if TeamCommListener and TeamCommListener.CanEnableHiddenSync and TeamCommListener:CanEnableHiddenSync() ~= true then
        return false;
    end

    local chatType = self:GetTeamChatType();
    if not chatType then
        return false;
    end

    if NotificationOutputService and NotificationOutputService.SendAirdropSync then
        return NotificationOutputService:SendAirdropSync(syncState, chatType);
    end
    return false;
end

function Notification:NotifyAirdropDetected(mapName, detectionSource, eventContext)
    if not self.isInitialized then self:Initialize() end
    if not mapName then 
        return 
    end
    
    eventContext = eventContext or {};
    local mapNotificationKey = eventContext.mapKey or mapName;
    local chatType = self:GetTeamChatType();
    local outboundChatType = chatType;
    local currentTime = Utils:GetCurrentTimestamp();
    -- 记录喊话时间，用于后续图标检测的去重
    if detectionSource == "npc_shout" then
        self:RecordShout(mapNotificationKey, currentTime);
    end
    local isRecentShout, lastShoutTime = self:IsRecentShout(mapNotificationKey, self.SHOUT_DEDUP_WINDOW, currentTime);
    local shouldSuppressMapIcon = detectionSource == "map_icon"
        and (
            (AirdropEventService and AirdropEventService.ShouldSuppressMapIconNotification
                and AirdropEventService:ShouldSuppressMapIconNotification(lastShoutTime, currentTime, self.SHOUT_DEDUP_WINDOW))
            or isRecentShout
        );
    if shouldSuppressMapIcon then
        self:NoteSuppressedVisibleAutoDispatch(mapNotificationKey, eventContext, lastShoutTime or currentTime);
        return;
    end

    local visibleAutoDispatchState = BuildVisibleAutoDispatchState(
        self,
        mapNotificationKey,
        eventContext,
        outboundChatType,
        currentTime
    );
    outboundChatType = visibleAutoDispatchState.outboundChatType;
    if visibleAutoDispatchState.shouldAbortNotification then
        local message = string.format(L["AirdropDetected"], mapName);
        Logger:Info("Notification", "通知", message);
        return;
    end
    
    local message = string.format(L["AirdropDetected"], mapName);

    if NotificationOutputService and NotificationOutputService.PlayDelayedAlertSound then
        NotificationOutputService:PlayDelayedAlertSound(self);
    else
        self:PlayAirdropAlertSound();
    end
    
    local visibleSendSuccess = false;
    if NotificationOutputService and NotificationOutputService.SendMessage then
        visibleSendSuccess = NotificationOutputService:SendMessage(self, message, outboundChatType) == true;
    end

    if visibleAutoDispatchState.shouldTrackVisibleSend and outboundChatType and visibleSendSuccess then
        self:CommitVisibleAutoDispatch(mapNotificationKey, eventContext, currentTime);
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

    if Area then
        if Area.CanUseTrackedMapFeatures then
            if not Area:CanUseTrackedMapFeatures() then
                return false;
            end
        elseif Area.IsActive and not Area:IsActive() then
            return false;
        end
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
        local visibleChatType = NotificationOutputService
            and NotificationOutputService.GetStandardVisibleChatType
            and NotificationOutputService:GetStandardVisibleChatType();
        if NotificationOutputService and NotificationOutputService.SendManualMessage then
            NotificationOutputService:SendManualMessage(message, visibleChatType);
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
        return 
    end
    
    if isAirdropActive == nil then
        isAirdropActive = false;
    end
    
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
        local visibleChatType = NotificationOutputService
            and NotificationOutputService.GetStandardVisibleChatType
            and NotificationOutputService:GetStandardVisibleChatType();
        local success, err = false, nil;
        if NotificationOutputService and NotificationOutputService.SendManualMessage then
            success, err = NotificationOutputService:SendManualMessage(message, visibleChatType);
        end
        if not success then
            Logger:Warn("Notification", "通知", "发送小队/团队消息失败: " .. tostring(err or "未知错误"));
        end
    else
        Logger:Info("Notification", "通知", systemMessage);
    end
end
