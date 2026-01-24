-- CountdownSystem.lua - 倒计时与颜色更新

local CountdownSystem = BuildEnv("CountdownSystem")
local UIConfig = BuildEnv("UIConfig")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local SortingSystem = BuildEnv("SortingSystem")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local L = CrateTrackerZK.L

local textByRowId = {}
local updateTimer = nil
local sortRefreshCallback = nil

local function GetConfig()
    return UIConfig.values
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

local function GetCountdownColor(seconds, isHidden)
    local cfg = GetConfig()
    if isHidden then
        return 0.5, 0.5, 0.5, 0.8
    end
    if seconds == nil then
        return cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4]
    end
    if seconds <= cfg.criticalTime then
        return cfg.countdownCriticalColor[1], cfg.countdownCriticalColor[2], cfg.countdownCriticalColor[3], cfg.countdownCriticalColor[4]
    end
    if seconds <= cfg.warningTime then
        return cfg.countdownWarningColor[1], cfg.countdownWarningColor[2], cfg.countdownWarningColor[3], cfg.countdownWarningColor[4]
    end
    return cfg.countdownNormalColor[1], cfg.countdownNormalColor[2], cfg.countdownNormalColor[3], cfg.countdownNormalColor[4]
end

function CountdownSystem:SetSortRefreshCallback(callback)
    sortRefreshCallback = callback
end

function CountdownSystem:RegisterText(rowId, textObject)
    textByRowId[rowId] = textObject
    local remaining, isHidden = GetRemaining(rowId)
    local text = FormatRemaining(remaining)
    local r, g, b, a = GetCountdownColor(remaining, isHidden)
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
            local r, g, b, a = GetCountdownColor(remaining, isHidden)
            textObject:SetText(text)
            textObject:SetTextColor(r, g, b, a)
        end

        if SortingSystem and SortingSystem.GetSortState and SortingSystem:GetSortState() ~= "default" then
            local currentTime = GetTime()
            local lastTime = SortingSystem:GetLastSortTime()
            if not lastTime or currentTime - lastTime >= 10 then
                if sortRefreshCallback then
                    sortRefreshCallback()
                end
                SortingSystem:SetLastSortTime(currentTime)
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

return CountdownSystem
