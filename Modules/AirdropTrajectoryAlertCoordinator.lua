-- AirdropTrajectoryAlertCoordinator.lua - 轨迹预测团队提示协调与限流

local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local Notification = BuildEnv("Notification")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Data = BuildEnv("Data")
local AppSettingsStore = BuildEnv("AppSettingsStore")
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")

AirdropTrajectoryAlertCoordinator.MAX_VISIBLE_SENDERS = 3
AirdropTrajectoryAlertCoordinator.CLAIM_COLLECTION_DELAY = 0.35
AirdropTrajectoryAlertCoordinator.EVENT_TTL = 20
AirdropTrajectoryAlertCoordinator.FEATURE_ENABLED = true
AirdropTrajectoryAlertCoordinator.SETTING_KEY = "trajectoryPredictionTeamAlertEnabled"
AirdropTrajectoryAlertCoordinator.eventStateByKey = AirdropTrajectoryAlertCoordinator.eventStateByKey or {}

function AirdropTrajectoryAlertCoordinator:IsSettingEnabled()
    if AppSettingsStore and AppSettingsStore.GetBoolean then
        return AppSettingsStore:GetBoolean(self.SETTING_KEY, false)
    end
    local uiDB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    return uiDB[self.SETTING_KEY] == true
end

function AirdropTrajectoryAlertCoordinator:SetSettingEnabled(enabled)
    local normalized = enabled == true
    if AppSettingsStore and AppSettingsStore.SetBoolean then
        AppSettingsStore:SetBoolean(self.SETTING_KEY, normalized)
    else
        CRATETRACKERZK_UI_DB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
        CRATETRACKERZK_UI_DB[self.SETTING_KEY] = normalized
    end
    if normalized ~= true and self.Reset then
        self:Reset()
    end
    return normalized
end

function AirdropTrajectoryAlertCoordinator:IsFeatureEnabled()
    if self.FEATURE_ENABLED ~= true then
        return false
    end
    if self:IsSettingEnabled() ~= true then
        return false
    end
    if AirdropTrajectoryService
        and AirdropTrajectoryService.IsPredictionEnabled
        and AirdropTrajectoryService:IsPredictionEnabled() ~= true then
        return false
    end
    return true
end

local function NormalizeSenderKey(sender)
    if type(sender) ~= "string" or sender == "" then
        return nil
    end
    local normalized = sender
        :gsub("’", "'")
        :gsub("‘", "'")
        :gsub("＇", "'")
        :lower()
        :gsub("[%s%-%_'`]", "")
    if normalized == "" then
        return nil
    end
    return normalized
end

local function BuildEventKey(mapID, alertToken, objectGUID)
    return table.concat({
        tostring(mapID or "unknown"),
        tostring(alertToken or "unknown"),
        tostring(objectGUID or "unknown"),
    }, ":")
end

local function CancelEvaluationTimer(state)
    if type(state) ~= "table" then
        return
    end
    if state.evaluationTimer and state.evaluationTimer.Cancel then
        state.evaluationTimer:Cancel()
    end
    state.evaluationTimer = nil
end

local function CountVisibleSenders(state)
    if type(state) ~= "table" or type(state.visibleSenderKeys) ~= "table" then
        return 0
    end

    local count = 0
    for _ in pairs(state.visibleSenderKeys) do
        count = count + 1
    end
    return count
end

local function AcquireEventState(self, mapID, alertToken, objectGUID, mapName, currentTime)
    self.eventStateByKey = self.eventStateByKey or {}
    local eventKey = BuildEventKey(mapID, alertToken, objectGUID)
    local state = self.eventStateByKey[eventKey]
    if type(state) ~= "table" then
        state = {
            eventKey = eventKey,
            mapID = mapID,
            alertToken = alertToken,
            objectGUID = objectGUID,
            mapName = mapName,
            predictedEndX = nil,
            predictedEndY = nil,
            candidateRoutes = nil,
            alertMode = nil,
            createdAt = currentTime,
            lastSeenAt = currentTime,
            claimsBySenderKey = {},
            visibleSenderKeys = {},
            localSenderKey = nil,
            localSenderName = nil,
            visibleAlertSent = false,
            evaluationTimer = nil,
        }
        self.eventStateByKey[eventKey] = state
    else
        state.mapName = mapName or state.mapName
        state.lastSeenAt = currentTime or state.lastSeenAt
    end
    return state
