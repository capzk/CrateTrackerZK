-- TableSystems.lua - 表格系统（排序 + 倒计时）

local UIConfig = BuildEnv("ThemeConfig")

-- ========================================
-- 排序系统
-- ========================================
local SortingSystem = BuildEnv("SortingSystem")

local sortState = "default"
local originalRows = {}
local currentRows = {}
local headerButton = nil
local lastSortTime = nil
local rebuildCallback = nil
local compactAutoSortEnabled = false
local compactAutoSortPreviousState = nil
local sortValidationRemainingCache = {}

local function GetSortingConfig()
    return UIConfig
end

local function ClearArray(buffer)
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

local function ClearMap(buffer)
    for key in pairs(buffer) do
        buffer[key] = nil
    end
    return buffer
end

local function CopyRows(source, target)
    ClearArray(target)
    if not source then
        return target
    end

    for index = 1, #source do
        target[index] = source[index]
    end
    return target
end

function SortingSystem:SetRebuildCallback(callback)
    rebuildCallback = callback
end

function SortingSystem:GetSortState()
    return sortState
end

function SortingSystem:IsCompactAutoSortEnabled()
    return compactAutoSortEnabled == true
end

function SortingSystem:SetHeaderButton(button)
    headerButton = button
end

function SortingSystem:GetLastSortTime()
    return lastSortTime
end

function SortingSystem:SetLastSortTime(value)
    lastSortTime = value
end

local function SetSortState(state)
    sortState = state
end

local function CycleSortState()
    if sortState == "default" then
        SetSortState("desc")
    elseif sortState == "desc" then
        SetSortState("asc")
    else
        SetSortState("default")
    end
end

local function CompareRows(a, b, ascending)
    if not a or not b then
        return false
    end

    if a.isHidden and not b.isHidden then
        return false
    elseif not a.isHidden and b.isHidden then
        return true
    elseif a.isHidden and b.isHidden then
        return (a.originalIndex or 0) < (b.originalIndex or 0)
    end

    local aValue = a.remainingTime
    local bValue = b.remainingTime

    if aValue == nil and bValue == nil then
        return (a.originalIndex or 0) < (b.originalIndex or 0)
    elseif aValue == nil then
        return false
    elseif bValue == nil then
        return true
    end

    if ascending then
        return aValue < bValue
    end

    return aValue > bValue
end

function SortingSystem:SetOriginalRows(rows)
    originalRows = rows or {}
    CopyRows(originalRows, currentRows)
end

function SortingSystem:GetCurrentRows()
    return currentRows
end

local function FindRowById(buffer, rowId)
    if rowId == nil then
        return nil, nil
    end

    for index = 1, #buffer do
        local rowInfo = buffer[index]
        if rowInfo and rowInfo.rowId == rowId then
            return rowInfo, index
        end
    end

    return nil, nil
end

function SortingSystem:GetRowData(rowId)
    local rowInfo = FindRowById(currentRows, rowId)
    if rowInfo then
        return rowInfo
    end

    rowInfo = FindRowById(originalRows, rowId)
    return rowInfo
end

function SortingSystem:ReplaceRow(rowId, rowInfo)
    if rowId == nil or not rowInfo then
        return false
    end

    local replaced = false
    local _, index = FindRowById(originalRows, rowId)
    if index then
        originalRows[index] = rowInfo
        replaced = true
    end

    _, index = FindRowById(currentRows, rowId)
    if index then
        currentRows[index] = rowInfo
        replaced = true
    end

    return replaced
end

