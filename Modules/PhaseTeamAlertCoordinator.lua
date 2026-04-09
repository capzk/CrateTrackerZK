-- PhaseTeamAlertCoordinator.lua - 位面团队提醒协调与限流

local PhaseTeamAlertCoordinator = BuildEnv("PhaseTeamAlertCoordinator")
local TeamCommListener = BuildEnv("TeamCommListener")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local Notification = BuildEnv("Notification")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Data = BuildEnv("Data")

PhaseTeamAlertCoordinator.MAX_VISIBLE_SENDERS = 2
PhaseTeamAlertCoordinator.CLAIM_COLLECTION_DELAY = 0.6
PhaseTeamAlertCoordinator.EVENT_TTL = 20
PhaseTeamAlertCoordinator.eventStateByKey = PhaseTeamAlertCoordinator.eventStateByKey or {}

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

function PhaseTeamAlertCoordinator:Reset()
    self.eventStateByKey = self.eventStateByKey or {}
    for eventKey, state in pairs(self.eventStateByKey) do
        CancelEvaluationTimer(state)
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
            self.eventStateByKey[eventKey] = nil
            removedCount = removedCount + 1
        end
    end
    return removedCount
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

    MarkVisibleSender(state, state.localSenderName, Utils:GetCurrentTimestamp())

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

return PhaseTeamAlertCoordinator
