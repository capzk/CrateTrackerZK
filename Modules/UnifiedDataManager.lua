-- UnifiedDataManager.lua - 统一数据管理模块
-- 负责管理运行时临时时间/位面，并统一读取持久层快照

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local UnifiedDataManager = BuildEnv('UnifiedDataManager')

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local AppContext = BuildEnv("AppContext");
local L = CrateTrackerZK.L;
local ExpansionConfig = BuildEnv("ExpansionConfig");
local PhaseStateStore = BuildEnv("PhaseStateStore");
local StateBuckets = BuildEnv("StateBuckets");
local TimeStateStore = BuildEnv("TimeStateStore");

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

local function GetPhaseCacheStore()
    if StateBuckets and StateBuckets.GetPhaseCache then
        return StateBuckets:GetPhaseCache();
    end
    if Data and Data.GetPhaseCache then
        return Data:GetPhaseCache();
    end
    return {};
end

local function ResolveMapExpansionID(mapId, expansionID)
    if expansionID then
        return expansionID;
    end
    if Data and Data.GetMap then
        local mapData = Data:GetMap(mapId);
        if mapData and mapData.expansionID then
            return mapData.expansionID;
        end
    end
    if AppContext and AppContext.GetCurrentExpansionID then
        local id = AppContext:GetCurrentExpansionID();
        if id then
            return id;
        end
    end
    return "default";
end

local function GetTimeScopedKey(mapId, expansionID)
    if TimeStateStore and TimeStateStore.GetScopedKey then
        return TimeStateStore:GetScopedKey(mapId, ResolveMapExpansionID(mapId, expansionID));
    end
    return tostring(ResolveMapExpansionID(mapId, expansionID)) .. ":" .. tostring(mapId);
end

local function GetPhaseScopedKey(mapId, expansionID)
    if PhaseStateStore and PhaseStateStore.GetScopedKey then
        return PhaseStateStore:GetScopedKey(mapId, ResolveMapExpansionID(mapId, expansionID));
    end
    return tostring(ResolveMapExpansionID(mapId, expansionID)) .. ":" .. tostring(mapId);
end

local function BuildPersistentTimeRecord(manager, snapshot)
    if not snapshot or not snapshot.lastRefresh then
        return nil;
    end

    return {
        timestamp = snapshot.lastRefresh,
        source = snapshot.lastRefreshSource or manager.TimeSource.ICON_DETECTION,
        phaseId = snapshot.lastRefreshPhase,
        objectGUID = snapshot.currentAirdropObjectGUID,
        eventTimestamp = snapshot.currentAirdropTimestamp or snapshot.lastRefresh,
    };
end

-- 初始化
function UnifiedDataManager:Initialize()
    Logger:Debug("UnifiedDataManager", "初始化", "开始初始化UnifiedDataManager")
    
    self.isInitialized = true;
    
    -- 时间数据存储 {mapId -> TimeData}（仅运行时临时态）
    self.temporaryTimes = {};
    
    -- 位面数据存储 {mapId -> PhaseData}（仅运行时临时态）
    self.temporaryPhases = {};
    
    self:SynchronizeTrackedMaps();
    self:RestoreTemporaryPhaseCache();
    Logger:Debug("UnifiedDataManager", "初始化", "统一数据管理器已初始化");
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

-- 对外暴露统一时间计算入口，便于其他模块复用
function UnifiedDataManager:CalculateNextRefreshTime(lastRefresh, interval, currentTime)
    if TimeStateStore and TimeStateStore.CalculateNextRefreshTime then
        return TimeStateStore:CalculateNextRefreshTime(lastRefresh, interval, currentTime);
    end
    return nil;
end

-- 获取或创建时间数据
function UnifiedDataManager:GetOrCreateTimeData(mapId, expansionID)
    if TimeStateStore and TimeStateStore.GetOrCreate then
        return TimeStateStore:GetOrCreate(self, mapId, ResolveMapExpansionID(mapId, expansionID));
    end
    return nil;
end

