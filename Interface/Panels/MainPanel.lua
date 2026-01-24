-- MainPanel.lua - 现代化界面适配层

local MainPanel = BuildEnv("MainPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("UIConfig")
local MainFrame = BuildEnv("MainFrame")
local TableUI = BuildEnv("TableUI")
local SortingSystem = BuildEnv("SortingSystem")
local CountdownSystem = BuildEnv("CountdownSystem")
local Data = BuildEnv("Data")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local TimerManager = BuildEnv("TimerManager")
local Notification = BuildEnv("Notification")
local MapTracker = BuildEnv("MapTracker")
local IconDetector = BuildEnv("IconDetector")
local Area = BuildEnv("Area")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local L = CrateTrackerZK.L

MainPanel.lastNotifyClickTime = MainPanel.lastNotifyClickTime or {}
MainPanel.NOTIFY_BUTTON_COOLDOWN = 0.5

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    CRATETRACKERZK_UI_DB.hiddenMaps = CRATETRACKERZK_UI_DB.hiddenMaps or {}
    CRATETRACKERZK_UI_DB.hiddenRemaining = CRATETRACKERZK_UI_DB.hiddenRemaining or {}
end

local function GetHiddenState(mapData)
    EnsureUIState()
    return CRATETRACKERZK_UI_DB.hiddenMaps[mapData.mapID] == true
end

local function GetFrozenRemaining(mapData)
    EnsureUIState()
    local value = CRATETRACKERZK_UI_DB.hiddenRemaining[mapData.mapID]
    if value and value < 0 then
        value = 0
    end
    return value
end

function MainPanel:GetRemainingSeconds(mapData)
    if not mapData then return nil end

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

    if mapData.lastRefresh then
        local now = time()
        if mapData.nextRefresh and mapData.nextRefresh <= now then
            Data:UpdateNextRefresh(mapData.id, mapData)
        end
        if mapData.nextRefresh then
            remaining = mapData.nextRefresh - now
            if remaining < 0 then remaining = 0 end
            return remaining
        end
    end

    return nil
end

function MainPanel:BuildRowData()
    local rows = {}
    local maps = Data and Data.GetAllMaps and Data:GetAllMaps() or {}
    local now = time()
    local hiddenSet = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps or {}
    local frozenSet = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenRemaining or {}

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
                    if remainingTime < 0 then remainingTime = 0 end
                end
                nextRefreshTime = mapData.nextRefresh
            end

            local hiddenRemaining = (mapData.mapID and frozenSet[mapData.mapID]) or nil
            if hiddenRemaining ~= nil then
                remainingTime = hiddenRemaining
            end
            if remainingTime and remainingTime < 0 then remainingTime = 0 end

            local phaseDisplayInfo = UnifiedDataManager and UnifiedDataManager.GetPhaseDisplayInfo and UnifiedDataManager:GetPhaseDisplayInfo(mapData.id)

            table.insert(rows, {
                rowId = mapData.id,
                mapId = mapData.mapID,
                mapName = Data:GetMapDisplayName(mapData),
                lastRefresh = displayTime and displayTime.time or mapData.lastRefresh,
                nextRefresh = nextRefreshTime or mapData.nextRefresh,
                remainingTime = remainingTime,
                currentPhaseID = mapData.currentPhaseID,
                phaseDisplayInfo = phaseDisplayInfo,
                isHidden = hiddenSet and hiddenSet[mapData.mapID] or false,
                isFrozen = hiddenRemaining ~= nil,
                timeSource = displayTime and displayTime.source or nil,
                isPersistent = displayTime and displayTime.isPersistent or false,
                originalIndex = index,
            })
        end
    end

    return rows
end

function MainPanel:BuildHeaderLabels()
    return {
        L["MapName"] or "Map",
        L["PhaseID"] or "Phase",
        L["LastRefresh"] or "Last",
        L["NextRefresh"] or "Next",
        L["Operation"] or "Ops",
    }
end

function MainPanel:CreateMainFrame()
    if CrateTrackerZKFrame then return CrateTrackerZKFrame end

    EnsureUIState()

    local frame = MainFrame and MainFrame.Create and MainFrame:Create()
    if not frame then
        return nil
    end

    if CRATETRACKERZK_UI_DB.position then
        local pos = CRATETRACKERZK_UI_DB.position
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    end

    if SortingSystem and SortingSystem.SetRebuildCallback then
        SortingSystem:SetRebuildCallback(function()
            self:UpdateTable(true)
        end)
    end

    if CountdownSystem and CountdownSystem.SetSortRefreshCallback then
        CountdownSystem:SetSortRefreshCallback(function()
            self:UpdateTable(true)
        end)
    end

    self.mainFrame = frame
    self:UpdateTable(true)
    self:StartUpdateTimer()

    frame:Hide()
    return frame
end

function MainPanel:StartUpdateTimer()
    if CountdownSystem and CountdownSystem.Start then
        CountdownSystem:Start()
    end
end

function MainPanel:StopUpdateTimer()
    if CountdownSystem and CountdownSystem.Stop then
        CountdownSystem:Stop()
    end
end

function MainPanel:Toggle()
    if not CrateTrackerZKFrame then
        self:CreateMainFrame()
    end

    if CrateTrackerZKFrame:IsShown() then
        CrateTrackerZKFrame:Hide()
    else
        CrateTrackerZKFrame:Show()
        self:UpdateTable(true)
    end
end

function MainPanel:UpdateTable(skipVisibilityCheck)
    if not self.mainFrame or not TableUI then return end
    if not skipVisibilityCheck and (not CrateTrackerZKFrame or not CrateTrackerZKFrame:IsShown()) then
        return
    end

    local rows = self:BuildRowData()
    local headers = self:BuildHeaderLabels()

    if SortingSystem and SortingSystem.SetOriginalRows then
        SortingSystem:SetOriginalRows(rows)
        SortingSystem:SortRows()
    end

    TableUI:RebuildUI(self.mainFrame, headers)
end

function MainPanel:RefreshMap(mapId)
    if not mapId then
        return false
    end

    local mapData = Data:GetMap(mapId)
    if not mapData then
        return false
    end

    local now = time()

    if TimerManager and TimerManager.StartTimer then
        local success = TimerManager:StartTimer(mapId, TimerManager.detectionSources.REFRESH_BUTTON, now)
        if success then
            self:UpdateTable(true)
            return true
        end
        return false
    end

    mapData.lastRefresh = now
    mapData.currentAirdropObjectGUID = nil
    mapData.currentAirdropTimestamp = nil
    Data:UpdateNextRefresh(mapId, mapData)
    self:UpdateTable(true)
    return true
end

function MainPanel:NotifyMapById(mapId)
    if not mapId then return end
    local now = GetTime()
    local last = self.lastNotifyClickTime[mapId] or 0
    if now - last < self.NOTIFY_BUTTON_COOLDOWN then return end
    self.lastNotifyClickTime[mapId] = now
    local mapData = Data:GetMap(mapId)
    if mapData then
        self:NotifyMapRefresh(mapData)
    end
end

function MainPanel:NotifyMapRefresh(mapData)
    if not Notification or not mapData then return end
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or (Area and Area:GetCurrentMapId() or nil)
    local isAirdropActive = false
    if currentMapID and MapTracker and MapTracker.GetTargetMapData then
        local target = MapTracker:GetTargetMapData(currentMapID)
        if target and target.id == mapData.id then
            if IconDetector and IconDetector.DetectIcon then
                local res = IconDetector:DetectIcon(currentMapID)
                if res and res.detected then
                    isAirdropActive = true
                end
            end
        end
    end
    Notification:NotifyMapRefresh(mapData, isAirdropActive)
end

function MainPanel:HideMap(mapId)
    EnsureUIState()
    local mapData = Data:GetMap(mapId)
    if not mapData then return end

    local remaining = self:GetRemainingSeconds(mapData)
    CRATETRACKERZK_UI_DB.hiddenMaps[mapData.mapID] = true
    if remaining and remaining < 0 then remaining = 0 end
    CRATETRACKERZK_UI_DB.hiddenRemaining[mapData.mapID] = remaining

    self:UpdateTable(true)
end

function MainPanel:RestoreMap(mapId)
    EnsureUIState()
    local mapData = Data:GetMap(mapId)
    if not mapData then return end

    CRATETRACKERZK_UI_DB.hiddenMaps[mapData.mapID] = nil
    CRATETRACKERZK_UI_DB.hiddenRemaining[mapData.mapID] = nil

    self:UpdateTable(true)
end

function MainPanel:ShowHelpDialog()
    if SettingsPanel and SettingsPanel.ShowTab then
        SettingsPanel:ShowTab("帮助")
    end
end

function MainPanel:ShowAboutDialog()
    if SettingsPanel and SettingsPanel.ShowTab then
        SettingsPanel:ShowTab("关于")
    end
end

return MainPanel
