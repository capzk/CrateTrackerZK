-- TeamSharedWarmupService.lua - 团队备用共享缓存低频预热广播
-- 注意：本服务只广播运行时备用缓存候选数据，不写长期持久化，也不影响主 CTKZK_SYNC。

local TeamSharedWarmupService = BuildEnv("TeamSharedWarmupService")

local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local Data = BuildEnv("Data")
local IconDetector = BuildEnv("IconDetector")
local SharedSyncSchedulerHelpers = BuildEnv("SharedSyncSchedulerHelpers")
local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")
local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local TeamSharedSyncStore = BuildEnv("TeamSharedSyncStore")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")

TeamSharedWarmupService.FEATURE_ENABLED = true
TeamSharedWarmupService.BROADCAST_INTERVAL = 540
TeamSharedWarmupService.SEND_INTERVAL = 1
TeamSharedWarmupService.REQUEST_COOLDOWN = 15
TeamSharedWarmupService.REQUEST_ACCEPT_WINDOW = 30
TeamSharedWarmupService.REQUEST_RESPONSE_JITTER_MIN = 0.35
TeamSharedWarmupService.REQUEST_RESPONSE_JITTER_MAX = 1.10
TeamSharedWarmupService.REQUEST_RESPONSE_STATE_TTL = 60
TeamSharedWarmupService.REQUEST_MAX_FUTURE_OFFSET = 10

TeamSharedWarmupService.broadcastQueue = TeamSharedWarmupService.broadcastQueue or {}
TeamSharedWarmupService.broadcastTimer = TeamSharedWarmupService.broadcastTimer or nil
TeamSharedWarmupService.broadcastIndex = TeamSharedWarmupService.broadcastIndex or 0
TeamSharedWarmupService.sharedRecordBuffer = TeamSharedWarmupService.sharedRecordBuffer or {}
TeamSharedWarmupService.candidateByKeyBuffer = TeamSharedWarmupService.candidateByKeyBuffer or {}
TeamSharedWarmupService.persistentStateBuffer = TeamSharedWarmupService.persistentStateBuffer or {}
TeamSharedWarmupService.lastTeamChannelReady = TeamSharedWarmupService.lastTeamChannelReady or false
TeamSharedWarmupService.lastSyncRequestAt = TeamSharedWarmupService.lastSyncRequestAt or 0
TeamSharedWarmupService.requestSequence = TeamSharedWarmupService.requestSequence or 0
TeamSharedWarmupService.pendingResponseTimer = TeamSharedWarmupService.pendingResponseTimer or nil
TeamSharedWarmupService.requestResponseStateByKey = TeamSharedWarmupService.requestResponseStateByKey or {}
TeamSharedWarmupService.pendingFollowupBroadcast = TeamSharedWarmupService.pendingFollowupBroadcast or false
TeamSharedWarmupService.lastTeamContextKey = TeamSharedWarmupService.lastTeamContextKey or nil

local function ClearArray(buffer)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ClearArray then
        return SharedSyncSchedulerHelpers:ClearArray(buffer)
    end
    return {}
end

local function ClearMap(buffer)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ClearMap then
        return SharedSyncSchedulerHelpers:ClearMap(buffer)
    end
    return {}
end

local function BuildRequestResponseKey(sender, requestID)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.BuildRequestKey then
        return SharedSyncSchedulerHelpers:BuildRequestKey(sender, requestID)
    end
    return tostring(sender or "unknown") .. ":" .. tostring(requestID or "unknown")
end

local function NormalizeJitterDelay(minDelay, maxDelay)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.NormalizeJitterDelay then
        return SharedSyncSchedulerHelpers:NormalizeJitterDelay(minDelay, maxDelay)
    end
    return 0
end

local function GetTeamContextKey()
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.GetTeamContextKey then
        return SharedSyncSchedulerHelpers:GetTeamContextKey(TeamSharedSyncChannelService)
    end
    return nil
end

local function BuildCandidateKey(expansionID, mapID, phaseID)
    return tostring(expansionID) .. ":" .. tostring(mapID) .. ":" .. tostring(phaseID)
end

local function GetSharedRecordTTL()
    if TeamSharedSyncStore and type(TeamSharedSyncStore.RECORD_TTL) == "number" then
        return TeamSharedSyncStore.RECORD_TTL
    end
    return 3600
end

local function ResolvePersistentPhaseID(state)
    if type(state) ~= "table" then
        return nil
    end

    if type(state.lastRefreshPhase) == "string" and state.lastRefreshPhase ~= "" then
        return state.lastRefreshPhase
    end

    if IconDetector and IconDetector.ExtractPhaseID then
        return IconDetector.ExtractPhaseID(state.currentAirdropObjectGUID)
    end

    return nil
