-- CrateTrackerZK - 命令模块
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
    
    -- 停止检测和计时器
    if TimerManager then TimerManager:StopMapIconDetection() end
    if CrateTrackerZK and CrateTrackerZK.phaseTimer then
        CrateTrackerZK.phaseTimer:SetScript("OnUpdate", nil);
    end

    -- 隐藏并销毁现有 UI，以便重建默认布局
    if CrateTrackerZKFrame then
        CrateTrackerZKFrame:Hide();
        CrateTrackerZKFrame = nil;
    end
    if CrateTrackerZKFloatingButton then
        CrateTrackerZKFloatingButton:Hide();
        CrateTrackerZKFloatingButton = nil;
    end

    -- 彻底清除持久化数据（SavedVariables）
    CRATETRACKERZK_DB = nil;
    CRATETRACKERZK_UI_DB = nil;

    -- 重置模块状态，确保重新初始化
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

    -- 重新初始化（等同于全新安装）
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
