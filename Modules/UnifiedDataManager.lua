-- UnifiedDataManager.lua - 统一数据管理模块
-- 负责管理时间数据（临时时间和持久化时间）和位面数据（临时位面和持久化位面）

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local UnifiedDataManager = BuildEnv('UnifiedDataManager')

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

if not Data then
    Data = BuildEnv('Data')
end

if not Logger then
    Logger = BuildEnv('Logger')
end

-- 时间来源枚举
UnifiedDataManager.TimeSource = {
    TEAM_MESSAGE = "team_message",
    REFRESH_BUTTON = "refresh_button", 
    ICON_DETECTION = "icon_detection"
}

-- 位面来源枚举
UnifiedDataManager.PhaseSource = {
    PHASE_DETECTION = "phase_detection", -- 临时位面（Phase模块检测）
    ICON_DETECTION = "icon_detection"    -- 持久化位面（空投检测保存）
}

-- 临时时间过期时间（秒）
UnifiedDataManager.TEMPORARY_TIME_EXPIRE = 3600  -- 1小时

-- 临时位面过期时间（秒）
UnifiedDataManager.TEMPORARY_PHASE_EXPIRE = 1800  -- 30分钟

-- 初始化
function UnifiedDataManager:Initialize()
    Logger:Debug("UnifiedDataManager", "初始化", "开始初始化UnifiedDataManager")
    
    self.isInitialized = true;
    
    -- 时间数据存储 {mapId -> TimeData}
    self.temporaryTimes = {};
    
    -- 位面数据存储 {mapId -> PhaseData}
    self.temporaryPhases = {};
    self.persistentPhases = {};
    
    -- 计算缓存 {mapId -> CacheData}
    self.calculationCache = {};
    
    -- 缓存有效期（秒）
    self.CACHE_EXPIRE_TIME = 5;
    
    Logger:Debug("UnifiedDataManager", "初始化", "统一数据管理器已初始化");
end

-- 时间数据结构
local function CreateTimeData(mapId)
    return {
        mapId = mapId,
        temporaryTime = nil,  -- {timestamp, source, setTime}
        persistentTime = nil, -- {timestamp, source, phaseId}
        -- 计算缓存
        cachedNextRefresh = nil,
        cacheTime = 0
    }
end

-- 位面数据结构
local function CreatePhaseData(mapId)
    return {
        mapId = mapId,
        phaseId = nil,
        source = nil,
        detectTime = nil
    }
end

-- 缓存数据结构
local function CreateCacheData(nextRefresh, remaining, source, isPersistent)
    return {
        nextRefresh = nextRefresh,
        remaining = remaining,
        source = source,
        isPersistent = isPersistent,
        cacheTime = time()
    }
end

-- 获取地图刷新间隔（优先使用Data中的配置）
local function GetMapInterval(mapId)
    if Data and Data.GetMap then
        local mapData = Data:GetMap(mapId);
        if mapData and mapData.interval and mapData.interval > 0 then
            return mapData.interval;
        end
    end

    if Data and Data.MAP_CONFIG and Data.MAP_CONFIG.defaults and Data.MAP_CONFIG.defaults.interval then
        return Data.MAP_CONFIG.defaults.interval;
    end

    -- 最后兜底默认18分20秒
    return 1100;
end

-- 计算下一次刷新时间，确保返回值始终指向“未来”
local function CalculateNextRefreshTime(lastRefresh, interval)
    if not lastRefresh or not interval or interval <= 0 then
        return nil;
    end

    local now = time();

    -- 如果记录时间在未来或刚刚发生，直接推一个间隔
    if now <= lastRefresh then
        return lastRefresh + interval;
    end

    -- 向上取整补齐所有间隔，保证结果不早于当前时间
    local cycles = math.ceil((now - lastRefresh) / interval);
    if cycles < 1 then
        cycles = 1;
    end

    return lastRefresh + cycles * interval;
end

-- 获取或创建时间数据
function UnifiedDataManager:GetOrCreateTimeData(mapId)
    if not self.temporaryTimes[mapId] then
        self.temporaryTimes[mapId] = CreateTimeData(mapId);
    end
    return self.temporaryTimes[mapId];
end

-- 获取或创建位面数据
function UnifiedDataManager:GetOrCreatePhaseData(mapId, isTemporary)
    local storage = isTemporary and self.temporaryPhases or self.persistentPhases;
    if not storage[mapId] then
        storage[mapId] = CreatePhaseData(mapId);
    end
    return storage[mapId];
