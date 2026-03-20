-- AddonLifecycle.lua - Core 初始化与重建流程

local AddonLifecycle = BuildEnv("CrateTrackerZKAddonLifecycle")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Analytics = BuildEnv("CrateTrackerZKAnalytics")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local TickerController = BuildEnv("CrateTrackerZKTickerController")

local function ResetRuntimeState()
    if RuntimeResetManager and RuntimeResetManager.ResetSharedRuntimeState then
        RuntimeResetManager:ResetSharedRuntimeState()
        return
    end

    if TimerManager then
        TimerManager.detectionState = {}
        Logger:Debug("Core", "重置", "已清除检测状态（2秒确认期的临时状态）")
    end
    if MapTracker then
        MapTracker:Initialize()
        Logger:Debug("Core", "重置", "已重置地图追踪器状态")
    end
    if Phase and Phase.Reset then
        Phase:Reset()
    end
    if Area then
        Area.lastAreaValidState = nil
        Area.detectionPaused = false
    end
    if Data and Data.maps then
        for _, mapData in ipairs(Data.maps) do
            if mapData then
                mapData.currentPhaseID = nil
            end
        end
    end
    if Notification then
        Notification.firstNotificationTime = {}
        Notification.playerSentNotification = {}
    end
    if CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel()
        CrateTrackerZK.phaseTimerTicker = nil
    end
    CrateTrackerZK.phaseTimerPaused = false
    CrateTrackerZK.phaseResumePending = false
    if Logger and Logger.ClearMessageCache then
        Logger:ClearMessageCache()
    end
    if MainPanel then
        MainPanel.lastNotifyClickTime = {}
    end
end

local function EnsureSavedVariables()
    if RuntimeResetManager and RuntimeResetManager.EnsureSavedVariables then
        RuntimeResetManager:EnsureSavedVariables()
        return
    end

    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {}
    end
end

function AddonLifecycle:OnLogin()
    CoreShared:DebugPrint("[核心] 玩家已登录，开始初始化")

    EnsureSavedVariables()

    if Localization and Localization.Initialize and not Localization.isInitialized then
        Localization:Initialize()
    end

    if Data then
        Data:Initialize()
    end

    ResetRuntimeState()

    if Analytics and Analytics.RecordSessionState then
        Analytics:RecordSessionState()
    end

    if Notification then Notification:Initialize() end
    if Commands then Commands:Initialize() end

    if not CoreShared:IsAddonEnabled() then
        if Area then
            Area.detectionPaused = true
        end
        TickerController:PauseAllDetections(CrateTrackerZK)
        if CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton()
        end
        Logger:Warn("Core", "状态", "插件处于关闭状态，已跳过初始化")
        return
    end

    if TeamCommListener then TeamCommListener:Initialize() end
    if ShoutDetector and ShoutDetector.Initialize then ShoutDetector:Initialize() end
    if TimerManager then TimerManager:Initialize() end

    if MainPanel then MainPanel:CreateMainFrame() end
    if CrateTrackerZK.CreateFloatingButton then
        CrateTrackerZK:CreateFloatingButton()
    end

    local addonEnabled = CoreShared:IsAddonEnabled()
    local currentMapID = addonEnabled and CoreShared:GetCurrentMapID() or nil
    if Area then
        if addonEnabled then
            Area:CheckAndUpdateAreaValid(currentMapID)
        else
            Area.detectionPaused = true
            Area.lastAreaValidState = nil
        end
    end

    if addonEnabled and CoreShared:IsAreaActive() then
        TickerController:StartMapIconDetection(CrateTrackerZK, 1)
        TickerController:StartCleanupTicker(CrateTrackerZK)
        TickerController:StartAutoTeamReportTicker(CrateTrackerZK)
        TickerController:StartPhaseTicker(CrateTrackerZK)
    end

    CoreShared:DebugPrint("[核心] 初始化完成")
end

function AddonLifecycle:Reinitialize()
    return self:OnLogin()
end

return AddonLifecycle
