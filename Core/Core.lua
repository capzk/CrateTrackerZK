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
    
    Logger:Success("Core", "启动", "插件初始化成功，祝您游戏愉快！");
    Logger:Success("Core", "启动", L["HelpCommandHint"]);

    if Localization and not Localization.isInitialized then
        Localization:Initialize();
    end
    
    if Data then Data:Initialize() end
    if Notification then Notification:Initialize() end
    if Commands then Commands:Initialize() end
    
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
    if self.phaseTimerTicker then
        self.phaseTimerTicker:Cancel();
        self.phaseTimerTicker = nil;
        self.phaseTimerPaused = true;
    end
    
    if TimerManager then TimerManager:StopMapIconDetection() end
    
end

function CrateTrackerZK:ResumeAllDetections()
    if TimerManager then TimerManager:StartMapIconDetection(1) end
    
    if not self.phaseResumePending then
        self.phaseResumePending = true;
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
        end)
    end
end

local function HandleSlashCommand(msg)
    if Commands then
        Commands:HandleCommand(msg);
    else
        Logger:Error("Core", "错误", L["CommandModuleNotLoaded"]);
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
