-- PublicChannelSyncStore.lua - 备用相位缓存共享记录运行时存储
-- 注意：这里只保存共享补充信息，不作为本地可靠事实源，也不写长期持久化。

local PublicChannelSyncStore = BuildEnv("PublicChannelSyncStore")

PublicChannelSyncStore.FEATURE_ENABLED = true
PublicChannelSyncStore.RECORD_TTL = 3600
PublicChannelSyncStore.MAX_PHASE_RECORDS_PER_MAP = 8
PublicChannelSyncStore.MAX_FUTURE_TIMESTAMP_OFFSET = 120

function PublicChannelSyncStore:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

local function EnsureRecords()
    PublicChannelSyncStore.sharedPhaseRecords = PublicChannelSyncStore.sharedPhaseRecords or {}
    return PublicChannelSyncStore.sharedPhaseRecords
end

local function EnsureMapBucket(expansionID, mapID)
    local records = EnsureRecords()
    records[expansionID] = records[expansionID] or {}
    records[expansionID][mapID] = records[expansionID][mapID] or {}
    return records[expansionID][mapID]
end

local function BuildRecordKey(expansionID, mapID, phaseID, objectGUID)
    return tostring(expansionID or "default")
        .. ":" .. tostring(mapID or "0")
        .. ":" .. tostring(phaseID or "unknown")
        .. ":" .. tostring(objectGUID or "unknown")
end

local function IsExpired(record, currentTime)
    local now = currentTime or Utils:GetCurrentTimestamp()
    return type(record) ~= "table"
        or type(record.expiresAt) ~= "number"
        or record.expiresAt <= now
end

local function IsTimestampWithinAcceptableWindow(timestamp, currentTime)
    local now = currentTime or Utils:GetCurrentTimestamp()
    local oldestAllowed = now - PublicChannelSyncStore.RECORD_TTL
    local newestAllowed = now + PublicChannelSyncStore.MAX_FUTURE_TIMESTAMP_OFFSET

    return type(timestamp) == "number"
        and timestamp > oldestAllowed
        and timestamp <= newestAllowed
end

local function SelectOldestPhaseRecord(mapBucket, currentTime)
    local oldestPhaseID, oldestReceivedAt = nil, nil
    local activeCount = 0

    for phaseID, record in pairs(mapBucket) do
        if IsExpired(record, currentTime) then
            mapBucket[phaseID] = nil
        else
            activeCount = activeCount + 1
            local receivedAt = tonumber(record.receivedAt) or 0
            if oldestReceivedAt == nil or receivedAt < oldestReceivedAt then
                oldestReceivedAt = receivedAt
                oldestPhaseID = phaseID
            end
        end
    end

    return oldestPhaseID, activeCount
end

local function PruneMapBucket(mapBucket, currentTime, maxRecords)
    if type(mapBucket) ~= "table" then
        return
    end

    local oldestPhaseID, activeCount = SelectOldestPhaseRecord(mapBucket, currentTime)
    while activeCount > (maxRecords or 8) and oldestPhaseID do
        mapBucket[oldestPhaseID] = nil
        oldestPhaseID, activeCount = SelectOldestPhaseRecord(mapBucket, currentTime)
    end
end

function PublicChannelSyncStore:Initialize()
    if self:IsFeatureEnabled() ~= true then
        self.sharedPhaseRecords = {}
        return false
    end
    EnsureRecords()
    return true
end

function PublicChannelSyncStore:Reset()
    self.sharedPhaseRecords = {}
end

function PublicChannelSyncStore:GetRecordInto(expansionID, mapID, phaseID, outRecord, currentTime)
    if self:IsFeatureEnabled() ~= true then
        return nil
    end
    if type(expansionID) ~= "string" or type(mapID) ~= "number" or type(phaseID) ~= "string" or type(outRecord) ~= "table" then
        return nil
    end

    local records = EnsureRecords()
    local expansionBucket = records[expansionID]
    local mapBucket = expansionBucket and expansionBucket[mapID]
    local record = mapBucket and mapBucket[phaseID]

    if not record then
        return nil
    end

    if IsExpired(record, currentTime) then
        mapBucket[phaseID] = nil
        if next(mapBucket) == nil then
            expansionBucket[mapID] = nil
            if next(expansionBucket) == nil then
                records[expansionID] = nil
            end
        end
        return nil
    end

    outRecord.expansionID = expansionID
    outRecord.mapID = mapID
    outRecord.phaseID = phaseID
    outRecord.timestamp = record.timestamp
    outRecord.objectGUID = record.objectGUID
    outRecord.source = record.source
    outRecord.sender = record.sender
    outRecord.receivedAt = record.receivedAt
    outRecord.expiresAt = record.expiresAt
    outRecord.recordKey = record.recordKey
    return outRecord
