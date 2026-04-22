-- Notification.lua - 处理空投检测通知和地图刷新通知

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Notification = BuildEnv('Notification');
local Area = BuildEnv("Area");
local NotificationSettingsStore = BuildEnv("NotificationSettingsStore");
local NotificationDedupService = BuildEnv("NotificationDedupService");
local NotificationDecisionService = BuildEnv("NotificationDecisionService");
local NotificationOutputService = BuildEnv("NotificationOutputService");
local NotificationQueryService = BuildEnv("NotificationQueryService");
local TeamCommListener = BuildEnv("TeamCommListener");
local Data = BuildEnv("Data");
local UnifiedDataManager = BuildEnv("UnifiedDataManager");

Notification.isInitialized = false;
Notification.teamNotificationEnabled = true;
Notification.leaderModeEnabled = false;
Notification.phaseTeamAlertEnabled = false;
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
        self.leaderModeEnabled = settings.leaderModeEnabled;
        self.phaseTeamAlertEnabled = settings.phaseTeamAlertEnabled;
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

function Notification:IsLeaderModeEnabled()
    return self.leaderModeEnabled == true;
end

function Notification:IsPhaseTeamAlertEnabled()
    return self.phaseTeamAlertEnabled == true;
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

function Notification:SetLeaderModeEnabled(enabled)
    self.leaderModeEnabled = enabled == true;
    if NotificationSettingsStore and NotificationSettingsStore.SetLeaderModeEnabled then
        NotificationSettingsStore:SetLeaderModeEnabled(self.leaderModeEnabled);
    end
end

function Notification:SetPhaseTeamAlertEnabled(enabled)
    self.phaseTeamAlertEnabled = enabled == true;
    if NotificationSettingsStore and NotificationSettingsStore.SetPhaseTeamAlertEnabled then
        NotificationSettingsStore:SetPhaseTeamAlertEnabled(self.phaseTeamAlertEnabled);
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

local function BuildAutomaticNotificationRequest(mapName, detectionSource, eventContext)
    eventContext = type(eventContext) == "table" and eventContext or {};
    return {
        kind = "airdrop_auto",
        source = detectionSource,
        mapKey = eventContext.mapKey or mapName,
        mapId = eventContext.mapId or eventContext.mapID or eventContext.id,
        mapName = mapName,
        eventTimestamp = eventContext.eventTimestamp or eventContext.timestamp,
        objectGUID = eventContext.objectGUID,
        allowTeamChat = true,
        allowLocalFallback = true,
        allowSound = true,
        chatIntent = "automatic",
    };
end

local function ExecuteNotificationDecision(notification, message, decision)
    if NotificationOutputService and NotificationOutputService.ExecuteDecision then
        return NotificationOutputService:ExecuteDecision(notification, message, decision);
    end

    return {
        sentTeamChat = false,
        sentLocalFallback = false,
        sentText = false,
        playedSound = false,
    };
end

local function SendManualVisibleMessage(message, preferredChatType)
    local result = {
        sentTeamChat = false,
        sentLocalFallback = false,
        sentText = false,
        err = nil,
    };

    if preferredChatType then
        if NotificationOutputService and NotificationOutputService.SendManualMessage then
            local success, err = NotificationOutputService:SendManualMessage(message, preferredChatType);
            result.sentTeamChat = success == true;
            result.sentText = result.sentTeamChat;
            result.err = err;
        end
        return result;
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        result.sentLocalFallback = NotificationOutputService:SendLocalMessage(message) == true;
        result.sentText = result.sentLocalFallback;
    end

    return result;
end

local function ResolveStandardVisibleChatType(notification)
    if type(notification) ~= "table"
        or not notification.IsTeamNotificationEnabled
        or notification:IsTeamNotificationEnabled() ~= true then
        return nil;
    end

    local teamChatType = notification.GetTeamChatType and notification:GetTeamChatType() or nil;
    if type(teamChatType) ~= "string" or teamChatType == "" then
        return nil;
    end

    return NotificationOutputService
        and NotificationOutputService.GetStandardVisibleChatType
        and NotificationOutputService:GetStandardVisibleChatType(teamChatType)
        or nil;
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