end

-- 统一时间设置接口
function UnifiedDataManager:SetTime(mapId, timestamp, source)
    Logger:Debug("UnifiedDataManager", "调试", string.format("SetTime被调用：mapId=%s，source=%s", 
        tostring(mapId), tostring(source)))
    
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    -- 根据来源自动决定是临时时间还是持久化时间
    if source == self.TimeSource.TEAM_MESSAGE or source == self.TimeSource.REFRESH_BUTTON then
        return self:SetTemporaryTime(mapId, timestamp, source);
    elseif source == self.TimeSource.ICON_DETECTION then
        return self:SetPersistentTime(mapId, timestamp, source, nil);
    else
        -- 默认为临时时间
        return self:SetTemporaryTime(mapId, timestamp, source);
    end
end

-- 设置临时时间
function UnifiedDataManager:SetTemporaryTime(mapId, timestamp, source)
    Logger:Debug("UnifiedDataManager", "调试", string.format("SetTemporaryTime被调用：mapId=%s，timestamp=%s，source=%s", 
        tostring(mapId), tostring(timestamp), tostring(source)))
    
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    local timeData = self:GetOrCreateTimeData(mapId);
    if not timeData then
        Logger:Error("UnifiedDataManager", "错误", string.format("无法创建时间数据：mapId=%s", tostring(mapId)));
        return false;
    end
    
    local oldTime = timeData.temporaryTime and timeData.temporaryTime.timestamp or nil;
    
    timeData.temporaryTime = {
        timestamp = timestamp,
        source = source,
        setTime = time()
    };
    
    -- 清除计算缓存
    self:ClearCache(mapId);
    
    -- 记录变更
    self:LogTimeChange(mapId, "临时时间", oldTime, timestamp, source);
    
    Logger:Debug("UnifiedDataManager", "临时时间", string.format("设置临时时间成功：地图ID=%d，时间=%d，来源=%s", 
        mapId, timestamp, source));
    
    return true;
end

-- 设置持久化时间
function UnifiedDataManager:SetPersistentTime(mapId, timestamp, source, phaseId)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    local timeData = self:GetOrCreateTimeData(mapId);
    local oldTime = timeData.persistentTime and timeData.persistentTime.timestamp or nil;
    
    timeData.persistentTime = {
        timestamp = timestamp,
        source = source,
        phaseId = phaseId
    };
    
    -- 持久化时间优先级最高，清除临时时间
    if timeData.temporaryTime then
        Logger:Debug("UnifiedDataManager", "优先级", string.format("持久化时间优先级更高，清除临时时间：地图ID=%d", mapId));
        timeData.temporaryTime = nil;
    end
    
    -- 清除计算缓存
    self:ClearCache(mapId);
    
    -- 调用Data模块进行持久化存储
    if Data and Data.SetLastRefresh then
        Data:SetLastRefresh(mapId, timestamp);
    end
    
    -- 记录变更
    self:LogTimeChange(mapId, "持久化时间", oldTime, timestamp, source);
    
    Logger:Debug("UnifiedDataManager", "持久化时间", string.format("设置持久化时间：地图ID=%d，时间=%d，来源=%s", 
        mapId, timestamp, source));
    
    return true;
end

