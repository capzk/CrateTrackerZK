-- Core.lua - 插件核心初始化、事件处理和模块协调

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local function DebugPrint(msg, ...)
    Logger:Debug("Core", "调试", msg, ...);
end

local function OnLogin()
    DebugPrint("[核心] 玩家已登录，开始初始化");
    
    -- 初始化 SavedVariables
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    -- 初始化团队时间共享功能开关（默认关闭）
    if CRATETRACKERZK_UI_DB.teamTimeShareEnabled == nil then
        CRATETRACKERZK_UI_DB.teamTimeShareEnabled = false;
    end
    if not CRATETRACKERZK_DB then
        CRATETRACKERZK_DB = {};
    end
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {};
    end
    if type(CRATETRACKERZK_DB.mapData) ~= "table" then
        CRATETRACKERZK_DB.mapData = {};
    end
    
    Logger:Success("Core", "启动", L["AddonInitializedSuccess"]);
    Logger:Success("Core", "启动", L["HelpCommandHint"]);

    if Localization and not Localization.isInitialized then
        Localization:Initialize();
    end
    
    if Data then Data:Initialize() end
    
    -- 重置内存检测状态（防止跨角色污染）
    
    if TimerManager then
        TimerManager.detectionState = {};
        Logger:Debug("Core", "重置", "已清除检测状态（2秒确认期的临时状态）");
    end
    
    if MapTracker then
        MapTracker:Initialize();
        Logger:Debug("Core", "重置", "已重置地图追踪器状态");
    end
    
    if Phase and Phase.Reset then
        Phase:Reset();
    end
    
    if Area then
        Area.lastAreaValidState = nil;
        Area.detectionPaused = false;
    end
    
    -- 清除地图数据中的内存状态
    if Data and Data.maps then
        for _, mapData in ipairs(Data.maps) do
            if mapData then
                mapData.currentPhaseID = nil;
                mapData.airdropActiveTimestamp = nil;  -- 清除空投活跃状态时间戳（内存变量）
            end
        end
    end
    
    -- 清除通知模块的通知时间记录
    if Notification then
        Notification.firstNotificationTime = {};
        Notification.playerSentNotification = {};
    end
    
    -- 重置定时器状态
    if CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel();
        CrateTrackerZK.phaseTimerTicker = nil;
    end
    CrateTrackerZK.phaseTimerPaused = false;
    CrateTrackerZK.phaseResumePending = false;
    
    -- 清理Logger缓存
    if Logger and Logger.ClearMessageCache then
        Logger:ClearMessageCache();
    end
    
    -- 清除MainPanel内存状态
    if MainPanel then
        MainPanel.lastNotifyClickTime = {};
    end
    
    if Notification then Notification:Initialize() end
    if Commands then Commands:Initialize() end
    if TeamMessageReader then TeamMessageReader:Initialize() end
    
    if TimerManager then
        TimerManager:Initialize();
        TimerManager:StartMapIconDetection(1);
    end
    
    if MainPanel then MainPanel:CreateMainFrame() end
    if CrateTrackerZK.CreateFloatingButton then
        CrateTrackerZK:CreateFloatingButton();
    end
    
    if Area then
        Area:CheckAndUpdateAreaValid();
        -- 启动位面检测定时器（取消延迟，立即启动）
        if Area.lastAreaValidState == true and not Area.detectionPaused then
            if not CrateTrackerZK.phaseTimerTicker then
                if CrateTrackerZK.phaseTimerTicker then
                    CrateTrackerZK.phaseTimerTicker:Cancel();
                end
                CrateTrackerZK.phaseTimerTicker = C_Timer.NewTicker(10, function()
                    if Phase and Area and not Area.detectionPaused then
                        Phase:UpdatePhaseInfo();
                    end
                end);
                CrateTrackerZK.phaseTimerPaused = false;
                Logger:Debug("Core", "状态", "已启动位面检测定时器（间隔10秒）");
                -- 立即执行一次位面检测
                if Phase then Phase:UpdatePhaseInfo() end
            end
        end
    end
    
    DebugPrint("[核心] 初始化完成");
end

function CrateTrackerZK:Reinitialize()
    OnLogin();
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnLogin();
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.1, function()
            local wasInvalid = Area and Area.lastAreaValidState == false;
            if Area then Area:CheckAndUpdateAreaValid() end
            local justValid = wasInvalid and (Area and Area.lastAreaValidState == true);
            
            if Area and not Area.detectionPaused then
                if TimerManager then TimerManager:DetectMapIcons() end
                -- 取消延迟，立即检测位面
                if Phase then Phase:UpdatePhaseInfo() end
            end
        end)
    elseif event == "PLAYER_TARGET_CHANGED" then
        if Area and not Area.detectionPaused then
            if Phase then Phase:UpdatePhaseInfo() end
        end
    elseif event == "PLAYER_LOGOUT" then
        -- 退出游戏时清除位面ID缓存
        if Phase and Phase.Reset then
            Phase:Reset();
            Logger:Debug("Core", "状态", "退出游戏，已清除位面ID缓存");
        end
    end
end

function CrateTrackerZK:PauseAllDetections()
    Logger:Debug("Core", "状态", "暂停所有检测功能");
    
    if self.phaseTimerTicker then
        self.phaseTimerTicker:Cancel();
        self.phaseTimerTicker = nil;
        self.phaseTimerPaused = true;
        Logger:Debug("Core", "状态", "已停止位面检测定时器");
    end
    
    if TimerManager then 
        TimerManager:StopMapIconDetection();
        Logger:Debug("Core", "状态", "已停止地图图标检测");
    end
end

function CrateTrackerZK:ResumeAllDetections()
    Logger:Debug("Core", "状态", "恢复所有检测功能");
    
    if TimerManager then 
        TimerManager:StartMapIconDetection(1);
        Logger:Debug("Core", "状态", "已启动地图图标检测");
    end
    
    -- 取消延迟，立即启动位面检测定时器
    if self.phaseTimerTicker then
        self.phaseTimerTicker:Cancel();
    end
    self.phaseTimerTicker = C_Timer.NewTicker(10, function()
        if Phase and Area and not Area.detectionPaused then
            Phase:UpdatePhaseInfo();
        end
    end);
    self.phaseTimerPaused = false;
    Logger:Debug("Core", "状态", "已启动位面检测定时器（间隔10秒）");
    -- 立即执行一次位面检测
    if Phase then Phase:UpdatePhaseInfo() end
end

local function HandleSlashCommand(msg)
    if Commands then
        Commands:HandleCommand(msg);
    else
        Logger:Error("Core", "错误", "Command module not loaded, please reload addon");
    end
end

SLASH_CRATETRACKERZK1 = "/ctk"
SLASH_CRATETRACKERZK2 = "/ct"
SlashCmdList.CRATETRACKERZK = HandleSlashCommand;

CrateTrackerZK.eventFrame = CreateFrame("Frame");
CrateTrackerZK.eventFrame:SetScript("OnEvent", OnEvent);
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_LOGIN");
CrateTrackerZK.eventFrame:RegisterEvent("ZONE_CHANGED");
CrateTrackerZK.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_LOGOUT");

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function()
        if Area and not Area.detectionPaused then
            if Phase then Phase:UpdatePhaseInfo() end
        end
    end)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function()
        if Area and not Area.detectionPaused then
            if Phase then Phase:UpdatePhaseInfo() end
        end
    end)
end
