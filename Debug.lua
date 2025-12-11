--[[
    调试模块 (Debug.lua)
    负责统一管理所有调试功能
]]

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义Debug命名空间
local Debug = BuildEnv('Debug');

-- 模块状态
Debug.isInitialized = false;
Debug.enabled = false;
Debug.lastDebugMessage = {}; -- 用于限制输出频率
Debug.DEBUG_MESSAGE_INTERVAL = 30; -- 30秒

-- 初始化调试模块
function Debug:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    
    -- 从保存的变量中加载调试状态
    if CRATETRACKER_UI_DB and CRATETRACKER_UI_DB.debugEnabled ~= nil then
        self.enabled = CRATETRACKER_UI_DB.debugEnabled;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("调试模块已初始化");
    end
end

-- 获取调试状态
function Debug:IsEnabled()
    return self.enabled;
end

-- 设置调试状态
function Debug:SetEnabled(enabled)
    self.enabled = enabled;
    
    -- 保存到数据库
    if not CRATETRACKER_UI_DB then
        CRATETRACKER_UI_DB = {};
    end
    CRATETRACKER_UI_DB.debugEnabled = enabled;
    
    -- 同步到Utils模块
    if Utils and Utils.SetDebugEnabled then
        Utils.SetDebugEnabled(enabled);
    end
end

-- 输出调试信息（带限制）
-- @param messageKey 消息键（用于限制输出频率）
-- @param msg 消息内容
-- @param ... 附加参数
function Debug:PrintLimited(messageKey, msg, ...)
    if not self.enabled then
        return;
    end
    
    local currentTime = time();
    local lastTime = self.lastDebugMessage[messageKey] or 0;
    
    -- 如果距离上次输出超过间隔时间，才输出
    if (currentTime - lastTime) >= self.DEBUG_MESSAGE_INTERVAL then
        self.lastDebugMessage[messageKey] = currentTime;
        self:Print(msg, ...);
    end
end

-- 输出调试信息（立即输出）
-- @param msg 消息内容
-- @param ... 附加参数
function Debug:Print(msg, ...)
    if not self.enabled then
        return;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug(msg, ...);
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[空投物资追踪器]|r " .. tostring(msg));
    end
end

-- 清除调试消息记录（用于重置限制）
function Debug:ClearMessageCache()
    self.lastDebugMessage = {};
end

return Debug;

