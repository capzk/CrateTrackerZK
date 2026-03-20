-- StateBuckets.lua - 统一管理按资料片分桶的状态访问

local StateBuckets = BuildEnv("StateBuckets")
local AppContext = BuildEnv("AppContext")

local function ResolveExpansionID(expansionID)
    if expansionID then
        return expansionID
    end
    if AppContext and AppContext.GetCurrentExpansionID then
        return AppContext:GetCurrentExpansionID()
    end
    return "default"
end

function StateBuckets:GetExpansionMapData(expansionID)
    local db = AppContext and AppContext.EnsurePersistentState and AppContext:EnsurePersistentState() or {}
    db.mapData = nil

    if type(db.expansionData) ~= "table" then
        db.expansionData = {}
    end

    expansionID = ResolveExpansionID(expansionID)

    if type(db.expansionData[expansionID]) ~= "table" then
        db.expansionData[expansionID] = {}
    end

    if type(db.expansionData[expansionID].mapData) ~= "table" then
        db.expansionData[expansionID].mapData = {}
    end

    return db.expansionData[expansionID].mapData, expansionID
end

function StateBuckets:GetExpansionUIBucket(expansionID)
    local uiDB = AppContext and AppContext.EnsureUIState and AppContext:EnsureUIState() or {}
    uiDB.hiddenMaps = nil
    uiDB.hiddenRemaining = nil
    uiDB.phaseCache = nil

    if type(uiDB.expansionUIData) ~= "table" then
        uiDB.expansionUIData = {}
    end

    expansionID = ResolveExpansionID(expansionID)

    if type(uiDB.expansionUIData[expansionID]) ~= "table" then
        uiDB.expansionUIData[expansionID] = {}
    end

    local bucket = uiDB.expansionUIData[expansionID]
    if type(bucket.hiddenMaps) ~= "table" then
        bucket.hiddenMaps = {}
    end
    if type(bucket.hiddenRemaining) ~= "table" then
        bucket.hiddenRemaining = {}
    end
    if type(bucket.phaseCache) ~= "table" then
        bucket.phaseCache = {}
    end

    return bucket, expansionID
end

function StateBuckets:GetHiddenMaps(expansionID)
    local bucket = self:GetExpansionUIBucket(expansionID)
    return bucket.hiddenMaps
end

function StateBuckets:GetHiddenRemaining(expansionID)
    local bucket = self:GetExpansionUIBucket(expansionID)
    return bucket.hiddenRemaining
end

function StateBuckets:GetPhaseCache(expansionID)
    local bucket = self:GetExpansionUIBucket(expansionID)
    return bucket.phaseCache
end

return StateBuckets
