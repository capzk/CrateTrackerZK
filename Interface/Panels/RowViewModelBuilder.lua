-- RowViewModelBuilder.lua - 主面板行数据组装器

local RowViewModelBuilder = BuildEnv("RowViewModelBuilder")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")

local function ClearArray(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

local function ClearMap(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for key in pairs(buffer) do
        buffer[key] = nil
    end
    return buffer
end

local function GetReusableArray(owner, fieldName)
    local buffer = owner[fieldName]
    if not buffer then
        buffer = {}
        owner[fieldName] = buffer
    else
        ClearArray(buffer)
    end
    return buffer
end

local function GetReusableMap(owner, fieldName)
    local buffer = owner[fieldName]
    if not buffer then
        buffer = {}
        owner[fieldName] = buffer
    else
        ClearMap(buffer)
    end
    return buffer
end

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

local function GetHiddenStateById(expansionID, mapID, hiddenMaps)
    if type(mapID) ~= "number" then
        return false
    end

    local resolvedHiddenMaps = hiddenMaps
    if resolvedHiddenMaps == nil then
        resolvedHiddenMaps = GetHiddenMaps(expansionID)
    end

    return resolvedHiddenMaps and resolvedHiddenMaps[mapID] == true or false
end

local function GetFrozenRemainingById(expansionID, mapID, hiddenRemaining)
    if type(mapID) ~= "number" then
        return nil
    end

    local resolvedHiddenRemaining = hiddenRemaining
    if resolvedHiddenRemaining == nil then
        resolvedHiddenRemaining = GetHiddenRemaining(expansionID)
    end

    local value = resolvedHiddenRemaining and resolvedHiddenRemaining[mapID] or nil
    if value and value < 0 then
        value = 0
    end
    return value
end

local function GetHiddenState(mapData, hiddenMaps)
    if not mapData then
        return false
    end
    return GetHiddenStateById(mapData.expansionID, mapData.mapID, hiddenMaps)
end

local function GetFrozenRemaining(mapData, hiddenRemaining)
    if not mapData then
        return nil
    end
    return GetFrozenRemainingById(mapData.expansionID, mapData.mapID, hiddenRemaining)
end

local function ResetPhaseDisplayInfo(phaseDisplayInfo)
    if type(phaseDisplayInfo) ~= "table" then
        phaseDisplayInfo = {}
    end
    phaseDisplayInfo.color = phaseDisplayInfo.color or {}
    phaseDisplayInfo.phaseId = nil
    phaseDisplayInfo.status = nil
    phaseDisplayInfo.tooltip = nil
    phaseDisplayInfo.compareStatus = nil
    phaseDisplayInfo.currentPhaseID = nil
    phaseDisplayInfo.persistentPhaseID = nil
    phaseDisplayInfo.color.r = 1
    phaseDisplayInfo.color.g = 1
    phaseDisplayInfo.color.b = 1
    return phaseDisplayInfo
end

local function ResolveDisplayTime(builder, rowId, now)
    builder.displayTimeBuffer = builder.displayTimeBuffer or {}
    return UnifiedDataManager
        and UnifiedDataManager.GetDisplayTimeInto
        and UnifiedDataManager:GetDisplayTimeInto(rowId, now, builder.displayTimeBuffer)
        or (UnifiedDataManager and UnifiedDataManager.GetDisplayTime and UnifiedDataManager:GetDisplayTime(rowId, now) or nil)
end

local function ResolveTimeMetrics(rowId, now, displayTime)
    local nextRefreshTime = UnifiedDataManager
        and UnifiedDataManager.GetNextRefreshTime
        and UnifiedDataManager:GetNextRefreshTime(rowId, now, displayTime)
        or nil
    local remainingTime = nil

    if type(nextRefreshTime) == "number" then
        remainingTime = nextRefreshTime - now
        if remainingTime < 0 then
            remainingTime = 0
        end
    end

    return nextRefreshTime, remainingTime
end

local function ResolvePhaseDisplayInfo(builder, rowId, rowInfo)
    rowInfo.phaseDisplayInfo = ResetPhaseDisplayInfo(rowInfo.phaseDisplayInfo)
    builder.phaseComparisonBuffer = builder.phaseComparisonBuffer or {}
    local phaseDisplayInfo = UnifiedDataManager
        and UnifiedDataManager.GetPhaseDisplayInfoInto
        and UnifiedDataManager:GetPhaseDisplayInfoInto(rowId, rowInfo.phaseDisplayInfo, builder.phaseComparisonBuffer)
        or (UnifiedDataManager and UnifiedDataManager.GetPhaseDisplayInfo and UnifiedDataManager:GetPhaseDisplayInfo(rowId) or nil)
    if phaseDisplayInfo ~= rowInfo.phaseDisplayInfo and phaseDisplayInfo ~= nil then
        rowInfo.phaseDisplayInfo = phaseDisplayInfo
    end
    return rowInfo.phaseDisplayInfo
end

local function BuildRowInfo(builder, mapData, outRow, now, hiddenMapsByExpansion, hiddenRemainingByExpansion)
    if not mapData then
        return nil
    end

    local rowInfo = type(outRow) == "table" and outRow or {}
    local rowId = mapData.id
    local mapID = mapData.mapID
    local expansionID = mapData.expansionID
    local expansionKey = expansionID
    if expansionKey == nil then
        expansionKey = false
    end

    local hiddenMaps = hiddenMapsByExpansion and hiddenMapsByExpansion[expansionKey] or nil
    if hiddenMaps == nil then
        hiddenMaps = GetHiddenMaps(expansionID)
        if hiddenMapsByExpansion then
            hiddenMapsByExpansion[expansionKey] = hiddenMaps or false
        end
    end
    if hiddenMaps == false then
        hiddenMaps = nil
    end

    local hiddenRemaining = hiddenRemainingByExpansion and hiddenRemainingByExpansion[expansionKey] or nil
    if hiddenRemaining == nil then
        hiddenRemaining = GetHiddenRemaining(expansionID)
        if hiddenRemainingByExpansion then
            hiddenRemainingByExpansion[expansionKey] = hiddenRemaining or false
        end
    end
    if hiddenRemaining == false then
        hiddenRemaining = nil
    end

    local isHidden = GetHiddenState(mapData, hiddenMaps)
    local frozenRemaining = GetFrozenRemaining(mapData, hiddenRemaining)
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or ""
    local displayTime = ResolveDisplayTime(builder, rowId, now)
    local nextRefreshTime, remainingTime = ResolveTimeMetrics(rowId, now, displayTime)
    if frozenRemaining ~= nil then
        remainingTime = frozenRemaining
    end
    if remainingTime and remainingTime < 0 then
        remainingTime = 0
    end

    local phaseDisplayInfo = ResolvePhaseDisplayInfo(builder, rowId, rowInfo)

    local currentPhaseID = phaseDisplayInfo and phaseDisplayInfo.currentPhaseID or nil
    local persistentPhaseID = phaseDisplayInfo and phaseDisplayInfo.persistentPhaseID or nil
    if phaseDisplayInfo == nil and UnifiedDataManager and UnifiedDataManager.GetCurrentPhase then
        currentPhaseID = UnifiedDataManager:GetCurrentPhase(rowId)
        persistentPhaseID = UnifiedDataManager:GetPersistentPhase(rowId)
    end

    local lastRefresh = displayTime and displayTime.time or nil
    local timeSource = displayTime and displayTime.source or nil
    local isPersistent = displayTime and displayTime.isPersistent or false

    rowInfo.rowId = rowId
    rowInfo.mapId = mapID
    rowInfo.mapName = mapName
    rowInfo.lastRefresh = lastRefresh
    rowInfo.nextRefresh = nextRefreshTime
    rowInfo.remainingTime = remainingTime
    rowInfo.currentPhaseID = currentPhaseID
    rowInfo.lastRefreshPhase = persistentPhaseID
    rowInfo.isHidden = isHidden
    rowInfo.isFrozen = frozenRemaining ~= nil
    rowInfo.timeSource = timeSource
    rowInfo.isPersistent = isPersistent
    rowInfo.originalIndex = mapData.listIndex or rowInfo.originalIndex or 0
    return rowInfo
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

function RowViewModelBuilder:BuildRowById(rowId, outRow)
    if not rowId or not Data or not Data.GetMap then
        return nil
    end

    local mapData = Data:GetMap(rowId)
    if not mapData then
        return nil
    end

    local now = Utils:GetCurrentTimestamp()
    local rowCacheById = self.rowCacheById or {}
    self.rowCacheById = rowCacheById
    local hiddenMapsByExpansion = GetReusableMap(self, "singleHiddenMapsByExpansionBuffer")
    local hiddenRemainingByExpansion = GetReusableMap(self, "singleHiddenRemainingByExpansionBuffer")
    local targetRow = type(outRow) == "table" and outRow or rowCacheById[rowId]
    local rowInfo = BuildRowInfo(self, mapData, targetRow, now, hiddenMapsByExpansion, hiddenRemainingByExpansion)
    if rowInfo then
        rowCacheById[rowId] = rowInfo
    end
    return rowInfo
end

function RowViewModelBuilder:BuildRows()
    local rows = GetReusableArray(self, "rowsBuffer")
    local maps = Data and Data.GetAllMaps and Data:GetAllMaps() or {}
    local now = Utils:GetCurrentTimestamp()
    local hiddenMapsByExpansion = GetReusableMap(self, "hiddenMapsByExpansionBuffer")
    local hiddenRemainingByExpansion = GetReusableMap(self, "hiddenRemainingByExpansionBuffer")
    local rowCacheById = self.rowCacheById or {}
    local seenRowIds = GetReusableMap(self, "seenRowIdsBuffer")
    self.rowCacheById = rowCacheById

    local insertIndex = 0
    for _, mapData in ipairs(maps) do
        if mapData then
            local rowId = mapData.id
            local rowInfo = BuildRowInfo(
                self,
                mapData,
                rowCacheById[rowId],
                now,
                hiddenMapsByExpansion,
                hiddenRemainingByExpansion
            )
            rowCacheById[rowId] = rowInfo
            seenRowIds[rowId] = true
            insertIndex = insertIndex + 1
            rows[insertIndex] = rowInfo
        end
    end

    for rowId in pairs(rowCacheById) do
        if not seenRowIds[rowId] then
            rowCacheById[rowId] = nil
        end
    end

    return rows
end

function RowViewModelBuilder:ReleaseCache()
    if self.rowsBuffer then
        ClearArray(self.rowsBuffer)
    end
    if self.rowCacheById then
        ClearMap(self.rowCacheById)
    end
    if self.hiddenMapsByExpansionBuffer then
        ClearMap(self.hiddenMapsByExpansionBuffer)
    end
    if self.hiddenRemainingByExpansionBuffer then
        ClearMap(self.hiddenRemainingByExpansionBuffer)
    end
    if self.singleHiddenMapsByExpansionBuffer then
        ClearMap(self.singleHiddenMapsByExpansionBuffer)
    end
    if self.singleHiddenRemainingByExpansionBuffer then
        ClearMap(self.singleHiddenRemainingByExpansionBuffer)
    end
    if self.seenRowIdsBuffer then
        ClearMap(self.seenRowIdsBuffer)
    end
    if self.displayTimeBuffer then
        ClearMap(self.displayTimeBuffer)
    end
    if self.phaseComparisonBuffer then
        ClearMap(self.phaseComparisonBuffer)
    end
end

return RowViewModelBuilder