function SortingSystem:SortRows()
    if sortState == "default" then
        ClearArray(currentRows)
        local insertIndex = 0

        for rowIndex = 1, #originalRows do
            local rowInfo = originalRows[rowIndex]
            if rowInfo and not rowInfo.isHidden then
                insertIndex = insertIndex + 1
                currentRows[insertIndex] = rowInfo
            end
        end

        for rowIndex = 1, #originalRows do
            local rowInfo = originalRows[rowIndex]
            if rowInfo and rowInfo.isHidden then
                insertIndex = insertIndex + 1
                currentRows[insertIndex] = rowInfo
            end
        end
        return
    end

    local ascending = sortState == "asc"
    local success = pcall(function()
        table.sort(currentRows, function(a, b)
            return CompareRows(a, b, ascending)
        end)
    end)

    if not success then
        sortState = "default"
        SortingSystem:SortRows()
    end
end

function SortingSystem:UpdateHeaderVisual()
    if not headerButton then return end
    local headerText = headerButton.label or (headerButton.GetFontString and headerButton:GetFontString())
    if not headerText then return end

    local cfg = GetSortingConfig()
    if sortState == "default" then
        local color = cfg.GetTextColor("tableHeader")
        headerText:SetTextColor(color[1], color[2], color[3], color[4])
    elseif sortState == "desc" then
        local color = cfg.GetTextColor("tableHeaderSortDesc")
        headerText:SetTextColor(color[1], color[2], color[3], color[4])
    else
        local color = cfg.GetTextColor("tableHeaderSortAsc")
        headerText:SetTextColor(color[1], color[2], color[3], color[4])
    end
end

function SortingSystem:OnHeaderClick()
    CycleSortState()
    self:SortRows()
    self:UpdateHeaderVisual()
    if rebuildCallback then
        rebuildCallback()
    end
end

function SortingSystem:RefreshSorting()
    self:SortRows()
    if rebuildCallback then
        rebuildCallback()
    end
end

function SortingSystem:ReleaseRuntimeCache()
    ClearArray(originalRows)
    ClearArray(currentRows)
    ClearMap(sortValidationRemainingCache)
    headerButton = nil
    lastSortTime = nil
end

function SortingSystem:SetCompactAutoSortEnabled(enabled)
    local shouldEnable = enabled == true
    if shouldEnable == compactAutoSortEnabled then
        return false
    end

    if shouldEnable then
        compactAutoSortPreviousState = sortState
        sortState = "asc"
        compactAutoSortEnabled = true
    else
        if compactAutoSortPreviousState ~= nil then
            sortState = compactAutoSortPreviousState
        else
            sortState = "default"
        end
        compactAutoSortPreviousState = nil
        compactAutoSortEnabled = false
    end

    self:SortRows()
    self:UpdateHeaderVisual()
    return true
end

-- ========================================
-- 倒计时系统
-- ========================================
local CountdownSystem = BuildEnv("CountdownSystem")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingRef = BuildEnv("SortingSystem")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local L = CrateTrackerZK.L

local textByRowId = {}
local rowDisplayCache = {}
local hoveredRowIds = {}
local realtimeRowIds = {}
local activeRealtimeTextCount = 0
local updateTicker = nil
local countdownRunning = false
local sortRefreshCallback = nil
local UPDATE_INTERVAL = 1.0
local SORT_VALIDATE_INTERVAL = 1.0
local PHASE_STATE_REFRESH_INTERVAL = 1.0
local NO_REMAINING_VALUE = {}
local RefreshCountdownUI
local tickContextBuffer = {
    now = 0,
}

local function GetCountdownConfig()
    return UIConfig
end

local function FormatRemaining(seconds)
    if not seconds then
        return L["NoRecord"] or "--:--"
    end
    return UnifiedDataManager:FormatTime(seconds)
end

local function BuildTickContext(now)
    tickContextBuffer.now = now or time()
    return tickContextBuffer
end

local function AcquireRowDisplayCache(rowId)
    local cache = rowDisplayCache[rowId]
    if not cache then
        cache = {}
        rowDisplayCache[rowId] = cache
    end
    return cache
end