end

function PublicChannelSyncStore:AppendActiveRecords(outRecords, currentTime)
    if self:IsFeatureEnabled() ~= true or type(outRecords) ~= "table" then
        return outRecords
    end

    local records = EnsureRecords()
    local now = currentTime or Utils:GetCurrentTimestamp()

    for expansionID, expansionBucket in pairs(records) do
        if type(expansionBucket) == "table" then
            for mapID, mapBucket in pairs(expansionBucket) do
                if type(mapBucket) == "table" then
                    for phaseID, record in pairs(mapBucket) do
                        if IsExpired(record, now) then
                            mapBucket[phaseID] = nil
                        else
                            outRecords[#outRecords + 1] = {
                                expansionID = expansionID,
                                mapID = mapID,
                                phaseID = phaseID,
                                timestamp = record.timestamp,
                                objectGUID = record.objectGUID,
                                source = record.source,
                                sender = record.sender,
                                receivedAt = record.receivedAt,
                                expiresAt = record.expiresAt,
                                recordKey = record.recordKey,
                            }
                        end
                    end
                    if next(mapBucket) == nil then
                        expansionBucket[mapID] = nil
                    end
                end
            end
            if next(expansionBucket) == nil then
                records[expansionID] = nil
            end
        end
    end

    return outRecords
end

function PublicChannelSyncStore:UpsertRecord(expansionID, mapID, phaseID, timestamp, objectGUID, sender, receivedAt)
    if self:IsFeatureEnabled() ~= true then
        return false, nil
    end
    if type(expansionID) ~= "string" or type(mapID) ~= "number" or type(phaseID) ~= "string" then
        return false, nil
    end

    timestamp = tonumber(timestamp)
    if not timestamp
        or IsTimestampWithinAcceptableWindow(timestamp, receivedAt) ~= true
        or type(objectGUID) ~= "string"
        or objectGUID == "" then
        return false, nil
    end

    local now = receivedAt or Utils:GetCurrentTimestamp()
    local mapBucket = EnsureMapBucket(expansionID, mapID)
    local existingRecord = mapBucket[phaseID]
    if existingRecord and not IsExpired(existingRecord, now) then
        if existingRecord.objectGUID == objectGUID then
            return false, existingRecord
        end
        if type(existingRecord.timestamp) == "number" and timestamp <= existingRecord.timestamp then
            return false, existingRecord
        end
    end

    local record = {
        expansionID = expansionID,
        mapID = mapID,
        phaseID = phaseID,
        timestamp = timestamp,
        objectGUID = objectGUID,
        source = "public_channel_sync",
        sender = sender,
        receivedAt = now,
        expiresAt = now + self.RECORD_TTL,
        recordKey = BuildRecordKey(expansionID, mapID, phaseID, objectGUID),
    }
    mapBucket[phaseID] = record
    PruneMapBucket(mapBucket, now, self.MAX_PHASE_RECORDS_PER_MAP)
    return true, record
end

function PublicChannelSyncStore:ClearExpiredRecords(currentTime)
    if self:IsFeatureEnabled() ~= true then
        self.sharedPhaseRecords = {}
        return
    end
    local records = EnsureRecords()
    local now = currentTime or Utils:GetCurrentTimestamp()

    for expansionID, expansionBucket in pairs(records) do
        if type(expansionBucket) == "table" then
            for mapID, mapBucket in pairs(expansionBucket) do
                if type(mapBucket) == "table" then
                    for phaseID, record in pairs(mapBucket) do
                        if IsExpired(record, now) then
                            mapBucket[phaseID] = nil
                        end
                    end
                    if next(mapBucket) == nil then
                        expansionBucket[mapID] = nil
                    end
                end
            end
            if next(expansionBucket) == nil then
                records[expansionID] = nil
            end
        end
    end
end

return PublicChannelSyncStore
