-- Logger.lua
-- 统一的日志输出模块
-- 职责：整合所有信息输出功能（错误信息/debug/常规通知等）
-- 使用不同前缀来表明输出来源和功能

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Logger = BuildEnv('Logger');

-- 日志级别
Logger.LEVELS = {
    ERROR = "ERROR",       -- 错误信息（红色）
    WARN = "WARN",         -- 警告信息（橙色）
    INFO = "INFO",         -- 常规信息（蓝色）
    DEBUG = "DEBUG",       -- 调试信息（绿色）
    SUCCESS = "SUCCESS"    -- 成功信息（青色）
};

-- 日志级别颜色（WoW颜色代码）
Logger.COLORS = {
    [Logger.LEVELS.ERROR] = "ffff0000",   -- 红色
    [Logger.LEVELS.WARN] = "ffff8800",    -- 橙色
    [Logger.LEVELS.INFO] = "ff4FC1FF",    -- 蓝色
    [Logger.LEVELS.DEBUG] = "ff00ff00",   -- 绿色
    [Logger.LEVELS.SUCCESS] = "ff00ffff"  -- 青色
};

-- 模块前缀映射（用于标识输出来源）
Logger.MODULE_PREFIXES = {
    -- 核心模块
    ["Core"] = "核心",
    ["Data"] = "数据",
    ["Timer"] = "计时器",
    ["Notification"] = "通知",
    ["Commands"] = "命令",
    ["Area"] = "区域",
    ["Phase"] = "位面",
    
    -- 重构后的检测模块
    ["IconDetector"] = "图标检测",
    ["MapTracker"] = "地图追踪",
    ["DetectionState"] = "检测状态",
    ["DetectionDecision"] = "检测决策",
    ["NotificationCooldown"] = "通知冷却",
    
    -- UI模块
    ["MainPanel"] = "主面板",
    ["FloatingButton"] = "浮动按钮",
    ["Info"] = "信息",
    
    -- 工具模块
    ["Utils"] = "工具",
    ["Localization"] = "本地化",
    ["Debug"] = "调试"
};

-- 功能前缀映射（用于标识输出功能）
Logger.FUNCTION_PREFIXES = {
    ["检测"] = "检测",
    ["通知"] = "通知",
    ["更新"] = "更新",
    ["初始化"] = "初始化",
    ["错误"] = "错误",
    ["警告"] = "警告",
    ["状态"] = "状态",
    ["地图"] = "地图",
    ["时间"] = "时间",
    ["冷却"] = "冷却",
    ["保存"] = "保存",
    ["加载"] = "加载",
    ["清除"] = "清除",
    ["用户操作"] = "用户操作",
    ["界面"] = "界面"
};

-- 调试文本字典（从 Debug.lua 迁移）
Logger.DEBUG_TEXTS = {
    DebugNoRecord = "无记录",
    DebugTimerStarted = "计时开始：%s，来源=%s，下次=%s",
    DebugDetectionSourceManual = "手动输入",
    DebugDetectionSourceRefresh = "刷新按钮",
    DebugDetectionSourceAPI = "API 接口",
    DebugDetectionSourceMapIcon = "地图图标检测",
    DebugCannotGetMapName2 = "无法获取当前地图名称",
    DebugCMapAPINotAvailable = "C_Map API 不可用",
    DebugCannotGetMapID = "无法获取当前地图 ID",
    DebugCMapGetMapInfoNotAvailable = "C_Map.GetMapInfo 不可用",
    DebugMapListEmpty = "地图列表为空，跳过检测",
    DebugMapMatchSuccess = "匹配到地图：%s",
    DebugParentMapMatchSuccess = "匹配到父地图：%s（父=%s）",
    DebugMapNotInList = "当前地图不在列表中，跳过：%s（父=%s，ID=%s）",
    DebugMapIconNameNotConfigured = "空投箱名称未配置，跳过图标检测",
    DebugIconDetectionStart = "开始检测地图图标：%s，空投名称=%s",
    DebugDetectedMapIconVignette = "检测到地图图标：%s（空投名称=%s）",
    DebugFirstDetectionWait = "首次检测到图标，等待持续确认：%s",
    DebugContinuousDetectionConfirmed = "持续检测确认，更新时间并通知：%s（间隔=%s秒）",
    DebugUpdatedRefreshTime = "刷新时间已更新：%s，下一次=%s",
    DebugUpdateRefreshTimeFailed = "刷新时间更新失败：地图 ID=%s",
    DebugAirdropActive = "空投事件进行中：%s",
    DebugWaitingForConfirmation = "等待持续检测确认：%s（已等待=%s秒）",
    DebugClearedFirstDetectionTime = "清除首次检测时间，未再检测到图标：%s",
    DebugAirdropEnded = "未检测到图标，空投事件结束：%s",
    DebugAreaInvalidInstance = "区域无效（副本/战场/室内），自动暂停",
    DebugAreaCannotGetMapID = "无法获取地图 ID",
    DebugAreaValid = "区域有效，已恢复：%s",
    DebugAreaInvalidNotInList = "区域无效（不在列表中），自动暂停：%s",
    DebugPhaseDetectionPaused = "位面检测已暂停，跳过",
    DebugPhaseNoMapID = "无法获取当前地图 ID，跳过位面更新",
};

