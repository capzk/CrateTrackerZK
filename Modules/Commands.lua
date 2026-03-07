-- Commands.lua - 设置面板动作处理

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local Commands = BuildEnv('Commands');

Commands.isInitialized = false;

local function EnsureUIConfig()
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
end

local function IsAddonEnabled()
    EnsureUIConfig();
    if CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true;
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true;
end

local function SetAddonEnabled(enabled)
    EnsureUIConfig();
    CRATETRACKERZK_UI_DB.addonEnabled = enabled == true;
end

function Commands:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true;
end

function Commands:HandleClearCommand(arg)
    if RuntimeResetManager and RuntimeResetManager.PrepareUIForClear then
        RuntimeResetManager:PrepareUIForClear();
    end
    if RuntimeResetManager and RuntimeResetManager.ClearPersistentData then
        RuntimeResetManager:ClearPersistentData();
    end
    if RuntimeResetManager and RuntimeResetManager.ResetCommandRuntimeState then
        RuntimeResetManager:ResetCommandRuntimeState();
    else
        if Data then
            Data.maps = {};
        end
        if TimerManager then
            TimerManager.isInitialized = false;
            if TimerManager.detectionState then
                TimerManager.detectionState = {};
            end
        end
        if TeamCommListener then
            TeamCommListener.isInitialized = false;
            TeamCommListener.messagePatterns = {};
        end
        if ShoutDetector then
            ShoutDetector.isInitialized = false;
        end
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
        if CrateTrackerZKFrame then
            CrateTrackerZKFrame:Hide();
            CrateTrackerZKFrame = nil;
        end
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show();
        end
    end

    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize();
        if CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton();
        end
    else
        Logger:Error("Commands", "错误", "Clear data failed: Data module not loaded");
    end
end

function Commands:HandleAddonToggle(enable)
    local currentlyEnabled = IsAddonEnabled();
    if enable and currentlyEnabled then
        return;
    end
    if not enable and not currentlyEnabled then
        return;
    end

    SetAddonEnabled(enable);

    if enable then
        if TimerManager and TimerManager.Initialize and not TimerManager.isInitialized then
            TimerManager:Initialize();
        end
        if Area then
            Area.detectionPaused = false;
            Area.lastAreaValidState = nil;
            Area:CheckAndUpdateAreaValid();
        end
        if TeamCommListener then
            TeamCommListener.isInitialized = false;
            TeamCommListener:Initialize();
        end
        if ShoutDetector and ShoutDetector.Initialize then
            ShoutDetector.isInitialized = false;
            ShoutDetector:Initialize();
        end
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Show();
        elseif CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton();
        end
        if MainPanel and MainPanel.StartUpdateTimer then
            MainPanel:StartUpdateTimer();
        end
    else
        if Area then
            Area.detectionPaused = true;
        end
        if CrateTrackerZK and CrateTrackerZK.PauseAllDetections then
            CrateTrackerZK:PauseAllDetections();
        end
        if TeamCommListener then
            TeamCommListener.isInitialized = false;
            TeamCommListener.messagePatterns = {};
        end
        if ShoutDetector then
            ShoutDetector.isInitialized = false;
        end
        if MainPanel and MainPanel.StopUpdateTimer then
            MainPanel:StopUpdateTimer();
        end
    end
    
    if SettingsPanel and SettingsPanel.RefreshState then
        SettingsPanel:RefreshState();
    end
end
