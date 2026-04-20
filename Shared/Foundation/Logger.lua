-- Logger.lua - 统一的日志输出模块，支持多级别日志和智能限流

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Logger = BuildEnv('Logger');

Logger.LEVELS = {
    ERROR = "ERROR",
    WARN = "WARN",
    INFO = "INFO",
    SUCCESS = "SUCCESS"
};

Logger.COLORS = {
    [Logger.LEVELS.ERROR] = "ffff0000",
    [Logger.LEVELS.WARN] = "ffff8800",
    [Logger.LEVELS.INFO] = "ff4FC1FF",
    [Logger.LEVELS.SUCCESS] = "ff00ff00"
};

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
    
    -- UI模块
    ["MainPanel"] = "主面板",
    ["FloatingButton"] = "浮动按钮",
    ["Info"] = "信息",
    
    -- 工具模块
    ["Utils"] = "工具",
    ["Localization"] = "本地化",
};

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
    ["界面"] = "界面",
    ["处理"] = "处理"
};

function Logger:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    if CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB.debugEnabled = nil;
    end
end

local function BuildPrefix(level, module, func)
    local color = Logger.COLORS[level] or Logger.COLORS[Logger.LEVELS.INFO];
    local prefix = "|c" .. color .. "CTK";
    
    -- 用户可见的信息/成功级别仅保留插件名前缀
    if level ~= Logger.LEVELS.INFO and level ~= Logger.LEVELS.SUCCESS then
        if module then
            local modulePrefix = Logger.MODULE_PREFIXES[module] or module;
            prefix = prefix .. "|" .. modulePrefix;
        end
        
        if func then
            local funcPrefix = Logger.FUNCTION_PREFIXES[func] or func;
            prefix = prefix .. "|" .. funcPrefix;
        end
    end
    
    prefix = prefix .. ":|r";
    return prefix;
end

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
    return message:match("^%s*(.-)%s*$");
end

function Logger:Log(level, module, func, ...)
    self:Initialize();

    local prefix = BuildPrefix(level, module, func);
    local message = FormatMessage(...);
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. message);
end

function Logger:LogLimited(messageKey, level, module, func, ...)
    self:Initialize();

    self:Log(level, module, func, ...);
end

function Logger:Error(module, func, ...)
    self:Log(Logger.LEVELS.ERROR, module, func, ...);
end

function Logger:Warn(module, func, ...)
    self:Log(Logger.LEVELS.WARN, module, func, ...);
end

function Logger:Info(module, func, ...)
    self:Log(Logger.LEVELS.INFO, module, func, ...);
end

function Logger:InfoLimited(messageKey, module, func, interval, ...)
    if type(interval) == "number" then
        self:LogLimited(messageKey, Logger.LEVELS.INFO, module, func, ...);
        return;
    end
    self:LogLimited(messageKey, Logger.LEVELS.INFO, module, func, interval, ...);
end

function Logger:Success(module, func, ...)
    self:Log(Logger.LEVELS.SUCCESS, module, func, ...);
end

function Logger:ClearMessageCache()
    return 0;
end

function Logger:PruneMessageCache(currentTime)
    return 0;
end

Logger:Initialize();

return Logger;
