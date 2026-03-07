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
local ExpansionConfig = BuildEnv("ExpansionConfig");

if not Data then
    Data = BuildEnv('Data')
end

if not Logger then
    Logger = BuildEnv('Logger')
end

-- 时间来源枚举
UnifiedDataManager.TimeSource = {
    TEAM_MESSAGE = "team_message",
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

-- 采用临时时间用于持久化的最大时间偏移（秒）
UnifiedDataManager.TEMPORARY_TIME_ADOPTION_WINDOW = 120  -- 2分钟

local function GetCurrentExpansionID()
    if Data and Data.GetCurrentExpansionID then
        local id = Data:GetCurrentExpansionID();
        if id then
            return id;
        end
    end
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        local id = ExpansionConfig:GetCurrentExpansionID();
        if id then
            return id;
        end
    end
    return "default";
end

local function BuildScopedMapKey(mapId)
    return tostring(GetCurrentExpansionID()) .. ":" .. tostring(mapId);
end

local function GetPhaseCacheStore()
    if Data and Data.GetPhaseCache then
        return Data:GetPhaseCache();
    end
    if not CRATETRACKERZK_UI_DB or type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB.expansionUIData) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData = {};
    end
    local expansionID = GetCurrentExpansionID();
    if type(CRATETRACKERZK_UI_DB.expansionUIData[expansionID]) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData[expansionID] = {};
    end
    local bucket = CRATETRACKERZK_UI_DB.expansionUIData[expansionID];
    if type(bucket.phaseCache) ~= "table" then
        bucket.phaseCache = {};
    end
    return bucket.phaseCache;
end

-- 初始化
function UnifiedDataManager:Initialize()
    Logger:Debug("UnifiedDataManager", "初始化", "开始初始化UnifiedDataManager")
    
    self.isInitialized = true;
    
    -- 时间数据存储 {mapId -> TimeData}
    self.temporaryTimes = {};
    
    -- 位面数据存储 {mapId -> PhaseData}
    self.temporaryPhases = {};
    self.persistentPhases = {};
    
    self:RestoreTemporaryPhaseCache();
    Logger:Debug("UnifiedDataManager", "初始化", "统一数据管理器已初始化");
end

