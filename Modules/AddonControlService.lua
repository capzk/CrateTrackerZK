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

local function RefreshTrackedMapRuntime()
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

    if MapTracker and MapTracker.Initialize then
        MapTracker:Initialize()
    end

    if Phase and Phase.Reset then
        Phase:Reset()
    end

    if TeamCommListener and TeamCommListener.Initialize then
        TeamCommListener.isInitialized = false
        TeamCommListener:Initialize()
    end

    if Area then
        Area.lastAreaValidState = nil
        if AddonControlService:IsAddonEnabled() then
            Area:CheckAndUpdateAreaValid()
        else
            Area.detectionPaused = true
        end
    end

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
        if TeamCommListener then
            TeamCommListener.isInitialized = false
            TeamCommListener.messagePatterns = {}
        end
        if ShoutDetector then
            ShoutDetector.isInitialized = false
        end
        if CRATETRACKERZK_DB then
            CRATETRACKERZK_DB.expansionData = {}
            CRATETRACKERZK_DB.mapData = nil
            if Data and Data.SCHEMA_VERSION then
                CRATETRACKERZK_DB.schemaVersion = Data.SCHEMA_VERSION
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
        if Area then
            Area.lastAreaValidState = nil
            Area:CheckAndUpdateAreaValid()
        end
        if TeamCommListener then
            TeamCommListener.isInitialized = false
            TeamCommListener:Initialize()
        end
        if ShoutDetector and ShoutDetector.Initialize then
            ShoutDetector.isInitialized = false
            ShoutDetector:Initialize()
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
        if TeamCommListener then
            TeamCommListener.isInitialized = false
            TeamCommListener.messagePatterns = {}
        end
        if ShoutDetector then
            ShoutDetector.isInitialized = false
        end
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