local function GetRemaining(rowId, context, cache)
    if not Data then return nil, false, false end
    local rowCache = cache or AcquireRowDisplayCache(rowId)
    local mapData = rowCache.mapData
    if not mapData then
        mapData = Data:GetMap(rowId)
        rowCache.mapData = mapData
    end
    if not mapData then return nil, false, false end

    local now = (context and context.now) or time()
    local isHidden = Data and Data.IsMapHidden and Data:IsMapHidden(mapData.expansionID, mapData.mapID)

    if isHidden then
        local frozen = Data and Data.GetHiddenRemainingValue and Data:GetHiddenRemainingValue(mapData.expansionID, mapData.mapID)
        if frozen and frozen < 0 then frozen = 0 end
        return frozen, true, false
    end

    local displayTime = nil
    if UnifiedDataManager then
        if UnifiedDataManager.GetDisplayTimeInto then
            rowCache.displayTimeBuffer = rowCache.displayTimeBuffer or {}
            rowCache.persistentTimeRecordBuffer = rowCache.persistentTimeRecordBuffer or {}
            displayTime = UnifiedDataManager:GetDisplayTimeInto(
                rowId,
                now,
                rowCache.displayTimeBuffer,
                rowCache.persistentTimeRecordBuffer
            )
        elseif UnifiedDataManager.GetDisplayTime then
            displayTime = UnifiedDataManager:GetDisplayTime(rowId, now)
        end
    end
    if not displayTime or not displayTime.time then
        return nil, false, false
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(rowId, now, displayTime)
    if remaining ~= nil then
        if remaining < 0 then remaining = 0 end
        return remaining, false, true
    end

    return nil, false, true
end

local function RefreshPhaseStateCache(rowId, cache)
    if not cache then
        return nil
    end

    cache.phaseStateDirty = false
    cache.phaseStateRefreshAt = GetTime and GetTime() or 0
    cache.hasCurrentPhase = false
    cache.hasPhaseMismatch = false

    if not UnifiedDataManager then
        return cache
    end

    local comparison = nil
    if UnifiedDataManager.ComparePhasesInto then
        cache.phaseComparisonBuffer = cache.phaseComparisonBuffer or {}
        comparison = UnifiedDataManager:ComparePhasesInto(rowId, cache.phaseComparisonBuffer)
    elseif UnifiedDataManager.ComparePhases then
        comparison = UnifiedDataManager:ComparePhases(rowId)
    end

    if not comparison then
        return cache
    end

    local currentPhaseID = comparison.current
    local persistentPhaseID = comparison.persistent
    cache.hasCurrentPhase = currentPhaseID ~= nil and currentPhaseID ~= ""
    cache.hasPhaseMismatch = cache.hasCurrentPhase
        and persistentPhaseID ~= nil
        and persistentPhaseID ~= ""
        and currentPhaseID ~= persistentPhaseID
    return cache
end

local function GetCountdownColor(rowId, seconds, isHidden, isHovered, cache)
    local cfg = GetCountdownConfig()
    if isHidden then
        return 0.5, 0.5, 0.5, 0.8
    end
    if isHovered then
        return 1.0, 0.82, 0.20, 1.0
    end
    if cache and cache.hasPhaseMismatch then
        local normal = cfg.GetTextColor("normal")
        return normal[1], normal[2], normal[3], normal[4]
    end
    if not cache or not cache.hasCurrentPhase then
        local normal = cfg.GetTextColor("normal")
        return normal[1], normal[2], normal[3], normal[4]
    end
    if seconds == nil then
        local normal = cfg.GetTextColor("normal")
        return normal[1], normal[2], normal[3], normal[4]
    end
    if seconds <= cfg.criticalTime then
        local critical = cfg.GetTextColor("countdownCritical")
        return critical[1], critical[2], critical[3], critical[4]
    end
    if seconds <= cfg.warningTime then
        local warning = cfg.GetTextColor("countdownWarning")
        return warning[1], warning[2], warning[3], warning[4]
    end
    local normal = cfg.GetTextColor("countdownNormal")
    return normal[1], normal[2], normal[3], normal[4]