end

local function UpsertClaim(state, senderName, claimTime, currentTime)
    if type(state) ~= "table" then
        return nil
    end

    local senderKey = NormalizeSenderKey(senderName)
    if not senderKey then
        return nil
    end

    local resolvedClaimTime = tonumber(claimTime) or currentTime or Utils:GetCurrentTimestamp()
    local claim = state.claimsBySenderKey[senderKey]
    if type(claim) ~= "table" then
        claim = {
            senderName = senderName,
            claimTime = resolvedClaimTime,
        }
        state.claimsBySenderKey[senderKey] = claim
    else
        claim.senderName = senderName or claim.senderName
        if type(claim.claimTime) ~= "number" or resolvedClaimTime < claim.claimTime then
            claim.claimTime = resolvedClaimTime
        end
    end

    state.lastSeenAt = currentTime or state.lastSeenAt
    return senderKey
end

local function MarkVisibleSender(state, senderName, currentTime)
    if type(state) ~= "table" then
        return nil
    end

    local senderKey = NormalizeSenderKey(senderName)
    if not senderKey then
        return nil
    end

    state.visibleSenderKeys = state.visibleSenderKeys or {}
    state.visibleSenderKeys[senderKey] = true
    state.lastSeenAt = currentTime or state.lastSeenAt
    return senderKey
end

local function BuildSortedClaims(state)
    local claims = {}
    if type(state) ~= "table" or type(state.claimsBySenderKey) ~= "table" then
        return claims
    end

    for senderKey, claim in pairs(state.claimsBySenderKey) do
        claims[#claims + 1] = {
            senderKey = senderKey,
            claimTime = type(claim) == "table" and tonumber(claim.claimTime) or nil,
        }
    end

    table.sort(claims, function(left, right)
        local leftTime = left.claimTime or math.huge
        local rightTime = right.claimTime or math.huge
        if leftTime == rightTime then
            return left.senderKey < right.senderKey
        end
        return leftTime < rightTime
    end)

    return claims
end

local function GetLocalSenderName()
    if TeamCommMapCache and TeamCommMapCache.EnsurePlayerIdentity then
        TeamCommMapCache:EnsurePlayerIdentity(TeamSharedSyncListener)
    end
    return TeamSharedSyncListener and (TeamSharedSyncListener.fullPlayerName or TeamSharedSyncListener.playerName) or UnitName("player")
end

local function ResolveCoordinationContext()
    if AirdropTrajectoryAlertCoordinator
        and AirdropTrajectoryAlertCoordinator.IsFeatureEnabled
        and AirdropTrajectoryAlertCoordinator:IsFeatureEnabled() ~= true then
        return nil, "feature_disabled"
    end
    if not Notification
        or not Notification.IsTeamNotificationEnabled
        or Notification:IsTeamNotificationEnabled() ~= true then
        return nil, "team_notification_disabled"
    end
    if not TeamSharedSyncListener
        or not TeamSharedSyncListener.CanSendSharedSync
        or TeamSharedSyncListener:CanSendSharedSync() ~= true then
        return nil, "shared_sync_unavailable"
    end

    local teamChatType = Notification.GetTeamChatType and Notification:GetTeamChatType() or nil
    if type(teamChatType) ~= "string" or teamChatType == "" then
        return nil, "team_chat_type_unavailable"
    end

    local visibleChatType = NotificationOutputService
        and NotificationOutputService.GetStandardVisibleChatType
        and NotificationOutputService:GetStandardVisibleChatType(teamChatType)
        or nil
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return nil, "visible_chat_type_unavailable"
    end

    return {
        teamChatType = teamChatType,
        visibleChatType = visibleChatType,
    }, nil
end

local function BuildTrajectoryAlertSyncState(state)
    return {
        mapID = state and state.mapID or nil,
        alertToken = state and state.alertToken or nil,
        objectGUID = state and state.objectGUID or nil,
        timestamp = state and state.createdAt or nil,
    }
end

