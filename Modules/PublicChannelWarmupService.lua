-- PublicChannelWarmupService.lua - 团队备用共享缓存低频预热广播
-- 注意：本服务只广播运行时备用缓存候选数据，不写长期持久化，也不影响主 CTKZK_SYNC。

local PublicChannelWarmupService = BuildEnv("PublicChannelWarmupService")

local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local Data = BuildEnv("Data")
local IconDetector = BuildEnv("IconDetector")
local PublicChannelSyncListener = BuildEnv("PublicChannelSyncListener")
local PublicChannelSyncStore = BuildEnv("PublicChannelSyncStore")

PublicChannelWarmupService.FEATURE_ENABLED = true
PublicChannelWarmupService.BROADCAST_INTERVAL = 540
PublicChannelWarmupService.SEND_INTERVAL = 1

PublicChannelWarmupService.broadcastQueue = PublicChannelWarmupService.broadcastQueue or {}
PublicChannelWarmupService.broadcastTimer = PublicChannelWarmupService.broadcastTimer or nil
PublicChannelWarmupService.broadcastIndex = PublicChannelWarmupService.broadcastIndex or 0
PublicChannelWarmupService.sharedRecordBuffer = PublicChannelWarmupService.sharedRecordBuffer or {}
PublicChannelWarmupService.candidateByKeyBuffer = PublicChannelWarmupService.candidateByKeyBuffer or {}
PublicChannelWarmupService.persistentStateBuffer = PublicChannelWarmupService.persistentStateBuffer or {}

local function ClearArray(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

local function ClearMap(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for key in pairs(buffer) do
        buffer[key] = nil
    end
    return buffer
end

local function BuildCandidateKey(expansionID, mapID, phaseID)
    return tostring(expansionID) .. ":" .. tostring(mapID) .. ":" .. tostring(phaseID)
end

local function GetSharedRecordTTL()
    if PublicChannelSyncStore and type(PublicChannelSyncStore.RECORD_TTL) == "number" then
        return PublicChannelSyncStore.RECORD_TTL
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
        return IconDetector:ExtractPhaseID(state.currentAirdropObjectGUID)
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

function PublicChannelWarmupService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function PublicChannelWarmupService:CanBroadcast()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not CoreShared or not CoreShared.IsAddonEnabled or CoreShared:IsAddonEnabled() ~= true then
        return false
    end
    if not PublicChannelSyncListener
        or not PublicChannelSyncListener.IsFeatureEnabled
        or PublicChannelSyncListener:IsFeatureEnabled() ~= true then
        return false
    end
    if not PublicChannelSyncListener.CanSendSharedSync
        or PublicChannelSyncListener:CanSendSharedSync() ~= true then
        return false
    end
    return true
end

function PublicChannelWarmupService:Initialize()
    self.broadcastQueue = self.broadcastQueue or {}
    self.sharedRecordBuffer = self.sharedRecordBuffer or {}
    self.candidateByKeyBuffer = self.candidateByKeyBuffer or {}
    self.persistentStateBuffer = self.persistentStateBuffer or {}
    return true
end

function PublicChannelWarmupService:CancelPendingBroadcast()
    if self.broadcastTimer and self.broadcastTimer.Cancel then
        self.broadcastTimer:Cancel()
    end
    self.broadcastTimer = nil
    self.broadcastIndex = 0
    self.broadcastQueue = ClearArray(self.broadcastQueue)
    return true
end

function PublicChannelWarmupService:Reset()
    self:CancelPendingBroadcast()
    self.sharedRecordBuffer = ClearArray(self.sharedRecordBuffer)
    self.candidateByKeyBuffer = ClearMap(self.candidateByKeyBuffer)
    self.persistentStateBuffer = ClearMap(self.persistentStateBuffer)
    return true
end

function PublicChannelWarmupService:CollectPersistentCandidates(candidateByKey, currentTime)
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
            local persistentState = Data
                and Data.GetPersistentAirdropStateInto
                and Data:GetPersistentAirdropStateInto(mapData.id, stateBuffer)
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

function PublicChannelWarmupService:CollectSharedCandidates(candidateByKey, currentTime)
    if type(candidateByKey) ~= "table" then
        return 0
    end

    local sharedRecords = self.sharedRecordBuffer or {}
    ClearArray(sharedRecords)
    if PublicChannelSyncStore and PublicChannelSyncStore.AppendActiveRecords then
        PublicChannelSyncStore:AppendActiveRecords(sharedRecords, currentTime)
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

function PublicChannelWarmupService:BuildBroadcastQueue(currentTime)
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

function PublicChannelWarmupService:ScheduleNextSend(delaySeconds)
    if not C_Timer or not C_Timer.NewTimer then
        self:CancelPendingBroadcast()
        return false
    end

    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then
        delay = 0
    end

    self.broadcastTimer = C_Timer.NewTimer(delay, function()
        self.broadcastTimer = nil
        self:SendNextRecord()
    end)
    return true
end

function PublicChannelWarmupService:SendNextRecord()
    if self:CanBroadcast() ~= true then
        self:CancelPendingBroadcast()
        return false
    end

    local record = self.broadcastQueue and self.broadcastQueue[self.broadcastIndex] or nil
    if not record then
        self:CancelPendingBroadcast()
        return false
    end

    if PublicChannelSyncListener and PublicChannelSyncListener.SendSharedSync then
        PublicChannelSyncListener:SendSharedSync(record)
    end

    self.broadcastIndex = self.broadcastIndex + 1
    if self.broadcastQueue[self.broadcastIndex] then
        return self:ScheduleNextSend(self.SEND_INTERVAL)
    end

    self:CancelPendingBroadcast()
    return true
end

function PublicChannelWarmupService:StartBroadcastRound()
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

return PublicChannelWarmupService
