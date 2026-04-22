-- UnifiedPhaseDisplayService.lua - 位面对比与显示服务

local UnifiedPhaseDisplayService = BuildEnv("UnifiedPhaseDisplayService")
local AppContext = BuildEnv("AppContext")
local Data = BuildEnv("Data")
local PhaseStateStore = BuildEnv("PhaseStateStore")
local StateBuckets = BuildEnv("StateBuckets")
local Utils = BuildEnv("Utils")

local function ResolveMapExpansionID(mapId, expansionID)
    if expansionID then
        return expansionID
    end
    if Data and Data.GetMap then
        local mapData = Data:GetMap(mapId)
        if type(mapData) == "table" and mapData.expansionID then
            return mapData.expansionID
        end
    end
    if AppContext and AppContext.GetCurrentExpansionID then
        local currentExpansionID = AppContext:GetCurrentExpansionID()
        if currentExpansionID then
            return currentExpansionID
        end
    end
    return "default"
end

local function GetPhaseScopedKey(mapId, expansionID)
    if PhaseStateStore and PhaseStateStore.GetScopedKey then
        return PhaseStateStore:GetScopedKey(mapId, ResolveMapExpansionID(mapId, expansionID))
    end
    return tostring(ResolveMapExpansionID(mapId, expansionID)) .. ":" .. tostring(mapId)
end

local function GetObservedPhaseHistoryStore()
    if StateBuckets and StateBuckets.GetObservedPhaseHistory then
        return StateBuckets:GetObservedPhaseHistory()
    end
    local uiDB = AppContext and AppContext.EnsureUIState and AppContext:EnsureUIState() or {}
    if type(uiDB.observedPhaseHistory) ~= "table" then
        uiDB.observedPhaseHistory = {}
    end
    return uiDB.observedPhaseHistory
end

local function PopulatePhaseColor(outColor, r, g, b)
    outColor.r = r
    outColor.g = g
    outColor.b = b
    return outColor
end

local function ResolveCurrentActualPhaseInfo(manager, mapId, outInfo)
    if not manager or type(outInfo) ~= "table" then
        return nil
    end
    local info = manager.GetCurrentPhaseInfoInto and manager:GetCurrentPhaseInfoInto(mapId, outInfo) or nil
    if type(info) ~= "table" then
        return nil
    end
    if info.isTemporary ~= true then
        return nil
    end
    if info.source ~= manager.PhaseSource.PHASE_DETECTION then
        return nil
    end
    if type(info.phaseId) ~= "string" or info.phaseId == "" then
        return nil
    end
    return info
end

function UnifiedPhaseDisplayService:GetObservedHistoricalPhase(manager, mapId)
    if type(mapId) ~= "number" then
        return nil
    end

    local historyStore = GetObservedPhaseHistoryStore()
    local history = historyStore and historyStore[GetPhaseScopedKey(mapId)] or nil
    return type(history) == "table"
        and type(history.phaseId) == "string"
        and history.phaseId ~= ""
        and history.phaseId
        or nil
end

function UnifiedPhaseDisplayService:GetObservedHistoricalPhaseRecordInto(manager, mapId, outRecord)
    if type(mapId) ~= "number" or type(outRecord) ~= "table" then
        return nil
    end

    outRecord.mapId = mapId
    outRecord.expansionID = ResolveMapExpansionID(mapId)
    outRecord.phaseId = nil
    outRecord.observedAt = nil

    local historyStore = GetObservedPhaseHistoryStore()
    local history = historyStore and historyStore[GetPhaseScopedKey(mapId)] or nil
    if type(history) ~= "table"
        or type(history.phaseId) ~= "string"
        or history.phaseId == "" then
        return nil
    end

    outRecord.phaseId = history.phaseId
    outRecord.observedAt = tonumber(history.observedAt) or nil
    return outRecord
end

function UnifiedPhaseDisplayService:PersistObservedHistoricalPhase(manager, mapId, phaseId, observedAt)
    if type(mapId) ~= "number" then
        return false
    end

    local historyStore = GetObservedPhaseHistoryStore()
    if type(historyStore) ~= "table" then
        return false
    end

    local scopedKey = GetPhaseScopedKey(mapId)
    if type(phaseId) ~= "string" or phaseId == "" then
        historyStore[scopedKey] = nil
        return true
    end

    historyStore[scopedKey] = {
        mapId = mapId,
        expansionID = ResolveMapExpansionID(mapId),
        phaseId = phaseId,
        observedAt = tonumber(observedAt) or Utils:GetCurrentTimestamp(),
    }
    return true
end

