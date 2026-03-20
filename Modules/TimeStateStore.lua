-- TimeStateStore.lua - 统一时间状态存储

local TimeStateStore = BuildEnv("TimeStateStore")
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

local function CreateTimeData(mapId)
    return {
        mapId = mapId,
        temporaryTime = nil,
        persistentTime = nil,
    }
end

function TimeStateStore:GetScopedKey(mapId)
    return BuildScopedMapKey(mapId)
end

function TimeStateStore:GetOrCreate(manager, mapId)
    local scopedKey = BuildScopedMapKey(mapId)
    manager.temporaryTimes = manager.temporaryTimes or {}
    if not manager.temporaryTimes[scopedKey] then
        manager.temporaryTimes[scopedKey] = CreateTimeData(mapId)
    end
    return manager.temporaryTimes[scopedKey]
end

function TimeStateStore:GetValidTemporary(manager, mapId, currentTime)
    local scopedKey = BuildScopedMapKey(mapId)
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

function TimeStateStore:ClearTemporary(manager, mapId)
    local scopedKey = BuildScopedMapKey(mapId)
    if manager.temporaryTimes and manager.temporaryTimes[scopedKey] then
        manager.temporaryTimes[scopedKey].temporaryTime = nil
    end
end

function TimeStateStore:SetTemporary(manager, mapId, timestamp, source, setTime)
    local timeData = self:GetOrCreate(manager, mapId)
    timeData.temporaryTime = {
        timestamp = timestamp,
        source = source,
        setTime = setTime or time(),
    }
    return timeData
end

function TimeStateStore:SetPersistent(manager, mapId, timestamp, source, phaseId)
    local timeData = self:GetOrCreate(manager, mapId)
    timeData.persistentTime = {
        timestamp = timestamp,
        source = source,
        phaseId = phaseId,
    }
    if timeData.temporaryTime then
        timeData.temporaryTime = nil
    end
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
