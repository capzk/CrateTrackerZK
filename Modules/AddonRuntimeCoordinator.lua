-- AddonRuntimeCoordinator.lua - 插件运行时编排协调器

local AddonRuntimeCoordinator = BuildEnv("AddonRuntimeCoordinator")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Analytics = BuildEnv("CrateTrackerZKAnalytics")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local TickerController = BuildEnv("CrateTrackerZKTickerController")
local RuntimeResetManager = BuildEnv("RuntimeResetManager")
local Data = BuildEnv("Data")
local Notification = BuildEnv("Notification")
local MainPanel = BuildEnv("MainPanel")
local SettingsPanel = BuildEnv("CrateTrackerZKSettingsPanel")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
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
local ShoutDetector = BuildEnv("ShoutDetector")
local Area = BuildEnv("Area")
local Commands = BuildEnv("Commands")

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

local function ResetShoutDetector()
    ResetModuleInitializationState(ShoutDetector)
end

local function InitializeShoutDetector()
    ResetShoutDetector()
    InitializeModule(ShoutDetector)
end

local function InitializeSyncListeners(enablePublicSync)
    InitializeModule(TeamCommListener)
    if enablePublicSync == true then
        InitializeModule(TeamSharedSyncListener)
    end
end

local function ResetSharedSyncRuntimeState()
    if TimerManager then
        TimerManager.pendingAuthoritativeShoutByMap = {}
        TimerManager.mapSwitchGuardState = nil
    end
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
    if ShoutDetector and ShoutDetector.CancelAllTrajectoryShoutRetries then
        ShoutDetector:CancelAllTrajectoryShoutRetries()
    end
end

local function ResetRuntimeState()
    if RuntimeResetManager and RuntimeResetManager.ResetSharedRuntimeState then
        RuntimeResetManager:ResetSharedRuntimeState()
    end
end

local function EnsureMainUI()
    if MainPanel then
        MainPanel:CreateMainFrame()
    end
    if CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
        CrateTrackerZK:CreateFloatingButton()
    end
end

local function RefreshTrackedMapRuntimeInternal()
    if AirdropTrajectoryStore and AirdropTrajectoryStore.Initialize then
        AirdropTrajectoryStore:Initialize()
    end
    if Data and Data.Initialize then
        Data:Initialize()
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
        if CoreShared and CoreShared.IsAddonEnabled and CoreShared:IsAddonEnabled() then
            Area:CheckAndUpdateAreaValid()
        else
            Area.detectionPaused = true
        end
    end

    InitializeSyncListeners(CoreShared and CoreShared.IsAddonEnabled and CoreShared:IsAddonEnabled() == true)

    if MainPanel and MainPanel.RefreshTrackedMapConfiguration then
        MainPanel:RefreshTrackedMapConfiguration()
    elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable(true)
    end

    RefreshSettingsState()
    return true
end

function AddonRuntimeCoordinator:BootstrapOnLogin()
    if AirdropTrajectoryStore and AirdropTrajectoryStore.Initialize then
        AirdropTrajectoryStore:Initialize()
    end
    if Data then
        Data:Initialize()
    end

    ResetRuntimeState()

    if Analytics and Analytics.RecordSessionState then
        Analytics:RecordSessionState()
    end

    if Notification then
        Notification:Initialize()
    end
    if Commands then
        Commands:Initialize()
    end

    if not CoreShared:IsAddonEnabled() then
        if Area then
            Area.detectionPaused = true
        end
        TickerController:PauseAllDetections(CrateTrackerZK)
        if TickerController and TickerController.StopTeamSharedWarmupTicker then
            TickerController:StopTeamSharedWarmupTicker(CrateTrackerZK)
        end
        if CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton()
        end
        Logger:Warn("Core", "状态", "插件处于关闭状态，已跳过初始化")
        return true
    end

    EnsureMainUI()

    local addonEnabled = CoreShared:IsAddonEnabled()
    local currentMapID = addonEnabled and CoreShared:GetCurrentMapID() or nil
    if Area then
        if addonEnabled then
            Area:CheckAndUpdateAreaValid(currentMapID)
        else
            Area.detectionPaused = true
            Area.lastAreaValidState = nil
            Area.lastAccessMode = nil
        end
    end

    if TeamCommListener then
        TeamCommListener:Initialize()
    end
    if TeamSharedSyncListener
        and TeamSharedSyncListener.Initialize
        and TeamSharedSyncListener.IsFeatureEnabled
        and TeamSharedSyncListener:IsFeatureEnabled() == true then
        TeamSharedSyncListener:Initialize()
    end
    if TeamSharedWarmupService and TeamSharedWarmupService.Initialize then
        TeamSharedWarmupService:Initialize()
    end
    if AirdropTrajectorySyncService and AirdropTrajectorySyncService.Initialize then
        AirdropTrajectorySyncService:Initialize()
    end
    if ShoutDetector and ShoutDetector.Initialize then
        ShoutDetector:Initialize()
    end
    if TimerManager then
        TimerManager:Initialize()
    end
    if TickerController and TickerController.RefreshTeamSharedWarmupTicker then
        TickerController:RefreshTeamSharedWarmupTicker(CrateTrackerZK)
    end
    if TeamSharedWarmupService and TeamSharedWarmupService.HandleTeamContextChanged then
        TeamSharedWarmupService:HandleTeamContextChanged(false)
    end
    if AirdropTrajectorySyncService and AirdropTrajectorySyncService.HandleTeamContextChanged then
        AirdropTrajectorySyncService:HandleTeamContextChanged(false)
    end

    if addonEnabled and CoreShared:IsAreaActive() then
        TickerController:StartMapIconDetection(CrateTrackerZK, 1)
        TickerController:StartCleanupTicker(CrateTrackerZK)
        TickerController:StartAutoTeamReportTicker(CrateTrackerZK)
        TickerController:RefreshPhaseTicker(CrateTrackerZK)
    end

    return true
end

function AddonRuntimeCoordinator:EnableAddon()
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

    RefreshSettingsState()
    return true
end

function AddonRuntimeCoordinator:DisableAddon()
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

    RefreshSettingsState()
    return true
end

function AddonRuntimeCoordinator:RefreshTrackedMapRuntime()
    return RefreshTrackedMapRuntimeInternal()
end

function AddonRuntimeCoordinator:ClearDataAndReinitialize()
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
            if Data and Data.SCHEMA_VERSION then
                CRATETRACKERZK_DB.schemaVersion = Data.SCHEMA_VERSION
            end
        end
        if AirdropTrajectoryStore and AirdropTrajectoryStore.ClearPersistentData then
            AirdropTrajectoryStore:ClearPersistentData()
        elseif type(CRATETRACKERZK_TRAJECTORY_DB) == "table" then
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

    local success = false
    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize()
        if CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton()
        end
        success = true
    else
        if Logger and Logger.Error then
            Logger:Error("AddonControlService", "错误", "插件重初始化失败：Core 未加载")
        end
    end

    if success then
        RefreshSettingsState()
    end
    return success
end

return AddonRuntimeCoordinator
