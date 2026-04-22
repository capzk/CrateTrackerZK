-- AddonControlService.lua - 插件控制应用服务

local AddonControlService = BuildEnv("AddonControlService")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local AppContext = BuildEnv("AppContext")
local ExpansionConfig = BuildEnv("ExpansionConfig")
local ThemeConfig = BuildEnv("ThemeConfig")
local Data = BuildEnv("Data")
local Notification = BuildEnv("Notification")
local MainPanel = BuildEnv("MainPanel")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local AppSettingsStore = BuildEnv("AppSettingsStore")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local MapTracker = BuildEnv("MapTracker")
local Phase = BuildEnv("Phase")
local TeamCommListener = BuildEnv("TeamCommListener")
local TimerManager = BuildEnv("TimerManager")
local TeamSharedSyncStore = BuildEnv("TeamSharedSyncStore")
local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")
local TeamSharedWarmupService = BuildEnv("TeamSharedWarmupService")
local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")
local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local TickerController = BuildEnv("CrateTrackerZKTickerController")
local ShoutDetector = BuildEnv("ShoutDetector")
local Area = BuildEnv("Area")

local function EnsureUIConfig()
    if AppSettingsStore and AppSettingsStore.GetUIState then
        return AppSettingsStore:GetUIState()
    end
    if AppContext and AppContext.EnsureUIState then
        return AppContext:EnsureUIState()
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    return CRATETRACKERZK_UI_DB
end

local function RefreshSettingsState()
    if SettingsPanel and SettingsPanel.RefreshState then
        SettingsPanel:RefreshState()
    end
end

local function ResetModuleInitializationState(module)
    if module then
        module.isInitialized = false
    end
end

local function InitializeModule(module)
    if module and module.Initialize then
        module:Initialize()
        return true
    end
    return false
end

local function ResetSyncListeners()
    ResetModuleInitializationState(TeamCommListener)
    ResetModuleInitializationState(TeamSharedSyncListener)
end

local function ResetSharedSyncRuntimeState()
    if TeamSharedSyncStore and TeamSharedSyncStore.Reset then
        TeamSharedSyncStore:Reset()
    end
    if TeamSharedWarmupService and TeamSharedWarmupService.Reset then
        TeamSharedWarmupService:Reset()
    end
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.Reset then
        TeamSharedSyncChannelService:Reset()
    end
    if UnifiedDataManager then
        UnifiedDataManager.sharedDisplayStateByMap = {}
    end
    if AirdropTrajectoryService and AirdropTrajectoryService.Reset then
        AirdropTrajectoryService:Reset()
    end
    if AirdropTrajectorySyncService and AirdropTrajectorySyncService.Reset then
        AirdropTrajectorySyncService:Reset()
    end
    if AirdropTrajectoryAlertCoordinator and AirdropTrajectoryAlertCoordinator.Reset then
        AirdropTrajectoryAlertCoordinator:Reset()
    end
end

local function InitializeSyncListeners(enablePublicSync)
    InitializeModule(TeamCommListener)
    if enablePublicSync == true then
        InitializeModule(TeamSharedSyncListener)
    end
end

local function ResetShoutDetector()
    ResetModuleInitializationState(ShoutDetector)
end

local function InitializeShoutDetector()
    ResetShoutDetector()
    InitializeModule(ShoutDetector)
end

