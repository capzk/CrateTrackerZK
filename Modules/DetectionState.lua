-- DetectionState.lua
-- 职责：管理检测状态（简化状态机）
-- 状态机：IDLE -> DETECTING -> CONFIRMED -> PROCESSED

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local DetectionState = BuildEnv('DetectionState');

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

-- 使用 Logger 模块统一输出
local function SafeDebug(...)
    Logger:Debug("DetectionState", "调试", ...);
end

local function DT(key)
    return Logger:GetDebugText(key);
end

-- 状态定义
DetectionState.STATES = {
    IDLE = "idle",              -- 未检测到图标
    DETECTING = "detecting",    -- 首次检测到图标，等待2秒确认
    CONFIRMED = "confirmed",    -- 已确认（持续2秒），等待通知和更新时间
    PROCESSED = "processed"     -- 已处理（通知+更新完成），暂停检测
};

-- 初始化
function DetectionState:Initialize()
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {}; -- 首次检测时间
    self.mapIconDetected = self.mapIconDetected or {}; -- 是否已确认检测
    self.lastUpdateTime = self.lastUpdateTime or {}; -- 上次更新时间
    self.processedTime = self.processedTime or {}; -- 处理时间（用于5分钟超时）
    self.CONFIRM_TIME = 2; -- 确认时间（秒）
    self.PROCESSED_TIMEOUT = 300; -- 处理暂停期（秒，5分钟）
end

-- 获取当前状态
-- 输入：mapId - 地图ID
-- 输出：state - 状态对象 {status, firstDetectedTime, lastUpdateTime, processedTime}
function DetectionState:GetState(mapId)
    self:Initialize(); -- 确保初始化
    
    local firstDetectedTime = self.mapIconFirstDetectedTime[mapId];
    local isDetected = self.mapIconDetected[mapId] == true;
    local lastUpdateTime = self.lastUpdateTime[mapId];
    local processedTime = self.processedTime[mapId];
    
    local status = self.STATES.IDLE;
    
    -- 如果已处理，返回 PROCESSED 状态
    if processedTime then
        status = self.STATES.PROCESSED;
    elseif isDetected then
        -- 已确认但未更新时间，是 CONFIRMED 状态
        if firstDetectedTime and not lastUpdateTime then
            status = self.STATES.CONFIRMED;
        end
    elseif firstDetectedTime then
        -- 有首次检测时间但未确认，是 DETECTING 状态
        status = self.STATES.DETECTING;
    end
    
    return {
        status = status,
        firstDetectedTime = firstDetectedTime,
        lastUpdateTime = lastUpdateTime,
        processedTime = processedTime,
        isDetected = isDetected
    };
end

