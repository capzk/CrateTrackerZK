-- PhaseStateStore.lua - 统一位面状态存储

local PhaseStateStore = BuildEnv("PhaseStateStore")
local AppContext = BuildEnv("AppContext")

local function GetCurrentExpansionID()
    if AppContext and AppContext.GetCurrentExpansionID then
        local expansionID = AppContext:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    return "default"
end

local function BuildScopedMapKey(mapId)
    return tostring(GetCurrentExpansionID()) .. ":" .. tostring(mapId)
end

local function CreatePhaseData(mapId)
    return {
        mapId = mapId,
        phaseId = nil,
        source = nil,
        detectTime = nil,
    }
end

function PhaseStateStore:GetScopedKey(mapId)
    return BuildScopedMapKey(mapId)
end

function PhaseStateStore:GetOrCreate(manager, mapId, isTemporary)
    local scopedKey = BuildScopedMapKey(mapId)
    local storage = isTemporary and manager.temporaryPhases or manager.persistentPhases
    if not storage[scopedKey] then
        storage[scopedKey] = CreatePhaseData(mapId)
    end
    return storage[scopedKey]
end

function PhaseStateStore:SetTemporary(manager, mapId, phaseId, source, detectTime, phaseCache)
    local phaseData = self:GetOrCreate(manager, mapId, true)
    phaseData.phaseId = phaseId
    phaseData.source = source
    phaseData.detectTime = detectTime or time()

    if type(phaseCache) == "table" then
        phaseCache[BuildScopedMapKey(mapId)] = {
            mapId = mapId,
            phaseId = phaseId,
            detectTime = phaseData.detectTime,
        }
    end

    return phaseData
end

function PhaseStateStore:SetPersistent(manager, mapId, phaseId, source, detectTime)
    local phaseData = self:GetOrCreate(manager, mapId, false)
    phaseData.phaseId = phaseId
    phaseData.source = source
    phaseData.detectTime = detectTime or time()
    return phaseData
end

function PhaseStateStore:GetCurrent(manager, mapId, currentTime)
    local scopedKey = BuildScopedMapKey(mapId)
    local tempPhase = manager.temporaryPhases and manager.temporaryPhases[scopedKey]
    if tempPhase and tempPhase.phaseId then
        local now = currentTime or time()
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

function PhaseStateStore:GetPersistent(manager, mapId)
    local scopedKey = BuildScopedMapKey(mapId)
    local persistentPhase = manager.persistentPhases and manager.persistentPhases[scopedKey]
    if persistentPhase and persistentPhase.phaseId then
        return persistentPhase.phaseId
    end
    return nil
end

return PhaseStateStore
