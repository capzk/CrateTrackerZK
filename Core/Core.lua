-- Core.lua
-- 插件核心初始化、事件处理和模块协调

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local function DebugPrint(msg, ...)
    Logger:Debug("Core", "调试", msg, ...);
end

local function OnLogin()
    DebugPrint("[核心] 玩家已登录，开始初始化");
    
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    
    Logger:Success("Core", "启动", L["AddonInitializedSuccess"]);
    Logger:Success("Core", "启动", L["HelpCommandHint"]);

    if Localization and not Localization.isInitialized then
        Localization:Initialize();
    end
    
    -- 初始化数据模块（必须在重置状态之前）
    if Data then Data:Initialize() end
    
    -- 【修复】角色切换时重置所有内存中的检测状态
    -- 这些状态不应该跨角色共享，必须在每次登录时清除
    if DetectionState and DetectionState.ClearAllStates then
        DetectionState:ClearAllStates();
    end
    
    if MapTracker then
        MapTracker:Initialize();
        Logger:Debug("Core", "重置", "已重置地图追踪器状态");
    end
    
    -- 通知冷却期已移除，通知与空投检测绑定（由PROCESSED状态和2秒确认期防止重复）
    
    if Phase and Phase.Reset then
        Phase:Reset();
    end
    
    -- 重置 Area 模块状态
    if Area then
        Area.lastAreaValidState = nil;
        Area.detectionPaused = false;
    end
    
    -- 重置核心模块的定时器状态
    if CrateTrackerZK.phaseTimerTicker then
        CrateTrackerZK.phaseTimerTicker:Cancel();
        CrateTrackerZK.phaseTimerTicker = nil;
    end
    CrateTrackerZK.phaseTimerPaused = false;
    CrateTrackerZK.phaseResumePending = false;
    
    -- 清理Logger缓存（防止跨角色缓存污染）
    if Logger and Logger.ClearMessageCache then
        Logger:ClearMessageCache();
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
        -- 如果区域有效，确保位面检测定时器已启动
        if Area.lastAreaValidState == true and not Area.detectionPaused then
            if not CrateTrackerZK.phaseResumePending and not CrateTrackerZK.phaseTimerTicker then
                CrateTrackerZK.phaseResumePending = true;
                C_Timer.After(6, function()
                    CrateTrackerZK.phaseResumePending = false;
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
                end);
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
                
                if justValid then
                    C_Timer.After(6, function()
                        if Phase then Phase:UpdatePhaseInfo() end
                    end)
                else
                    if Phase then Phase:UpdatePhaseInfo() end
                end
            end
        end)
    elseif event == "PLAYER_TARGET_CHANGED" then
        if Area and not Area.detectionPaused then
            if Phase then Phase:UpdatePhaseInfo() end
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
    
    if not self.phaseResumePending then
        self.phaseResumePending = true;
        Logger:Debug("Core", "状态", "将在6秒后启动位面检测定时器");
        C_Timer.After(6, function()
            self.phaseResumePending = false;
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
        end)
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
CrateTrackerZK.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED");

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
