-- Core.lua - 插件核心模块

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local function DebugPrint(msg, ...)
    Logger:Debug("Core", "调试", msg, ...);
end

local function IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true;
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true;
end

local function IsAreaActive()
    return Area and Area.lastAreaValidState == true and not Area.detectionPaused;
end

local function ShowWelcomeMessage()
    if CrateTrackerZK.welcomeShown then
        return;
    end
    local message = (L and L["AddonLoadedMessage"]) or "CrateTrackerZK loaded. /ctk help";
    if Logger and Logger.Info then
        Logger:Info("Core", "状态", message);
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(message);
    end
    CrateTrackerZK.welcomeShown = true;
end

local function OnLogin()
    DebugPrint("[核心] 玩家已登录，开始初始化");
    
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
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
    

    if Localization and not Localization.isInitialized then
        Localization:Initialize();
    end

    ShowWelcomeMessage();
    
    if Data then Data:Initialize() end
    
    -- 重置内存状态（防止跨角色污染）
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
    
    if Data and Data.maps then
        for _, mapData in ipairs(Data.maps) do
            if mapData then
                mapData.currentPhaseID = nil;
            end
        end
    end
    
    if Notification then
        Notification.firstNotificationTime = {};
        Notification.playerSentNotification = {};
    end
    
    if CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel();
        CrateTrackerZK.phaseTimerTicker = nil;
    end
    CrateTrackerZK.phaseTimerPaused = false;
    CrateTrackerZK.phaseResumePending = false;
    
    if Logger and Logger.ClearMessageCache then
        Logger:ClearMessageCache();
    end
    
    if MainPanel then
        MainPanel.lastNotifyClickTime = {};
    end
    
    if Notification then Notification:Initialize() end
    if Commands then Commands:Initialize() end

    if not IsAddonEnabled() then
        if Area then
            Area.detectionPaused = true;
        end
        if CrateTrackerZK and CrateTrackerZK.PauseAllDetections then
            CrateTrackerZK:PauseAllDetections();
        end
        if CrateTrackerZK and CrateTrackerZK.CreateFloatingButton then
            CrateTrackerZK:CreateFloatingButton();
        end
        Logger:Warn("Core", "状态", "插件处于关闭状态，已跳过初始化");
        return;
    end

    if TeamCommListener then TeamCommListener:Initialize() end
    if ShoutDetector and ShoutDetector.Initialize then ShoutDetector:Initialize() end
    
    if TimerManager then
        TimerManager:Initialize();
    end
    
    if MainPanel then MainPanel:CreateMainFrame() end
    if CrateTrackerZK.CreateFloatingButton then
        CrateTrackerZK:CreateFloatingButton();
    end
    
    if Area then
        Area:CheckAndUpdateAreaValid();
    end
    
    if IsAreaActive() then
        if TimerManager then
            TimerManager:StartMapIconDetection(1);
        end
        if CrateTrackerZK and CrateTrackerZK.StartCleanupTicker then
            CrateTrackerZK:StartCleanupTicker();
        end
        if CrateTrackerZK.phaseTimerTicker then
            CrateTrackerZK.phaseTimerTicker:Cancel();
        end
        CrateTrackerZK.phaseTimerTicker = C_Timer.NewTicker(10, function()
            if IsAreaActive() and Phase then
                Phase:UpdatePhaseInfo();
            end
        end);
        CrateTrackerZK.phaseTimerPaused = false;
        Logger:Debug("Core", "状态", "已启动位面检测定时器（间隔10秒）");
        if IsAreaActive() and Phase then Phase:UpdatePhaseInfo() end
    end
    
    DebugPrint("[核心] 初始化完成");
end

function CrateTrackerZK:Reinitialize()
    OnLogin();
end