end

local function UpsertCandidate(candidateByKey, expansionID, mapID, phaseID, timestamp, objectGUID, source)
    if type(candidateByKey) ~= "table"
        or type(expansionID) ~= "string"
        or type(mapID) ~= "number"
        or type(phaseID) ~= "string"
        or phaseID == ""
        or type(timestamp) ~= "number"
        or timestamp <= 0
        or type(objectGUID) ~= "string"
        or objectGUID == "" then
        return false
    end

    local key = BuildCandidateKey(expansionID, mapID, phaseID)
    local existing = candidateByKey[key]
    if existing then
        if timestamp < existing.timestamp then
            return false
        end
        if timestamp == existing.timestamp and existing.source == "persistent" and source ~= "persistent" then
            return false
        end
    end

    candidateByKey[key] = {
        expansionID = expansionID,
        mapID = mapID,
        phaseID = phaseID,
        timestamp = math.floor(timestamp),
        objectGUID = objectGUID,
        source = source,
    }
    return true
end

function TeamSharedWarmupService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function TeamSharedWarmupService:CanRequestSync()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not CoreShared or not CoreShared.IsAddonEnabled or CoreShared:IsAddonEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncListener
        or not TeamSharedSyncListener.IsFeatureEnabled
        or TeamSharedSyncListener:IsFeatureEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncListener.CanSendSharedSync
        or TeamSharedSyncListener:CanSendSharedSync() ~= true then
        return false
    end
    return true
end

function TeamSharedWarmupService:CanBroadcast()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not CoreShared or not CoreShared.IsAddonEnabled or CoreShared:IsAddonEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncListener
        or not TeamSharedSyncListener.IsFeatureEnabled
        or TeamSharedSyncListener:IsFeatureEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncListener.CanSendSharedSync
        or TeamSharedSyncListener:CanSendSharedSync() ~= true then
        return false
    end
    return true
end

function TeamSharedWarmupService:Initialize()
    self.broadcastQueue = self.broadcastQueue or {}
    self.sharedRecordBuffer = self.sharedRecordBuffer or {}
    self.candidateByKeyBuffer = self.candidateByKeyBuffer or {}
    self.persistentStateBuffer = self.persistentStateBuffer or {}
    self.requestResponseStateByKey = self.requestResponseStateByKey or {}
    return true
end

function TeamSharedWarmupService:CancelPendingBroadcast()
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.CancelOwnedTimer then
        SharedSyncSchedulerHelpers:CancelOwnedTimer(self, "broadcastTimer")
    elseif self.broadcastTimer and self.broadcastTimer.Cancel then
        self.broadcastTimer:Cancel()
        self.broadcastTimer = nil
    end
    self.broadcastIndex = 0
    self.pendingFollowupBroadcast = false
    self.broadcastQueue = ClearArray(self.broadcastQueue)
    return true
end

function TeamSharedWarmupService:CancelPendingResponse()
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.CancelOwnedTimer then
        SharedSyncSchedulerHelpers:CancelOwnedTimer(self, "pendingResponseTimer")
    elseif self.pendingResponseTimer and self.pendingResponseTimer.Cancel then
        self.pendingResponseTimer:Cancel()
        self.pendingResponseTimer = nil
    end
    return true
end

function TeamSharedWarmupService:Reset()
    self:CancelPendingBroadcast()
    self:CancelPendingResponse()
    self.sharedRecordBuffer = ClearArray(self.sharedRecordBuffer)
    self.candidateByKeyBuffer = ClearMap(self.candidateByKeyBuffer)
    self.persistentStateBuffer = ClearMap(self.persistentStateBuffer)
    self.requestResponseStateByKey = ClearMap(self.requestResponseStateByKey)
    self.lastTeamChannelReady = false
    self.lastTeamContextKey = nil
    self.lastSyncRequestAt = 0
    self.requestSequence = 0
    self.pendingFollowupBroadcast = false
    return true
end

function TeamSharedWarmupService:PruneRequestResponseState(currentTime)
    local stateByKey = self.requestResponseStateByKey or {}
    local now = currentTime or Utils:GetCurrentTimestamp()
    local ttl = tonumber(self.REQUEST_RESPONSE_STATE_TTL) or 60
    for requestKey, respondedAt in pairs(stateByKey) do
        if type(respondedAt) ~= "number" or (now - respondedAt) > ttl then
            stateByKey[requestKey] = nil
        end
    end
    self.requestResponseStateByKey = stateByKey
    return stateByKey
end