function Notification:RecordConfirmedSyncReceipt(mapRef, eventContext, receivedAt)
    if NotificationDedupService and NotificationDedupService.RecordReceivedSync then
        return NotificationDedupService:RecordReceivedSync(self, mapRef, receivedAt, eventContext);
    end
    return false;
end

function Notification:RecordReceivedSync(mapRef, timestamp, eventContext)
    return self:RecordConfirmedSyncReceipt(mapRef, eventContext, timestamp);
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

    if TeamCommListener and TeamCommListener.SendConfirmedSync then
        return TeamCommListener:SendConfirmedSync(syncState, chatType);
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
    local currentTime = Utils:GetCurrentTimestamp();
    -- 记录喊话时间，用于后续图标检测的去重
    if detectionSource == "npc_shout" then
        self:RecordShout(mapNotificationKey, currentTime);
    end

    local request = BuildAutomaticNotificationRequest(mapName, detectionSource, eventContext);
    local decision = NotificationDecisionService
        and NotificationDecisionService.DecideVisibleNotification
        and NotificationDecisionService:DecideVisibleNotification(self, request, currentTime)
        or nil;
    if not decision or decision.suppress == true then
        return;
    end

    local message = NotificationQueryService and NotificationQueryService.BuildAirdropDetectedMessage
        and NotificationQueryService:BuildAirdropDetectedMessage(mapName)
        or string.format(L["AirdropDetected"], mapName);
    local outputResult = ExecuteNotificationDecision(self, message, decision);
    if decision.trackDispatch == true and outputResult and outputResult.sentText == true then
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

function Notification:NotifySharedPhaseSyncApplied(mapId, sharedRecord)
    if not self.isInitialized then self:Initialize() end
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" then
        return false;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId);
    local message = NotificationQueryService and NotificationQueryService.BuildSharedPhaseSyncAppliedMessage
        and NotificationQueryService:BuildSharedPhaseSyncAppliedMessage(mapName)
        or string.format((L and L["SharedPhaseSyncApplied"]) or "Acquired the latest shared airdrop info for the current phase in [%s].", mapName);

    return NotificationOutputService
        and NotificationOutputService.SendLocalMessage
        and NotificationOutputService:SendLocalMessage(message) == true
        or false;
end

function Notification:SendSharedPhaseSyncAppliedTeamMessage(mapId, sharedRecord)
    if not self.isInitialized then self:Initialize() end
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" then
        return false;
    end

    local visibleChatType = ResolveStandardVisibleChatType(self);
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId);
    local message = NotificationQueryService and NotificationQueryService.BuildSharedPhaseSyncAppliedMessage
        and NotificationQueryService:BuildSharedPhaseSyncAppliedMessage(mapName)
        or string.format((L and L["SharedPhaseSyncApplied"]) or "Acquired the latest shared airdrop info for the current phase in [%s].", mapName);

    return NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType) == true
        or false;
end

function Notification:SendTimeRemainingTeamMessage(mapId)
    if not self.isInitialized then self:Initialize() end
    if type(mapId) ~= "number" then
        return false;
    end

    local visibleChatType = ResolveStandardVisibleChatType(self);
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    if not mapData then
        return false;
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapId) or nil;
    if type(remaining) ~= "number" then
        return false;
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId);
    local message = NotificationQueryService and NotificationQueryService.BuildTimeRemainingMessage
        and NotificationQueryService:BuildTimeRemainingMessage(mapName, remaining)
        or string.format((L and L["TimeRemaining"]) or "[%s]War Supplies airdrop in: %s!!!", mapName, UnifiedDataManager:FormatTime(remaining, true));

    return NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType) == true
        or false;
end

