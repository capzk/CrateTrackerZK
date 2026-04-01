-- MainPanel.lua - 现代化界面适配层

local MainPanel = BuildEnv("MainPanel")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local UIConfig = BuildEnv("ThemeConfig")
local MainFrame = BuildEnv("MainFrame")
local MainPanelController = BuildEnv("MainPanelController")
local RowViewModelBuilder = BuildEnv("RowViewModelBuilder")
local StateBuckets = BuildEnv("StateBuckets")
local TableUI = BuildEnv("TableUI")
local SortingSystem = BuildEnv("SortingSystem")
local Data = BuildEnv("Data")
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

local function EnsureUIBucket()
    if StateBuckets and StateBuckets.GetExpansionUIBucket then
        StateBuckets:GetExpansionUIBucket()
        return
    end
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
end

function MainPanel:GetRemainingSeconds(mapData)
    if RowViewModelBuilder and RowViewModelBuilder.GetRemainingSeconds then
        return RowViewModelBuilder:GetRemainingSeconds(mapData)
    end
    return nil
end

function MainPanel:BuildRowData()
    if RowViewModelBuilder and RowViewModelBuilder.BuildRows then
        return RowViewModelBuilder:BuildRows()
    end
    return {}
end

function MainPanel:BuildHeaderLabels()
    return {
        L["MapName"] or "Map",
        L["PhaseID"] or "当前位面",
        L["LastRefresh"] or "Last",
        L["NextRefresh"] or "Next",
    }
end

function MainPanel:IsMainFrameVisible()
    return self.mainFrame and self.mainFrame.IsShown and self.mainFrame:IsShown()
end

function MainPanel:BindFrameLifecycle(frame)
    if MainPanelController and MainPanelController.BindFrameLifecycle then
        return MainPanelController:BindFrameLifecycle(self, frame)
    end
end

function MainPanel:CreateMainFrame()
    if CrateTrackerZKFrame then
        self.mainFrame = CrateTrackerZKFrame
        if MainFrame and MainFrame.ApplySavedSize then
            MainFrame:ApplySavedSize(self.mainFrame)
        end
        self.mainFrame:ClearAllPoints()
        if CRATETRACKERZK_UI_DB.position then
            local pos = CRATETRACKERZK_UI_DB.position
            self.mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
        else
            self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        if MainFrame and MainFrame.ApplyAdaptiveHeight then
            MainFrame:ApplyAdaptiveHeight(self.mainFrame)
        end
        if MainFrame and MainFrame.ApplyThemeColors then
            MainFrame:ApplyThemeColors(self.mainFrame)
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

    EnsureUIBucket()

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
    if MainPanelController and MainPanelController.RequestLayoutUpdate then
        return MainPanelController:RequestLayoutUpdate(self)
    end
end

function MainPanel:StartUpdateTimer()
    if MainPanelController and MainPanelController.StartUpdateTimer then
        return MainPanelController:StartUpdateTimer(self)
    end
end

function MainPanel:StopUpdateTimer()
    if MainPanelController and MainPanelController.StopUpdateTimer then
        return MainPanelController:StopUpdateTimer(self)
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
    end
end

function MainPanel:UpdateTable(skipVisibilityCheck)
    if not self.mainFrame or not TableUI then return end
    -- 主界面隐藏时不执行任何表格重建，避免隐藏态 UI 资源占用
    if not self:IsMainFrameVisible() then
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

function MainPanel:UpdateLayoutOnly()
    if not self.mainFrame or not TableUI or not SortingSystem then return end
    if not self:IsMainFrameVisible() then
        return
    end
    local headers = self:BuildHeaderLabels()
    TableUI:RebuildUI(self.mainFrame, headers)
end

function MainPanel:RefreshTrackedMapConfiguration()
    if self.mainFrame and MainFrame and MainFrame.ApplyAdaptiveHeight then
        MainFrame:ApplyAdaptiveHeight(self.mainFrame)
    end
    self:UpdateTable(true)
end

function MainPanel:RefreshTheme()
    if self.mainFrame and MainFrame and MainFrame.ApplyThemeColors then
        MainFrame:ApplyThemeColors(self.mainFrame)
    end
    self:UpdateTable()
end

function MainPanel:NotifyMapById(mapId, clickButton)
    if not mapId then return end
    local now = GetTime()
    local last = self.lastNotifyClickTime[mapId] or 0
    if now - last < self.NOTIFY_BUTTON_COOLDOWN then return end
    self.lastNotifyClickTime[mapId] = now
    local mapData = Data:GetMap(mapId)
    if mapData then
        self:NotifyMapRefresh(mapData, clickButton)
    end
end

function MainPanel:NotifyMapRefresh(mapData, clickButton)
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
    Notification:NotifyMapRefresh(mapData, isAirdropActive, clickButton)
end

function MainPanel:HideMap(mapId)
    EnsureUIBucket()
    local mapData = Data:GetMap(mapId)
    if not mapData then return end

    local remaining = self:GetRemainingSeconds(mapData)
    if remaining and remaining < 0 then remaining = 0 end
    if Data and Data.SetMapHiddenState then
        Data:SetMapHiddenState(mapData.expansionID, mapData.mapID, true, remaining)
    end

    self:UpdateTable(true)
end

function MainPanel:RestoreMap(mapId)
    EnsureUIBucket()
    local mapData = Data:GetMap(mapId)
    if not mapData then return end

    if Data and Data.SetMapHiddenState then
        Data:SetMapHiddenState(mapData.expansionID, mapData.mapID, false)
    end

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