-- 获取调试文本（从 Debug.lua 迁移）
function Logger:GetDebugText(key)
    return (self.DEBUG_TEXTS and self.DEBUG_TEXTS[key]) or key;
end

-- 初始化
function Logger:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    self.debugEnabled = false;
    self.lastDebugMessage = {}; -- 用于限流 { [messageKey] = timestamp }
    self.messageCounts = {}; -- 用于统计限流消息数量 { [messageKey] = count }
    self.DEBUG_MESSAGE_INTERVAL = 30; -- 默认调试消息限流间隔（秒）
    
    -- 不同消息类型的限流间隔（秒）
    -- 关键信息限流很短或不限流，普通信息限流较长
    self.RATE_LIMITS = {
        -- 关键调试信息（应该显示，限流很短）
        ["detection_loop:start"] = 5, -- 检测循环开始，5秒限流（避免刷屏但能看到）
        ["detection_loop:map_matched"] = 0, -- 地图匹配成功，不限流（关键信息）
        ["detection_loop:map_not_in_list"] = 10, -- 地图不在列表，10秒限流
        ["icon_detection:result"] = 0, -- 图标检测结果，不限流（关键信息，但只在状态变化时输出）
        ["map_check:match"] = 0, -- 地图匹配成功，不限流（关键信息）
        ["state_change"] = 0, -- 状态变化，不限流（关键信息）
        ["phase_update"] = 0, -- 位面更新，不限流（关键信息）
        ["area_change"] = 0, -- 区域变化，不限流（关键信息）
        
        -- 普通调试信息（限流较长）
        ["detection_loop"] = 30, -- 其他检测循环信息，30秒限流
        ["icon_detection"] = 20, -- 其他图标检测信息，20秒限流
        ["map_check"] = 20, -- 其他地图检查信息，20秒限流
        ["state_check"] = 30, -- 状态检查，30秒限流
        
        -- 无用信息（限流很长或完全隐藏）
        ["ui_update"] = 300, -- UI更新，300秒限流（5分钟，基本不显示）
        
        -- 中频操作类
        ["data_save"] = 10, -- 数据保存，10秒限流
        ["data_update"] = 10, -- 数据更新，10秒限流
        
        -- 低频但可能重复的
        ["notification"] = 2, -- 通知，2秒限流（已有独立冷却期）
    };
    
    -- 从保存数据加载调试设置
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.debugEnabled ~= nil then
        self.debugEnabled = CRATETRACKERZK_UI_DB.debugEnabled;
    end
end

-- 设置调试模式
function Logger:SetDebugEnabled(enabled)
    self:Initialize();
    self.debugEnabled = enabled;
    
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    CRATETRACKERZK_UI_DB.debugEnabled = enabled;
end

-- 检查调试模式是否启用
function Logger:IsDebugEnabled()
    self:Initialize();
    return self.debugEnabled;
end

-- 构建日志前缀
-- 输入：level - 日志级别
--      module - 模块名称（可选）
--      func - 功能名称（可选）
-- 输出：格式化后的前缀字符串
local function BuildPrefix(level, module, func)
    local color = Logger.COLORS[level] or Logger.COLORS[Logger.LEVELS.INFO];
    local prefix = "|c" .. color .. "[CrateTrackerZK";
    
    if module then
        local modulePrefix = Logger.MODULE_PREFIXES[module] or module;
        prefix = prefix .. "|" .. modulePrefix;
    end
    
    if func then
        local funcPrefix = Logger.FUNCTION_PREFIXES[func] or func;
        prefix = prefix .. "|" .. funcPrefix;
    end
    
    prefix = prefix .. "]|r";
    return prefix;
end

-- 格式化消息（处理多个参数）
local function FormatMessage(...)
    local message = "";
    for i = 1, select("#", ...) do
        local arg = select(i, ...);
        if type(arg) == "table" then
            message = message .. " {table}";
        else
            message = message .. " " .. tostring(arg);
        end
    end
    return message:match("^%s*(.-)%s*$"); -- 去除首尾空格