-- 获取或创建位面数据
function UnifiedDataManager:GetOrCreatePhaseData(mapId, isTemporary, expansionID)
    if PhaseStateStore and PhaseStateStore.GetOrCreate then
        return PhaseStateStore:GetOrCreate(self, mapId, isTemporary, ResolveMapExpansionID(mapId, expansionID));
    end
    return nil;
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
    
    local expansionID = ResolveMapExpansionID(mapId);
    local timeData = self:GetOrCreateTimeData(mapId, expansionID);
    if not timeData then
        Logger:Error("UnifiedDataManager", "错误", string.format("无法创建时间数据：mapId=%s", tostring(mapId)));
        return false;
    end

    if TimeStateStore and TimeStateStore.SetTemporary then
        TimeStateStore:SetTemporary(self, mapId, timestamp, source, time(), expansionID);
    end
    
    Logger:Debug("UnifiedDataManager", "临时时间", string.format("设置临时时间成功：地图ID=%d，时间=%d，来源=%s", 
        mapId, timestamp, source));
    
    return true;
end

-- 获取未过期的临时时间（不清除）
function UnifiedDataManager:GetValidTemporaryTime(mapId)
    if TimeStateStore and TimeStateStore.GetValidTemporary then
        return TimeStateStore:GetValidTemporary(self, mapId, time(), ResolveMapExpansionID(mapId));
    end
    return nil;
end

-- 清除指定地图的临时时间
function UnifiedDataManager:ClearTemporaryTime(mapId)
    if TimeStateStore and TimeStateStore.ClearTemporary then
        TimeStateStore:ClearTemporary(self, mapId, ResolveMapExpansionID(mapId));
    end
end

function UnifiedDataManager:GetPersistentTimeRecord(mapId)
    if not self.isInitialized then
        return nil;
    end

    if Data and Data.GetPersistentSnapshot then
        local snapshot = Data:GetPersistentSnapshot(mapId);
        local fallbackRecord = BuildPersistentTimeRecord(self, snapshot);
        if fallbackRecord then
            return fallbackRecord;
        end
    end

    return nil;
end

function UnifiedDataManager:GetPersistentAirdropState(mapId)
    local record = self:GetPersistentTimeRecord(mapId);
    if not record then
        return nil;
    end

    return {
        lastRefresh = record.timestamp,
        currentAirdropObjectGUID = record.objectGUID,
        currentAirdropTimestamp = record.eventTimestamp or record.timestamp,
        lastRefreshPhase = record.phaseId,
        source = record.source,
    };
end

function UnifiedDataManager:ClearPersistentPhase(mapId)
    if not self.isInitialized then
        return false;
    end
    if Data and Data.PersistAirdropState then
        return Data:PersistAirdropState(mapId, {
            lastRefreshPhase = false,
        }) == true;
    end
    return true;
end