local function OnEvent(self, event, ...)
    if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_LOGOUT" then
        if not IsAddonEnabled() then
            return;
        end
    end
    if event == "PLAYER_LOGIN" then
        OnLogin();
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.1, function()
            if Area then Area:CheckAndUpdateAreaValid() end
            if IsAreaActive() then
                if TimerManager then TimerManager:DetectMapIcons() end
                if Phase then Phase:UpdatePhaseInfo() end
            end
        end)
    elseif event == "PLAYER_TARGET_CHANGED" then
        if IsAreaActive() then
            if Phase then Phase:UpdatePhaseInfo() end
        end
    elseif event == "PLAYER_LOGOUT" then
        if Phase and Phase.Reset then
            Phase:Reset();
            Logger:Debug("Core", "状态", "退出游戏，已清除位面ID缓存");
        end
    elseif event == "CHAT_MSG_MONSTER_SAY"
        or event == "CHAT_MSG_MONSTER_YELL"
        or event == "CHAT_MSG_MONSTER_EMOTE"
        or event == "CHAT_MSG_MONSTER_PARTY"
        or event == "CHAT_MSG_MONSTER_WHISPER"
        or event == "CHAT_MSG_RAID_BOSS_EMOTE"
        or event == "CHAT_MSG_RAID_BOSS_WHISPER" then
        if IsAreaActive() then
            if ShoutDetector and ShoutDetector.HandleChatEvent then
                local message = select(1, ...);
                ShoutDetector:HandleChatEvent(event, message);
            end
        end
    elseif event == "CHAT_MSG_RAID"
        or event == "CHAT_MSG_RAID_WARNING"
        or event == "CHAT_MSG_PARTY"
        or event == "CHAT_MSG_INSTANCE_CHAT" then
        if IsAreaActive() then
            if TeamCommListener and TeamCommListener.HandleChatEvent then
                local message = select(1, ...);
                local sender = select(2, ...);
                TeamCommListener:HandleChatEvent(event, message, sender);
            end
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
    
    if self.mapIconDetectionTicker then
        self.mapIconDetectionTicker:Cancel();
        self.mapIconDetectionTicker = nil;
        Logger:Debug("Core", "状态", "已停止地图图标检测");
    end
    
    if self.cleanupTicker then
        self.cleanupTicker:Cancel();
        self.cleanupTicker = nil;
        Logger:Debug("Core", "状态", "已停止临时数据清理定时器");
    end
end

function CrateTrackerZK:ResumeAllDetections()
    Logger:Debug("Core", "状态", "恢复所有检测功能");
    
    if self.StartMapIconDetection then
        self:StartMapIconDetection(1);
    end
    if self.StartCleanupTicker then
        self:StartCleanupTicker();
    end
    
    if self.phaseTimerTicker then
        self.phaseTimerTicker:Cancel();
    end
    self.phaseTimerTicker = C_Timer.NewTicker(10, function()
        if IsAreaActive() and Phase then
            Phase:UpdatePhaseInfo();
        end
    end);
    self.phaseTimerPaused = false;
    Logger:Debug("Core", "状态", "已启动位面检测定时器（间隔10秒）");
    if IsAreaActive() and Phase then Phase:UpdatePhaseInfo() end
end

function CrateTrackerZK:StartMapIconDetection(interval)
    if not TimerManager or not TimerManager.DetectMapIcons then
        Logger:Error("Core", "错误", "TimerManager不可用，无法启动地图图标检测");
        return false;
    end
    
    if self.mapIconDetectionTicker then
        self.mapIconDetectionTicker:Cancel();
        self.mapIconDetectionTicker = nil;
    end
    
    interval = interval or 1;
    self.mapIconDetectionTicker = C_Timer.NewTicker(interval, function()
        if IsAreaActive() then
            TimerManager:DetectMapIcons();
        end
    end);
    
    Logger:Debug("Core", "状态", string.format("已启动地图图标检测（间隔%d秒）", interval));
    return true;
end

function CrateTrackerZK:StopMapIconDetection()
    if self.mapIconDetectionTicker then
        self.mapIconDetectionTicker:Cancel();
        self.mapIconDetectionTicker = nil;
        Logger:Debug("Core", "状态", "已停止地图图标检测");
    end
    return true;
end

function CrateTrackerZK:StartCleanupTicker()
    if self.cleanupTicker then
        return;
    end
    if not UnifiedDataManager or not UnifiedDataManager.ClearExpiredTemporaryData then
        return;
    end
    self.cleanupTicker = C_Timer.NewTicker(300, function()
        UnifiedDataManager:ClearExpiredTemporaryData();
    end);
    Logger:Debug("Core", "状态", "已启动临时数据清理定时器（间隔300秒）");
end

function CrateTrackerZK:StopCleanupTicker()
    if self.cleanupTicker then
        self.cleanupTicker:Cancel();
        self.cleanupTicker = nil;
        Logger:Debug("Core", "状态", "已停止临时数据清理定时器");
    end
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
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_LOGOUT");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_PARTY");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_RAID");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_PARTY");
CrateTrackerZK.eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT");

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function()
        if IsAreaActive() and Phase then
            Phase:UpdatePhaseInfo();
        end
    end)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function()
        if IsAreaActive() and Phase then
            Phase:UpdatePhaseInfo();
        end
    end)
end