-- 更新状态（状态机转换）
-- 输入：mapId - 地图ID
--      iconDetected - 是否检测到图标
--      currentTime - 当前时间戳
-- 输出：newState - 新状态对象
function DetectionState:UpdateState(mapId, iconDetected, currentTime)
    self:Initialize(); -- 确保初始化
    
    local state = self:GetState(mapId);
    local newState = {
        status = state.status,
        firstDetectedTime = state.firstDetectedTime,
        lastUpdateTime = state.lastUpdateTime,
        processedTime = state.processedTime,
        isDetected = state.isDetected
    };
    
    -- 如果已处理，不进行状态更新（已停止检测）
    if state.status == self.STATES.PROCESSED then
        return newState;
    end
    
    if iconDetected then
        -- 图标存在
        if state.status == self.STATES.IDLE then
            -- IDLE -> DETECTING：首次检测到图标
            newState.firstDetectedTime = currentTime;
            newState.status = self.STATES.DETECTING;
            Logger:Debug("DetectionState", "状态", string.format("状态变化：IDLE -> DETECTING，地图=%s", Data:GetMapDisplayName(Data:GetMap(mapId))));
            SafeDebug(string.format(DT("DebugFirstDetectionWait"), Data:GetMapDisplayName(Data:GetMap(mapId))));
        elseif state.status == self.STATES.DETECTING then
            -- DETECTING -> CONFIRMED：持续检测2秒
            local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
            if timeSinceFirstDetection >= self.CONFIRM_TIME then
                newState.status = self.STATES.CONFIRMED;
                Logger:Debug("DetectionState", "状态", string.format("状态变化：DETECTING -> CONFIRMED，地图=%s，已确认（%d秒）", 
                    Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceFirstDetection));
                SafeDebug(string.format(DT("DebugContinuousDetectionConfirmed"), Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceFirstDetection));
            else
                -- 等待确认中，限流输出
                Logger:DebugLimited("state_check:waiting_" .. mapId, "DetectionState", "状态", 
                    string.format("等待确认中：地图=%s，已等待=%d秒", Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceFirstDetection));
            end
        end
        -- CONFIRMED 状态：保持状态，等待外部处理（通知+更新）
    else
        -- 图标不存在
        if state.status == self.STATES.DETECTING then
            -- DETECTING -> IDLE：2秒内图标消失（误报）
            local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
            if timeSinceFirstDetection < self.CONFIRM_TIME then
                newState.firstDetectedTime = nil;
                newState.status = self.STATES.IDLE;
                self.mapIconFirstDetectedTime[mapId] = nil;
                SafeDebug(string.format(DT("DebugClearedFirstDetectionTime"), Data:GetMapDisplayName(Data:GetMap(mapId))));
            end
        elseif state.status == self.STATES.CONFIRMED then
            -- CONFIRMED -> IDLE：确认后图标立即消失（误报），立即清除状态
            newState.firstDetectedTime = nil;
            newState.status = self.STATES.IDLE;
            newState.isDetected = false;
            self.mapIconDetected[mapId] = nil;
            self.mapIconFirstDetectedTime[mapId] = nil;
            Logger:Debug("DetectionState", "状态", string.format("状态变化：CONFIRMED -> IDLE，地图=%s（确认后图标立即消失，判定为误报）", 
                Data:GetMapDisplayName(Data:GetMap(mapId))));
            SafeDebug(string.format("确认后图标立即消失，判定为误报：%s", Data:GetMapDisplayName(Data:GetMap(mapId))));
        end
    end
    
    -- 更新内部状态
    if newState.firstDetectedTime then
        self.mapIconFirstDetectedTime[mapId] = newState.firstDetectedTime;
    end
    
    if newState.status == self.STATES.CONFIRMED then
        self.mapIconDetected[mapId] = true;
        newState.isDetected = true;
    end
    
    return newState;
end

-- 检查是否已处理
function DetectionState:IsProcessed(mapId)
    self:Initialize();
    return self.processedTime[mapId] ~= nil;
end

-- 检查是否超时
function DetectionState:IsProcessedTimeout(mapId, currentTime)
    self:Initialize();
    local processedTime = self.processedTime[mapId];
    if not processedTime then
        return false;
    end
    return (currentTime - processedTime) >= self.PROCESSED_TIMEOUT;
end

-- 标记为已处理
function DetectionState:MarkAsProcessed(mapId, timestamp)
    self:Initialize();
    self.processedTime[mapId] = timestamp;
    Logger:Debug("DetectionState", "状态", string.format("标记为已处理：地图=%s，处理时间=%s，暂停检测5分钟", 
        Data:GetMapDisplayName(Data:GetMap(mapId)), 
        Data:FormatDateTime(timestamp)));
end

-- 清除处理状态（离开地图或超时）
function DetectionState:ClearProcessed(mapId)
    self:Initialize();
    if self.processedTime[mapId] then
        local mapData = Data:GetMap(mapId);
        Logger:Debug("DetectionState", "状态", string.format("清除处理状态：地图=%s，重新开始检测", 
            mapData and Data:GetMapDisplayName(mapData) or tostring(mapId)));
        
        -- 清除所有相关状态
        self.processedTime[mapId] = nil;
        self.mapIconFirstDetectedTime[mapId] = nil;
        self.mapIconDetected[mapId] = nil;
        self.lastUpdateTime[mapId] = nil;
    end
end

-- 设置上次更新时间
function DetectionState:SetLastUpdateTime(mapId, timestamp)
    if not mapId or not timestamp then
        return;
    end
    
    self:Initialize();
    self.lastUpdateTime[mapId] = timestamp;
end

-- 初始化
DetectionState:Initialize();

return DetectionState;
