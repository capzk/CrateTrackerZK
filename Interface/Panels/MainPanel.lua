-- MainPanel.lua - 现代化界面适配层

local MainPanel = BuildEnv("MainPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("ThemeConfig")
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
local ExpansionConfig = BuildEnv("ExpansionConfig")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local L = CrateTrackerZK.L

MainPanel.lastNotifyClickTime = MainPanel.lastNotifyClickTime or {}
MainPanel.NOTIFY_BUTTON_COOLDOWN = 0.5
MainPanel.updateTimerActive = MainPanel.updateTimerActive or false
MainPanel.layoutUpdatePending = MainPanel.layoutUpdatePending or false
MainPanel.lastLayoutUpdateAt = MainPanel.lastLayoutUpdateAt or 0
MainPanel.LAYOUT_UPDATE_INTERVAL = 0.016
MainPanel.layoutUpdateTimer = MainPanel.layoutUpdateTimer or nil

local function EnsureUIState()
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
end

local function GetCurrentExpansionID()
    if Data and Data.GetCurrentExpansionID then
        local id = Data:GetCurrentExpansionID()
        if id then
            return id
        end
    end
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        local id = ExpansionConfig:GetCurrentExpansionID()
        if id then
            return id
        end
    end
    return "default"
end

local function GetFallbackExpansionBucket()
    EnsureUIState()
    if type(CRATETRACKERZK_UI_DB.expansionUIData) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData = {}
    end
    local expansionID = GetCurrentExpansionID()
    if type(CRATETRACKERZK_UI_DB.expansionUIData[expansionID]) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData[expansionID] = {}
    end
    local bucket = CRATETRACKERZK_UI_DB.expansionUIData[expansionID]
    if type(bucket.hiddenMaps) ~= "table" then
        bucket.hiddenMaps = {}
    end
    if type(bucket.hiddenRemaining) ~= "table" then
        bucket.hiddenRemaining = {}
    end
    return bucket
end

local function GetHiddenMaps()
    if Data and Data.GetHiddenMaps then
        return Data:GetHiddenMaps()
    end
    return GetFallbackExpansionBucket().hiddenMaps
end

local function GetHiddenRemaining()
    if Data and Data.GetHiddenRemaining then
        return Data:GetHiddenRemaining()
    end
    return GetFallbackExpansionBucket().hiddenRemaining
end

local function GetHiddenState(mapData)
    local hiddenMaps = GetHiddenMaps()
    return hiddenMaps[mapData.mapID] == true
end

local function GetFrozenRemaining(mapData)
    local hiddenRemaining = GetHiddenRemaining()
    local value = hiddenRemaining[mapData.mapID]
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
    local hiddenSet = GetHiddenMaps()
    local frozenSet = GetHiddenRemaining()

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
                lastRefreshPhase = mapData.lastRefreshPhase,
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
        L["PhaseID"] or "当前位面",
        L["LastRefresh"] or "Last",
        L["NextRefresh"] or "Next",
        L["Operation"] or "Ops",
    }
end

function MainPanel:IsMainFrameVisible()
    return self.mainFrame and self.mainFrame.IsShown and self.mainFrame:IsShown()
end

function MainPanel:BindFrameLifecycle(frame)
    if not frame or frame.__ctkMainPanelLifecycleBound then
        return
    end

    if frame.HookScript then
        frame:HookScript("OnShow", function()
            MainPanel:StartUpdateTimer()
            MainPanel:UpdateTable(true)
        end)
        frame:HookScript("OnHide", function()
            MainPanel:StopUpdateTimer()
        end)
    end

    frame.__ctkMainPanelLifecycleBound = true
end

