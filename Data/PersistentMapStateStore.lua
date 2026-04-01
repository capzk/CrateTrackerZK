-- PersistentMapStateStore.lua - 地图持久化状态访问

local PersistentMapStateStore = BuildEnv("PersistentMapStateStore")
local AppContext = BuildEnv("AppContext")

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

function PersistentMapStateStore:GetSavedRecord(expansionID, mapID)
    if not expansionID or type(mapID) ~= "number" then
        return nil
    end
    local mapStore = EnsureExpansionBucket(expansionID)
    return mapStore[mapID]
end

function PersistentMapStateStore:SaveRecord(expansionID, mapID, savedData)
    if not expansionID or type(mapID) ~= "number" then
        return false
    end
    local mapStore = EnsureExpansionBucket(expansionID)
    mapStore[mapID] = savedData
    return true
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