local function RefreshTrackedMapRuntime()
    if Data and Data.Initialize then
        Data:Initialize()
    end
    if AirdropTrajectoryStore and AirdropTrajectoryStore.Initialize then
        AirdropTrajectoryStore:Initialize()
    end

    if UnifiedDataManager then
        if not UnifiedDataManager.isInitialized and UnifiedDataManager.Initialize then
            UnifiedDataManager:Initialize()
        elseif UnifiedDataManager.MigrateExistingData then
            UnifiedDataManager:MigrateExistingData()
        end
    end

    if TimerManager then
        TimerManager.detectionState = {}
    end
    if AirdropTrajectoryService and AirdropTrajectoryService.Reset then
        AirdropTrajectoryService:Reset()
    end

    if MapTracker and MapTracker.Initialize then
        MapTracker:Initialize()
    end

    if Phase and Phase.Reset then
        Phase:Reset()
    end

    ResetSyncListeners()

    if Area then
        Area.lastAreaValidState = nil
        Area.lastAccessMode = nil
        if AddonControlService:IsAddonEnabled() then
            Area:CheckAndUpdateAreaValid()
        else
            Area.detectionPaused = true
        end
    end

    InitializeSyncListeners(AddonControlService:IsAddonEnabled() == true)

    if MainPanel and MainPanel.RefreshTrackedMapConfiguration then
        MainPanel:RefreshTrackedMapConfiguration()
    elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable(true)
    end

    RefreshSettingsState()
    return true
end

function AddonControlService:IsAddonEnabled()
    if AppSettingsStore and AppSettingsStore.GetBoolean then
        return AppSettingsStore:GetBoolean("addonEnabled", true)
    end
    local uiDB = EnsureUIConfig()
    if uiDB.addonEnabled == nil then
        return true
    end
    return uiDB.addonEnabled == true
end

function AddonControlService:SetAddonEnabledFlag(enabled)
    if AppSettingsStore and AppSettingsStore.SetBoolean then
        return AppSettingsStore:SetBoolean("addonEnabled", enabled == true)
    end
    local uiDB = EnsureUIConfig()
    uiDB.addonEnabled = enabled == true
    return uiDB.addonEnabled
end

function AddonControlService:ReinitializeAddon()
    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize()
        if CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton()
        end
        return true
    end

    if Logger and Logger.Error then
        Logger:Error("AddonControlService", "错误", "插件重初始化失败：Core 未加载")
    end
    return false
end

function AddonControlService:ClearDataAndReinitialize()
    if RuntimeResetManager and RuntimeResetManager.PrepareUIForClear then
        RuntimeResetManager:PrepareUIForClear()
    end
    if RuntimeResetManager and RuntimeResetManager.ClearPersistentData then
        RuntimeResetManager:ClearPersistentData()
    end
    if RuntimeResetManager and RuntimeResetManager.ResetCommandRuntimeState then
        RuntimeResetManager:ResetCommandRuntimeState()
    else
        if Data then
            Data.maps = {}
            Data.mapsById = {}
            Data.mapsByMapID = {}
        end
        if TimerManager then
            TimerManager.isInitialized = false
            TimerManager.detectionState = {}
        end
        ResetSyncListeners()
        ResetShoutDetector()
        if CRATETRACKERZK_DB then
            CRATETRACKERZK_DB.expansionData = {}
            CRATETRACKERZK_DB.mapData = nil
            CRATETRACKERZK_DB.trajectoryData = nil
            if Data and Data.SCHEMA_VERSION then
                CRATETRACKERZK_DB.schemaVersion = Data.SCHEMA_VERSION
            end
        end
        if type(CRATETRACKERZK_TRAJECTORY_DB) == "table" then
            for key in pairs(CRATETRACKERZK_TRAJECTORY_DB) do
                CRATETRACKERZK_TRAJECTORY_DB[key] = nil
            end
        end
        if CRATETRACKERZK_UI_DB then
            for key in pairs(CRATETRACKERZK_UI_DB) do
                CRATETRACKERZK_UI_DB[key] = nil
            end
        end
        if CrateTrackerZKFrame then
            CrateTrackerZKFrame:Hide()
        end
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show()
        end
    end

    local success = self:ReinitializeAddon()
    if success then
        RefreshSettingsState()
    end
    return success
end

