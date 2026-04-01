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

local function GetSortingConfig()
    return UIConfig
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
    currentRows = {}
    for _, rowInfo in ipairs(originalRows) do
        table.insert(currentRows, rowInfo)
    end
end

function SortingSystem:GetCurrentRows()
    return currentRows
end

function SortingSystem:SortRows()
    if sortState == "default" then
        local normalRows = {}
        local hiddenRows = {}

        for _, rowInfo in ipairs(originalRows) do
            if rowInfo.isHidden then
                table.insert(hiddenRows, rowInfo)
            else
                table.insert(normalRows, rowInfo)
            end
        end

        currentRows = {}
        for _, rowInfo in ipairs(normalRows) do
            table.insert(currentRows, rowInfo)
        end
        for _, rowInfo in ipairs(hiddenRows) do
            table.insert(currentRows, rowInfo)
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
local updateDriver = nil
local updateElapsed = 0
local sortRefreshCallback = nil
local UPDATE_INTERVAL = 0.2
local SORT_VALIDATE_INTERVAL = 0.5

local function GetCountdownConfig()
    return UIConfig
end

local function HasCurrentPhase(rowId)
    if not UnifiedDataManager or not UnifiedDataManager.GetCurrentPhase then
        return true;
    end
    local currentPhaseID = UnifiedDataManager:GetCurrentPhase(rowId);
    return currentPhaseID ~= nil and currentPhaseID ~= "";
end

local function FormatRemaining(seconds)
    if not seconds then
        return L["NoRecord"] or "--:--"
    end
    return UnifiedDataManager:FormatTime(seconds)
end

local function BuildTickContext(now)
    return {
        now = now or time(),
    }
end

local function ShouldRealtimeUpdate(rowId, context)
    if not Data or not Data.GetMap then
        return false
    end

    local mapData = Data:GetMap(rowId)
    if not mapData then
        return false
    end

    if Data and Data.IsMapHidden and Data:IsMapHidden(mapData.expansionID, mapData.mapID) then
        return false
    end

    if UnifiedDataManager and UnifiedDataManager.GetDisplayTime then
        local display = UnifiedDataManager:GetDisplayTime(rowId, (context and context.now) or time())
        if display and display.time then
            return true
        end
    end

    return false
end

local function GetRemaining(rowId, context)
    if not Data then return nil, false end
    local mapData = Data:GetMap(rowId)
    if not mapData then return nil, false end

    local now = (context and context.now) or time()
    local isHidden = Data and Data.IsMapHidden and Data:IsMapHidden(mapData.expansionID, mapData.mapID)

    if isHidden then
        local frozen = Data and Data.GetHiddenRemainingValue and Data:GetHiddenRemainingValue(mapData.expansionID, mapData.mapID)
        if frozen and frozen < 0 then frozen = 0 end
        return frozen, true
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(rowId, now)
    if remaining ~= nil then
        if remaining < 0 then remaining = 0 end
        return remaining, false
    end

    return nil, false
end

local function GetCountdownColor(rowId, seconds, isHidden, isHovered)
    local cfg = GetCountdownConfig()
    if isHidden then
        return 0.5, 0.5, 0.5, 0.8
    end
    if isHovered then
        return 1.0, 0.82, 0.20, 1.0
    end
    if UnifiedDataManager and UnifiedDataManager.ComparePhases then
        local compare = UnifiedDataManager:ComparePhases(rowId)
        if compare and compare.status == "mismatch" then
            local normal = cfg.GetTextColor("normal")
            return normal[1], normal[2], normal[3], normal[4]
        end
    end
    if not HasCurrentPhase(rowId) then
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
            return cache.value
        end
        local remaining = GetRemaining(rowId, context)
        remainingCache[rowId] = { value = remaining }
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
    local remainingCache = {}
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

function CountdownSystem:RegisterText(rowId, textObject)
    textByRowId[rowId] = textObject
    local context = BuildTickContext(time())
    local remaining, isHidden = GetRemaining(rowId, context)
    local text = FormatRemaining(remaining)
    local isHovered = hoveredRowIds[rowId] == true
    local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden, isHovered)
    textObject:SetText(text)
    textObject:SetTextColor(r, g, b, a)
    rowDisplayCache[rowId] = {
        text = text,
        r = r, g = g, b = b, a = a,
    }
end

function CountdownSystem:ClearTexts()
    textByRowId = {}
    rowDisplayCache = {}
    hoveredRowIds = {}
end

local function RefreshCountdownUI(now)
    local context = BuildTickContext(now)

    for rowId, textObject in pairs(textByRowId) do
        if ShouldRealtimeUpdate(rowId, context) then
            local remaining, isHidden = GetRemaining(rowId, context)
            local text = FormatRemaining(remaining)
            local isHovered = hoveredRowIds[rowId] == true
            local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden, isHovered)
            local cache = rowDisplayCache[rowId]
            if not cache or cache.text ~= text or cache.r ~= r or cache.g ~= g or cache.b ~= b or cache.a ~= a then
                textObject:SetText(text)
                textObject:SetTextColor(r, g, b, a)
                rowDisplayCache[rowId] = {
                    text = text,
                    r = r, g = g, b = b, a = a,
                }
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
    local remaining, isHidden = GetRemaining(rowId, context)
    local text = FormatRemaining(remaining)
    local isHovered = hoveredRowIds[rowId] == true
    local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden, isHovered)

    textObject:SetText(text)
    textObject:SetTextColor(r, g, b, a)
    rowDisplayCache[rowId] = {
        text = text,
        r = r, g = g, b = b, a = a,
    }
end

function CountdownSystem:Start()
    if not updateDriver then
        updateDriver = CreateFrame("Frame")
    end

    updateElapsed = UPDATE_INTERVAL
    updateDriver:SetScript("OnUpdate", function(_, elapsed)
        if CrateTrackerZKFrame and not CrateTrackerZKFrame:IsShown() then
            return
        end

        updateElapsed = updateElapsed + (elapsed or 0)
        if updateElapsed < UPDATE_INTERVAL then
            return
        end
        updateElapsed = 0

        RefreshCountdownUI(time())
    end)
end

function CountdownSystem:Stop()
    if updateDriver and updateDriver:GetScript("OnUpdate") then
        updateDriver:SetScript("OnUpdate", nil)
    end
    updateElapsed = 0
end

return {
    SortingSystem = SortingSystem,
    CountdownSystem = CountdownSystem,
}
