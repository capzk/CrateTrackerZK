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
    if arg == "on" then
        if Debug then Debug:SetEnabled(true) end
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DebugEnabled"]);
    elseif arg == "off" then
        if Debug then Debug:SetEnabled(false) end
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DebugDisabled"]);
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DebugUsage"]);
    end
end

function Commands:HandleClearCommand(arg)
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["ClearingData"]);
    
    if Data and Data.ClearAllData then
        local success = Data:ClearAllData();
        if success then
            DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DataCleared"]);
        else
            DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["DataClearFailedEmpty"]);
        end
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
    elseif arg == "status" or arg == "check" then
        local status = Notification:IsTeamNotificationEnabled();
        local statusText = status and L["Enabled"] or L["Disabled"];
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamNotificationStatusPrefix"] .. statusText);
    else
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage1"]);
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage2"]);
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage3"]);
        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["TeamUsage4"]);
    end
end

function Commands:ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpTitle"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpClear"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpTeam"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpStatus"]);
    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["HelpHelp"]);
end