local function ResolveMapName(mapID)
    if type(mapID) ~= "number" then
        return tostring(mapID)
    end
    if Data and Data.GetMapByMapID then
        local mapData = Data:GetMapByMapID(mapID)
        if mapData and Data.GetMapDisplayName then
            return Data:GetMapDisplayName(mapData)
        end
    end
    if Data and Data.GetMapDisplayName then
        return Data:GetMapDisplayName({ mapID = mapID })
    end
    return tostring(mapID)
end

local function FindExistingCandidateStateForObject(self, mapID, objectGUID)
    if type(self) ~= "table"
        or type(mapID) ~= "number"
        or type(objectGUID) ~= "string"
        or objectGUID == ""
        or type(self.eventStateByKey) ~= "table" then
        return nil
    end

    for _, state in pairs(self.eventStateByKey) do
        if type(state) == "table"
            and state.alertMode == "candidates"
            and tonumber(state.mapID) == mapID
            and state.objectGUID == objectGUID then
            return state
        end
    end
    return nil
end

local function RecordCoordinationTrace(state, eventType, note)
    if type(state) ~= "table"
        or type(eventType) ~= "string"
        or eventType == ""
        or not AirdropTrajectoryService
        or not AirdropTrajectoryService.RecordTraceEvent then
        return false
    end

    local traceKey = table.concat({
        tostring(eventType),
        tostring(state.alertMode or ""),
        tostring(note or ""),
    }, "|")
    if state.lastCoordinationTraceKey == traceKey then
        return false
    end
    state.lastCoordinationTraceKey = traceKey

    AirdropTrajectoryService:RecordTraceEvent({
        recordedAt = Utils:GetCurrentTimestamp(),
        eventType = eventType,
        mapName = state.mapName,
        mapID = state.mapID,
        objectGUID = state.objectGUID,
        sourceObjectGUID = state.objectGUID,
        routeKey = state.alertToken,
        note = note,
    })
    return true
end

function AirdropTrajectoryAlertCoordinator:Reset()
    self.eventStateByKey = self.eventStateByKey or {}
    for eventKey, state in pairs(self.eventStateByKey) do
        CancelEvaluationTimer(state)
        self.eventStateByKey[eventKey] = nil
    end
end

function AirdropTrajectoryAlertCoordinator:PruneExpiredState(currentTime)
    self.eventStateByKey = self.eventStateByKey or {}
    local now = currentTime or Utils:GetCurrentTimestamp()
    local removedCount = 0
    for eventKey, state in pairs(self.eventStateByKey) do
        local lastSeenAt = type(state) == "table" and tonumber(state.lastSeenAt) or nil
        if type(state) ~= "table"
            or type(lastSeenAt) ~= "number"
            or (now - lastSeenAt) > (self.EVENT_TTL or 20) then
            CancelEvaluationTimer(state)
            self.eventStateByKey[eventKey] = nil
            removedCount = removedCount + 1
        end
    end
    return removedCount
end

