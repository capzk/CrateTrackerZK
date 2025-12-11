--[[
    命令模块 (Commands.lua)
    负责处理所有命令行功能
]]

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义Commands命名空间
local Commands = BuildEnv('Commands');

-- 模块状态
Commands.isInitialized = false;

-- 初始化命令模块
function Commands:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    
    if Utils and Utils.Debug then
        Utils.Debug("命令模块已初始化");
    end
end

-- 处理命令
-- @param msg 命令消息
function Commands:HandleCommand(msg)
    if not self.isInitialized then
        self:Initialize();
    end
    
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
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[空投物资追踪器]|r 未知命令：" .. command);
        self:ShowHelp();
    end
end

-- 处理调试命令
function Commands:HandleDebugCommand(arg)
    if arg == "on" then
        if Debug then
            Debug:SetEnabled(true);
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 调试信息已开启");
    elseif arg == "off" then
        if Debug then
            Debug:SetEnabled(false);
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 调试信息已关闭");
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 调试命令：/ct debug on|off");
        end
end

-- 处理清除数据命令
function Commands:HandleClearCommand(arg)
    if arg == "data" or arg == "all" or not arg then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 正在清除所有时间和位面数据...");
        
        if Data and Data.ClearAllData then
            local success = Data:ClearAllData();
            if success then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[空投物资追踪器]|r 已清除所有时间和位面数据，地图列表已保留");
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[空投物资追踪器]|r 清除数据失败：地图列表为空");
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[空投物资追踪器]|r 清除数据失败：Data模块未加载");
        end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 清除命令：/ct clear 或 /ct reset");
        end
end

-- 处理团队通知命令
function Commands:HandleTeamNotificationCommand(arg)
    if not Notification then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[空投物资追踪器]|r 通知模块未加载");
        return;
    end
    
    if arg == "on" or arg == "enable" then
        Notification:SetTeamNotificationEnabled(true);
    elseif arg == "off" or arg == "disable" then
        Notification:SetTeamNotificationEnabled(false);
    elseif arg == "status" or arg == "check" then
        local status = Notification:IsTeamNotificationEnabled();
        local statusText = status and "已开启" or "已关闭";
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 团队通知状态：" .. statusText);
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 团队通知命令：");
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct team on - 开启团队通知");
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct team off - 关闭团队通知");
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct team status - 查看团队通知状态");
    end
end

-- 显示帮助信息
function Commands:ShowHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r 可用命令：");
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct clear 或 /ct reset - 清除所有时间和位面数据（保留地图列表）");
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct team on|off - 开启/关闭团队通知");
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct team status - 查看团队通知状态");
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[空投物资追踪器]|r /ct help - 显示此帮助信息");
end

return Commands;