end

local function IsPairOrdered(a, b, ascending, context, remainingCache)
    if not a or not b then
        return true
    end

    if a.isHidden and not b.isHidden then
        return false
    elseif not a.isHidden and b.isHidden then
        return true
    elseif a.isHidden and b.isHidden then
        return true
    end

    local function GetCachedRemaining(rowInfo)
        local rowId = rowInfo and rowInfo.rowId
        if rowId == nil then
            return nil
        end
        local cache = remainingCache[rowId]
        if cache ~= nil then
            if cache == NO_REMAINING_VALUE then
                return nil
            end
            return cache
        end
        local remaining = GetRemaining(rowId, context)
        remainingCache[rowId] = remaining ~= nil and remaining or NO_REMAINING_VALUE
        return remaining
    end

    local aValue = GetCachedRemaining(a)
    local bValue = GetCachedRemaining(b)

    if aValue == nil and bValue == nil then
        return true
    elseif aValue == nil then
        return false
    elseif bValue == nil then
        return true
    end

    if ascending then
        return aValue <= bValue
    end
    return aValue >= bValue
end

local function IsCurrentSortOrderValid(context)
    if not SortingRef or not SortingRef.GetSortState or not SortingRef.GetCurrentRows then
        return true
    end
    local sortState = SortingRef:GetSortState()
    if sortState == "default" then
        return true
    end

    local rows = SortingRef:GetCurrentRows() or {}
    if #rows < 2 then
        return true
    end

    local ascending = sortState == "asc"
    local remainingCache = ClearMap(sortValidationRemainingCache)
    for i = 1, (#rows - 1) do
        if not IsPairOrdered(rows[i], rows[i + 1], ascending, context, remainingCache) then
            return false
        end
    end
    return true
end

function CountdownSystem:SetSortRefreshCallback(callback)
    sortRefreshCallback = callback
end

local function UpdateRowDisplayCache(rowId, remainingKey, text, r, g, b, a)
    local cache = AcquireRowDisplayCache(rowId)
    cache.remaining = remainingKey
    cache.text = text
    cache.r = r
    cache.g = g
    cache.b = b
    cache.a = a
    return cache
end

local function SetRealtimeRowState(rowId, isRealtime)
    if rowId == nil then
        return
    end

    local previousState = realtimeRowIds[rowId] == true
    local nextState = isRealtime == true
    if previousState == nextState then
        return
    end

    if nextState then
        realtimeRowIds[rowId] = true
        activeRealtimeTextCount = activeRealtimeTextCount + 1
    else
        realtimeRowIds[rowId] = nil
        if activeRealtimeTextCount > 0 then
            activeRealtimeTextCount = activeRealtimeTextCount - 1
        end
    end
end

local function CancelRefreshTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

local function EnsureRefreshTicker()
    local shouldRun = countdownRunning == true and activeRealtimeTextCount > 0
    if not shouldRun then
        CancelRefreshTicker()
        return
    end

    if updateTicker then
        return
    end

    updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        if not countdownRunning then
            CancelRefreshTicker()
            return
        end
        if CrateTrackerZKFrame and not CrateTrackerZKFrame:IsShown() then
            return
        end
        if activeRealtimeTextCount <= 0 then
            CancelRefreshTicker()
            return
        end

        RefreshCountdownUI(time())
    end)
end

function CountdownSystem:RegisterText(rowId, textObject)
    textByRowId[rowId] = textObject
    local context = BuildTickContext(time())
    local cache = AcquireRowDisplayCache(rowId)
    local remaining, isHidden, hasRealtimeUpdate = GetRemaining(rowId, context, cache)
    RefreshPhaseStateCache(rowId, cache)
    local remainingKey = remaining ~= nil and remaining or false
    local text = FormatRemaining(remaining)
    local isHovered = hoveredRowIds[rowId] == true
    local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden, isHovered, cache)
    textObject:SetText(text)
    textObject:SetTextColor(r, g, b, a)
    UpdateRowDisplayCache(rowId, remainingKey, text, r, g, b, a)
    SetRealtimeRowState(rowId, hasRealtimeUpdate == true)
    EnsureRefreshTicker()
