-- UnifiedDataDisplayResolver.lua - 统一时间显示与事件时间仲裁服务

local UnifiedDataDisplayResolver = BuildEnv("UnifiedDataDisplayResolver")
local AppContext = BuildEnv("AppContext")
local AirdropEventService = BuildEnv("AirdropEventService")
local Data = BuildEnv("Data")
local TimeStateStore = BuildEnv("TimeStateStore")
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

local function GetTimeScopedKey(mapId, expansionID)
    if TimeStateStore and TimeStateStore.GetScopedKey then
        return TimeStateStore:GetScopedKey(mapId, ResolveMapExpansionID(mapId, expansionID))
    end
    return tostring(ResolveMapExpansionID(mapId, expansionID)) .. ":" .. tostring(mapId)
end

local function IsPlayerCurrentlyOnTrackedMap(mapId)
    if type(mapId) ~= "number" then
        return false
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil
    if type(mapData) ~= "table" or type(mapData.mapID) ~= "number" then
        return false
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    return currentMapID == mapData.mapID
end

local function CanUseTemporaryRecordForPhase(manager, mapId, phaseId, tempRecord)
    if type(tempRecord) ~= "table" then
        return false
    end
    if type(phaseId) ~= "string" or phaseId == "" then
        return true
    end

    if type(tempRecord.phaseId) == "string" and tempRecord.phaseId ~= "" then
        return tempRecord.phaseId == phaseId
    end

    local sharedStateByMap = manager and manager.sharedDisplayStateByMap or nil
    local state = type(sharedStateByMap) == "table" and sharedStateByMap[mapId] or nil
    local phaseChangedAt = type(state) == "table" and tonumber(state.phaseChangedAt) or nil
    if type(phaseChangedAt) ~= "number" then
        return true
    end

    local setTime = tonumber(tempRecord.setTime)
    if type(setTime) ~= "number" then
        return true
    end

    return setTime >= phaseChangedAt
end

local function AssignDisplayTime(outDisplayTime, record, isPersistent)
    if type(outDisplayTime) ~= "table" or type(record) ~= "table" then
        return nil
    end

    outDisplayTime.time = record.timestamp
    outDisplayTime.source = record.source
    outDisplayTime.isPersistent = isPersistent == true
    outDisplayTime.timeType = record.timeType
    return outDisplayTime
end

local function ResetDisplayTime(outDisplayTime)
    if type(outDisplayTime) ~= "table" then
        return nil
    end

    outDisplayTime.time = nil
    outDisplayTime.source = nil
    outDisplayTime.isPersistent = nil
    outDisplayTime.timeType = nil
    return outDisplayTime
end

local function ReleaseSharedDisplay(manager, mapId)
    if manager and manager.OnSharedDisplayReleased then
        manager:OnSharedDisplayReleased(mapId)
    end
end

local function ActivateSharedDisplay(manager, mapId, currentPhaseID, sharedRecord, outDisplayTime)
    if type(outDisplayTime) ~= "table" or type(sharedRecord) ~= "table" then
        return nil
    end

    outDisplayTime.time = sharedRecord.timestamp
    outDisplayTime.source = sharedRecord.source or manager.TimeSource.PUBLIC_CHANNEL_SYNC
    outDisplayTime.isPersistent = false
    outDisplayTime.timeType = sharedRecord.timeType
    if manager and manager.OnSharedDisplayActivated then
        manager:OnSharedDisplayActivated(mapId, currentPhaseID, sharedRecord)
    end
    return outDisplayTime
end

local function BuildEventTimeCandidate(timestamp, source, timeType, objectGUID)
    if AirdropEventService and AirdropEventService.BuildEventTimeCandidate then
        return AirdropEventService:BuildEventTimeCandidate(timestamp, source, timeType, objectGUID)
    end
    local resolvedTimestamp = tonumber(timestamp)
    if type(resolvedTimestamp) ~= "number" then
        return nil
    end
    return {
        timestamp = resolvedTimestamp,
        source = source,
        timeType = timeType,
        objectGUID = objectGUID,
    }
end

local function SelectPreferredSameEventCandidate(currentCandidate, incomingCandidate)
    if AirdropEventService and AirdropEventService.SelectPreferredSameEventCandidate then
        return AirdropEventService:SelectPreferredSameEventCandidate(currentCandidate, incomingCandidate)
    end
    return currentCandidate or incomingCandidate
end

local function SelectLatestLocalDisplayRecord(tempRecord, persistentRecord)
    if tempRecord and persistentRecord then
        if tempRecord.timestamp > persistentRecord.timestamp then
            return tempRecord, false
        end
        return persistentRecord, true
    end
    if persistentRecord then
        return persistentRecord, true
    end
    if tempRecord then
        return tempRecord, false
    end
    return nil, nil
end

