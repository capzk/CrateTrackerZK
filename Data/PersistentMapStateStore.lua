-- PersistentMapStateStore.lua - 地图持久化状态访问

local PersistentMapStateStore = BuildEnv("PersistentMapStateStore")
local AppContext = BuildEnv("AppContext")
local Utils = BuildEnv("Utils")
local Logger = BuildEnv("Logger")

local function EnsurePersistentState()
    if AppContext and AppContext.EnsurePersistentState then
        return AppContext:EnsurePersistentState()
    end
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {}
    end
    return CRATETRACKERZK_DB
end

local function EnsureExpansionBucket(expansionID)
    local db = EnsurePersistentState()
    db.mapData = nil
    db.expansionData = db.expansionData or {}
    db.expansionData[expansionID] = db.expansionData[expansionID] or {}
    db.expansionData[expansionID].mapData = db.expansionData[expansionID].mapData or {}
    return db.expansionData[expansionID].mapData
end

local function SanitizeTimestamp(ts)
    if type(ts) ~= "number" then
        return nil
    end

    local maxFuture = (Utils and Utils.GetCurrentTimestamp and Utils:GetCurrentTimestamp() or 0) + (86400 * 365)
    if ts < 0 or ts > maxFuture then
        return nil
    end
    return ts
end

local function GetSavedRecordByMapData(mapData)
    if type(mapData) ~= "table"
        or type(mapData.expansionID) ~= "string"
        or type(mapData.mapID) ~= "number" then
        return nil
    end
    return PersistentMapStateStore:GetSavedRecord(mapData.expansionID, mapData.mapID)
end

local function PopulatePersistentSnapshot(outSnapshot, mapData, savedData)
    if type(outSnapshot) ~= "table" or type(mapData) ~= "table" then
        return nil
    end

    outSnapshot.expansionID = mapData.expansionID
    outSnapshot.mapID = mapData.mapID
    outSnapshot.createTime = SanitizeTimestamp(savedData and savedData.createTime)
        or mapData.createTime
        or (Utils and Utils.GetCurrentTimestamp and Utils:GetCurrentTimestamp() or nil)
    outSnapshot.lastRefresh = SanitizeTimestamp(savedData and savedData.lastRefresh) or nil
    outSnapshot.lastRefreshSource = type(savedData and savedData.lastRefreshSource) == "string" and savedData.lastRefreshSource or nil
    outSnapshot.currentAirdropObjectGUID = type(savedData and savedData.currentAirdropObjectGUID) == "string" and savedData.currentAirdropObjectGUID or nil
    outSnapshot.currentAirdropTimestamp = SanitizeTimestamp(savedData and savedData.currentAirdropTimestamp) or nil
    outSnapshot.lastRefreshPhase = type(savedData and savedData.lastRefreshPhase) == "string" and savedData.lastRefreshPhase or nil
    return outSnapshot
end

local function PopulatePersistentTimeRecord(outRecord, savedData)
    if type(outRecord) ~= "table" then
        return nil
    end

    outRecord.timestamp = nil
    outRecord.source = nil
    outRecord.phaseId = nil
    outRecord.objectGUID = nil
    outRecord.eventTimestamp = nil

    if type(savedData) ~= "table" then
        return nil
    end

    local lastRefresh = SanitizeTimestamp(savedData.lastRefresh)
    if not lastRefresh then
        return nil
    end

    outRecord.timestamp = lastRefresh
    outRecord.source = type(savedData.lastRefreshSource) == "string" and savedData.lastRefreshSource or nil
    outRecord.phaseId = type(savedData.lastRefreshPhase) == "string" and savedData.lastRefreshPhase or nil
    outRecord.objectGUID = type(savedData.currentAirdropObjectGUID) == "string" and savedData.currentAirdropObjectGUID or nil
    outRecord.eventTimestamp = SanitizeTimestamp(savedData.currentAirdropTimestamp) or lastRefresh
    return outRecord
end

local function PopulatePersistentAirdropState(outState, mapData, savedData)
    if type(outState) ~= "table" then
        return nil
    end

    outState.expansionID = type(mapData) == "table" and mapData.expansionID or nil
    outState.mapID = type(mapData) == "table" and mapData.mapID or nil
    outState.lastRefresh = nil
    outState.currentAirdropObjectGUID = nil
    outState.currentAirdropTimestamp = nil
    outState.lastRefreshPhase = nil
    outState.source = nil

    if type(savedData) ~= "table" then
        return nil
    end

    local lastRefresh = SanitizeTimestamp(savedData.lastRefresh)
    if not lastRefresh then
        return nil
    end

    outState.lastRefresh = lastRefresh
    outState.currentAirdropObjectGUID = type(savedData.currentAirdropObjectGUID) == "string"
        and savedData.currentAirdropObjectGUID
        or nil
    outState.currentAirdropTimestamp = SanitizeTimestamp(savedData.currentAirdropTimestamp) or lastRefresh
    outState.lastRefreshPhase = type(savedData.lastRefreshPhase) == "string" and savedData.lastRefreshPhase or nil
    outState.source = type(savedData.lastRefreshSource) == "string" and savedData.lastRefreshSource or nil
    return outState
end

