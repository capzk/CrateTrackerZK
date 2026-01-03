-- Commands.lua - 处理斜杠命令

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
        Logger:Error("Commands", "错误", "Command module not loaded, please reload addon");
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
        -- 清除所有地图数据（包括旧版本字段）
        for k in pairs(CRATETRACKERZK_DB.mapData) do
            CRATETRACKERZK_DB.mapData[k] = nil;
        end
        -- 确保 mapData 表本身也被重置
        CRATETRACKERZK_DB.mapData = {};
    end
    if CRATETRACKERZK_UI_DB then
        -- 清除所有UI设置
        for k in pairs(CRATETRACKERZK_UI_DB) do
            CRATETRACKERZK_UI_DB[k] = nil;
        end
    end

    if Data then
        Data.maps = {};
    end
    if TimerManager then
        TimerManager.isInitialized = false;
        TimerManager.lastStatusReportTime = 0;  -- 重置状态报告时间
        -- 清除检测状态
        if TimerManager.detectionState then
            TimerManager.detectionState = {};
        end
    end
    if MapTracker then
        MapTracker:Initialize();  -- 重置所有地图追踪状态
    end
    if Phase and Phase.Reset then
        Phase:Reset();  -- 重置位面检测状态
    end
    if Area then
        Area.lastAreaValidState = nil;
        Area.detectionPaused = false;
    end
    if Notification then
        Notification.isInitialized = false;
        Notification.firstNotificationTime = {};  -- 清除首次通知时间记录
        Notification.playerSentNotification = {};  -- 清除玩家发送通知记录
    end
    if TeamCommListener then
        TeamCommListener.isInitialized = false;
        TeamCommListener.messagePatterns = {};
        -- 清理聊天框架
        if TeamCommListener.chatFrame then
            TeamCommListener.chatFrame:UnregisterAllEvents();
            TeamCommListener.chatFrame:SetScript("OnEvent", nil);
            TeamCommListener.chatFrame = nil;
        end
    end
    if Logger then
        Logger:ClearMessageCache();
    end
    -- 重置核心模块的定时器状态
    if CrateTrackerZK then
        CrateTrackerZK.phaseTimerPaused = false;
        CrateTrackerZK.phaseResumePending = false;
    end
    
    -- 清除MainPanel的内存状态
    if MainPanel then
        MainPanel.lastNotifyClickTime = {};
    end
    
    -- 清除所有地图数据中的内存状态
    if Data and Data.maps then
        for _, mapData in ipairs(Data.maps) do
            if mapData then
                mapData.currentPhaseID = nil;
            end
        end
    end

    if CrateTrackerZK and CrateTrackerZK.Reinitialize then
        CrateTrackerZK:Reinitialize();
        Logger:Success("Commands", "命令", L["DataCleared"]);
    else
        Logger:Error("Commands", "错误", "Clear data failed: Data module not loaded");
    end
end

function Commands:HandleTeamNotificationCommand(arg)
    if not Notification then
        Logger:Error("Commands", "错误", "Notification module not loaded");
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
    Logger:Info("Commands", "帮助", "更多帮助信息请查看UI帮助菜单（点击主面板的'帮助'按钮）");
    if L["HelpUpdateWarning"] then
        Logger:Warn("Commands", "警告", L["HelpUpdateWarning"]);
    end
end