local function SelectLatestPhaseMatchedLocalRecord(tempRecord, tempRecordMatchesCurrentPhase, persistentRecord, persistentMatchesCurrentPhase)
    return SelectLatestLocalDisplayRecord(
        tempRecordMatchesCurrentPhase == true and tempRecord or nil,
        persistentMatchesCurrentPhase == true and persistentRecord or nil
    )
end

local function GetActiveTemporaryTimeRecord(manager, timeData, now)
    if not manager or type(timeData) ~= "table" or type(timeData.temporaryTime) ~= "table" then
        return nil
    end

    local temporaryTime = timeData.temporaryTime
    if now - temporaryTime.setTime <= manager.TEMPORARY_TIME_EXPIRE then
        return temporaryTime
    end

    timeData.temporaryTime = nil
    return nil
end

local function ResolveLocalDisplay(manager, mapId, tempRecord, persistentRecord, outDisplayTime)
    local localRecord, isPersistent = SelectLatestLocalDisplayRecord(tempRecord, persistentRecord)
    if not localRecord then
        ReleaseSharedDisplay(manager, mapId)
        return nil
    end

    AssignDisplayTime(outDisplayTime, localRecord, isPersistent == true)
    ReleaseSharedDisplay(manager, mapId)
    return outDisplayTime
end

local function ResolvePhaseScopedDisplay(manager, mapId, currentPhaseID, tempRecord, persistentRecord, sharedRecord, outDisplayTime)
    local phaseTransitionEligible = manager.CanUseSharedDisplayForPhase
        and manager:CanUseSharedDisplayForPhase(mapId, currentPhaseID) == true
    local tempRecordMatchesCurrentPhase = CanUseTemporaryRecordForPhase(manager, mapId, currentPhaseID, tempRecord)
    local persistentMatchesCurrentPhase = persistentRecord
        and type(persistentRecord.phaseId) == "string"
        and persistentRecord.phaseId == currentPhaseID
    local currentPhaseRecord, currentPhaseIsPersistent = SelectLatestPhaseMatchedLocalRecord(
        tempRecord,
        tempRecordMatchesCurrentPhase,
        persistentRecord,
        persistentMatchesCurrentPhase
    )
    local hasLocalCurrentPhaseSource = currentPhaseRecord ~= nil
    local shouldTrySharedDisplay = (not hasLocalCurrentPhaseSource) or phaseTransitionEligible

    if currentPhaseRecord then
        AssignDisplayTime(outDisplayTime, currentPhaseRecord, currentPhaseIsPersistent == true)
        ReleaseSharedDisplay(manager, mapId)
        return outDisplayTime
    end

    if sharedRecord and shouldTrySharedDisplay then
        return ActivateSharedDisplay(manager, mapId, currentPhaseID, sharedRecord, outDisplayTime)
    end

    return ResolveLocalDisplay(manager, mapId, tempRecord, persistentRecord, outDisplayTime)
end

function UnifiedDataDisplayResolver:CanUseTemporaryRecordForPhase(manager, mapId, phaseId, tempRecord)
    return CanUseTemporaryRecordForPhase(manager, mapId, phaseId, tempRecord)
end