-- 时间数据结构
local function CreateTimeData(mapId)
    return {
        mapId = mapId,
        temporaryTime = nil,  -- {timestamp, source, setTime}
        persistentTime = nil -- {timestamp, source, phaseId}
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
local function CalculateNextRefreshTime(lastRefresh, interval, currentTime)
    if not lastRefresh or not interval or interval <= 0 then
        return nil;
    end

    local now = currentTime or time();

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

-- 对外暴露统一时间计算入口，便于其他模块复用
function UnifiedDataManager:CalculateNextRefreshTime(lastRefresh, interval, currentTime)
    return CalculateNextRefreshTime(lastRefresh, interval, currentTime);
end

-- 获取或创建时间数据
function UnifiedDataManager:GetOrCreateTimeData(mapId)
    local scopedKey = BuildScopedMapKey(mapId);
    if not self.temporaryTimes[scopedKey] then
        self.temporaryTimes[scopedKey] = CreateTimeData(mapId);
    end
    return self.temporaryTimes[scopedKey];
end

-- 获取或创建位面数据
function UnifiedDataManager:GetOrCreatePhaseData(mapId, isTemporary)
    local scopedKey = BuildScopedMapKey(mapId);
    local storage = isTemporary and self.temporaryPhases or self.persistentPhases;
    if not storage[scopedKey] then
        storage[scopedKey] = CreatePhaseData(mapId);
    end
    return storage[scopedKey];
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
    if source == self.TimeSource.TEAM_MESSAGE then
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
    
    timeData.temporaryTime = {
        timestamp = timestamp,
        source = source,
        setTime = time()
    };
    
    Logger:Debug("UnifiedDataManager", "临时时间", string.format("设置临时时间成功：地图ID=%d，时间=%d，来源=%s", 
        mapId, timestamp, source));
    
    return true;
end

-- 获取未过期的临时时间（不清除）
function UnifiedDataManager:GetValidTemporaryTime(mapId)
    local scopedKey = BuildScopedMapKey(mapId);
    local timeData = self.temporaryTimes[scopedKey];
    if not timeData or not timeData.temporaryTime then
        return nil;
    end
    
    local now = time();
    local record = timeData.temporaryTime;
    if now - record.setTime <= self.TEMPORARY_TIME_EXPIRE then
        return record;
    end
    
    -- 已过期则清除
    timeData.temporaryTime = nil;
    return nil;
end

-- 清除指定地图的临时时间
function UnifiedDataManager:ClearTemporaryTime(mapId)
    local scopedKey = BuildScopedMapKey(mapId);
    if self.temporaryTimes[scopedKey] then
        self.temporaryTimes[scopedKey].temporaryTime = nil;
    end
end

-- 选择事件时间戳：优先采用未过期且与检测时间相近的临时时间
function UnifiedDataManager:SelectEventTimestamp(mapId, detectionTimestamp)
    local fallback = detectionTimestamp or time();
    local record = self:GetValidTemporaryTime(mapId);
    if not record then
        return fallback, false;
    end
    
    local delta = math.abs(fallback - record.timestamp);
    if delta <= self.TEMPORARY_TIME_ADOPTION_WINDOW then
        Logger:Debug("UnifiedDataManager", "优先级", string.format(
            "采用临时时间作为事件时间：地图ID=%d，临时=%s，检测=%s，差值=%d秒",
            mapId,
            self:FormatDateTime(record.timestamp),
            self:FormatDateTime(fallback),
            delta));
        return record.timestamp, true;
    end
    
    return fallback, false;
end

-- 设置持久化时间
function UnifiedDataManager:SetPersistentTime(mapId, timestamp, source, phaseId)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    local timeData = self:GetOrCreateTimeData(mapId);
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
    
    -- 调用Data模块进行持久化存储
    if Data and Data.SetLastRefresh then
        Data:SetLastRefresh(mapId, timestamp);
    end
    
    Logger:Debug("UnifiedDataManager", "持久化时间", string.format("设置持久化时间：地图ID=%d，时间=%d，来源=%s", 
        mapId, timestamp, source));
    
    return true;
end

-- 获取显示时间
function UnifiedDataManager:GetDisplayTime(mapId, currentTime)
    if not self.isInitialized then
        return nil;
    end
    
    local scopedKey = BuildScopedMapKey(mapId);
    local timeData = self.temporaryTimes[scopedKey];
    local now = currentTime or time();

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
    
    phaseData.phaseId = phaseId;
    phaseData.source = source;
    phaseData.detectTime = time();
    
    local phaseCache = GetPhaseCacheStore();
    phaseCache[BuildScopedMapKey(mapId)] = {
        mapId = mapId,
        phaseId = phaseId,
        detectTime = phaseData.detectTime
    };

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
    
    phaseData.phaseId = phaseId;
    phaseData.source = source;
    phaseData.detectTime = time();
    
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
    local scopedKey = BuildScopedMapKey(mapId);
    local tempPhase = self.temporaryPhases[scopedKey];
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
    local persistentPhase = self.persistentPhases[scopedKey];
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
    
    local scopedKey = BuildScopedMapKey(mapId);
    local persistentPhase = self.persistentPhases[scopedKey];
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
        color = {r = 0, g = 1, b = 0}; -- 绿色
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
function UnifiedDataManager:GetRemainingTime(mapId, currentTime, displayTime)
    if not self.isInitialized then
        return nil;
    end
    
    local now = currentTime or time();
    displayTime = displayTime or self:GetDisplayTime(mapId, now);
    if not displayTime then
        return nil;
    end
    
    local nextRefresh = self:GetNextRefreshTime(mapId, now, displayTime);
    if not nextRefresh then
        return nil;
    end
    
    local remaining = nextRefresh - now;
    if remaining < 0 then
        remaining = 0;
    end
    
    return remaining;
end

-- 获取下次刷新时间
function UnifiedDataManager:GetNextRefreshTime(mapId, currentTime, displayTime)
    if not self.isInitialized then
        return nil;
    end

    displayTime = displayTime or self:GetDisplayTime(mapId, currentTime);
    if not displayTime then
        return nil;
    end

    local interval = GetMapInterval(mapId);
    return CalculateNextRefreshTime(displayTime.time, interval, currentTime);
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

-- 清理与格式化函数已拆分到 Modules/UnifiedDataManagerExtensions.lua

return UnifiedDataManager;