function PersistentMapStateStore:GetSavedRecord(expansionID, mapID)
    if not expansionID or type(mapID) ~= "number" then
        return nil
    end
    local mapStore = EnsureExpansionBucket(expansionID)
    return mapStore[mapID]
end

function PersistentMapStateStore:GetSavedRecordByMap(mapData)
    return GetSavedRecordByMapData(mapData)
end

function PersistentMapStateStore:SaveRecord(expansionID, mapID, savedData)
    if not expansionID or type(mapID) ~= "number" then
        return false
    end
    local mapStore = EnsureExpansionBucket(expansionID)
    mapStore[mapID] = savedData
    return true
end

function PersistentMapStateStore:GetTimeRecordInto(mapData, outRecord)
    local savedData = GetSavedRecordByMapData(mapData)
    return PopulatePersistentTimeRecord(outRecord, savedData)
end

function PersistentMapStateStore:GetAirdropStateInto(mapData, outState)
    local savedData = GetSavedRecordByMapData(mapData)
    return PopulatePersistentAirdropState(outState, mapData, savedData)
end

function PersistentMapStateStore:GetSnapshotInto(mapData, outSnapshot)
    local savedData = GetSavedRecordByMapData(mapData)
    return PopulatePersistentSnapshot(outSnapshot, mapData, savedData)
end

function PersistentMapStateStore:GetPhase(mapData)
    local state = {}
    if not self:GetAirdropStateInto(mapData, state) then
        return nil
    end
    return state.lastRefreshPhase
end

function PersistentMapStateStore:SaveSnapshot(mapData, snapshot)
    if type(mapData) ~= "table"
        or type(mapData.mapID) ~= "number"
        or type(mapData.expansionID) ~= "string" then
        return false
    end

    local existingRecord = GetSavedRecordByMapData(mapData)
    local savedData = {
        createTime = SanitizeTimestamp((snapshot and snapshot.createTime) or (existingRecord and existingRecord.createTime))
            or mapData.createTime
            or (Utils and Utils.GetCurrentTimestamp and Utils:GetCurrentTimestamp() or nil),
        lastRefresh = SanitizeTimestamp(snapshot and snapshot.lastRefresh) or nil,
        lastRefreshSource = type(snapshot and snapshot.lastRefreshSource) == "string" and snapshot.lastRefreshSource or nil,
        currentAirdropObjectGUID = type(snapshot and snapshot.currentAirdropObjectGUID) == "string" and snapshot.currentAirdropObjectGUID or nil,
        currentAirdropTimestamp = SanitizeTimestamp(snapshot and snapshot.currentAirdropTimestamp) or nil,
        lastRefreshPhase = type(snapshot and snapshot.lastRefreshPhase) == "string" and snapshot.lastRefreshPhase or nil,
    }

    if self:SaveRecord(mapData.expansionID, mapData.mapID, savedData) ~= true then
        return false
    end

    if Logger and Logger.Error then
        local verifyData = self:GetSavedRecord(mapData.expansionID, mapData.mapID)
        if verifyData and verifyData.currentAirdropObjectGUID ~= savedData.currentAirdropObjectGUID then
            Logger:Error("PersistentMapStateStore", "错误", string.format(
                "数据保存验证失败：地图ID=%d，期望objectGUID=%s，实际objectGUID=%s",
                mapData.mapID,
                savedData.currentAirdropObjectGUID or "nil",
                verifyData.currentAirdropObjectGUID or "nil"
            ))
        end
    end

    mapData.createTime = savedData.createTime
    return true
end

function PersistentMapStateStore:PersistAirdropState(mapData, state)
    if type(mapData) ~= "table" or type(state) ~= "table" then
        return false
    end

    local currentRecord = GetSavedRecordByMapData(mapData)
    local lastRefreshPhase = currentRecord and currentRecord.lastRefreshPhase or nil
    if state.lastRefreshPhase ~= nil then
        lastRefreshPhase = state.lastRefreshPhase or nil
    end

    return self:SaveSnapshot(mapData, {
        createTime = (currentRecord and currentRecord.createTime)
            or mapData.createTime
            or (Utils and Utils.GetCurrentTimestamp and Utils:GetCurrentTimestamp() or nil),
        lastRefresh = state.lastRefresh ~= nil and state.lastRefresh or (currentRecord and currentRecord.lastRefresh),
        lastRefreshSource = state.lastRefreshSource ~= nil and state.lastRefreshSource or (currentRecord and currentRecord.lastRefreshSource),
        currentAirdropObjectGUID = state.currentAirdropObjectGUID ~= nil and state.currentAirdropObjectGUID or (currentRecord and currentRecord.currentAirdropObjectGUID),
        currentAirdropTimestamp = state.currentAirdropTimestamp ~= nil and state.currentAirdropTimestamp or (currentRecord and currentRecord.currentAirdropTimestamp),
        lastRefreshPhase = lastRefreshPhase,
    })
end

function PersistentMapStateStore:ClearAll()
    local db = EnsurePersistentState()
    db.expansionData = db.expansionData or {}
    for _, expansionBucket in pairs(db.expansionData) do
        if type(expansionBucket) == "table" then
            expansionBucket.mapData = {}
        end
    end
end

return PersistentMapStateStore
