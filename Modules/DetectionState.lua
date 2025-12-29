-- DetectionState.lua
-- 管理空投检测状态机：IDLE -> DETECTING -> CONFIRMED -> PROCESSED

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local DetectionState = BuildEnv('DetectionState');

local CrateTrackerZK = BuildEnv("CrateTrackerZK");

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

local function DT(key)
    return Logger:GetDebugText(key);
end

DetectionState.STATES = {
    IDLE = "idle",
    DETECTING = "detecting",
    CONFIRMED = "confirmed",
    PROCESSED = "processed"
};

function DetectionState:Initialize()
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {};
    self.mapIconDetected = self.mapIconDetected or {};
    self.lastUpdateTime = self.lastUpdateTime or {};
    self.processedTime = self.processedTime or {};
    self.confirmedTime = self.confirmedTime or {};  -- 记录CONFIRMED状态的开始时间
    self.CONFIRM_TIME = 2;
    self.PROCESSED_TIMEOUT = 180;  -- 3分钟冷却期
end

function DetectionState:GetState(mapId)
    self:Initialize();
    
    local firstDetectedTime = self.mapIconFirstDetectedTime[mapId];
    local isDetected = self.mapIconDetected[mapId] == true;
    local lastUpdateTime = self.lastUpdateTime[mapId];
    local processedTime = self.processedTime[mapId];
    
    local status = self.STATES.IDLE;
    
    if processedTime then
        status = self.STATES.PROCESSED;
    elseif isDetected then
        if firstDetectedTime and not lastUpdateTime then
            status = self.STATES.CONFIRMED;
        end
    elseif firstDetectedTime then
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

function DetectionState:UpdateState(mapId, iconDetected, currentTime)
    self:Initialize();
    
    local state = self:GetState(mapId);
    local newState = {
        status = state.status,
        firstDetectedTime = state.firstDetectedTime,
        lastUpdateTime = state.lastUpdateTime,
        processedTime = state.processedTime,
        isDetected = state.isDetected
    };
    
    if state.status == self.STATES.PROCESSED then
        return newState;
    end
    
    if iconDetected then
        if state.status == self.STATES.IDLE then
            newState.firstDetectedTime = currentTime;
            newState.status = self.STATES.DETECTING;
            Logger:Debug("DetectionState", "状态", string.format("状态变化：IDLE -> DETECTING，地图=%s", Data:GetMapDisplayName(Data:GetMap(mapId))));
        elseif state.status == self.STATES.DETECTING then
            local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
            if timeSinceFirstDetection >= self.CONFIRM_TIME then
                newState.status = self.STATES.CONFIRMED;
                Logger:Debug("DetectionState", "状态", string.format("状态变化：DETECTING -> CONFIRMED，地图=%s，已确认（%d秒）", 
                    Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceFirstDetection));
            else
                Logger:DebugLimited("state_check:waiting_" .. mapId, "DetectionState", "状态", 
                    string.format("等待确认中：地图=%s，已等待=%d秒", Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceFirstDetection));
            end
        end
    else
        if state.status == self.STATES.DETECTING then
            local timeSinceFirstDetection = currentTime - state.firstDetectedTime;
            -- 图标消失，清除DETECTING状态
            newState.firstDetectedTime = nil;
            newState.status = self.STATES.IDLE;
            self.mapIconFirstDetectedTime[mapId] = nil;
            
            if timeSinceFirstDetection < self.CONFIRM_TIME then
                -- 无效空投：DETECTING状态下，图标在2秒确认期内消失
                local mapDisplayName = Data:GetMapDisplayName(Data:GetMap(mapId));
                local L = CrateTrackerZK.L;
                Logger:Warn("DetectionState", "无效", string.format(L["InvalidAirdropDetecting"], mapDisplayName, timeSinceFirstDetection));
            else
                -- 图标在2秒后消失，清除状态但不输出警告（可能是正常消失）
                Logger:Debug("DetectionState", "状态", string.format("图标消失：地图=%s，已等待%.1f秒，清除DETECTING状态", 
                    Data:GetMapDisplayName(Data:GetMap(mapId)), timeSinceFirstDetection));
            end
        elseif state.status == self.STATES.CONFIRMED then
            -- CONFIRMED状态下图标消失：已通过2秒确认，视为有效空投，静默清除状态
            -- 不再区分持续时间，不再发送无效通知（空投即将结束的情况不再处理）
            newState.firstDetectedTime = nil;
            newState.status = self.STATES.IDLE;
            newState.isDetected = false;
            self.mapIconDetected[mapId] = nil;
            self.mapIconFirstDetectedTime[mapId] = nil;
            self.confirmedTime[mapId] = nil;  -- 清除CONFIRMED时间记录
            
            local mapDisplayName = Data:GetMapDisplayName(Data:GetMap(mapId));
            Logger:Debug("DetectionState", "状态", string.format("图标消失：地图=%s，已通过2秒确认，静默清除CONFIRMED状态", mapDisplayName));
        end
    end
    
    if newState.firstDetectedTime then
        self.mapIconFirstDetectedTime[mapId] = newState.firstDetectedTime;
    end
    
    if newState.status == self.STATES.CONFIRMED then
        self.mapIconDetected[mapId] = true;
        newState.isDetected = true;
        -- 记录CONFIRMED状态的开始时间（如果还没有记录）
        if not self.confirmedTime[mapId] then
            self.confirmedTime[mapId] = currentTime;
        end
    end
    
    return newState;
end

function DetectionState:IsProcessed(mapId)
    self:Initialize();
    return self.processedTime[mapId] ~= nil;
end

function DetectionState:IsProcessedTimeout(mapId, currentTime)
    self:Initialize();
    local processedTime = self.processedTime[mapId];
    if not processedTime then
        return false;
    end
    return (currentTime - processedTime) >= self.PROCESSED_TIMEOUT;
end

function DetectionState:MarkAsProcessed(mapId, timestamp)
    self:Initialize();
    self.processedTime[mapId] = timestamp;
    Logger:Debug("DetectionState", "状态", string.format("标记为已处理：地图=%s，处理时间=%s，暂停检测3分钟", 
        Data:GetMapDisplayName(Data:GetMap(mapId)), 
        Data:FormatDateTime(timestamp)));
end

function DetectionState:ClearProcessed(mapId)
    self:Initialize();
    if self.processedTime[mapId] then
        local mapData = Data:GetMap(mapId);
        Logger:Debug("DetectionState", "状态", string.format("清除处理状态：地图=%s，重新开始检测", 
            mapData and Data:GetMapDisplayName(mapData) or tostring(mapId)));
        
        self.processedTime[mapId] = nil;
        self.mapIconFirstDetectedTime[mapId] = nil;
        self.mapIconDetected[mapId] = nil;
        self.lastUpdateTime[mapId] = nil;
        self.confirmedTime[mapId] = nil;  -- 清除CONFIRMED时间记录
    end
end

function DetectionState:SetLastUpdateTime(mapId, timestamp)
    if not mapId or not timestamp then
        return;
    end
    
    self:Initialize();
    self.lastUpdateTime[mapId] = timestamp;
end

function DetectionState:ClearAllStates()
    self:Initialize();
    
    -- 清除所有地图的检测状态
    self.mapIconFirstDetectedTime = {};
    self.mapIconDetected = {};
    self.lastUpdateTime = {};
    self.processedTime = {};
    self.confirmedTime = {};  -- 清除CONFIRMED时间记录
    
    Logger:Debug("DetectionState", "重置", "已清除所有地图的检测状态");
end

DetectionState:Initialize();

return DetectionState;
