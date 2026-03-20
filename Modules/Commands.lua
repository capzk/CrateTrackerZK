-- Commands.lua - 设置面板动作处理

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local AddonControlService = BuildEnv("AddonControlService");
local Commands = BuildEnv('Commands');

Commands.isInitialized = false;

function Commands:Initialize()
    if self.isInitialized then return end
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