function AirdropTrajectoryAlertCoordinator:EvaluateVisibleSend(eventKey)
    if self:IsFeatureEnabled() ~= true then
        return false, "feature_disabled"
    end
    local state = self.eventStateByKey and self.eventStateByKey[eventKey] or nil
    if type(state) ~= "table" then
        return false, "state_missing"
    end
    if type(state.localSenderKey) ~= "string" or state.localSenderKey == "" then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "local_sender_missing")
        return false, "local_sender_missing"
    end
    if state.visibleSenderKeys and state.visibleSenderKeys[state.localSenderKey] == true then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "already_visible")
        return false, "already_visible"
    end
    if CountVisibleSenders(state) >= (self.MAX_VISIBLE_SENDERS or 1) then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "visible_sender_limit_reached")
        return false, "visible_sender_limit_reached"
    end

    local localRank = nil
    for index, claim in ipairs(BuildSortedClaims(state)) do
        if claim.senderKey == state.localSenderKey then
            localRank = index
            break
        end
    end
    if not localRank or localRank > (self.MAX_VISIBLE_SENDERS or 1) then
        RecordCoordinationTrace(
            state,
            "prediction_coordination_skip",
            string.format("local_rank_exceeded rank=%s max=%d", tostring(localRank or "nil"), (self.MAX_VISIBLE_SENDERS or 1))
        )
        return false, "local_rank_exceeded"
    end

    local visibleSent = Notification
        and (
            (state.alertMode == "candidates"
                and Notification.SendTrajectoryPredictionCandidatesTeamMessage
                and Notification:SendTrajectoryPredictionCandidatesTeamMessage(
                    state.mapID,
                    state.alertToken,
                    state.objectGUID,
                    state.candidateRoutes,
                    state.createdAt
                ) == true)
            or (state.alertMode ~= "candidates"
                and Notification.SendTrajectoryPredictionTeamMessage
                and Notification:SendTrajectoryPredictionTeamMessage(
                    state.mapID,
                    state.alertToken,
                    state.objectGUID,
                    state.predictedEndX,
                    state.predictedEndY,
                    state.createdAt
                ) == true)
        )
        or false
    if visibleSent ~= true then
        RecordCoordinationTrace(
            state,
            "prediction_coordination_skip",
            string.format("team_message_send_failed mode=%s rank=%d", tostring(state.alertMode or "prediction"), localRank)
        )
        return false, "team_message_send_failed"
    end

    state.visibleAlertSent = true
    MarkVisibleSender(state, state.localSenderName, Utils:GetCurrentTimestamp())
    RecordCoordinationTrace(
        state,
        "prediction_coordination_sent",
        string.format("mode=%s rank=%d", tostring(state.alertMode or "prediction"), localRank)
    )

    local syncState = BuildTrajectoryAlertSyncState(state)
    if TeamSharedSyncListener and TeamSharedSyncListener.SendTrajectoryAlertAck then
        TeamSharedSyncListener:SendTrajectoryAlertAck(syncState)
    end
    return true, "sent"
end

function AirdropTrajectoryAlertCoordinator:ScheduleLocalEvaluation(state)
    if type(state) ~= "table" then
        return false
    end
    if state.evaluationTimer then
        return true
    end

    local delay = tonumber(self.CLAIM_COLLECTION_DELAY) or 0.35
    state.evaluationTimer = C_Timer.NewTimer(delay, function()
        state.evaluationTimer = nil
        self:EvaluateVisibleSend(state.eventKey)
    end)
    return true
end

function AirdropTrajectoryAlertCoordinator:HandleLocalPredictionMatched(targetMapData, route, objectGUID, detectedAt)
    if self:IsFeatureEnabled() ~= true then
        return false, "feature_disabled"
    end
    if type(targetMapData) ~= "table"
        or type(targetMapData.mapID) ~= "number"
        or type(route) ~= "table"
        or type(route.alertToken) ~= "string"
        or route.alertToken == ""
        or type(objectGUID) ~= "string"
        or objectGUID == "" then
        return false, "invalid_args"
    end

    local coordinationContext, coordinationReason = ResolveCoordinationContext()
    if not coordinationContext then
        return false, coordinationReason or "coordination_unavailable"
    end

    local now = tonumber(detectedAt) or Utils:GetCurrentTimestamp()
    self:PruneExpiredState(now)

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID)
    local state = AcquireEventState(self, targetMapData.mapID, route.alertToken, objectGUID, mapName, now)
    if CountVisibleSenders(state) >= (self.MAX_VISIBLE_SENDERS or 1) then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "visible_sender_limit_reached")
        return false, "visible_sender_limit_reached"
    end

    state.predictedEndX = route.endX
    state.predictedEndY = route.endY
    state.candidateRoutes = nil
    state.alertMode = "prediction"

    local localSenderName = GetLocalSenderName()
    local localSenderKey = UpsertClaim(state, localSenderName, now, now)
    if not localSenderKey then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "local_sender_invalid")
        return false, "local_sender_invalid"
    end

    state.localSenderKey = localSenderKey
    state.localSenderName = localSenderName

    local syncState = BuildTrajectoryAlertSyncState(state)
    if TeamSharedSyncListener and TeamSharedSyncListener.SendTrajectoryAlertClaim then
        TeamSharedSyncListener:SendTrajectoryAlertClaim(syncState)
    end

    self:ScheduleLocalEvaluation(state)
    RecordCoordinationTrace(state, "prediction_coordination_queued", "mode=prediction")
    return true, "queued"
end

