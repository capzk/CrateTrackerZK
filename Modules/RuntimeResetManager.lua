-- RuntimeResetManager.lua - 统一运行时重置与清理入口

local RuntimeResetManager = BuildEnv("RuntimeResetManager");
local CrateTrackerZK = BuildEnv("CrateTrackerZK");

function RuntimeResetManager:EnsureSavedVariables()
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {};
    end
end

function RuntimeResetManager:ResetSharedRuntimeState()
    if TimerManager then
        TimerManager.detectionState = {};
    end

    if MapTracker and MapTracker.Initialize then
        MapTracker:Initialize();
    end

    if Phase and Phase.Reset then
        Phase:Reset();
    end

    if Area then
        Area.lastAreaValidState = nil;
        Area.lastAccessMode = nil;
        Area.detectionPaused = false;
    end

    if Notification then
        Notification.firstNotificationTime = {};
        Notification.playerSentNotification = {};
    end

    if CrateTrackerZK and CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel();
        CrateTrackerZK.phaseTimerTicker = nil;
    end
    if CrateTrackerZK then
        CrateTrackerZK.phaseTimerPaused = false;
        CrateTrackerZK.phaseResumePending = false;
    end

    if Logger and Logger.ClearMessageCache then
        Logger:ClearMessageCache();
    end

    if MainPanel then
        MainPanel.lastNotifyClickTime = {};
    end
end

function RuntimeResetManager:PrepareUIForClear()
    if TimerManager and TimerManager.StopMapIconDetection then
        TimerManager:StopMapIconDetection();
    end

    if CrateTrackerZK and CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel();
        CrateTrackerZK.phaseTimerTicker = nil;
    end

    if CrateTrackerZKFrame then
        CrateTrackerZKFrame:Hide();
    end
    if CrateTrackerZKFloatingButton then
        CrateTrackerZKFloatingButton:Show();
    end
end

function RuntimeResetManager:ClearPersistentData()
    if CRATETRACKERZK_DB then
        CRATETRACKERZK_DB.expansionData = {};
        CRATETRACKERZK_DB.mapData = nil;
        if Data and Data.SCHEMA_VERSION then
            CRATETRACKERZK_DB.schemaVersion = Data.SCHEMA_VERSION;
        end
    end

    if CRATETRACKERZK_UI_DB then
        for k in pairs(CRATETRACKERZK_UI_DB) do
            CRATETRACKERZK_UI_DB[k] = nil;
        end
    end
end

function RuntimeResetManager:ResetCommandRuntimeState()
    if Data then
        Data.maps = {};
        Data.mapsById = {};
        Data.mapsByMapID = {};
    end

    if TimerManager then
        TimerManager.isInitialized = false;
        TimerManager.detectionState = {};
    end

    self:ResetSharedRuntimeState();

    if Notification then
        Notification.isInitialized = false;
    end

    if TeamCommListener then
        TeamCommListener.isInitialized = false;
        TeamCommListener.messagePatterns = {};
    end

    if ShoutDetector then
        ShoutDetector.isInitialized = false;
    end
end

return RuntimeResetManager;