end

-- 核心输出函数
-- 输入：level - 日志级别
--      module - 模块名称（可选）
--      func - 功能名称（可选）
--      ... - 消息内容
function Logger:Log(level, module, func, ...)
    self:Initialize();
    
    -- DEBUG级别需要检查是否启用调试模式
    if level == Logger.LEVELS.DEBUG and not self.debugEnabled then
        return;
    end
    
    local prefix = BuildPrefix(level, module, func);
    local message = FormatMessage(...);
    
    -- 输出到聊天框
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. message);
end

-- 限流输出函数（用于频繁的调试消息）
-- 输入：messageKey - 消息键（用于限流，支持类型前缀如 "detection_loop:map_123"）
--      level - 日志级别
--      module - 模块名称（可选）
--      func - 功能名称（可选）
--      ... - 消息内容（如果第一个是数字，则作为自定义间隔）
function Logger:LogLimited(messageKey, level, module, func, ...)
    self:Initialize();
    
    -- DEBUG级别需要检查是否启用调试模式
    if level == Logger.LEVELS.DEBUG and not self.debugEnabled then
        return;
    end
    
    -- 检查第一个参数是否是数字（自定义间隔）
    local args = {...};
    local rateLimit = self.DEBUG_MESSAGE_INTERVAL;
    local startArg = 1;
    
    if #args > 0 and type(args[1]) == "number" then
        rateLimit = args[1];
        startArg = 2;
    end
    
    -- 检查消息键是否匹配预定义的限流类型
    for limitType, limitInterval in pairs(self.RATE_LIMITS) do
        if messageKey:find(limitType, 1, true) == 1 then
            rateLimit = limitInterval;
            break;
        end
    end
    
    local currentTime = time();
    local lastTime = self.lastDebugMessage[messageKey] or 0;
    local timeSinceLast = currentTime - lastTime;
    
    if timeSinceLast >= rateLimit then
        self.lastDebugMessage[messageKey] = currentTime;
        
        -- 如果有被限流的消息，在输出时显示统计
        local count = self.messageCounts[messageKey] or 0;
        if count > 0 then
            local message = FormatMessage(select(startArg, ...));
            self:Log(level, module, func, string.format("%s（已限流 %d 条消息）", message, count));
            self.messageCounts[messageKey] = 0;
        else
            self:Log(level, module, func, select(startArg, ...));
        end
    else
        -- 记录被限流的消息数量
        self.messageCounts[messageKey] = (self.messageCounts[messageKey] or 0) + 1;
    end
end

-- 便捷方法：错误信息
function Logger:Error(module, func, ...)
    self:Log(Logger.LEVELS.ERROR, module, func, ...);
end

-- 便捷方法：警告信息
function Logger:Warn(module, func, ...)
    self:Log(Logger.LEVELS.WARN, module, func, ...);
end

-- 便捷方法：常规信息
function Logger:Info(module, func, ...)
    self:Log(Logger.LEVELS.INFO, module, func, ...);
end

-- 便捷方法：限流常规信息（用于初始化等可能重复的信息）
-- 输入：messageKey - 消息键（用于限流）
--      module - 模块名称
--      func - 功能名称
--      interval - 可选的自定义限流间隔（秒，默认300秒）
--      ... - 消息内容
function Logger:InfoLimited(messageKey, module, func, interval, ...)
    local args = {...};
    if type(interval) == "number" then
        self:LogLimited(messageKey, Logger.LEVELS.INFO, module, func, interval, ...);
    else
        -- interval 是消息内容的一部分
        self:LogLimited(messageKey, Logger.LEVELS.INFO, module, func, 300, interval, ...);
    end
end

-- 便捷方法：调试信息
function Logger:Debug(module, func, ...)
    self:Log(Logger.LEVELS.DEBUG, module, func, ...);
end

-- 便捷方法：成功信息
function Logger:Success(module, func, ...)
    self:Log(Logger.LEVELS.SUCCESS, module, func, ...);
end

-- 便捷方法：限流调试信息
-- 输入：messageKey - 消息键（支持类型前缀）
--      module - 模块名称
--      func - 功能名称
--      ... - 消息内容（如果第一个是数字，则作为自定义间隔）
function Logger:DebugLimited(messageKey, module, func, ...)
    self:LogLimited(messageKey, Logger.LEVELS.DEBUG, module, func, ...);
end

-- 清除消息缓存（用于限流）
function Logger:ClearMessageCache()
    self:Initialize();
    self.lastDebugMessage = {};
    self.messageCounts = {};
end

-- 初始化
Logger:Initialize();

return Logger;