end

function CountdownSystem:ClearTexts()
    ClearMap(textByRowId)
    ClearMap(rowDisplayCache)
    ClearMap(hoveredRowIds)
    ClearMap(realtimeRowIds)
    activeRealtimeTextCount = 0
    EnsureRefreshTicker()
end

function RefreshCountdownUI(now)
    local context = BuildTickContext(now)
    local currentStateTime = GetTime and GetTime() or 0

    for rowId, textObject in pairs(textByRowId) do
        local cache = AcquireRowDisplayCache(rowId)
        local remaining, isHidden, hasRealtimeUpdate = GetRemaining(rowId, context, cache)
        if hasRealtimeUpdate then
            if cache.phaseStateDirty or not cache.phaseStateRefreshAt or (currentStateTime - cache.phaseStateRefreshAt) >= PHASE_STATE_REFRESH_INTERVAL then
                RefreshPhaseStateCache(rowId, cache)
            end
            local remainingKey = remaining ~= nil and remaining or false
            local text = cache and cache.remaining == remainingKey and cache.text or FormatRemaining(remaining)
            local isHovered = hoveredRowIds[rowId] == true
            local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden, isHovered, cache)
            if not cache or cache.remaining ~= remainingKey or cache.text ~= text or cache.r ~= r or cache.g ~= g or cache.b ~= b or cache.a ~= a then
                textObject:SetText(text)
                textObject:SetTextColor(r, g, b, a)
                UpdateRowDisplayCache(rowId, remainingKey, text, r, g, b, a)
            end
        end
    end

    if SortingRef and SortingRef.GetSortState and SortingRef:GetSortState() ~= "default" then
        local currentTime = GetTime()
        local lastTime = SortingRef:GetLastSortTime()
        if not lastTime or currentTime - lastTime >= SORT_VALIDATE_INTERVAL then
            if sortRefreshCallback and not IsCurrentSortOrderValid(context) then
                sortRefreshCallback()
            end
            SortingRef:SetLastSortTime(currentTime)
        end
    end
end

function CountdownSystem:MarkRowStateDirty(rowId)
    if rowId == nil then
        return
    end

    local cache = AcquireRowDisplayCache(rowId)
    cache.phaseStateDirty = true
end

function CountdownSystem:SetRowHover(rowId, hovered)
    if rowId == nil then
        return
    end

    if hovered == true then
        hoveredRowIds[rowId] = true
    else
        hoveredRowIds[rowId] = nil
    end

    local textObject = textByRowId[rowId]
    if not textObject then
        return
    end

    local context = BuildTickContext(time())
    local cache = AcquireRowDisplayCache(rowId)
    local remaining, isHidden = GetRemaining(rowId, context, cache)
    if cache.phaseStateDirty then
        RefreshPhaseStateCache(rowId, cache)
    end
    local remainingKey = remaining ~= nil and remaining or false
    local text = FormatRemaining(remaining)
    local isHovered = hoveredRowIds[rowId] == true
    local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden, isHovered, cache)

    textObject:SetText(text)
    textObject:SetTextColor(r, g, b, a)
    UpdateRowDisplayCache(rowId, remainingKey, text, r, g, b, a)
end

function CountdownSystem:Start()
    countdownRunning = true
    EnsureRefreshTicker()
end

function CountdownSystem:Stop()
    countdownRunning = false
    CancelRefreshTicker()
end

function CountdownSystem:ReleaseRuntimeState()
    self:ClearTexts()
end

return {
    SortingSystem = SortingSystem,
    CountdownSystem = CountdownSystem,
}
