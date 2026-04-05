-- PublicChannelSyncStore.lua - 公共频道相位共享记录运行时存储
-- 注意：这里只保存共享补充信息，不作为本地可靠事实源，也不写长期持久化。

local PublicChannelSyncStore = BuildEnv("PublicChannelSyncStore")

PublicChannelSyncStore.RECORD_TTL = 3600

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
    return table.concat({
        tostring(expansionID or "default"),
        tostring(mapID or "0"),
        tostring(phaseID or "unknown"),
        tostring(objectGUID or "unknown"),
    }, ":")
end

local function IsExpired(record, currentTime)
    local now = currentTime or Utils:GetCurrentTimestamp()
    return type(record) ~= "table"
        or type(record.expiresAt) ~= "number"
        or record.expiresAt <= now
end

function PublicChannelSyncStore:Initialize()
    EnsureRecords()
end

function PublicChannelSyncStore:Reset()
    self.sharedPhaseRecords = {}
end

function PublicChannelSyncStore:GetRecord(expansionID, mapID, phaseID, currentTime)
    local outRecord = {}
    if not self:GetRecordInto(expansionID, mapID, phaseID, outRecord, currentTime) then
        return nil
    end
    return outRecord
end

function PublicChannelSyncStore:GetRecordInto(expansionID, mapID, phaseID, outRecord, currentTime)
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

function PublicChannelSyncStore:UpsertRecord(expansionID, mapID, phaseID, timestamp, objectGUID, sender, receivedAt)
    if type(expansionID) ~= "string" or type(mapID) ~= "number" or type(phaseID) ~= "string" then
        return false, nil
    end

    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 or type(objectGUID) ~= "string" or objectGUID == "" then
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
    return true, record
end

function PublicChannelSyncStore:ClearExpiredRecords(currentTime)
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