function UnifiedDataManager:SynchronizeTrackedMaps()
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end

    if not Data or not Data.GetAllMaps then
        Logger:Error("UnifiedDataManager", "错误", "Data模块未加载");
        return false;
    end

    local now = time();
    local maps = Data:GetAllMaps() or {};
    local previousTimeState = self.temporaryTimes or {};
    local previousTemporaryPhases = self.temporaryPhases or {};
    local synchronizedTimes = {};
    local synchronizedTemporaryPhases = {};

    for _, mapData in ipairs(maps) do
        if mapData and mapData.id then
            local expansionID = ResolveMapExpansionID(mapData.id, mapData.expansionID);
            local timeScopedKey = GetTimeScopedKey(mapData.id, expansionID);
            local phaseScopedKey = GetPhaseScopedKey(mapData.id, expansionID);
            local previousTimeData = previousTimeState[timeScopedKey];
            local previousTemporaryPhase = previousTemporaryPhases[phaseScopedKey];

            synchronizedTimes[timeScopedKey] = {
                mapId = mapData.id,
                temporaryTime = previousTimeData and previousTimeData.temporaryTime or nil,
            };

            if synchronizedTimes[timeScopedKey].temporaryTime
                and now - synchronizedTimes[timeScopedKey].temporaryTime.setTime > self.TEMPORARY_TIME_EXPIRE then
                synchronizedTimes[timeScopedKey].temporaryTime = nil;
            end

            if previousTemporaryPhase
                and previousTemporaryPhase.phaseId
                and previousTemporaryPhase.detectTime
                and now - previousTemporaryPhase.detectTime <= self.TEMPORARY_PHASE_EXPIRE then
                synchronizedTemporaryPhases[phaseScopedKey] = previousTemporaryPhase;
            end
        end
    end

    self.temporaryTimes = synchronizedTimes;
    self.temporaryPhases = synchronizedTemporaryPhases;

    Logger:Debug("UnifiedDataManager", "同步", string.format("已同步 %d 个追踪地图的运行时状态", #maps));
    return true;
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
function UnifiedDataManager:SetPersistentTime(mapId, timestamp, source, phaseId, metadata)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end

    local persisted = true;
    if Data and Data.PersistAirdropState then
        local persistState = {
            lastRefresh = timestamp,
            lastRefreshSource = source,
            currentAirdropObjectGUID = metadata and metadata.currentAirdropObjectGUID or nil,
            currentAirdropTimestamp = metadata and (metadata.currentAirdropTimestamp or metadata.eventTimestamp) or timestamp,
        };
        if metadata and metadata.persistPhaseState == true then
            persistState.lastRefreshPhase = metadata.lastRefreshPhase;
        end
        persisted = Data:PersistAirdropState(mapId, persistState) == true;
    end
    if not persisted then
        return false;
    end

    local expansionID = ResolveMapExpansionID(mapId);
    local timeData = self:GetOrCreateTimeData(mapId, expansionID);
    if timeData and timeData.temporaryTime then
        timeData.temporaryTime = nil;
        Logger:Debug("UnifiedDataManager", "优先级", string.format("持久化时间优先级更高，清除临时时间：地图ID=%d", mapId));
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
    
    local scopedKey = GetTimeScopedKey(mapId);
    local timeData = scopedKey and self.temporaryTimes[scopedKey] or nil;
    local now = currentTime or time();

    local tempRecord = nil;
    local persistentRecord = self:GetPersistentTimeRecord(mapId);

    if timeData then
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
    
    local expansionID = ResolveMapExpansionID(mapId);
    local phaseData = self:GetOrCreatePhaseData(mapId, true, expansionID);
    if not phaseData then
        Logger:Error("UnifiedDataManager", "错误", string.format("无法创建临时位面数据：mapId=%s", tostring(mapId)));
        return false;
    end

    if PhaseStateStore and PhaseStateStore.SetTemporary then
        PhaseStateStore:SetTemporary(self, mapId, phaseId, source, time(), GetPhaseCacheStore(), expansionID);
    end

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
    if Data and Data.PersistAirdropState then
        local success = Data:PersistAirdropState(mapId, {
            lastRefreshPhase = phaseId or false,
        }) == true;
        if not success then
            return false;
        end
    end
    
    Logger:Debug("UnifiedDataManager", "持久化位面", string.format("设置持久化位面成功：地图ID=%d，位面ID=%s，来源=%s", 
        mapId, phaseId, source));
    
    return true;
end

function UnifiedDataManager:PersistConfirmedAirdropState(mapId, state)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    if type(state) ~= "table" then
        Logger:Error("UnifiedDataManager", "错误", "PersistConfirmedAirdropState 缺少状态数据");
        return false;
    end

    local timestamp = state.lastRefresh or state.timestamp or state.currentAirdropTimestamp;
    if type(timestamp) ~= "number" then
        Logger:Error("UnifiedDataManager", "错误", string.format("PersistConfirmedAirdropState 时间无效：mapId=%s", tostring(mapId)));
        return false;
    end

    local phaseId = state.lastRefreshPhase;
    local success = self:SetPersistentTime(
        mapId,
        timestamp,
        state.source or self.TimeSource.ICON_DETECTION,
        phaseId,
        {
            currentAirdropObjectGUID = state.currentAirdropObjectGUID,
            currentAirdropTimestamp = state.currentAirdropTimestamp or timestamp,
            persistPhaseState = true,
            lastRefreshPhase = phaseId or false,
        }
    );
    if not success then
        return false;
    end

    return true;
end

-- 获取当前位面（优先临时位面）
function UnifiedDataManager:GetCurrentPhase(mapId)
    if not self.isInitialized then
        return nil;
    end
    
    -- 优先使用临时位面（如果存在且未过期）
    if PhaseStateStore and PhaseStateStore.GetCurrent then
        return PhaseStateStore:GetCurrent(self, mapId, time(), ResolveMapExpansionID(mapId));
    end
    return nil;
end

-- 获取持久化位面
function UnifiedDataManager:GetPersistentPhase(mapId)
    if not self.isInitialized then
        return nil;
    end

    if Data and Data.GetPersistentSnapshot then
        local snapshot = Data:GetPersistentSnapshot(mapId);
        if snapshot and snapshot.lastRefreshPhase then
            return snapshot.lastRefreshPhase;
        end
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
    return self:CalculateNextRefreshTime(displayTime.time, interval, currentTime);
end

-- 迁移现有数据
function UnifiedDataManager:MigrateExistingData()
    return self:SynchronizeTrackedMaps();
end

-- 清理与格式化函数已拆分到 Modules/UnifiedDataManagerExtensions.lua

return UnifiedDataManager;
