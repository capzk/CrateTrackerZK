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
        Logger:Warn("Commands", "命令", string.format(L["UnknownCommand"], command));
        self:ShowHelp();
    end
end

function Commands:HandleDebugCommand(arg)
    if not Logger then
        Logger:Error("Commands", "错误", L["CommandModuleNotLoaded"]);
        return;
    end
    local enableDebug = (arg == "on");
    Logger:SetDebugEnabled(enableDebug);
    Logger:Info("Commands", "命令", enableDebug and "已开启调试" or "已关闭调试");
end

function Commands:HandleClearCommand(arg)
    Logger:Info("Commands", "命令", L["ClearingData"]);
    
    if TimerManager then TimerManager:StopMapIconDetection() end
    if CrateTrackerZK and CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel();
        CrateTrackerZK.phaseTimerTicker = nil;
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
    end
    if TimerManager then
        TimerManager.isInitialized = false;
    end
    -- 清除检测状态
    if DetectionState and Data then
        -- 清除所有地图的处理状态
        local maps = Data:GetAllMaps();
        if maps then
            for _, mapData in ipairs(maps) do
                if mapData then
                    DetectionState:ClearProcessed(mapData.id);
                end
            end
        end
    end
    if MapTracker then
        MapTracker.mapLeftTime = {};
        MapTracker.lastDetectedMapId = nil;
        MapTracker.lastDetectedGameMapID = nil;
    end
    if NotificationCooldown then
        NotificationCooldown.lastNotificationTime = {};
    end
    if Notification then
        Notification.isInitialized = false;
    end
    if Logger then
        Logger:ClearMessageCache();
    end

    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize();
        Logger:Success("Commands", "命令", L["DataCleared"]);
    else
        Logger:Error("Commands", "错误", L["DataClearFailedModule"]);
    end
end

function Commands:HandleTeamNotificationCommand(arg)
    if not Notification then
        Logger:Error("Commands", "错误", L["NotificationModuleNotLoaded"]);
        return;
    end
    
    if arg == "on" or arg == "enable" then
        Notification:SetTeamNotificationEnabled(true);
    elseif arg == "off" or arg == "disable" then
        Notification:SetTeamNotificationEnabled(false);
    else
        Logger:Info("Commands", "命令", L["TeamUsage1"]);
        Logger:Info("Commands", "命令", L["TeamUsage2"]);
        Logger:Info("Commands", "命令", L["TeamUsage3"]);
    end
end

function Commands:ShowHelp()
    Logger:Info("Commands", "帮助", L["HelpTitle"]);
    Logger:Info("Commands", "帮助", L["HelpClear"]);
    Logger:Info("Commands", "帮助", L["HelpTeam"]);
    Logger:Info("Commands", "帮助", L["HelpHelp"]);
    if L["HelpUpdateWarning"] then
        Logger:Warn("Commands", "警告", L["HelpUpdateWarning"]);
    end
end