function TeamSharedWarmupService:BuildSyncRequestState(currentTime)
    self.requestSequence = (tonumber(self.requestSequence) or 0) + 1
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    return {
        requestID = tostring(now) .. "-" .. tostring(self.requestSequence),
        timestamp = now,
    }
end

function TeamSharedWarmupService:SendSyncRequest(currentTime, force)
    if self:CanRequestSync() ~= true then
        return false
    end

    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    if force ~= true then
        local lastSentAt = tonumber(self.lastSyncRequestAt) or 0
        if (now - lastSentAt) < (tonumber(self.REQUEST_COOLDOWN) or 15) then
            return false
        end
    end

    local requestState = self:BuildSyncRequestState(now)
    if TeamSharedSyncListener and TeamSharedSyncListener.SendSyncRequest and TeamSharedSyncListener:SendSyncRequest(requestState) == true then
        self.lastSyncRequestAt = now
        return true
    end
    return false
end

function TeamSharedWarmupService:HandleTeamContextChanged(forceRequest)
    local canRequestSync = self:CanRequestSync() == true
    local previousReady = self.lastTeamChannelReady == true
    local previousContextKey = self.lastTeamContextKey
    self.lastTeamChannelReady = canRequestSync

    if canRequestSync ~= true then
        self.lastTeamContextKey = nil
        self:CancelPendingResponse()
        return false
    end

    local currentContextKey = GetTeamContextKey()
    self.lastTeamContextKey = currentContextKey
    local contextChanged = previousReady == true
        and type(previousContextKey) == "string"
        and previousContextKey ~= ""
        and type(currentContextKey) == "string"
        and currentContextKey ~= ""
        and previousContextKey ~= currentContextKey

    if previousReady ~= true or contextChanged == true or forceRequest == true then
        return self:SendSyncRequest(
            Utils:GetCurrentTimestamp(),
            previousReady ~= true or contextChanged == true or forceRequest == true
        )
    end

    return false
end

function TeamSharedWarmupService:ScheduleResponseBroadcast(delaySeconds)
    if self.pendingResponseTimer then
        return true
    end
    if self.broadcastTimer or (self.broadcastIndex > 0 and self.broadcastQueue[self.broadcastIndex]) then
        self.pendingFollowupBroadcast = true
        return true
    end
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ScheduleOwnedTimer then
        return SharedSyncSchedulerHelpers:ScheduleOwnedTimer(self, "pendingResponseTimer", delaySeconds, function()
            self:StartBroadcastRound()
        end)
    end

    return self:StartBroadcastRound()
end

function TeamSharedWarmupService:HandleSyncRequest(syncState, sender)
    if self:CanBroadcast() ~= true then
        return false
    end
    if type(syncState) ~= "table" or type(syncState.requestID) ~= "string" or syncState.requestID == "" then
        return false
    end
    if type(sender) ~= "string" or sender == "" then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    local requestTimestamp = tonumber(syncState.timestamp)
    local acceptWindow = tonumber(self.REQUEST_ACCEPT_WINDOW) or 30
    local maxFutureOffset = tonumber(self.REQUEST_MAX_FUTURE_OFFSET) or 10
    if type(requestTimestamp) ~= "number"
        or requestTimestamp < (now - acceptWindow)
        or requestTimestamp > (now + maxFutureOffset) then
        return false
    end

    local stateByKey = self:PruneRequestResponseState(now)
    local requestKey = BuildRequestResponseKey(sender, syncState.requestID)
    if stateByKey[requestKey] ~= nil then
        return false
    end
    stateByKey[requestKey] = now

    local delay = NormalizeJitterDelay(
        self.REQUEST_RESPONSE_JITTER_MIN,
        self.REQUEST_RESPONSE_JITTER_MAX
    )
    return self:ScheduleResponseBroadcast(delay)
end

function TeamSharedWarmupService:CollectPersistentCandidates(candidateByKey, currentTime)
    if type(candidateByKey) ~= "table" then
        return 0
    end

    local maps = Data and Data.GetAllMaps and Data:GetAllMaps() or {}
    local stateBuffer = self.persistentStateBuffer or {}
    local expireBefore = (currentTime or Utils:GetCurrentTimestamp()) - GetSharedRecordTTL()
    local count = 0

    for _, mapData in ipairs(maps) do
        if mapData and type(mapData.expansionID) == "string" and type(mapData.mapID) == "number" then
            ClearMap(stateBuffer)
            local persistentState = UnifiedDataManager
                and UnifiedDataManager.GetPersistentAirdropStateInto
                and UnifiedDataManager:GetPersistentAirdropStateInto(mapData.id, stateBuffer)
                or nil
            local timestamp = tonumber(persistentState and (persistentState.currentAirdropTimestamp or persistentState.lastRefresh))
            local objectGUID = persistentState and persistentState.currentAirdropObjectGUID or nil
            local phaseID = ResolvePersistentPhaseID(persistentState)

            if type(timestamp) == "number"
                and timestamp > expireBefore
                and UpsertCandidate(
                    candidateByKey,
                    mapData.expansionID,
                    mapData.mapID,
                    phaseID,
                    timestamp,
                    objectGUID,
                    "persistent"
                ) then
                count = count + 1
            end
        end
    end

    self.persistentStateBuffer = stateBuffer
    return count
