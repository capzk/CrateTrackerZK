-- SortingSystem.lua - 表格排序系统

local SortingSystem = BuildEnv("SortingSystem")
local UIConfig = BuildEnv("UIConfig")

local sortState = "default"
local originalRows = {}
local currentRows = {}
local headerButton = nil
local lastSortTime = nil
local rebuildCallback = nil

local function GetConfig()
    return UIConfig.values
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
    local success, err = pcall(function()
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

    local cfg = GetConfig()
    if sortState == "default" then
        headerText:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
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

return SortingSystem
