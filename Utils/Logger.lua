-- Logger.lua
-- 统一的日志输出模块，支持多级别日志和智能限流

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
    DEBUG = "DEBUG",
    SUCCESS = "SUCCESS"
};

Logger.COLORS = {
    [Logger.LEVELS.ERROR] = "ffff0000",
    [Logger.LEVELS.WARN] = "ffff8800",
    [Logger.LEVELS.INFO] = "ff4FC1FF",
    [Logger.LEVELS.DEBUG] = "ff00ff00",
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
    ["DetectionState"] = "检测状态",
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
    DebugAirdropProcessed = "空投已处理，暂停检测5分钟：%s",
    DebugProcessedTimeout = "处理状态超时（5分钟），清除状态，重新开始检测：%s",
    DebugProcessedSkipped = "已处理状态，跳过检测（剩余%d秒）",
    DebugAreaInvalidInstance = "区域无效（副本/战场），自动暂停",
    DebugAreaCannotGetMapID = "无法获取地图 ID",
    DebugAreaValid = "区域有效，已恢复：%s",
    DebugAreaInvalidNotInList = "区域无效（不在列表中），自动暂停：%s",
    DebugPhaseDetectionPaused = "位面检测已暂停，跳过",
    DebugPhaseNoMapID = "无法获取当前地图 ID，跳过位面更新",
};

function Logger:GetDebugText(key)
    return (self.DEBUG_TEXTS and self.DEBUG_TEXTS[key]) or key;
end

function Logger:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    self.debugEnabled = false;
    self.lastDebugMessage = {};
    self.messageCounts = {};
    self.DEBUG_MESSAGE_INTERVAL = 30;
    
    self.RATE_LIMITS = {
        ["detection_loop:start"] = 5,
        ["detection_loop:map_matched"] = 0,
        ["detection_loop:map_not_in_list"] = 10,
        ["icon_detection:result"] = 0,
        ["map_check:match"] = 0,
        ["state_change"] = 0,
        ["state_processed"] = 0,
        ["phase_update"] = 0,
        ["area_change"] = 0,
        ["detection_loop"] = 30,
        ["icon_detection"] = 20,
        ["map_check"] = 20,
        ["state_check"] = 30,
        ["ui_update"] = 300,
        ["data_save"] = 10,
        ["data_update"] = 10,
        ["notification"] = 2,
    };
    
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.debugEnabled ~= nil then
        self.debugEnabled = CRATETRACKERZK_UI_DB.debugEnabled;
    end
end

function Logger:SetDebugEnabled(enabled)
    self:Initialize();
    self.debugEnabled = enabled;
    
    if not CRATETRACKERZK_UI_DB then
        CRATETRACKERZK_UI_DB = {};
    end
    CRATETRACKERZK_UI_DB.debugEnabled = enabled;
end

function Logger:IsDebugEnabled()
    self:Initialize();
    return self.debugEnabled;
end

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
    
    if level == Logger.LEVELS.DEBUG and not self.debugEnabled then
        return;
    end
    
    local prefix = BuildPrefix(level, module, func);
    local message = FormatMessage(...);
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. message);
end

function Logger:LogLimited(messageKey, level, module, func, ...)
    self:Initialize();
    
    if level == Logger.LEVELS.DEBUG and not self.debugEnabled then
        return;
    end
    
    local args = {...};
    local rateLimit = self.DEBUG_MESSAGE_INTERVAL;
    local startArg = 1;
    
    if #args > 0 and type(args[1]) == "number" then
        rateLimit = args[1];
        startArg = 2;
    end
    
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
        
        local count = self.messageCounts[messageKey] or 0;
        if count > 0 then
            local message = FormatMessage(select(startArg, ...));
            self:Log(level, module, func, string.format("%s（已限流 %d 条消息）", message, count));
            self.messageCounts[messageKey] = 0;
        else
            self:Log(level, module, func, select(startArg, ...));
        end
    else
        self.messageCounts[messageKey] = (self.messageCounts[messageKey] or 0) + 1;
    end
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
    local args = {...};
    if type(interval) == "number" then
        self:LogLimited(messageKey, Logger.LEVELS.INFO, module, func, interval, ...);
    else
        self:LogLimited(messageKey, Logger.LEVELS.INFO, module, func, 300, interval, ...);
    end
end

function Logger:Debug(module, func, ...)
    self:Log(Logger.LEVELS.DEBUG, module, func, ...);
end

function Logger:Success(module, func, ...)
    self:Log(Logger.LEVELS.SUCCESS, module, func, ...);
end

function Logger:DebugLimited(messageKey, module, func, ...)
    self:LogLimited(messageKey, Logger.LEVELS.DEBUG, module, func, ...);
end

function Logger:ClearMessageCache()
    self:Initialize();
    self.lastDebugMessage = {};
    self.messageCounts = {};
end

Logger:Initialize();

return Logger;

