-- TimeStateStore.lua - 统一时间状态存储

local TimeStateStore = BuildEnv("TimeStateStore")
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

local function CreateTimeData(mapId)
    return {
        mapId = mapId,
        temporaryTime = nil,
    }
end

function TimeStateStore:GetScopedKey(mapId, expansionID)
    return BuildScopedMapKey(mapId, expansionID)
end

function TimeStateStore:GetOrCreate(manager, mapId, expansionID)
    local scopedKey = BuildScopedMapKey(mapId, expansionID)
    manager.temporaryTimes = manager.temporaryTimes or {}
    if not manager.temporaryTimes[scopedKey] then
        manager.temporaryTimes[scopedKey] = CreateTimeData(mapId)
    end
    return manager.temporaryTimes[scopedKey]
end

function TimeStateStore:GetValidTemporary(manager, mapId, currentTime, expansionID)
    local scopedKey = BuildScopedMapKey(mapId, expansionID)
    local timeData = manager.temporaryTimes and manager.temporaryTimes[scopedKey]
    if not timeData or not timeData.temporaryTime then
        return nil
    end

    local now = currentTime or time()
    local record = timeData.temporaryTime
    if now - record.setTime <= manager.TEMPORARY_TIME_EXPIRE then
        return record
    end

    timeData.temporaryTime = nil
    return nil
end

function TimeStateStore:ClearTemporary(manager, mapId, expansionID)
    local scopedKey = BuildScopedMapKey(mapId, expansionID)
    if manager.temporaryTimes and manager.temporaryTimes[scopedKey] then
        manager.temporaryTimes[scopedKey].temporaryTime = nil
    end
end

function TimeStateStore:SetTemporary(manager, mapId, timestamp, source, setTime, expansionID)
    local timeData = self:GetOrCreate(manager, mapId, expansionID)
    local temporaryTime = timeData.temporaryTime
    if not temporaryTime then
        temporaryTime = {}
        timeData.temporaryTime = temporaryTime
    end
    temporaryTime.timestamp = timestamp
    temporaryTime.source = source
    temporaryTime.setTime = setTime or time()
    return timeData
end

function TimeStateStore:CalculateNextRefreshTime(lastRefresh, interval, currentTime)
    if not lastRefresh or not interval or interval <= 0 then
        return nil
    end

    local now = currentTime or time()
    if now <= lastRefresh then
        return lastRefresh + interval
    end

    local cycles = math.ceil((now - lastRefresh) / interval)
    if cycles < 1 then
        cycles = 1
    end

    return lastRefresh + cycles * interval
end

return TimeStateStore
