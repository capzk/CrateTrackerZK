-- DetectionState.lua
-- 职责：管理检测状态（状态机，符合设计文档）
-- 状态机：IDLE -> DETECTING -> CONFIRMED -> ACTIVE -> DISAPPEARING

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
    ACTIVE = "active",          -- 持续检测中（已更新时间）
    DISAPPEARING = "disappearing" -- 图标消失，等待5秒确认
};

-- 初始化
function DetectionState:Initialize()
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {}; -- 首次检测时间
    self.mapIconDetected = self.mapIconDetected or {}; -- 是否已确认检测
    self.mapIconDisappearedTime = self.mapIconDisappearedTime or {}; -- 消失时间
    self.lastUpdateTime = self.lastUpdateTime or {}; -- 上次更新时间
    self.DISAPPEAR_CONFIRM_TIME = 5; -- 消失确认时间（秒）
    self.CONFIRM_TIME = 2; -- 确认时间（秒）
end

-- 获取当前状态
-- 输入：mapId - 地图ID
-- 输出：state - 状态对象 {status, firstDetectedTime, lastUpdateTime, disappearedTime}
function DetectionState:GetState(mapId)
    self:Initialize(); -- 确保初始化
    
    local firstDetectedTime = self.mapIconFirstDetectedTime[mapId];
    local isDetected = self.mapIconDetected[mapId] == true;
    local disappearedTime = self.mapIconDisappearedTime[mapId];
    local lastUpdateTime = self.lastUpdateTime[mapId];
    
    local status = self.STATES.IDLE;
    
    if isDetected then
        if disappearedTime then
            status = self.STATES.DISAPPEARING;
        else
            status = self.STATES.ACTIVE;
        end
    elseif firstDetectedTime then
        status = self.STATES.DETECTING;
    end
    
    return {
        status = status,
        firstDetectedTime = firstDetectedTime,
        lastUpdateTime = lastUpdateTime,
        disappearedTime = disappearedTime,
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
        disappearedTime = state.disappearedTime,
        isDetected = state.isDetected
    };
    
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
        elseif state.status == self.STATES.DISAPPEARING then
            -- DISAPPEARING -> ACTIVE：5秒内图标重新出现
            newState.disappearedTime = nil;
            newState.status = self.STATES.ACTIVE;
            self.mapIconDisappearedTime[mapId] = nil;
            Logger:Debug("DetectionState", "状态", string.format("状态变化：DISAPPEARING -> ACTIVE，地图=%s（图标重新出现）", 
                Data:GetMapDisplayName(Data:GetMap(mapId))));
        end
        -- ACTIVE 状态：图标持续存在，保持状态
    else
        -- 图标不存在
        if state.status == self.STATES.DETECTING then
            -- DETECTING -> IDLE：2秒内图标消失
            local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
            if timeSinceFirstDetection < self.CONFIRM_TIME then
                newState.firstDetectedTime = nil;
                newState.status = self.STATES.IDLE;
                self.mapIconFirstDetectedTime[mapId] = nil;
                SafeDebug(string.format(DT("DebugClearedFirstDetectionTime"), Data:GetMapDisplayName(Data:GetMap(mapId))));
            end
        elseif state.status == self.STATES.ACTIVE then
            -- ACTIVE -> DISAPPEARING：图标消失
            newState.disappearedTime = currentTime;
            newState.status = self.STATES.DISAPPEARING;
            self.mapIconDisappearedTime[mapId] = currentTime;
            Logger:Debug("DetectionState", "状态", string.format("状态变化：ACTIVE -> DISAPPEARING，地图=%s（图标消失，等待%d秒确认）", 
                Data:GetMapDisplayName(Data:GetMap(mapId)), self.DISAPPEAR_CONFIRM_TIME));
            SafeDebug(string.format("图标消失，等待确认（%d秒）", self.DISAPPEAR_CONFIRM_TIME));
        elseif state.status == self.STATES.DISAPPEARING then
            -- DISAPPEARING -> IDLE：持续消失5秒
            local timeSinceDisappeared = currentTime - state.disappearedTime;
            if timeSinceDisappeared >= self.DISAPPEAR_CONFIRM_TIME then
                -- 清除所有状态（但保留通知冷却期）
                newState.status = self.STATES.IDLE;
                newState.firstDetectedTime = nil;
                newState.disappearedTime = nil;
                newState.isDetected = false;
                self.mapIconDetected[mapId] = nil;
                self.mapIconFirstDetectedTime[mapId] = nil;
                self.mapIconDisappearedTime[mapId] = nil;
                Logger:Debug("DetectionState", "状态", string.format("状态变化：DISAPPEARING -> IDLE，地图=%s（空投事件结束）", 
                    Data:GetMapDisplayName(Data:GetMap(mapId))));
                SafeDebug(string.format(DT("DebugAirdropEnded"), Data:GetMapDisplayName(Data:GetMap(mapId))));
            else
                -- 消失确认中，限流输出
                Logger:DebugLimited("state_check:disappearing_" .. mapId, "DetectionState", "状态", 
                    string.format("图标消失确认中：地图=%s，%d/%d秒", 
                        Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceDisappeared, self.DISAPPEAR_CONFIRM_TIME));
            end
        end
    end
    
    -- 更新内部状态
    if newState.firstDetectedTime then
        self.mapIconFirstDetectedTime[mapId] = newState.firstDetectedTime;
    end
    
    if newState.status == self.STATES.CONFIRMED or newState.status == self.STATES.ACTIVE then
        self.mapIconDetected[mapId] = true;
        newState.isDetected = true;
    end
    
    return newState;
end

-- 清除状态（但保留通知冷却期）
-- 输入：mapId - 地图ID
--      reason - 清除原因："game_map_changed" | "left_map_timeout" | "disappeared_confirmed"
function DetectionState:ClearState(mapId, reason)
    if not mapId then
        return;
    end
    
    self:Initialize(); -- 确保初始化
    
    local mapData = Data:GetMap(mapId);
    local mapDisplayName = mapData and Data:GetMapDisplayName(mapData) or tostring(mapId);
    
    if reason == "game_map_changed" then
        Logger:Debug("DetectionState", "状态", string.format("游戏地图变化，清除检测状态：地图=%s", mapDisplayName));
    elseif reason == "left_map_timeout" then
        Logger:Debug("DetectionState", "状态", string.format("离开地图超时，清除检测状态：地图=%s", mapDisplayName));
    elseif reason == "disappeared_confirmed" then
        Logger:Debug("DetectionState", "状态", string.format("图标消失确认，清除检测状态：地图=%s", mapDisplayName));
    end
    
    -- 清除检测状态（但保留通知冷却期）
    self.mapIconDetected[mapId] = nil;
    self.mapIconFirstDetectedTime[mapId] = nil;
    self.mapIconDisappearedTime[mapId] = nil;
    -- 注意：不清除 lastNotificationTime，保持通知冷却期
end

-- 设置上次更新时间
-- 输入：mapId - 地图ID
--      timestamp - 更新时间戳
function DetectionState:SetLastUpdateTime(mapId, timestamp)
    if not mapId or not timestamp then
        return;
    end
    
    self:Initialize(); -- 确保初始化
    self.lastUpdateTime[mapId] = timestamp;
end

-- 初始化
DetectionState:Initialize();

return DetectionState;