function Notification:NotifyPhaseTeamAlert(mapName, previousPhaseID, currentPhaseID)
    if not self.isInitialized then self:Initialize() end
    if type(mapName) ~= "string" or mapName == "" then
        return false
    end
    if currentPhaseID == nil then
        return false
    end
    if not self:IsPhaseTeamAlertEnabled() then
        return false
    end
    if not self:IsTeamNotificationEnabled() then
        return false
    end

    local teamChatType = self:GetTeamChatType()
    if type(teamChatType) ~= "string" or teamChatType == "" then
        return false
    end

    -- 位面变化提醒只走普通小队/团队频道，不升级为团队通知。
    local visibleChatType = NotificationOutputService
        and NotificationOutputService.GetStandardVisibleChatType
        and NotificationOutputService:GetStandardVisibleChatType(teamChatType)
        or nil
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false
    end

    local message = NotificationQueryService
        and NotificationQueryService.BuildPhaseTeamAlertMessage
        and NotificationQueryService:BuildPhaseTeamAlertMessage(mapName, previousPhaseID, currentPhaseID)
        or string.format(
            (L and L["PhaseTeamAlertMessage"]) or "Current %s phase changed: %s --> %s",
            mapName,
            tostring(previousPhaseID or ((L and L["UnknownPhaseValue"]) or "unknown")),
            tostring(currentPhaseID)
        )
    return NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType, {
            logFailure = true,
            label = "发送位面团队提醒失败",
        }) == true
        or false
end

function Notification:SendTrajectoryPredictionTeamMessage(mapId, routeKey, objectGUID, endX, endY, eventTimestamp)
    if not self.isInitialized then self:Initialize() end
    if type(mapId) ~= "number" or type(routeKey) ~= "string" or routeKey == "" then
        return false
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return false
    end
    if not self:IsTeamNotificationEnabled() then
        return false
    end

    local visibleChatType = ResolveStandardVisibleChatType(self)
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false
    end

    local currentTime = Utils:GetCurrentTimestamp()
    local mapKey = "trajectory:" .. tostring(mapId) .. ":" .. routeKey
    local eventContext = {
        mapKey = mapKey,
        eventTimestamp = tonumber(eventTimestamp) or currentTime,
        objectGUID = objectGUID,
    }

    if self.HasPlayerSentNotification and self:HasPlayerSentNotification(mapKey, eventContext) then
        return false
    end
    if self.CanSendNotification and self:CanSendNotification(mapKey, eventContext, currentTime) ~= true then
        return false
    end

    local mapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(mapId) or nil
    if not mapData and Data and Data.GetMap then
        mapData = Data:GetMap(mapId)
    end
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId)
    local message = NotificationQueryService and NotificationQueryService.BuildTrajectoryPredictionMessage
        and NotificationQueryService:BuildTrajectoryPredictionMessage(
            mapName,
            (tonumber(endX) or 0) * 100,
            (tonumber(endY) or 0) * 100
        )
        or string.format((L and L["TrajectoryPredictionMatched"]) or "[%s] Matched airdrop trajectory, predicted drop coordinates: %.1f, %.1f", mapName, (tonumber(endX) or 0) * 100, (tonumber(endY) or 0) * 100)

    local sent = NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType, {
            logFailure = true,
            label = "发送轨迹预测团队消息失败",
        }) == true
        or false
    if sent == true and self.CommitVisibleAutoDispatch then
        self:CommitVisibleAutoDispatch(mapKey, eventContext, currentTime)
    end
    return sent == true
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
            and NotificationOutputService.GetManualAirdropChatType
            and NotificationOutputService:GetManualAirdropChatType(self, chatType);
        if visibleChatType then
            SendManualVisibleMessage(message, visibleChatType);
        end
    else
        SendManualVisibleMessage(message, nil);
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
        message = NotificationQueryService and NotificationQueryService.BuildAirdropDetectedMessage
            and NotificationQueryService:BuildAirdropDetectedMessage(displayName)
            or string.format(L["AirdropDetected"], displayName);
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
            and NotificationOutputService.GetManualAirdropChatType
            and NotificationOutputService:GetManualAirdropChatType(self, chatType);
        local outputResult = visibleChatType and SendManualVisibleMessage(message, visibleChatType) or nil;
        if not outputResult or outputResult.sentText ~= true then
            SendManualVisibleMessage(systemMessage, nil);
        end
    else
        SendManualVisibleMessage(systemMessage, nil);
    end
end