function UnifiedDataDisplayResolver:SelectEventTimestamp(manager, mapId, detectionTimestamp, currentPhaseId, detectedObjectGUID)
    local fallback = detectionTimestamp or Utils:GetCurrentTimestamp()
    local record = manager and manager.GetValidTemporaryTime and manager:GetValidTemporaryTime(mapId) or nil
    local function IsAuthoritativeSource(source)
        return manager
            and manager.IsAuthoritativeTimeSource
            and manager:IsAuthoritativeTimeSource(source) == true
            or false
    end

    if record then
        if type(currentPhaseId) == "string"
            and currentPhaseId ~= ""
            and not CanUseTemporaryRecordForPhase(manager, mapId, currentPhaseId, record) then
            record = nil
        elseif type(record.objectGUID) == "string"
            and record.objectGUID ~= ""
            and type(detectedObjectGUID) == "string"
            and detectedObjectGUID ~= ""
            and record.objectGUID ~= detectedObjectGUID then
            record = nil
        end
    end

    local selectedCandidate = nil
    if record
        and IsAuthoritativeSource(record.source) == true
        and record.source ~= (manager and manager.TimeSource and manager.TimeSource.NPC_SHOUT or nil) then
        local delta = math.abs(fallback - record.timestamp)
        if delta <= (manager and manager.TEMPORARY_TIME_ADOPTION_WINDOW or 120) then
            selectedCandidate = SelectPreferredSameEventCandidate(
                selectedCandidate,
                BuildEventTimeCandidate(
                    record.timestamp,
                    record.source,
                    record.timeType,
                    record.objectGUID or detectedObjectGUID
                )
            )
        end
    end

    if manager and manager.GetPersistentTimeRecordInto then
        manager.selectEventTimestampPersistentRecordBuffer = manager.selectEventTimestampPersistentRecordBuffer or {}
        local persistentRecord = manager:GetPersistentTimeRecordInto(
            mapId,
            manager.selectEventTimestampPersistentRecordBuffer
        )
        if persistentRecord
            and IsAuthoritativeSource(persistentRecord.source) == true
            and type(persistentRecord.eventTimestamp) == "number" then
            local persistentObjectGUID = type(persistentRecord.objectGUID) == "string" and persistentRecord.objectGUID or nil
            if persistentObjectGUID == nil
                or persistentObjectGUID == ""
                or (type(detectedObjectGUID) == "string" and detectedObjectGUID ~= "" and persistentObjectGUID == detectedObjectGUID) then
                local delta = math.abs(fallback - persistentRecord.eventTimestamp)
                if delta <= (manager and manager.TEMPORARY_TIME_ADOPTION_WINDOW or 120) then
                    selectedCandidate = SelectPreferredSameEventCandidate(
                        selectedCandidate,
                        BuildEventTimeCandidate(
                            persistentRecord.eventTimestamp,
                            persistentRecord.source,
                            persistentRecord.timeType,
                            persistentObjectGUID or detectedObjectGUID
                        )
                    )
                end
            end
        end
    end

    if type(currentPhaseId) == "string"
        and currentPhaseId ~= ""
        and type(detectedObjectGUID) == "string"
        and detectedObjectGUID ~= ""
        and manager
        and manager.GetSharedPhaseTimeRecordInto then
        manager.selectEventTimestampSharedRecordBuffer = manager.selectEventTimestampSharedRecordBuffer or {}
        local sharedRecord = manager:GetSharedPhaseTimeRecordInto(
            mapId,
            currentPhaseId,
            manager.selectEventTimestampSharedRecordBuffer
        )
        if sharedRecord
            and type(sharedRecord.objectGUID) == "string"
            and sharedRecord.objectGUID == detectedObjectGUID
            and type(sharedRecord.timestamp) == "number" then
            selectedCandidate = SelectPreferredSameEventCandidate(
                selectedCandidate,
                BuildEventTimeCandidate(
                    sharedRecord.timestamp,
                    sharedRecord.source or (manager and manager.TimeSource and manager.TimeSource.PUBLIC_CHANNEL_SYNC) or nil,
                    sharedRecord.timeType,
                    sharedRecord.objectGUID
                )
            )
        end
    end

    if type(selectedCandidate) == "table" and type(selectedCandidate.timestamp) == "number" then
        return selectedCandidate.timestamp, selectedCandidate.source, selectedCandidate.timeType
    end
    return fallback, manager and manager.TimeSource and manager.TimeSource.ICON_DETECTION or nil, manager and manager.TimeType and manager.TimeType.ICON_DETECTION or nil
end

function UnifiedDataDisplayResolver:GetDisplayTimeInto(manager, mapId, currentTime, outDisplayTime, persistentRecordBuffer)
    if not manager or not manager.isInitialized or type(outDisplayTime) ~= "table" then
        return nil
    end

    local scopedKey = GetTimeScopedKey(mapId)
    local timeData = scopedKey and manager.temporaryTimes[scopedKey] or nil
    local now = currentTime or Utils:GetCurrentTimestamp()
    local recordBuffer = persistentRecordBuffer or outDisplayTime.__ctkPersistentRecordBuffer or {}
    local persistentRecord = manager.GetPersistentTimeRecordInto and manager:GetPersistentTimeRecordInto(mapId, recordBuffer) or nil
    outDisplayTime.__ctkPersistentRecordBuffer = recordBuffer

    local currentPhaseID = manager.GetCurrentPhase and manager:GetCurrentPhase(mapId) or nil
    local sharedRecordBuffer = outDisplayTime.__ctkSharedRecordBuffer or {}
    local sharedRecord = nil
    if type(currentPhaseID) == "string" and manager.GetSharedPhaseTimeRecordInto then
        sharedRecord = manager:GetSharedPhaseTimeRecordInto(mapId, currentPhaseID, sharedRecordBuffer)
    end
    outDisplayTime.__ctkSharedRecordBuffer = sharedRecordBuffer
    ResetDisplayTime(outDisplayTime)

    local tempRecord = GetActiveTemporaryTimeRecord(manager, timeData, now)
    local isPlayerOnCurrentMap = IsPlayerCurrentlyOnTrackedMap(mapId)
    if not isPlayerOnCurrentMap and manager.ClearSharedDisplayPhaseGate then
        manager:ClearSharedDisplayPhaseGate(mapId)
    end

    if isPlayerOnCurrentMap and type(currentPhaseID) == "string" and currentPhaseID ~= "" then
        return ResolvePhaseScopedDisplay(manager, mapId, currentPhaseID, tempRecord, persistentRecord, sharedRecord, outDisplayTime)
    end

    return ResolveLocalDisplay(manager, mapId, tempRecord, persistentRecord, outDisplayTime)
end

return UnifiedDataDisplayResolver
