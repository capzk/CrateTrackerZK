local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Commands = BuildEnv('Commands');

Commands.isInitialized = false;

function Commands:Initialize()
    if self.isInitialized then return end
    self.isInitialized = true;
end

function Commands:HandleCommand(msg)
    if not self.isInitialized then self:Initialize() end
    
    local command, arg = strsplit(" ", msg, 2);
    command = string.lower(command or "");
    
    if command == "debug" then
        self:HandleDebugCommand(arg);
    elseif command == "clear" or command == "reset" then
        self:HandleClearCommand(arg);
    elseif command == "team" or command == "teamnotify" then
        self:HandleTeamNotificationCommand(arg);
    elseif command == "help" or command == "" or command == nil then
        self:ShowHelp();
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. string.format(L["UnknownCommand"], command));
        self:ShowHelp();
    end
end

function Commands:HandleDebugCommand(arg)
    if not Debug then
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["CommandModuleNotLoaded"]);
        return;
    end
    local enableDebug = (arg == "on");
    Debug:SetEnabled(enableDebug);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. (enableDebug and "已开启调试" or "已关闭调试"));
end

function Commands:HandleClearCommand(arg)
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["ClearingData"]);
    
    if TimerManager then TimerManager:StopMapIconDetection() end
    if CrateTrackerZK and CrateTrackerZK.phaseTimer then
        CrateTrackerZK.phaseTimer:SetScript("OnUpdate", nil);
    end
    if MainPanel and MainPanel.updateTimer then
        MainPanel.updateTimer:Cancel();
        MainPanel.updateTimer = nil;
    end

    if CrateTrackerZKFrame then
        CrateTrackerZKFrame:Hide();
        CrateTrackerZKFrame = nil;
    end
    if CrateTrackerZKFloatingButton then
        CrateTrackerZKFloatingButton:Hide();
        CrateTrackerZKFloatingButton = nil;
    end

    if CRATETRACKERZK_DB and CRATETRACKERZK_DB.mapData then
        for k in pairs(CRATETRACKERZK_DB.mapData) do
            CRATETRACKERZK_DB.mapData[k] = nil;
        end
    end
    if CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB.position = nil;
        CRATETRACKERZK_UI_DB.minimapButton = nil;
        CRATETRACKERZK_UI_DB.debugEnabled = nil;
        CRATETRACKERZK_UI_DB.teamNotificationEnabled = nil;
    end

    if Data then
        Data.maps = {};
        Data.manualInputLock = {};
    end
    if TimerManager then
        TimerManager.isInitialized = false;
        TimerManager.mapIconDetected = {};
        TimerManager.mapIconFirstDetectedTime = {};
        TimerManager.lastUpdateTime = {};
        TimerManager.lastDebugMessage = {};
    end
    if Notification then
        Notification.isInitialized = false;
    end
    if Debug then
        Debug.isInitialized = false;
        Debug.enabled = false;
        Debug.lastDebugMessage = {};
    end

    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize();
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DataCleared"]);
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DataClearFailedModule"]);
    end
end

function Commands:HandleTeamNotificationCommand(arg)
    if not Notification then
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["NotificationModuleNotLoaded"]);
        return;
    end
    
    if arg == "on" or arg == "enable" then
        Notification:SetTeamNotificationEnabled(true);
    elseif arg == "off" or arg == "disable" then
        Notification:SetTeamNotificationEnabled(false);
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage1"]);
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage2"]);
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage3"]);
    end
end

function Commands:ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpTitle"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpClear"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpTeam"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpHelp"]);
    if L["HelpUpdateWarning"] then
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpUpdateWarning"]);
    end
end