function AirdropTrajectoryAlertCoordinator:HandleLocalPredictionCandidates(targetMapData, syntheticAlertToken, objectGUID, candidateRoutes, detectedAt)
    if self:IsFeatureEnabled() ~= true then
        return false, "feature_disabled"
    end
    if type(targetMapData) ~= "table"
        or type(targetMapData.mapID) ~= "number"
        or type(syntheticAlertToken) ~= "string"
        or syntheticAlertToken == ""
        or type(objectGUID) ~= "string"
        or objectGUID == ""
        or type(candidateRoutes) ~= "table"
        or #candidateRoutes ~= 2 then
        return false, "invalid_args"
    end

    local coordinationContext, coordinationReason = ResolveCoordinationContext()
    if not coordinationContext then
        return false, coordinationReason or "coordination_unavailable"
    end

    local now = tonumber(detectedAt) or Utils:GetCurrentTimestamp()
    self:PruneExpiredState(now)

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID)
    local existingCandidateState = FindExistingCandidateStateForObject(self, targetMapData.mapID, objectGUID)
    if type(existingCandidateState) == "table" then
        if existingCandidateState.visibleAlertSent == true then
            RecordCoordinationTrace(existingCandidateState, "prediction_coordination_skip", "candidate_event_already_visible")
            return false, "candidate_event_already_visible"
        end
        if existingCandidateState.evaluationTimer
            or (type(existingCandidateState.localSenderKey) == "string" and existingCandidateState.localSenderKey ~= "") then
            RecordCoordinationTrace(existingCandidateState, "prediction_coordination_skip", "candidate_event_already_queued")
            return false, "candidate_event_already_queued"
        end
    end

    local state = AcquireEventState(self, targetMapData.mapID, syntheticAlertToken, objectGUID, mapName, now)
    if CountVisibleSenders(state) >= (self.MAX_VISIBLE_SENDERS or 3) then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "visible_sender_limit_reached")
        return false, "visible_sender_limit_reached"
    end

    state.predictedEndX = nil
    state.predictedEndY = nil
    state.candidateRoutes = {
        {
            endX = candidateRoutes[1].endX,
            endY = candidateRoutes[1].endY,
        },
        {
            endX = candidateRoutes[2].endX,
            endY = candidateRoutes[2].endY,
        },
    }
    state.alertMode = "candidates"

    local localSenderName = GetLocalSenderName()
    local localSenderKey = UpsertClaim(state, localSenderName, now, now)
    if not localSenderKey then
        RecordCoordinationTrace(state, "prediction_coordination_skip", "local_sender_invalid")
        return false, "local_sender_invalid"
    end

    state.localSenderKey = localSenderKey
    state.localSenderName = localSenderName

    local syncState = BuildTrajectoryAlertSyncState(state)
    if TeamSharedSyncListener and TeamSharedSyncListener.SendTrajectoryAlertClaim then
        TeamSharedSyncListener:SendTrajectoryAlertClaim(syncState)
    end

    self:ScheduleLocalEvaluation(state)
    RecordCoordinationTrace(state, "prediction_coordination_queued", "mode=candidates")
    return true, "queued"
end

function AirdropTrajectoryAlertCoordinator:HandleRemoteCoordination(syncState, sender)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if type(syncState) ~= "table" then
        return false
    end

    local messageType = syncState.messageType
    if messageType ~= "TRAJECTORY_ALERT_CLAIM" and messageType ~= "TRAJECTORY_ALERT_ACK" then
        return false
    end
    if type(syncState.mapID) ~= "number"
        or type(syncState.alertToken) ~= "string"
        or syncState.alertToken == ""
        or type(syncState.objectGUID) ~= "string"
        or syncState.objectGUID == "" then
        return false
    end
    if TeamCommMapCache and TeamCommMapCache.IsSelfSender and TeamCommMapCache:IsSelfSender(TeamSharedSyncListener, sender) then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    self:PruneExpiredState(now)

    local mapName = ResolveMapName(syncState.mapID)
    local state = AcquireEventState(self, syncState.mapID, syncState.alertToken, syncState.objectGUID, mapName, now)
    if messageType == "TRAJECTORY_ALERT_CLAIM" then
        UpsertClaim(state, sender, syncState.timestamp, now)
        return true
    end

    MarkVisibleSender(state, sender, now)
    return true
end

return AirdropTrajectoryAlertCoordinator
