-- Commands.lua - 设置面板动作处理

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local AddonControlService = BuildEnv("AddonControlService");
local MainPanel = BuildEnv("MainPanel");
local Commands = BuildEnv('Commands');

Commands.isInitialized = false;

local function RegisterSlashCommands()
    if not SlashCmdList then
        return;
    end
    SLASH_CRATETRACKERZK1 = "/ctk";
    SlashCmdList["CRATETRACKERZK"] = function(msg)
        Commands:HandleSlashCommand(msg);
    end
end

function Commands:Initialize()
    if self.isInitialized then return end
    RegisterSlashCommands();
    self.isInitialized = true;
end

function Commands:HandleClearCommand(arg)
    if AddonControlService and AddonControlService.ClearDataAndReinitialize then
        if not AddonControlService:ClearDataAndReinitialize() then
            Logger:Error("Commands", "错误", "Clear data failed: Data module not loaded");
        end
    else
        Logger:Error("Commands", "错误", "Clear data failed: Data module not loaded");
    end
end

function Commands:HandleAddonToggle(enable)
    if AddonControlService and AddonControlService.ApplyAddonEnabled then
        AddonControlService:ApplyAddonEnabled(enable == true);
    end
end

function Commands:HandleSlashCommand(msg)
    if MainPanel and MainPanel.Toggle then
        MainPanel:Toggle();
    end
end

return Commands
