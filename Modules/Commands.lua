-- Commands.lua - 处理斜杠命令

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
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
    elseif command == "on" then
        self:HandleAddonToggle(true);
    elseif command == "off" then
        self:HandleAddonToggle(false);
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
    Logger:Debug("Commands", "命令", "正在清除所有时间和位面数据...");
    
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

function Commands:HandleAddonToggle(enable)
    local currentlyEnabled = IsAddonEnabled();
    if enable and currentlyEnabled then
        Logger:Info("Commands", "命令", "插件已处于开启状态");
        return;
    end
    if not enable and not currentlyEnabled then
        Logger:Info("Commands", "命令", "插件已处于关闭状态");
        return;
    end

    SetAddonEnabled(enable);

    if enable then
        if Area then
            Area.detectionPaused = false;
        end
        if TimerManager and TimerManager.Initialize and not TimerManager.isInitialized then
            TimerManager:Initialize();
        end
        if CrateTrackerZK and CrateTrackerZK.ResumeAllDetections then
            CrateTrackerZK:ResumeAllDetections();
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
        Logger:Success("Commands", "命令", "插件已开启");
    else
        if Area then
            Area.detectionPaused = true;
        end
        if CrateTrackerZK and CrateTrackerZK.PauseAllDetections then
            CrateTrackerZK:PauseAllDetections();
        end
        if CrateTrackerZKFrame then
            CrateTrackerZKFrame:Hide();
        end
        if CrateTrackerZKFloatingButton then
            CrateTrackerZKFloatingButton:Hide();
        end
        if MainPanel and MainPanel.StopUpdateTimer then
            MainPanel:StopUpdateTimer();
        end
        if TeamCommListener then
            TeamCommListener.isInitialized = false;
            TeamCommListener.messagePatterns = {};
            if TeamCommListener.chatFrame then
                TeamCommListener.chatFrame:UnregisterAllEvents();
                TeamCommListener.chatFrame:SetScript("OnEvent", nil);
                TeamCommListener.chatFrame = nil;
            end
        end
        if ShoutDetector and ShoutDetector.eventFrame then
            ShoutDetector.eventFrame:UnregisterAllEvents();
            ShoutDetector.eventFrame:SetScript("OnEvent", nil);
            ShoutDetector.eventFrame = nil;
            ShoutDetector.isInitialized = false;
        end
        Logger:Success("Commands", "命令", "插件已关闭（功能暂停）");
    end
end

function Commands:ShowHelp()
    Logger:Info("Commands", "帮助", "可用命令：");
    Logger:Info("Commands", "帮助", "/ctk on - 启动插件");
    Logger:Info("Commands", "帮助", "/ctk off - 彻底关闭插件（暂停检测并隐藏界面）");
    Logger:Info("Commands", "帮助", "/ctk clear 或 /ctk reset - 清除所有数据并重新初始化插件");
    Logger:Info("Commands", "帮助", "/ctk team on|off - 开启/关闭团队通知");
    Logger:Info("Commands", "帮助", "更多帮助信息请查看UI帮助菜单（点击主面板的'帮助'按钮）");
end