function MainPanel:CreateMainFrame()
    if CrateTrackerZKFrame then
        self.mainFrame = CrateTrackerZKFrame
        if MainFrame and MainFrame.ApplyAdaptiveHeight then
            MainFrame:ApplyAdaptiveHeight(self.mainFrame)
        end
        self:BindFrameLifecycle(self.mainFrame)
        if self:IsMainFrameVisible() then
            self:StartUpdateTimer()
            self:UpdateTable(true)
        else
            self:StopUpdateTimer()
        end
        return CrateTrackerZKFrame
    end

    EnsureUIState()

    local frame = MainFrame and MainFrame.Create and MainFrame:Create()
    if not frame then
        return nil
    end

    frame.OnLayoutChanged = function()
        self:RequestLayoutUpdate()
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
    self:BindFrameLifecycle(frame)
    frame:Hide()
    return frame
end

function MainPanel:RequestLayoutUpdate()
    if not self.mainFrame then
        return
    end
    if not self:IsMainFrameVisible() then
        return
    end

    local now = GetTime and GetTime() or 0
    local interval = self.LAYOUT_UPDATE_INTERVAL or 0.016
    local elapsed = now - (self.lastLayoutUpdateAt or 0)
    if elapsed >= interval then
        self.lastLayoutUpdateAt = now
        self:UpdateTable(true)
        return
    end

    if self.layoutUpdatePending then
        return
    end

    self.layoutUpdatePending = true
    local delay = interval - elapsed
    if delay < 0.005 then
        delay = 0.005
    end
    self.layoutUpdateTimer = C_Timer.NewTimer(delay, function()
        self.layoutUpdateTimer = nil
        self.layoutUpdatePending = false
        if not self.mainFrame or not self:IsMainFrameVisible() then
            return
        end
        self.lastLayoutUpdateAt = GetTime and GetTime() or 0
        self:UpdateTable(true)
    end)
end

function MainPanel:StartUpdateTimer()
    if not self:IsMainFrameVisible() then
        self:StopUpdateTimer()
        return
    end
    if self.updateTimerActive then
        return
    end
    if CountdownSystem and CountdownSystem.Start then
        CountdownSystem:Start()
        self.updateTimerActive = true
    end
end

function MainPanel:StopUpdateTimer()
    if self.layoutUpdateTimer then
        self.layoutUpdateTimer:Cancel()
        self.layoutUpdateTimer = nil
    end
    self.layoutUpdatePending = false
    if CountdownSystem and CountdownSystem.Stop then
        CountdownSystem:Stop()
    end
    self.updateTimerActive = false
end

function MainPanel:Toggle()
    if not CrateTrackerZKFrame then
        self:CreateMainFrame()
    end

    if CrateTrackerZKFrame:IsShown() then
        CrateTrackerZKFrame:Hide()
    else
        CrateTrackerZKFrame:Show()
    end
end

function MainPanel:UpdateTable(skipVisibilityCheck)
    if not self.mainFrame or not TableUI then return end
    if not skipVisibilityCheck and not self:IsMainFrameVisible() then
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

function MainPanel:RefreshTheme()
    if self.mainFrame and MainFrame and MainFrame.ApplyThemeColors then
        MainFrame:ApplyThemeColors(self.mainFrame)
    end
    self:UpdateTable(true)
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
    local hiddenMaps = GetHiddenMaps()
    local hiddenRemaining = GetHiddenRemaining()
    hiddenMaps[mapData.mapID] = true
    if remaining and remaining < 0 then remaining = 0 end
    hiddenRemaining[mapData.mapID] = remaining

    self:UpdateTable(true)
end

function MainPanel:RestoreMap(mapId)
    EnsureUIState()
    local mapData = Data:GetMap(mapId)
    if not mapData then return end

    local hiddenMaps = GetHiddenMaps()
    local hiddenRemaining = GetHiddenRemaining()
    hiddenMaps[mapData.mapID] = nil
    hiddenRemaining[mapData.mapID] = nil

    self:UpdateTable(true)
end

function MainPanel:ShowHelpDialog()
    if SettingsPanel and SettingsPanel.ShowTab then
        SettingsPanel:ShowTab("help")
    end
end

function MainPanel:ShowAboutDialog()
    if SettingsPanel and SettingsPanel.ShowTab then
        SettingsPanel:ShowTab("about")
    end
end

return MainPanel