function AddonControlService:ApplyAddonEnabled(enabled)
    local shouldEnable = enabled == true
    local currentlyEnabled = self:IsAddonEnabled()
    if shouldEnable == currentlyEnabled then
        return false
    end

    self:SetAddonEnabledFlag(shouldEnable)

    if shouldEnable then
        if TimerManager and TimerManager.Initialize and not TimerManager.isInitialized then
            TimerManager:Initialize()
        end
        if AirdropTrajectorySyncService and AirdropTrajectorySyncService.Initialize then
            AirdropTrajectorySyncService:Initialize()
        end
        if Area then
            Area.lastAreaValidState = nil
            Area.lastAccessMode = nil
            Area:CheckAndUpdateAreaValid()
        end
        ResetSyncListeners()
        ResetSharedSyncRuntimeState()
        InitializeSyncListeners(true)
        InitializeShoutDetector()
        if TickerController and TickerController.RefreshTeamSharedWarmupTicker then
            TickerController:RefreshTeamSharedWarmupTicker(CrateTrackerZK)
        end
        if AirdropTrajectorySyncService and AirdropTrajectorySyncService.HandleTeamContextChanged then
            AirdropTrajectorySyncService:HandleTeamContextChanged(true)
        end
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show()
        elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton()
        end
        if MainPanel and MainPanel.StartUpdateTimer then
            MainPanel:StartUpdateTimer()
        end
    else
        if Area then
            Area.detectionPaused = true
        end
        if CrateTrackerZK and CrateTrackerZK.PauseAllDetections then
            CrateTrackerZK:PauseAllDetections()
        end
        if TickerController and TickerController.StopTeamSharedWarmupTicker then
            TickerController:StopTeamSharedWarmupTicker(CrateTrackerZK)
        end
        ResetSyncListeners()
        ResetSharedSyncRuntimeState()
        ResetShoutDetector()
        if MainPanel and MainPanel.StopUpdateTimer then
            MainPanel:StopUpdateTimer()
        end
    end

    RefreshSettingsState()
    return true
end

function AddonControlService:SetMapTracked(expansionID, mapID, tracked)
    if not Data or not Data.SetMapTracked then
        return false
    end
    local changed = Data:SetMapTracked(expansionID, mapID, tracked == true)
    if not changed then
        return false
    end
    return RefreshTrackedMapRuntime()
end

function AddonControlService:SetMapVisibleForExpansion(expansionID, mapID, visible)
    if not expansionID or type(mapID) ~= "number" then
        return false
    end

    if Data and Data.GetMapByMapID then
        local mapData = Data:GetMapByMapID(mapID, expansionID)
        if mapData and mapData.id and mapData.expansionID == expansionID then
            if visible then
                if MainPanel and MainPanel.RestoreMap then
                    MainPanel:RestoreMap(mapData.id)
                end
            else
                if MainPanel and MainPanel.HideMap then
                    MainPanel:HideMap(mapData.id)
                end
            end
            return true
        end
    end

    if not Data or not Data.SetMapHiddenState then
        return false
    end

    Data:SetMapHiddenState(expansionID, mapID, visible ~= true)

    RefreshSettingsState()
    return true
end

function AddonControlService:CycleTheme()
    if not ThemeConfig or not ThemeConfig.IsSwitchEnabled or not ThemeConfig:IsSwitchEnabled() then
        return false
    end
    if not ThemeConfig.GetCurrentThemeID or not ThemeConfig.SetCurrentThemeID or not ThemeConfig.GetThemeList then
        return false
    end

    local options = ThemeConfig:GetThemeList() or {}
    if #options == 0 then
        return false
    end

    local currentID = ThemeConfig.GetCurrentThemeID()
    local currentIndex = 1
    for index, option in ipairs(options) do
        if option.id == currentID then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #options then
        nextIndex = 1
    end

    local nextID = options[nextIndex].id
    if not nextID then
        return false
    end
    if not ThemeConfig:SetCurrentThemeID(nextID) then
        return false
    end

    if MainPanel and MainPanel.RefreshTheme then
        MainPanel:RefreshTheme()
    elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable()
    end

    RefreshSettingsState()
    return true
end

return AddonControlService
