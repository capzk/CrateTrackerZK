-- TableSystems.lua - 表格系统（排序 + 倒计时）

local UIConfig = BuildEnv("UIConfig")

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

local function GetSortingConfig()
    return UIConfig
end

function SortingSystem:SetRebuildCallback(callback)
    rebuildCallback = callback
end

function SortingSystem:GetSortState()
    return sortState
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
    local headerText = headerButton:GetFontString()
    if not headerText then return end

    local cfg = GetSortingConfig()
    if sortState == "default" then
        local normal = cfg.GetTextColor("normal")
        headerText:SetTextColor(normal[1], normal[2], normal[3], normal[4])
    elseif sortState == "desc" then
        headerText:SetTextColor(1, 0.8, 0.8, 1)
    else
        headerText:SetTextColor(0.8, 1, 0.8, 1)
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
local updateTimer = nil
local sortRefreshCallback = nil

local function GetCountdownConfig()
    return UIConfig
end

local function HasCurrentPhase(rowId)
    if not Data or not Data.GetMap then
        return true;
    end
    local mapData = Data:GetMap(rowId);
    if not mapData then
        return true;
    end
    return mapData.currentPhaseID ~= nil and mapData.currentPhaseID ~= "";
end

local function FormatRemaining(seconds)
    if not seconds then
        return L["NoRecord"] or "--:--"
    end
    return UnifiedDataManager:FormatTime(seconds)
end

local function GetRemaining(rowId)
    if not Data then return nil, false end
    local mapData = Data:GetMap(rowId)
    if not mapData then return nil, false end

    local hiddenMaps = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps or {}
    local hiddenRemaining = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenRemaining or {}
    local isHidden = hiddenMaps and hiddenMaps[mapData.mapID] == true

    if isHidden then
        local frozen = hiddenRemaining and hiddenRemaining[mapData.mapID]
        if frozen and frozen < 0 then frozen = 0 end
        return frozen, true
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(rowId)
    if remaining ~= nil then
        if remaining < 0 then remaining = 0 end
        return remaining, false
    end

    if mapData.lastRefresh then
        local now = time()
        if mapData.nextRefresh and mapData.nextRefresh <= now then
            Data:UpdateNextRefresh(mapData.id, mapData)
        end
        if mapData.nextRefresh then
            remaining = mapData.nextRefresh - now
            if remaining < 0 then remaining = 0 end
            return remaining, false
        end
    end

    return nil, false
end

local function GetCountdownColor(rowId, seconds, isHidden)
    local cfg = GetCountdownConfig()
    if isHidden then
        return 0.5, 0.5, 0.5, 0.8
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

function CountdownSystem:SetSortRefreshCallback(callback)
    sortRefreshCallback = callback
end

function CountdownSystem:RegisterText(rowId, textObject)
    textByRowId[rowId] = textObject
    local remaining, isHidden = GetRemaining(rowId)
    local text = FormatRemaining(remaining)
    local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden)
    textObject:SetText(text)
    textObject:SetTextColor(r, g, b, a)
end

function CountdownSystem:ClearTexts()
    textByRowId = {}
end

function CountdownSystem:Start()
    if updateTimer then
        updateTimer:Cancel()
    end

    updateTimer = C_Timer.NewTicker(1, function()
        if CrateTrackerZKFrame and not CrateTrackerZKFrame:IsShown() then
            return
        end

        for rowId, textObject in pairs(textByRowId) do
            local remaining, isHidden = GetRemaining(rowId)
            local text = FormatRemaining(remaining)
            local r, g, b, a = GetCountdownColor(rowId, remaining, isHidden)
            textObject:SetText(text)
            textObject:SetTextColor(r, g, b, a)
        end

        if SortingRef and SortingRef.GetSortState and SortingRef:GetSortState() ~= "default" then
            local currentTime = GetTime()
            local lastTime = SortingRef:GetLastSortTime()
            if not lastTime or currentTime - lastTime >= 10 then
                if sortRefreshCallback then
                    sortRefreshCallback()
                end
                SortingRef:SetLastSortTime(currentTime)
            end
        end
    end)
end

function CountdownSystem:Stop()
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
end

return {
    SortingSystem = SortingSystem,
    CountdownSystem = CountdownSystem,
}
