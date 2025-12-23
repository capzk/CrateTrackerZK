-- CrateTrackerZK - 核心逻辑模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

local function OnLogin()
    DebugPrint("[Core] Player logged in, starting initialization");
    
    -- 确保 UI 数据库已初始化（SavedVariables 可能未自动初始化）
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    
    -- 验证 UI 数据库结构（处理旧版本或损坏的数据）
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["AddonLoaded"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpCommandHint"]);

    -- 初始化顺序：Localization -> Data -> 其他模块
    -- 注意：Localization:Initialize() 已在文件加载时自动调用，这里确保已初始化
    if Localization and not Localization.isInitialized then
        Localization:Initialize();
    end
    
    if Data then Data:Initialize() end
    if Debug then Debug:Initialize() end
    if Notification then Notification:Initialize() end
    if Commands then Commands:Initialize() end
    
    if TimerManager then
        TimerManager:Initialize();
        TimerManager:StartMapIconDetection(2);
    end
    
    if MainPanel then MainPanel:CreateMainFrame() end
    if CrateTrackerZK.CreateFloatingButton then
        CrateTrackerZK:CreateFloatingButton();
    end
    
    if Area then
        Area:CheckAndUpdateAreaValid();
    end
    
    DebugPrint("[Core] Initialization completed");
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
    if self.phaseTimer then
        self.phaseTimer:SetScript("OnUpdate", nil);
        self.phaseTimerPaused = true;
    end
    
    if TimerManager then TimerManager:StopMapIconDetection() end
    
end

function CrateTrackerZK:ResumeAllDetections()
    if TimerManager then TimerManager:StartMapIconDetection(2) end
    
    
    if self.phaseTimer and not self.phaseResumePending then
        self.phaseResumePending = true;
        C_Timer.After(6, function()
            self.phaseResumePending = false;
            if self.phaseTimer then
                local phaseLastTime = 0;
                self.phaseTimer:SetScript("OnUpdate", function(sf, elapsed)
                    phaseLastTime = phaseLastTime + elapsed;
                    if phaseLastTime >= 10 then
                        phaseLastTime = 0;
                        if Phase then Phase:UpdatePhaseInfo() end
                    end
                end);
                self.phaseTimerPaused = false;
            end
        end)
    end
end

local function HandleSlashCommand(msg)
    if Commands then
        Commands:HandleCommand(msg);
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["CommandModuleNotLoaded"]);
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

CrateTrackerZK.phaseTimer = CreateFrame("Frame");

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
