-- PhaseStateStore.lua - 统一位面状态存储

local PhaseStateStore = BuildEnv("PhaseStateStore")
local AppContext = BuildEnv("AppContext")
local Data = BuildEnv("Data")

local function ResolveExpansionID(mapId, expansionID)
    if expansionID then
        return expansionID
    end
    if Data and Data.GetMap then
        local mapData = Data:GetMap(mapId)
        if mapData and mapData.expansionID then
            return mapData.expansionID
        end
    end
    if AppContext and AppContext.GetCurrentExpansionID then
        local expansionID = AppContext:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    return "default"
end

local function BuildScopedMapKey(mapId, expansionID)
    return tostring(ResolveExpansionID(mapId, expansionID)) .. ":" .. tostring(mapId)
end

local function ParseScopedMapKey(scopedKey)
    if type(scopedKey) ~= "string" then
        return nil, nil
    end
    local expansionID, mapId = scopedKey:match("^([^:]+):(.+)$")
    return expansionID, tonumber(mapId) or mapId
end

local function CreatePhaseData(mapId)
    return {
        mapId = mapId,
        phaseId = nil,
        source = nil,
        detectTime = nil,
    }
end

function PhaseStateStore:GetScopedKey(mapId, expansionID)
    return BuildScopedMapKey(mapId, expansionID)
end

function PhaseStateStore:GetOrCreate(manager, mapId, isTemporary, expansionID)
    local scopedKey = BuildScopedMapKey(mapId, expansionID)
    local storage = isTemporary and manager.temporaryPhases or manager.persistentPhases
    if not storage[scopedKey] then
        storage[scopedKey] = CreatePhaseData(mapId)
    end
    return storage[scopedKey]
end

function PhaseStateStore:SetTemporary(manager, mapId, phaseId, source, detectTime, phaseCache, expansionID)
    local resolvedExpansionID = ResolveExpansionID(mapId, expansionID)
    local phaseData = self:GetOrCreate(manager, mapId, true, resolvedExpansionID)
    phaseData.phaseId = phaseId
    phaseData.source = source
    phaseData.detectTime = detectTime or Utils:GetCurrentTimestamp()

    if type(phaseCache) == "table" then
        phaseCache[BuildScopedMapKey(mapId, resolvedExpansionID)] = {
            mapId = mapId,
            expansionID = resolvedExpansionID,
            phaseId = phaseId,
            detectTime = phaseData.detectTime,
        }
    end

    return phaseData
end

function PhaseStateStore:SetPersistent(manager, mapId, phaseId, source, detectTime, expansionID)
    local phaseData = self:GetOrCreate(manager, mapId, false, expansionID)
    phaseData.phaseId = phaseId
    phaseData.source = source
    phaseData.detectTime = detectTime or Utils:GetCurrentTimestamp()
    return phaseData
end

function PhaseStateStore:GetCurrent(manager, mapId, currentTime, expansionID)
    local scopedKey = BuildScopedMapKey(mapId, expansionID)
    local tempPhase = manager.temporaryPhases and manager.temporaryPhases[scopedKey]
    if tempPhase and tempPhase.phaseId then
        local now = currentTime or Utils:GetCurrentTimestamp()
        if now - tempPhase.detectTime <= manager.TEMPORARY_PHASE_EXPIRE then
            return tempPhase.phaseId
        end
        tempPhase.phaseId = nil
        tempPhase.source = nil
        tempPhase.detectTime = nil
    end

    local persistentPhase = manager.persistentPhases and manager.persistentPhases[scopedKey]
    if persistentPhase and persistentPhase.phaseId then
        return persistentPhase.phaseId
    end

    return nil
end

function PhaseStateStore:GetPersistent(manager, mapId, expansionID)
    local scopedKey = BuildScopedMapKey(mapId, expansionID)
    local persistentPhase = manager.persistentPhases and manager.persistentPhases[scopedKey]
    if persistentPhase and persistentPhase.phaseId then
        return persistentPhase.phaseId
    end
    return nil
end

function PhaseStateStore:ParseScopedKey(scopedKey)
    return ParseScopedMapKey(scopedKey)
end

return PhaseStateStore
