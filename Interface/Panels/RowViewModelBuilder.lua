-- RowViewModelBuilder.lua - 主面板行数据组装器

local RowViewModelBuilder = BuildEnv("RowViewModelBuilder")
local StateBuckets = BuildEnv("StateBuckets")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")

local function GetHiddenMaps()
    if Data and Data.GetHiddenMaps then
        return Data:GetHiddenMaps()
    end
    if StateBuckets and StateBuckets.GetHiddenMaps then
        return StateBuckets:GetHiddenMaps()
    end
    return {}
end

local function GetHiddenRemaining()
    if Data and Data.GetHiddenRemaining then
        return Data:GetHiddenRemaining()
    end
    if StateBuckets and StateBuckets.GetHiddenRemaining then
        return StateBuckets:GetHiddenRemaining()
    end
    return {}
end

local function GetHiddenState(mapData, hiddenMaps)
    if not mapData or not hiddenMaps then
        return false
    end
    return hiddenMaps[mapData.mapID] == true
end

local function GetFrozenRemaining(mapData, hiddenRemaining)
    if not mapData or not hiddenRemaining then
        return nil
    end
    local value = hiddenRemaining[mapData.mapID]
    if value and value < 0 then
        value = 0
    end
    return value
end

function RowViewModelBuilder:GetHiddenMaps()
    return GetHiddenMaps()
end

function RowViewModelBuilder:GetHiddenRemaining()
    return GetHiddenRemaining()
end

function RowViewModelBuilder:GetRemainingSeconds(mapData)
    if not mapData then
        return nil
    end

    local hiddenMaps = GetHiddenMaps()
    local hiddenRemaining = GetHiddenRemaining()
    if GetHiddenState(mapData, hiddenMaps) then
        return GetFrozenRemaining(mapData, hiddenRemaining)
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapData.id)
    if remaining ~= nil then
        if remaining < 0 then
            remaining = 0
        end
        return remaining
    end

    if mapData.lastRefresh then
        local now = time()
        if mapData.nextRefresh and mapData.nextRefresh <= now then
            Data:UpdateNextRefresh(mapData.id, mapData)
        end
        if mapData.nextRefresh then
            remaining = mapData.nextRefresh - now
            if remaining < 0 then
                remaining = 0
            end
            return remaining
        end
    end

    return nil
end

function RowViewModelBuilder:BuildRows()
    local rows = {}
    local maps = Data and Data.GetAllMaps and Data:GetAllMaps() or {}
    local now = time()
    local hiddenMaps = GetHiddenMaps()
    local hiddenRemaining = GetHiddenRemaining()

    for index, mapData in ipairs(maps) do
        if mapData then
            local displayTime = UnifiedDataManager and UnifiedDataManager.GetDisplayTime and UnifiedDataManager:GetDisplayTime(mapData.id)
            local remainingTime = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapData.id)
            local nextRefreshTime = UnifiedDataManager and UnifiedDataManager.GetNextRefreshTime and UnifiedDataManager:GetNextRefreshTime(mapData.id)

            if not displayTime and mapData.lastRefresh then
                displayTime = {
                    time = mapData.lastRefresh,
                    source = "icon_detection",
                    isPersistent = true,
                }

                if mapData.nextRefresh and mapData.nextRefresh <= now then
                    Data:UpdateNextRefresh(mapData.id, mapData)
                end

                if mapData.nextRefresh then
                    remainingTime = mapData.nextRefresh - now
                    if remainingTime < 0 then
                        remainingTime = 0
                    end
                end
                nextRefreshTime = mapData.nextRefresh
            end

            local frozenRemaining = (mapData.mapID and hiddenRemaining[mapData.mapID]) or nil
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
                lastRefresh = displayTime and displayTime.time or mapData.lastRefresh,
                nextRefresh = nextRefreshTime or mapData.nextRefresh,
                remainingTime = remainingTime,
                currentPhaseID = mapData.currentPhaseID,
                lastRefreshPhase = mapData.lastRefreshPhase,
                phaseDisplayInfo = phaseDisplayInfo,
                isHidden = hiddenMaps and hiddenMaps[mapData.mapID] or false,
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