-- 获取显示时间
function UnifiedDataManager:GetDisplayTime(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    local timeData = self.temporaryTimes[mapId];
    local now = time();

    local tempRecord = nil;
    local persistentRecord = nil;

    if timeData then
        -- 持久化记录
        if timeData.persistentTime then
            persistentRecord = timeData.persistentTime;
        end

        -- 临时记录（先检查是否过期）
        if timeData.temporaryTime then
            if now - timeData.temporaryTime.setTime <= self.TEMPORARY_TIME_EXPIRE then
                tempRecord = timeData.temporaryTime;
            else
                -- 临时时间已过期，清除
                timeData.temporaryTime = nil;
            end
        end
    end

    -- 如果本地没有持久化记录，回退到Data模块的持久化时间
    if not persistentRecord and Data and Data.GetMap then
        local mapData = Data:GetMap(mapId);
        if mapData and mapData.lastRefresh then
            persistentRecord = {
                timestamp = mapData.lastRefresh,
                source = self.TimeSource.ICON_DETECTION,
                phaseId = mapData.lastRefreshPhase
            };
        end
    end

    -- 同时存在时，取时间更“新”的一条；否则按可用记录返回
    if tempRecord and persistentRecord then
        local useTemp = tempRecord.timestamp > persistentRecord.timestamp;
        local record = useTemp and tempRecord or persistentRecord;
        return {
            time = record.timestamp,
            source = record.source,
            isPersistent = not useTemp
        };
    elseif persistentRecord then
        return {
            time = persistentRecord.timestamp,
            source = persistentRecord.source,
            isPersistent = true
        };
    elseif tempRecord then
        return {
            time = tempRecord.timestamp,
            source = tempRecord.source,
            isPersistent = false
        };
    end

    return nil;
end

-- 统一位面设置接口
function UnifiedDataManager:SetPhase(mapId, phaseId, source, isPersistent)
    Logger:Debug("UnifiedDataManager", "调试", string.format("SetPhase被调用：mapId=%s，phaseId=%s，source=%s，isPersistent=%s", 
        tostring(mapId), tostring(phaseId), tostring(source), tostring(isPersistent)))
    
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    -- 根据isPersistent参数决定是临时位面还是持久化位面
    if isPersistent then
        return self:SetPersistentPhase(mapId, phaseId, source);
    else
        return self:SetTemporaryPhase(mapId, phaseId, source);
    end
end

-- 设置临时位面
function UnifiedDataManager:SetTemporaryPhase(mapId, phaseId, source)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    local phaseData = self:GetOrCreatePhaseData(mapId, true);
    if not phaseData then
        Logger:Error("UnifiedDataManager", "错误", string.format("无法创建临时位面数据：mapId=%s", tostring(mapId)));
        return false;
    end
    
    local oldPhase = phaseData.phaseId;
    
    phaseData.phaseId = phaseId;
    phaseData.source = source;
    phaseData.detectTime = time();
    
    -- 记录变更
    self:LogPhaseChange(mapId, "临时位面", oldPhase, phaseId, source);
    
    Logger:Debug("UnifiedDataManager", "临时位面", string.format("设置临时位面成功：地图ID=%d，位面ID=%s，来源=%s", 
        mapId, phaseId, source));
    
    return true;
end

-- 设置持久化位面
function UnifiedDataManager:SetPersistentPhase(mapId, phaseId, source)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    local phaseData = self:GetOrCreatePhaseData(mapId, false);
    if not phaseData then
        Logger:Error("UnifiedDataManager", "错误", string.format("无法创建持久化位面数据：mapId=%s", tostring(mapId)));
        return false;
    end
    
    local oldPhase = phaseData.phaseId;
    
    phaseData.phaseId = phaseId;
    phaseData.source = source;
    phaseData.detectTime = time();
    
    -- 记录变更
    self:LogPhaseChange(mapId, "持久化位面", oldPhase, phaseId, source);
    
    Logger:Debug("UnifiedDataManager", "持久化位面", string.format("设置持久化位面成功：地图ID=%d，位面ID=%s，来源=%s", 
        mapId, phaseId, source));
    
    return true;
end

-- 获取当前位面（优先临时位面）
function UnifiedDataManager:GetCurrentPhase(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    -- 优先使用临时位面（如果存在且未过期）
    local tempPhase = self.temporaryPhases[mapId];
    if tempPhase and tempPhase.phaseId then
        local now = time();
        if now - tempPhase.detectTime <= self.TEMPORARY_PHASE_EXPIRE then
            return tempPhase.phaseId;
        else
            -- 临时位面已过期，清除
            tempPhase.phaseId = nil;
            tempPhase.source = nil;
            tempPhase.detectTime = nil;
        end
    end
    
    -- 使用持久化位面
    local persistentPhase = self.persistentPhases[mapId];
    if persistentPhase and persistentPhase.phaseId then
        return persistentPhase.phaseId;
    end
    
    return nil;
end

-- 获取持久化位面
function UnifiedDataManager:GetPersistentPhase(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    local persistentPhase = self.persistentPhases[mapId];
    if persistentPhase and persistentPhase.phaseId then
        return persistentPhase.phaseId;
    end
    
    return nil;
end

-- 位面数据比对
function UnifiedDataManager:ComparePhases(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    local currentPhase = self:GetCurrentPhase(mapId);
    local persistentPhase = self:GetPersistentPhase(mapId);
    
    local result = {
        match = false,
        current = currentPhase,
        persistent = persistentPhase,
        status = "unknown"
    };
    
    if not currentPhase and not persistentPhase then
        result.status = "no_data";
    elseif not currentPhase then
        result.status = "no_current";
    elseif not persistentPhase then
        result.status = "no_persistent";
    elseif currentPhase == persistentPhase then
        result.match = true;
        result.status = "match";
    else
        result.match = false;
        result.status = "mismatch";
    end
    
    return result;
end

-- 获取位面显示信息
function UnifiedDataManager:GetPhaseDisplayInfo(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    local comparison = self:ComparePhases(mapId);
    if not comparison then
        return nil;
    end
    
    local displayPhase = comparison.current or comparison.persistent or "未知";
    local color = {r = 1, g = 1, b = 1}; -- 默认白色
    local status = "未知";
    local tooltip = "";
    
    if comparison.status == "match" then
        color = {r = 0, g = 1, b = 0}; -- 绿色
        status = "匹配";
        tooltip = string.format("当前位面：%s\n持久化位面：%s\n状态：匹配", comparison.current, comparison.persistent);
    elseif comparison.status == "mismatch" then
        color = {r = 1, g = 0, b = 0}; -- 红色
        status = "不匹配";
        tooltip = string.format("当前位面：%s\n持久化位面：%s\n状态：不匹配", comparison.current, comparison.persistent);
    elseif comparison.status == "no_data" then
        color = {r = 1, g = 1, b = 1}; -- 白色
        status = "无数据";
        tooltip = "无位面数据";
    elseif comparison.status == "no_current" then
        color = {r = 1, g = 1, b = 1}; -- 白色
        status = "无当前位面";
        tooltip = string.format("持久化位面：%s\n当前位面：未检测到", comparison.persistent);
        displayPhase = comparison.persistent;
    elseif comparison.status == "no_persistent" then
        color = {r = 1, g = 1, b = 1}; -- 白色
        status = "无持久化位面";
        tooltip = string.format("当前位面：%s\n持久化位面：无", comparison.current);
        displayPhase = comparison.current;
    end
    
    return {
        phaseId = displayPhase,
        color = color,
        status = status,
        tooltip = tooltip
    };
end

-- 获取剩余时间
function UnifiedDataManager:GetRemainingTime(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    local displayTime = self:GetDisplayTime(mapId);
    if not displayTime then
        return nil;
    end
    
    local nextRefresh = self:GetNextRefreshTime(mapId);
    if not nextRefresh then
        return nil;
    end
    
    local remaining = nextRefresh - time();
    if remaining < 0 then
        remaining = 0;
    end
    
    return remaining;
end

-- 获取下次刷新时间
function UnifiedDataManager:GetNextRefreshTime(mapId)
    if not self.isInitialized then
        return nil;
    end

    local displayTime = self:GetDisplayTime(mapId);
    if not displayTime then
        return nil;
    end

    local interval = GetMapInterval(mapId);
    return CalculateNextRefreshTime(displayTime.time, interval);
end

-- 清除计算缓存
function UnifiedDataManager:ClearCache(mapId)
    if mapId then
        self.calculationCache[mapId] = nil;
    else
        self.calculationCache = {};
    end
end

-- 清除过期的临时时间数据
function UnifiedDataManager:ClearExpiredTemporaryTimes()
    if not self.isInitialized then
        return;
    end
    
    local now = time();
    local expiredCount = 0;
    
    for mapId, timeData in pairs(self.temporaryTimes) do
        if timeData.temporaryTime then
            if now - timeData.temporaryTime.setTime > self.TEMPORARY_TIME_EXPIRE then
                timeData.temporaryTime = nil;
                expiredCount = expiredCount + 1;
            end
        end
        
        -- 如果时间数据为空，移除整个条目
        if not timeData.temporaryTime and not timeData.persistentTime then
            self.temporaryTimes[mapId] = nil;
        end
    end
    
    if expiredCount > 0 then
        Logger:Debug("UnifiedDataManager", "清理", string.format("清理了%d个过期的临时时间数据", expiredCount));
    end
end

-- 清除过期的临时位面数据
function UnifiedDataManager:ClearExpiredTemporaryPhases()
    if not self.isInitialized then
        return;
    end
    
    local now = time();
    local expiredCount = 0;
    
    for mapId, phaseData in pairs(self.temporaryPhases) do
        if phaseData.phaseId and phaseData.detectTime then
            if now - phaseData.detectTime > self.TEMPORARY_PHASE_EXPIRE then
                phaseData.phaseId = nil;
                phaseData.source = nil;
                phaseData.detectTime = nil;
                expiredCount = expiredCount + 1;
            end
        end
        
        -- 如果位面数据为空，移除整个条目
        if not phaseData.phaseId then
            self.temporaryPhases[mapId] = nil;
        end
    end
    
    if expiredCount > 0 then
        Logger:Debug("UnifiedDataManager", "清理", string.format("清理了%d个过期的临时位面数据", expiredCount));
    end
end

-- 清除过期的临时数据（统一接口）
function UnifiedDataManager:ClearExpiredTemporaryData()
    self:ClearExpiredTemporaryTimes();
    self:ClearExpiredTemporaryPhases();
end

-- 迁移现有数据
function UnifiedDataManager:MigrateExistingData()
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    if not Data or not Data.GetAllMaps then
        Logger:Error("UnifiedDataManager", "错误", "Data模块未加载");
        return false;
    end
    
    local maps = Data:GetAllMaps();
    local migratedCount = 0;
    
    for _, mapData in ipairs(maps) do
        if mapData and mapData.lastRefresh then
            local timeData = self:GetOrCreateTimeData(mapData.id);
            
            -- 将现有的持久化时间迁移到新系统
            timeData.persistentTime = {
                timestamp = mapData.lastRefresh,
                source = self.TimeSource.ICON_DETECTION,
                phaseId = mapData.lastRefreshPhase
            };
            
            -- 迁移位面数据
            if mapData.lastRefreshPhase then
                local phaseData = self:GetOrCreatePhaseData(mapData.id, false);
                phaseData.phaseId = mapData.lastRefreshPhase;
                phaseData.source = self.PhaseSource.ICON_DETECTION;
                phaseData.detectTime = mapData.lastRefresh;
            end
            
            migratedCount = migratedCount + 1;
        end
    end
    
    Logger:Debug("UnifiedDataManager", "迁移", string.format("成功迁移了%d个地图的时间和位面数据", migratedCount));
    return true;
end

-- 获取时间来源信息
function UnifiedDataManager:GetTimeSourceInfo(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    local displayTime = self:GetDisplayTime(mapId);
    if not displayTime then
        return nil;
    end
    
    return {
        source = displayTime.source,
        isPersistent = displayTime.isPersistent,
        sourceDisplayName = self:GetSourceDisplayName(displayTime.source)
    };
end

-- 获取来源显示名称
function UnifiedDataManager:GetSourceDisplayName(source)
    local displayNames = {
        [self.TimeSource.TEAM_MESSAGE] = "团队消息",
        [self.TimeSource.REFRESH_BUTTON] = "手动刷新",
        [self.TimeSource.ICON_DETECTION] = "图标检测"
    };
    
    return displayNames[source] or "未知来源";
end

-- 格式化时间显示（从Data模块移动过来）
function UnifiedDataManager:FormatTime(seconds, showOnlyMinutes)
    if not seconds then 
        return L["NoRecord"] or "--:--";
    end
    
    if seconds < 0 then
        return L["NoRecord"] or "--:--";
    end
    
    if seconds == 0 then
        return "00:00";
    end
    
    local hours = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    local secs = seconds % 60;
    
    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"] or "%d:%02d";
        return string.format(formatStr, minutes + hours * 60, secs);
    else
        if hours > 0 then
            return string.format("%d:%02d:%02d", hours, minutes, secs);
        else
            return string.format("%02d:%02d", minutes, secs);
        end
    end
end

-- 格式化日期时间（从Data模块移动过来）
function UnifiedDataManager:FormatDateTime(timestamp)
    if not timestamp then 
        return L["NoRecord"] or "无";
    end
    
    -- 只显示时分秒
    return date("%H:%M:%S", timestamp);
end

-- 格式化时间用于显示（从Data模块移动过来）
function UnifiedDataManager:FormatTimeForDisplay(timestamp)
    if not timestamp then 
        return "--:--";
    end
    
    local t = date('*t', timestamp);
    return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec);
end

-- 获取数据状态（调试用）
function UnifiedDataManager:GetDataStatus(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    if mapId then
        local timeData = self.temporaryTimes[mapId];
        local tempPhase = self.temporaryPhases[mapId];
        local persistentPhase = self.persistentPhases[mapId];
        
        return {
            mapId = mapId,
            hasTemporary = timeData and timeData.temporaryTime ~= nil,
            hasPersistent = timeData and timeData.persistentTime ~= nil,
            hasTemporaryPhase = tempPhase and tempPhase.phaseId ~= nil,
            hasPersistentPhase = persistentPhase and persistentPhase.phaseId ~= nil,
            cacheValid = self.calculationCache[mapId] and 
                        (time() - self.calculationCache[mapId].cacheTime) < self.CACHE_EXPIRE_TIME
        };
    else
        -- 返回全局状态
        local totalMaps = 0;
        local temporaryCount = 0;
        local persistentCount = 0;
        local temporaryPhaseCount = 0;
        local persistentPhaseCount = 0;
        local cacheCount = 0;
        
        for _, timeData in pairs(self.temporaryTimes) do
            totalMaps = totalMaps + 1;
            if timeData.temporaryTime then temporaryCount = temporaryCount + 1; end
            if timeData.persistentTime then persistentCount = persistentCount + 1; end
        end
        
        for _, phaseData in pairs(self.temporaryPhases) do
            if phaseData.phaseId then temporaryPhaseCount = temporaryPhaseCount + 1; end
        end
        
        for _, phaseData in pairs(self.persistentPhases) do
            if phaseData.phaseId then persistentPhaseCount = persistentPhaseCount + 1; end
        end
        
        for _ in pairs(self.calculationCache) do
            cacheCount = cacheCount + 1;
        end
        
        return {
            totalMaps = totalMaps,
            temporaryCount = temporaryCount,
            persistentCount = persistentCount,
            temporaryPhaseCount = temporaryPhaseCount,
            persistentPhaseCount = persistentPhaseCount,
            cacheCount = cacheCount
        };
    end
end

-- 记录时间数据变更（调试用）
function UnifiedDataManager:LogTimeChange(mapId, changeType, oldValue, newValue, source)
    if not Logger or not Logger.Debug then
        return;
    end
    
    local mapName = "未知地图";
    if Data and Data.GetMap then
        local mapData = Data:GetMap(mapId);
        if mapData then
            if Data.GetMapDisplayName then
                mapName = Data:GetMapDisplayName(mapData);
            else
                mapName = string.format("地图ID_%d", mapId);
            end
        end
    end
    
    Logger:Debug("UnifiedDataManager", "变更", string.format("时间数据变更：地图=%s，类型=%s，旧值=%s，新值=%s，来源=%s", 
        mapName, changeType, 
        (oldValue and self:FormatDateTime(oldValue)) or "无",
        (newValue and self:FormatDateTime(newValue)) or "无",
        source or "未知"));
end

-- 记录位面数据变更（调试用）
function UnifiedDataManager:LogPhaseChange(mapId, changeType, oldValue, newValue, source)
    if not Logger or not Logger.Debug then
        return;
    end
    
    local mapName = "未知地图";
    if Data and Data.GetMap then
        local mapData = Data:GetMap(mapId);
        if mapData then
            if Data.GetMapDisplayName then
                mapName = Data:GetMapDisplayName(mapData);
            else
                mapName = string.format("地图ID_%d", mapId);
            end
        end
    end
    
    Logger:Debug("UnifiedDataManager", "变更", string.format("位面数据变更：地图=%s，类型=%s，旧值=%s，新值=%s，来源=%s", 
        mapName, changeType, 
        oldValue or "无",
        newValue or "无",
        source or "未知"));
end

-- 获取详细的调试信息
function UnifiedDataManager:GetDebugInfo(mapId)
    if not self.isInitialized then
        return "UnifiedDataManager未初始化";
    end
    
    local info = {};
    
    if mapId then
        local timeData = self.temporaryTimes[mapId];
        local tempPhase = self.temporaryPhases[mapId];
        local persistentPhase = self.persistentPhases[mapId];
        local displayTime = self:GetDisplayTime(mapId);
        local remainingTime = self:GetRemainingTime(mapId);
        local nextRefresh = self:GetNextRefreshTime(mapId);
        local phaseComparison = self:ComparePhases(mapId);
        local phaseDisplayInfo = self:GetPhaseDisplayInfo(mapId);
        
        table.insert(info, string.format("=== 地图ID %d 的统一数据详情 ===", mapId));
        
        -- 时间数据
        table.insert(info, "--- 时间数据 ---");
        if timeData then
            if timeData.temporaryTime then
                table.insert(info, string.format("临时时间: %s (来源: %s, 设置于: %s)", 
                    self:FormatDateTime(timeData.temporaryTime.timestamp),
                    timeData.temporaryTime.source,
                    self:FormatDateTime(timeData.temporaryTime.setTime)));
            else
                table.insert(info, "临时时间: 无");
            end
            
            if timeData.persistentTime then
                table.insert(info, string.format("持久化时间: %s (来源: %s, 位面ID: %s)", 
                    self:FormatDateTime(timeData.persistentTime.timestamp),
                    timeData.persistentTime.source,
                    timeData.persistentTime.phaseId or "无"));
            else
                table.insert(info, "持久化时间: 无");
            end
        else
            table.insert(info, "无时间数据");
        end
        
        if displayTime then
            table.insert(info, string.format("当前显示时间: %s (来源: %s, 持久化: %s)", 
                self:FormatDateTime(displayTime.time),
                displayTime.source,
                tostring(displayTime.isPersistent)));
        else
            table.insert(info, "当前显示时间: 无");
        end
        
        if remainingTime then
            table.insert(info, string.format("剩余时间: %s", self:FormatTime(remainingTime)));
        else
            table.insert(info, "剩余时间: 无");
        end
        
        if nextRefresh then
            table.insert(info, string.format("下次刷新时间: %s", self:FormatDateTime(nextRefresh)));
        else
            table.insert(info, "下次刷新时间: 无");
        end
        
        -- 位面数据
        table.insert(info, "--- 位面数据 ---");
        if tempPhase and tempPhase.phaseId then
            table.insert(info, string.format("临时位面: %s (来源: %s, 检测于: %s)", 
                tempPhase.phaseId,
                tempPhase.source,
                self:FormatDateTime(tempPhase.detectTime)));
        else
            table.insert(info, "临时位面: 无");
        end
        
        if persistentPhase and persistentPhase.phaseId then
            table.insert(info, string.format("持久化位面: %s (来源: %s, 检测于: %s)", 
                persistentPhase.phaseId,
                persistentPhase.source,
                self:FormatDateTime(persistentPhase.detectTime)));
        else
            table.insert(info, "持久化位面: 无");
        end
        
        if phaseComparison then
            table.insert(info, string.format("位面比对结果: %s (当前: %s, 持久化: %s)", 
                phaseComparison.status,
                phaseComparison.current or "无",
                phaseComparison.persistent or "无"));
        end
        
        if phaseDisplayInfo then
            table.insert(info, string.format("位面显示信息: %s (状态: %s, 颜色: RGB(%.1f,%.1f,%.1f))", 
                phaseDisplayInfo.phaseId,
                phaseDisplayInfo.status,
                phaseDisplayInfo.color.r,
                phaseDisplayInfo.color.g,
                phaseDisplayInfo.color.b));
        end
        
        -- 缓存状态
        local cache = self.calculationCache[mapId];
        if cache then
            local cacheAge = time() - cache.cacheTime;
            table.insert(info, string.format("缓存状态: 有效 (年龄: %d秒)", cacheAge));
        else
            table.insert(info, "缓存状态: 无");
        end
    else
        local globalStatus = self:GetDataStatus();
        table.insert(info, "=== UnifiedDataManager 全局状态 ===");
        table.insert(info, string.format("管理的地图数量: %d", globalStatus.totalMaps));
        table.insert(info, string.format("有临时时间的地图: %d", globalStatus.temporaryCount));
        table.insert(info, string.format("有持久化时间的地图: %d", globalStatus.persistentCount));
        table.insert(info, string.format("有临时位面的地图: %d", globalStatus.temporaryPhaseCount));
        table.insert(info, string.format("有持久化位面的地图: %d", globalStatus.persistentPhaseCount));
        table.insert(info, string.format("缓存条目数量: %d", globalStatus.cacheCount));
    end
    
    return table.concat(info, "\n");
end

return UnifiedDataManager;
