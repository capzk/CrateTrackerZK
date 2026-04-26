-- Notification.lua - 处理空投检测通知和地图刷新通知

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Notification = BuildEnv('Notification');
local Area = BuildEnv("Area");
local NotificationSettingsStore = BuildEnv("NotificationSettingsStore");
local NotificationDedupService = BuildEnv("NotificationDedupService");
local NotificationDecisionService = BuildEnv("NotificationDecisionService");
local NotificationDispatchService = BuildEnv("NotificationDispatchService");
local NotificationOutputService = BuildEnv("NotificationOutputService");
local NotificationQueryService = BuildEnv("NotificationQueryService");
local NotificationTeamMessageService = BuildEnv("NotificationTeamMessageService");
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
    if NotificationDispatchService and NotificationDispatchService.SendAirdropSync then
        return NotificationDispatchService:SendAirdropSync(self, syncState);
    end
    return false;
end

function Notification:NotifyAirdropDetected(mapName, detectionSource, eventContext)
    if NotificationDispatchService and NotificationDispatchService.NotifyAirdropDetected then
        return NotificationDispatchService:NotifyAirdropDetected(self, mapName, detectionSource, eventContext);
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
    if NotificationTeamMessageService and NotificationTeamMessageService.NotifySharedPhaseSyncApplied then
        return NotificationTeamMessageService:NotifySharedPhaseSyncApplied(self, mapId, sharedRecord);
    end
    return false;
end

function Notification:SendSharedPhaseSyncAppliedTeamMessage(mapId, sharedRecord)
    if NotificationTeamMessageService and NotificationTeamMessageService.SendSharedPhaseSyncAppliedTeamMessage then
        return NotificationTeamMessageService:SendSharedPhaseSyncAppliedTeamMessage(self, mapId, sharedRecord);
    end
    return false;
end

function Notification:SendTimeRemainingTeamMessage(mapId)
    if NotificationTeamMessageService and NotificationTeamMessageService.SendTimeRemainingTeamMessage then
        return NotificationTeamMessageService:SendTimeRemainingTeamMessage(self, mapId);
    end
    return false;
end

function Notification:NotifyPhaseTeamAlert(mapName, previousPhaseID, currentPhaseID)
    if NotificationTeamMessageService and NotificationTeamMessageService.NotifyPhaseTeamAlert then
        return NotificationTeamMessageService:NotifyPhaseTeamAlert(self, mapName, previousPhaseID, currentPhaseID);
    end
    return false;
end

function Notification:SendTrajectoryPredictionTeamMessage(mapId, alertToken, objectGUID, endX, endY, eventTimestamp)
    if NotificationTeamMessageService and NotificationTeamMessageService.SendTrajectoryPredictionTeamMessage then
        return NotificationTeamMessageService:SendTrajectoryPredictionTeamMessage(self, mapId, alertToken, objectGUID, endX, endY, eventTimestamp);
    end
    return false;
end

function Notification:SendTrajectoryPredictionCandidatesTeamMessage(mapId, alertToken, objectGUID, candidates, eventTimestamp)
    if NotificationTeamMessageService and NotificationTeamMessageService.SendTrajectoryPredictionCandidatesTeamMessage then
        return NotificationTeamMessageService:SendTrajectoryPredictionCandidatesTeamMessage(self, mapId, alertToken, objectGUID, candidates, eventTimestamp);
    end
    return false;
end

function Notification:SendAutoTeamReport()
    if NotificationDispatchService and NotificationDispatchService.SendAutoTeamReport then
        return NotificationDispatchService:SendAutoTeamReport(self);
    end
    return false;
end

function Notification:NotifyMapRefresh(mapData, isAirdropActive, clickButton)
    if NotificationDispatchService and NotificationDispatchService.NotifyMapRefresh then
        return NotificationDispatchService:NotifyMapRefresh(self, mapData, isAirdropActive, clickButton);
    end
end