end

function TeamSharedWarmupService:CollectSharedCandidates(candidateByKey, currentTime)
    if type(candidateByKey) ~= "table" then
        return 0
    end

    local sharedRecords = self.sharedRecordBuffer or {}
    ClearArray(sharedRecords)
    if TeamSharedSyncStore and TeamSharedSyncStore.AppendActiveRecords then
        TeamSharedSyncStore:AppendActiveRecords(sharedRecords, currentTime)
    end

    local count = 0
    for _, record in ipairs(sharedRecords) do
        if record
            and Data
            and Data.GetMapByMapID
            and Data:GetMapByMapID(record.mapID, record.expansionID) then
            if UpsertCandidate(
                candidateByKey,
                record.expansionID,
                record.mapID,
                record.phaseID,
                record.timestamp,
                record.objectGUID,
                "shared"
            ) then
                count = count + 1
            end
        end
    end

    self.sharedRecordBuffer = sharedRecords
    return count
end

function TeamSharedWarmupService:BuildBroadcastQueue(currentTime)
    self:Initialize()

    local candidateByKey = ClearMap(self.candidateByKeyBuffer)
    local queue = ClearArray(self.broadcastQueue)
    local now = currentTime or Utils:GetCurrentTimestamp()

    self:CollectPersistentCandidates(candidateByKey, now)
    self:CollectSharedCandidates(candidateByKey, now)

    for _, candidate in pairs(candidateByKey) do
        queue[#queue + 1] = candidate
    end

    table.sort(queue, function(left, right)
        if left.timestamp ~= right.timestamp then
            return left.timestamp > right.timestamp
        end
        if left.source ~= right.source then
            return left.source == "persistent"
        end
        if left.expansionID ~= right.expansionID then
            return left.expansionID < right.expansionID
        end
        if left.mapID ~= right.mapID then
            return left.mapID < right.mapID
        end
        return left.phaseID < right.phaseID
    end)

    self.candidateByKeyBuffer = candidateByKey
    self.broadcastQueue = queue
    return queue
end

function TeamSharedWarmupService:ScheduleNextSend(delaySeconds)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ScheduleOwnedTimer then
        return SharedSyncSchedulerHelpers:ScheduleOwnedTimer(self, "broadcastTimer", delaySeconds, function()
            self:SendNextRecord()
        end)
    end
    self:CancelPendingBroadcast()
    return false
end

function TeamSharedWarmupService:SendNextRecord()
    if self:CanBroadcast() ~= true then
        self:CancelPendingBroadcast()
        return false
    end

    local record = self.broadcastQueue and self.broadcastQueue[self.broadcastIndex] or nil
    if not record then
        self:CancelPendingBroadcast()
        return false
    end

    if TeamSharedSyncListener and TeamSharedSyncListener.SendSharedSync then
        TeamSharedSyncListener:SendSharedSync(record)
    end

    self.broadcastIndex = self.broadcastIndex + 1
    if self.broadcastQueue[self.broadcastIndex] then
        return self:ScheduleNextSend(self.SEND_INTERVAL)
    end

    local shouldFollowup = self.pendingFollowupBroadcast == true and self:CanBroadcast() == true
    self:CancelPendingBroadcast()
    if shouldFollowup then
        return self:ScheduleResponseBroadcast(NormalizeJitterDelay(
            self.REQUEST_RESPONSE_JITTER_MIN,
            self.REQUEST_RESPONSE_JITTER_MAX
        ))
    end
    return true
end

function TeamSharedWarmupService:StartBroadcastRound()
    if self:CanBroadcast() ~= true then
        self:CancelPendingBroadcast()
        return false
    end
    if self.broadcastTimer or (self.broadcastIndex > 0 and self.broadcastQueue[self.broadcastIndex]) then
        return false
    end

    local queue = self:BuildBroadcastQueue(Utils:GetCurrentTimestamp())
    if #queue == 0 then
        return false
    end

    self.broadcastIndex = 1
    return self:ScheduleNextSend(0)
end

return TeamSharedWarmupService
