-- RowViewModelBuilder.lua - 主面板行数据组装器

local RowViewModelBuilder = BuildEnv("RowViewModelBuilder")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")

local function GetHiddenMaps(expansionID)
    if Data and Data.GetHiddenMaps then
        return Data:GetHiddenMaps(expansionID)
    end
    return {}
end

local function GetHiddenRemaining(expansionID)
    if Data and Data.GetHiddenRemaining then
        return Data:GetHiddenRemaining(expansionID)
    end
    return {}
end

local function GetHiddenState(mapData)
    if not mapData then
        return false
    end
    if Data and Data.IsMapHidden then
        return Data:IsMapHidden(mapData.expansionID, mapData.mapID)
    end
    return false
end

local function GetFrozenRemaining(mapData)
    if not mapData then
        return nil
    end
    local value = Data and Data.GetHiddenRemainingValue and Data:GetHiddenRemainingValue(mapData.expansionID, mapData.mapID) or nil
    if value and value < 0 then
        value = 0
    end
    return value
end

function RowViewModelBuilder:GetHiddenMaps(expansionID)
    return GetHiddenMaps(expansionID)
end

function RowViewModelBuilder:GetHiddenRemaining(expansionID)
    return GetHiddenRemaining(expansionID)
end

function RowViewModelBuilder:GetRemainingSeconds(mapData)
    if not mapData then
        return nil
    end

    if GetHiddenState(mapData) then
        return GetFrozenRemaining(mapData)
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapData.id)
    if remaining ~= nil then
        if remaining < 0 then
            remaining = 0
        end
        return remaining
    end

    return nil
end

function RowViewModelBuilder:BuildRows()
    local rows = {}
    local maps = Data and Data.GetAllMaps and Data:GetAllMaps() or {}
    local now = time()
    for index, mapData in ipairs(maps) do
        if mapData then
            local displayTime = UnifiedDataManager and UnifiedDataManager.GetDisplayTime and UnifiedDataManager:GetDisplayTime(mapData.id, now)
            local remainingTime = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapData.id, now, displayTime)
            local nextRefreshTime = UnifiedDataManager and UnifiedDataManager.GetNextRefreshTime and UnifiedDataManager:GetNextRefreshTime(mapData.id, now, displayTime)

            local frozenRemaining = GetFrozenRemaining(mapData)
            if frozenRemaining ~= nil then
                remainingTime = frozenRemaining
            end
            if remainingTime and remainingTime < 0 then
                remainingTime = 0
            end

            local phaseDisplayInfo = UnifiedDataManager and UnifiedDataManager.GetPhaseDisplayInfo and UnifiedDataManager:GetPhaseDisplayInfo(mapData.id)

            table.insert(rows, {
                rowId = mapData.id,
                mapId = mapData.mapID,
                mapName = Data:GetMapDisplayName(mapData),
                lastRefresh = displayTime and displayTime.time or nil,
                nextRefresh = nextRefreshTime,
                remainingTime = remainingTime,
                currentPhaseID = UnifiedDataManager and UnifiedDataManager.GetCurrentPhase and UnifiedDataManager:GetCurrentPhase(mapData.id) or nil,
                lastRefreshPhase = UnifiedDataManager and UnifiedDataManager.GetPersistentPhase and UnifiedDataManager:GetPersistentPhase(mapData.id) or nil,
                phaseDisplayInfo = phaseDisplayInfo,
                isHidden = GetHiddenState(mapData),
                isFrozen = frozenRemaining ~= nil,
                timeSource = displayTime and displayTime.source or nil,
                isPersistent = displayTime and displayTime.isPersistent or false,
                originalIndex = index,
            })
        end
    end

    return rows
end

return RowViewModelBuilder