function UnifiedPhaseDisplayService:ComparePhasesInto(manager, mapId, outResult)
    if not manager or not manager.isInitialized or type(outResult) ~= "table" then
        return nil
    end

    outResult.currentPhaseInfo = outResult.currentPhaseInfo or {}
    outResult.sharedRecord = outResult.sharedRecord or {}
    outResult.latestSharedRecord = outResult.latestSharedRecord or {}

    local currentPhaseInfo = ResolveCurrentActualPhaseInfo(manager, mapId, outResult.currentPhaseInfo)
    local currentPhase = currentPhaseInfo and currentPhaseInfo.phaseId or nil
    local persistentPhase = manager.GetPersistentPhase and manager:GetPersistentPhase(mapId) or nil
    local historicalPhase = self:GetObservedHistoricalPhase(manager, mapId)
    local sharedRecord = nil
    if type(currentPhase) == "string" and manager.GetSharedPhaseTimeRecordInto then
        sharedRecord = manager:GetSharedPhaseTimeRecordInto(mapId, currentPhase, outResult.sharedRecord)
    end
    local latestSharedRecord = manager.GetLatestSharedPhaseRecordForMapInto
        and manager:GetLatestSharedPhaseRecordForMapInto(mapId, outResult.latestSharedRecord)
        or nil

    local persistentMatches = type(currentPhase) == "string"
        and type(persistentPhase) == "string"
        and persistentPhase == currentPhase
    local sharedMatches = type(sharedRecord) == "table"
        and type(sharedRecord.phaseID) == "string"
        and sharedRecord.phaseID == currentPhase

    local baselinePhase = nil
    local baselineSource = nil
    if persistentMatches then
        baselinePhase = persistentPhase
        baselineSource = "persistent"
    elseif sharedMatches then
        baselinePhase = currentPhase
        baselineSource = "shared"
    elseif type(persistentPhase) == "string" and persistentPhase ~= "" then
        baselinePhase = persistentPhase
        baselineSource = "persistent"
    elseif latestSharedRecord and type(latestSharedRecord.phaseID) == "string" and latestSharedRecord.phaseID ~= "" then
        baselinePhase = latestSharedRecord.phaseID
        baselineSource = "shared"
    end

    outResult.match = false
    outResult.current = currentPhase
    outResult.persistent = persistentPhase
    outResult.historical = historicalPhase
    outResult.shared = sharedMatches and currentPhase or nil
    outResult.latestShared = latestSharedRecord and latestSharedRecord.phaseID or nil
    outResult.baseline = baselinePhase
    outResult.baselineSource = baselineSource
    outResult.matchSource = nil
    outResult.status = "unknown"

    if not currentPhase and not baselinePhase then
        outResult.status = "no_data"
    elseif not currentPhase then
        outResult.status = "no_current"
    elseif persistentMatches then
        outResult.match = true
        outResult.matchSource = "persistent"
        outResult.status = "match"
    elseif sharedMatches then
        outResult.match = true
        outResult.matchSource = "shared"
        outResult.status = "match"
    else
        outResult.match = false
        outResult.status = "mismatch"
    end

    return outResult
end

function UnifiedPhaseDisplayService:GetPhaseDisplayInfoInto(manager, mapId, outInfo, comparisonBuffer)
    if not manager or not manager.isInitialized or type(outInfo) ~= "table" then
        return nil
    end

    local comparison = self:ComparePhasesInto(manager, mapId, comparisonBuffer or outInfo.__ctkComparisonBuffer or {})
    outInfo.__ctkComparisonBuffer = comparisonBuffer or outInfo.__ctkComparisonBuffer or comparison
    if not comparison then
        return nil
    end

    outInfo.color = outInfo.color or {}
    outInfo.phaseId = comparison.current or comparison.baseline or "未知"
    outInfo.status = "未知"
    outInfo.tooltip = ""
    outInfo.compareStatus = comparison.status
    outInfo.currentPhaseID = comparison.current
    outInfo.persistentPhaseID = comparison.persistent
    outInfo.historicalPhaseID = comparison.historical
    outInfo.sharedPhaseID = comparison.shared
    outInfo.latestSharedPhaseID = comparison.latestShared
    outInfo.baselinePhaseID = comparison.baseline
    outInfo.baselineSource = comparison.baselineSource
    PopulatePhaseColor(outInfo.color, 1, 1, 1)

    local baselineLabel = comparison.baselineSource == "shared" and "共享空投位面" or "持久化空投位面"

    if comparison.status == "match" then
        PopulatePhaseColor(outInfo.color, 0, 1, 0)
        outInfo.status = "匹配"
        outInfo.tooltip = string.format("当前实际位面：%s\n%s：%s\n状态：匹配", comparison.current, baselineLabel, comparison.baseline)
    elseif comparison.status == "mismatch" then
        PopulatePhaseColor(outInfo.color, 1, 0, 0)
        outInfo.status = "不匹配"
        if type(comparison.persistent) == "string" and comparison.persistent ~= "" and type(comparison.latestShared) == "string" and comparison.latestShared ~= "" then
            outInfo.tooltip = string.format(
                "当前实际位面：%s\n持久化空投位面：%s\n共享空投位面：%s\n状态：不匹配",
                comparison.current,
                comparison.persistent,
                comparison.latestShared
            )
        elseif type(comparison.persistent) == "string" and comparison.persistent ~= "" then
            outInfo.tooltip = string.format("当前实际位面：%s\n持久化空投位面：%s\n状态：不匹配", comparison.current, comparison.persistent)
        elseif type(comparison.latestShared) == "string" and comparison.latestShared ~= "" then
            outInfo.tooltip = string.format("当前实际位面：%s\n共享空投位面：%s\n状态：不匹配", comparison.current, comparison.latestShared)
        else
            outInfo.tooltip = string.format("当前实际位面：%s\n空投位面：无\n状态：不匹配", comparison.current)
        end
    elseif comparison.status == "no_data" then
        outInfo.status = "无数据"
        outInfo.tooltip = "无位面数据"
    elseif comparison.status == "no_current" then
        outInfo.status = "无当前位面"
        if type(comparison.persistent) == "string" and comparison.persistent ~= "" and type(comparison.latestShared) == "string" and comparison.latestShared ~= "" then
            outInfo.tooltip = string.format("当前实际位面：未检测到\n持久化空投位面：%s\n共享空投位面：%s", comparison.persistent, comparison.latestShared)
        elseif type(comparison.baseline) == "string" and comparison.baseline ~= "" then
            outInfo.tooltip = string.format("%s：%s\n当前实际位面：未检测到", baselineLabel, comparison.baseline)
        else
            outInfo.tooltip = "当前实际位面：未检测到"
        end
        outInfo.phaseId = comparison.baseline
    end

    return outInfo
end

return UnifiedPhaseDisplayService
