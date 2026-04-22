-- PhaseTeamAlertCoordinator.lua - 位面团队提醒协调与限流

local PhaseTeamAlertCoordinator = BuildEnv("PhaseTeamAlertCoordinator")
local TeamCommListener = BuildEnv("TeamCommListener")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local Notification = BuildEnv("Notification")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")

PhaseTeamAlertCoordinator.MAX_VISIBLE_SENDERS = 2
PhaseTeamAlertCoordinator.CLAIM_COLLECTION_DELAY = 0.6
PhaseTeamAlertCoordinator.EVENT_TTL = 20
PhaseTeamAlertCoordinator.SHARED_FOLLOWUP_DELAY = 0.5
PhaseTeamAlertCoordinator.REMAINING_FOLLOWUP_DELAY = 0.8
PhaseTeamAlertCoordinator.eventStateByKey = PhaseTeamAlertCoordinator.eventStateByKey or {}
PhaseTeamAlertCoordinator.phaseAlertGuardBuffers = PhaseTeamAlertCoordinator.phaseAlertGuardBuffers or {}
PhaseTeamAlertCoordinator.sharedRecordBuffer = PhaseTeamAlertCoordinator.sharedRecordBuffer or {}

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

local function BuildEventKey(expansionID, mapID, phaseID)
    return table.concat({
        tostring(expansionID or "default"),
        tostring(mapID or "unknown"),
        tostring(phaseID or "unknown"),
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

local function CancelFollowupTimer(state)
    if type(state) ~= "table" then
        return
    end
    if state.followupTimer and state.followupTimer.Cancel then
        state.followupTimer:Cancel()
    end
    state.followupTimer = nil
    state.followupStage = nil
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

local function AcquireEventState(self, expansionID, mapID, phaseID, mapName, currentTime)
    self.eventStateByKey = self.eventStateByKey or {}
    local eventKey = BuildEventKey(expansionID, mapID, phaseID)
    local state = self.eventStateByKey[eventKey]
    if type(state) ~= "table" then
        state = {
            eventKey = eventKey,
            expansionID = expansionID,
            mapID = mapID,
            phaseID = phaseID,
            previousPhaseID = nil,
            currentPhaseID = phaseID,
            mapName = mapName,
            createdAt = currentTime,
            lastSeenAt = currentTime,
            claimsBySenderKey = {},
            visibleSenderKeys = {},
            localSenderKey = nil,
            localSenderName = nil,
            runtimeMapId = nil,
            sharedRecord = nil,
            visiblePhaseAlertSent = false,
            sharedFollowupSent = false,
            followupStage = nil,
            followupTimer = nil,
            evaluationTimer = nil,
        }
        self.eventStateByKey[eventKey] = state
    else
        state.mapName = mapName or state.mapName
        state.currentPhaseID = phaseID or state.currentPhaseID
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
        TeamCommMapCache:EnsurePlayerIdentity(TeamCommListener)
    end
    return TeamCommListener and (TeamCommListener.fullPlayerName or TeamCommListener.playerName) or UnitName("player")
end

local function ResolveCoordinationContext()
    if not Notification
        or not Notification.IsPhaseTeamAlertEnabled
        or Notification:IsPhaseTeamAlertEnabled() ~= true
        or not Notification.IsTeamNotificationEnabled
        or Notification:IsTeamNotificationEnabled() ~= true then
        return nil
    end
    if not TeamCommListener
        or not TeamCommListener.CanEnableHiddenSync
        or TeamCommListener:CanEnableHiddenSync() ~= true then
        return nil
    end

    local teamChatType = Notification.GetTeamChatType and Notification:GetTeamChatType() or nil
    if type(teamChatType) ~= "string" or teamChatType == "" then
        return nil
    end

    local visibleChatType = NotificationOutputService
        and NotificationOutputService.GetAutomaticVisibleChatType
        and NotificationOutputService:GetAutomaticVisibleChatType(teamChatType)
        or nil
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return nil
    end

    return {
        teamChatType = teamChatType,
        visibleChatType = visibleChatType,
    }
end

local function BuildPhaseAlertSyncState(targetMapData, phaseID, timestamp)
    return {
        expansionID = targetMapData and targetMapData.expansionID or nil,
        mapID = targetMapData and targetMapData.mapID or nil,
        phaseID = phaseID,
        timestamp = timestamp,
    }
end

local function CopySharedRecordInto(outRecord, sharedRecord)
    if type(outRecord) ~= "table" or type(sharedRecord) ~= "table" then
        return nil
    end
    outRecord.expansionID = sharedRecord.expansionID
    outRecord.mapID = sharedRecord.mapID
    outRecord.phaseID = sharedRecord.phaseID
    outRecord.timestamp = sharedRecord.timestamp
    outRecord.objectGUID = sharedRecord.objectGUID
    outRecord.source = sharedRecord.source
    outRecord.sender = sharedRecord.sender
    outRecord.receivedAt = sharedRecord.receivedAt
    outRecord.expiresAt = sharedRecord.expiresAt
    outRecord.recordKey = sharedRecord.recordKey
    return outRecord
end

local function EnsureSharedRecordForSequence(self, state)
    if type(self) ~= "table" or type(state) ~= "table" then
        return nil
    end
    if type(state.sharedRecord) == "table" then
        return state.sharedRecord
    end
    if type(state.runtimeMapId) ~= "number" then
        return nil
    end

    self.sharedRecordBuffer = self.sharedRecordBuffer or {}
    local sharedRecord = UnifiedDataManager
        and UnifiedDataManager.GetSharedPhaseTimeRecordInto
        and UnifiedDataManager:GetSharedPhaseTimeRecordInto(
            state.runtimeMapId,
            state.currentPhaseID or state.phaseID,
            self.sharedRecordBuffer
        )
        or nil
    if type(sharedRecord) ~= "table" then
        return nil
    end

    state.sharedRecord = CopySharedRecordInto(state.sharedRecord or {}, sharedRecord)
    return state.sharedRecord
end

function PhaseTeamAlertCoordinator:Reset()
    self.eventStateByKey = self.eventStateByKey or {}
    for eventKey, state in pairs(self.eventStateByKey) do
        CancelEvaluationTimer(state)
        CancelFollowupTimer(state)
        self.eventStateByKey[eventKey] = nil
    end
end

function PhaseTeamAlertCoordinator:PruneExpiredState(currentTime)
    self.eventStateByKey = self.eventStateByKey or {}
    local now = currentTime or Utils:GetCurrentTimestamp()
    local removedCount = 0
    for eventKey, state in pairs(self.eventStateByKey) do
        local lastSeenAt = type(state) == "table" and tonumber(state.lastSeenAt) or nil
        if type(state) ~= "table"
            or type(lastSeenAt) ~= "number"
            or (now - lastSeenAt) > (self.EVENT_TTL or 20) then
            CancelEvaluationTimer(state)
            CancelFollowupTimer(state)
            self.eventStateByKey[eventKey] = nil
            removedCount = removedCount + 1
        end
    end
    return removedCount
end

function PhaseTeamAlertCoordinator:ExecuteSharedFollowupStep(state, stage)
    if type(state) ~= "table" or type(stage) ~= "string" then
        return false
    end
    if type(state.runtimeMapId) ~= "number" or state.visiblePhaseAlertSent ~= true then
        CancelFollowupTimer(state)
        return false
    end

    state.followupTimer = nil
    state.followupStage = nil

    if stage == "shared" then
        local sharedSent = Notification
            and Notification.SendSharedPhaseSyncAppliedTeamMessage
            and Notification:SendSharedPhaseSyncAppliedTeamMessage(state.runtimeMapId, state.sharedRecord) == true
            or false
        if sharedSent ~= true then
            return false
        end
        return self:ScheduleSharedFollowupStep(
            state,
            "remaining",
            self.REMAINING_FOLLOWUP_DELAY or 0.8
        )
    end

    if stage == "remaining" then
        local remainingSent = Notification
            and Notification.SendTimeRemainingTeamMessage
            and Notification:SendTimeRemainingTeamMessage(state.runtimeMapId) == true
            or false
        if remainingSent == true then
            state.sharedFollowupSent = true
        end
        return remainingSent == true
    end

    return false
end

function PhaseTeamAlertCoordinator:ScheduleSharedFollowupStep(state, stage, delaySeconds)
    if type(state) ~= "table" or type(stage) ~= "string" or stage == "" then
        return false
    end
    if state.sharedFollowupSent == true then
        return false
    end
    if state.followupTimer or state.followupStage then
        return true
    end

    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then
        delay = 0
    end

    state.followupStage = stage
    if C_Timer and C_Timer.NewTimer then
        state.followupTimer = C_Timer.NewTimer(delay, function()
            self:ExecuteSharedFollowupStep(state, stage)
        end)
        return true
    end

    if C_Timer and C_Timer.After then
        state.followupTimer = {}
        C_Timer.After(delay, function()
            self:ExecuteSharedFollowupStep(state, stage)
        end)
        return true
    end

    return self:ExecuteSharedFollowupStep(state, stage)
end

function PhaseTeamAlertCoordinator:TrySendSharedFollowup(state)
    if type(state) ~= "table" or state.sharedFollowupSent == true or state.visiblePhaseAlertSent ~= true then
        return false
    end
    if type(state.runtimeMapId) ~= "number" then
        return false
    end

    local sharedRecord = EnsureSharedRecordForSequence(self, state)
    if type(sharedRecord) ~= "table" then
        return false
    end

    return self:ScheduleSharedFollowupStep(
        state,
        "shared",
        self.SHARED_FOLLOWUP_DELAY or 0.5
    )
end

function PhaseTeamAlertCoordinator:EvaluateVisibleSend(eventKey)
    local state = self.eventStateByKey and self.eventStateByKey[eventKey] or nil
    if type(state) ~= "table" then
        return false
    end

    if type(state.localSenderKey) ~= "string" or state.localSenderKey == "" then
        return false
    end
    if state.visibleSenderKeys and state.visibleSenderKeys[state.localSenderKey] == true then
        return false
    end
    if CountVisibleSenders(state) >= (self.MAX_VISIBLE_SENDERS or 2) then
        return false
    end

    local localRank = nil
    for index, claim in ipairs(BuildSortedClaims(state)) do
        if claim.senderKey == state.localSenderKey then
            localRank = index
            break
        end
    end
    if not localRank or localRank > (self.MAX_VISIBLE_SENDERS or 2) then
        return false
    end

    local visibleSent = Notification
        and Notification.NotifyPhaseTeamAlert
        and Notification:NotifyPhaseTeamAlert(state.mapName, state.previousPhaseID, state.currentPhaseID or state.phaseID) == true
        or false
    if visibleSent ~= true then
        return false
    end

    state.visiblePhaseAlertSent = true

    MarkVisibleSender(state, state.localSenderName, Utils:GetCurrentTimestamp())
    self:TrySendSharedFollowup(state)

    local syncState = BuildPhaseAlertSyncState(state, state.phaseID, state.createdAt)
    local teamChatType = Notification and Notification.GetTeamChatType and Notification:GetTeamChatType() or nil
    if TeamCommListener and TeamCommListener.SendPhaseAlertAck then
        TeamCommListener:SendPhaseAlertAck(syncState, teamChatType)
    end
    return true
end

function PhaseTeamAlertCoordinator:ScheduleLocalEvaluation(state)
    if type(state) ~= "table" then
        return false
    end
    if state.evaluationTimer then
        return true
    end

    local delay = tonumber(self.CLAIM_COLLECTION_DELAY) or 0.6
    state.evaluationTimer = C_Timer.NewTimer(delay, function()
        state.evaluationTimer = nil
        self:EvaluateVisibleSend(state.eventKey)
    end)
    return true
end

function PhaseTeamAlertCoordinator:HandleLocalPhaseDetected(targetMapData, previousPhaseID, historicalPhaseID, currentPhaseID)
    if type(targetMapData) ~= "table"
        or type(targetMapData.expansionID) ~= "string"
        or type(targetMapData.mapID) ~= "number"
        or type(currentPhaseID) ~= "string"
        or currentPhaseID == "" then
        return false
    end

    self.phaseAlertGuardBuffers = self.phaseAlertGuardBuffers or {}
    local shouldSuppress = UnifiedDataManager
        and UnifiedDataManager.ShouldSuppressPhaseTeamAlert
        and UnifiedDataManager:ShouldSuppressPhaseTeamAlert(
            targetMapData.id,
            currentPhaseID,
            self.phaseAlertGuardBuffers
        ) == true
    if shouldSuppress then
        return false
    end

    local coordinationContext = ResolveCoordinationContext()
    if not coordinationContext then
        return false
    end

    local baselinePhaseID = nil
    if type(previousPhaseID) == "string" and previousPhaseID ~= "" and previousPhaseID ~= currentPhaseID then
        baselinePhaseID = previousPhaseID
    elseif type(historicalPhaseID) == "string" and historicalPhaseID ~= "" and historicalPhaseID ~= currentPhaseID then
        baselinePhaseID = historicalPhaseID
    end

    if type(baselinePhaseID) ~= "string" or baselinePhaseID == "" then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    self:PruneExpiredState(now)

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID)
    local state = AcquireEventState(self, targetMapData.expansionID, targetMapData.mapID, currentPhaseID, mapName, now)
    if CountVisibleSenders(state) >= (self.MAX_VISIBLE_SENDERS or 2) then
        return false
    end

    state.previousPhaseID = baselinePhaseID
    state.currentPhaseID = currentPhaseID
    state.phaseID = currentPhaseID
    state.runtimeMapId = targetMapData.id
    state.sharedRecord = nil
    state.visiblePhaseAlertSent = false
    state.sharedFollowupSent = false
    CancelFollowupTimer(state)

    local localSenderName = GetLocalSenderName()
    local localSenderKey = UpsertClaim(state, localSenderName, now, now)
    if not localSenderKey then
        return false
    end

    state.localSenderKey = localSenderKey
    state.localSenderName = localSenderName

    local syncState = BuildPhaseAlertSyncState(targetMapData, currentPhaseID, now)
    if TeamCommListener and TeamCommListener.SendPhaseAlertClaim then
        TeamCommListener:SendPhaseAlertClaim(syncState, coordinationContext.teamChatType)
    end

    self:ScheduleLocalEvaluation(state)
    return true
end

function PhaseTeamAlertCoordinator:HandleRemoteCoordination(listener, syncState, sender)
    if type(syncState) ~= "table" then
        return false
    end
    if not Notification
        or not Notification.IsPhaseTeamAlertEnabled
        or Notification:IsPhaseTeamAlertEnabled() ~= true
        or not Notification.IsTeamNotificationEnabled
        or Notification:IsTeamNotificationEnabled() ~= true then
        return false
    end

    local messageType = syncState.messageType
    if messageType ~= "PHASE_CLAIM" and messageType ~= "PHASE_ACK" then
        return false
    end

    local mapData = Data
        and Data.GetMapByMapID
        and Data:GetMapByMapID(syncState.mapID, syncState.expansionID)
        or nil
    if not mapData then
        return false
    end

    if TeamCommMapCache and TeamCommMapCache.IsSelfSender and TeamCommMapCache:IsSelfSender(listener, sender) then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    self:PruneExpiredState(now)

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(syncState.mapID)
    local state = AcquireEventState(self, syncState.expansionID, syncState.mapID, syncState.phaseID, mapName, now)
    if messageType == "PHASE_CLAIM" then
        UpsertClaim(state, sender, syncState.timestamp, now)
        return true
    end

    MarkVisibleSender(state, sender, now)
    return true
end

function PhaseTeamAlertCoordinator:HandleSharedDisplayActivated(mapId, sharedRecord)
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" then
        return false
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil
    if type(mapData) ~= "table"
        or type(mapData.expansionID) ~= "string"
        or type(mapData.mapID) ~= "number"
        or type(sharedRecord.phaseID) ~= "string"
        or sharedRecord.phaseID == "" then
        return false
    end

    local eventKey = BuildEventKey(mapData.expansionID, mapData.mapID, sharedRecord.phaseID)
    local state = self.eventStateByKey and self.eventStateByKey[eventKey] or nil
    if type(state) ~= "table" then
        return false
    end

    state.runtimeMapId = mapId
    state.lastSeenAt = Utils:GetCurrentTimestamp()
    state.sharedRecord = CopySharedRecordInto(state.sharedRecord or {}, sharedRecord)
    if state.visiblePhaseAlertSent == true then
        return self:TrySendSharedFollowup(state)
    end
    if state.evaluationTimer then
        return true
    end
    return self:EvaluateVisibleSend(state.eventKey)
end

return PhaseTeamAlertCoordinator
