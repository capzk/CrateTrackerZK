-- UnifiedDataManager.lua - 统一数据管理模块
-- 负责管理运行时临时时间/位面，并统一读取持久层快照

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local UnifiedDataManager = BuildEnv('UnifiedDataManager')

local AppContext = BuildEnv("AppContext");
local PersistentMapStateStore = BuildEnv("PersistentMapStateStore");
local PhaseStateStore = BuildEnv("PhaseStateStore");
local StateBuckets = BuildEnv("StateBuckets");
local TimeStateStore = BuildEnv("TimeStateStore");
local UnifiedDataDisplayResolver = BuildEnv("UnifiedDataDisplayResolver");
local UnifiedPhaseDisplayService = BuildEnv("UnifiedPhaseDisplayService");

if not Data then
    Data = BuildEnv('Data')
end

if not Logger then
    Logger = BuildEnv('Logger')
end

-- 时间来源枚举
UnifiedDataManager.TimeSource = {
    TEAM_MESSAGE = "team_message",
    ICON_DETECTION = "icon_detection",
    PUBLIC_CHANNEL_SYNC = "public_channel_sync",
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

local function GetTrackedMapData(mapId)
    if type(mapId) ~= "number" or not Data or not Data.GetMap then
        return nil;
    end
    return Data:GetMap(mapId);
end

local function GetPersistentTimeRecordInto(mapId, outRecord)
    local mapData = GetTrackedMapData(mapId);
    if not mapData or type(outRecord) ~= "table" then
        return nil;
    end
    if PersistentMapStateStore and PersistentMapStateStore.GetTimeRecordInto then
        return PersistentMapStateStore:GetTimeRecordInto(mapData, outRecord);
    end
    return nil;
end

local function GetPersistentAirdropStateInto(mapId, outState)
    local mapData = GetTrackedMapData(mapId);
    if not mapData or type(outState) ~= "table" then
        return nil;
    end
    if PersistentMapStateStore and PersistentMapStateStore.GetAirdropStateInto then
        return PersistentMapStateStore:GetAirdropStateInto(mapData, outState);
    end
    return nil;
end

local function PersistAirdropState(mapId, state)
    local mapData = GetTrackedMapData(mapId);
    if not mapData or type(state) ~= "table" then
        return false;
    end
    if PersistentMapStateStore and PersistentMapStateStore.PersistAirdropState then
        return PersistentMapStateStore:PersistAirdropState(mapData, state) == true;
    end
    return false;
end

-- 初始化
function UnifiedDataManager:Initialize()
    self.isInitialized = true;
    
    -- 时间数据存储 {mapId -> TimeData}（仅运行时临时态）
    self.temporaryTimes = {};
    
    -- 位面数据存储 {mapId -> PhaseData}（仅运行时临时态）
    self.temporaryPhases = {};
    self.sharedDisplayStateByMap = {};
    
    self:SynchronizeTrackedMaps();
    self:RestoreTemporaryPhaseCache();
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
function UnifiedDataManager:SetTime(mapId, timestamp, source, phaseId)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    
    -- 根据来源自动决定是临时时间还是持久化时间
    if source == self.TimeSource.TEAM_MESSAGE then
        return self:SetTemporaryTime(mapId, timestamp, source, phaseId);
    elseif source == self.TimeSource.ICON_DETECTION then
        return self:SetPersistentTime(mapId, timestamp, source, nil);
    else
        -- 默认为临时时间
        return self:SetTemporaryTime(mapId, timestamp, source, phaseId);
    end
end

-- 设置临时时间
function UnifiedDataManager:SetTemporaryTime(mapId, timestamp, source, phaseId)
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
        TimeStateStore:SetTemporary(self, mapId, timestamp, source, Utils:GetCurrentTimestamp(), expansionID, phaseId);
    end
    
    return true;
end

-- 获取未过期的临时时间（不清除）
function UnifiedDataManager:GetValidTemporaryTime(mapId)
    if TimeStateStore and TimeStateStore.GetValidTemporary then
        return TimeStateStore:GetValidTemporary(self, mapId, Utils:GetCurrentTimestamp(), ResolveMapExpansionID(mapId));
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
    local record = {};
    if not self:GetPersistentTimeRecordInto(mapId, record) then
        return nil;
    end
    return record;
end

function UnifiedDataManager:GetPersistentTimeRecordInto(mapId, outRecord)
    if not self.isInitialized then
        return nil;
    end

    if type(outRecord) ~= "table" then
        return nil;
    end

    local record = GetPersistentTimeRecordInto(mapId, outRecord);
    if not record then
        return nil;
    end

    if type(record.source) ~= "string" then
        record.source = self.TimeSource.ICON_DETECTION;
    end
    if type(record.eventTimestamp) ~= "number" then
        record.eventTimestamp = record.timestamp;
    end
    return record;
end

function UnifiedDataManager:GetPersistentAirdropState(mapId)
    local state = {};
    if not self:GetPersistentAirdropStateInto(mapId, state) then
        return nil;
    end
    return state;
end

function UnifiedDataManager:GetPersistentAirdropStateInto(mapId, outState)
    if not self.isInitialized or type(outState) ~= "table" then
        return nil;
    end

    local state = GetPersistentAirdropStateInto(mapId, outState);
    if not state then
        return nil;
    end

    if type(state.source) ~= "string" then
        state.source = self.TimeSource.ICON_DETECTION;
    end
    if type(state.currentAirdropTimestamp) ~= "number" then
        state.currentAirdropTimestamp = state.lastRefresh;
    end
    return state;
end

function UnifiedDataManager:ClearPersistentPhase(mapId)
    if not self.isInitialized then
        return false;
    end
    return PersistAirdropState(mapId, {
        lastRefreshPhase = false,
    }) == true;
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

    local now = Utils:GetCurrentTimestamp();
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
    return true;
end

-- 选择事件时间戳：
-- 1. 优先采用未过期且与检测时间相近的临时时间；
-- 2. 若当前位面存在同 objectGUID 的共享缓存记录，则采用共享缓存中的原始事件时间。
function UnifiedDataManager:SelectEventTimestamp(mapId, detectionTimestamp, currentPhaseId, detectedObjectGUID)
    if UnifiedDataDisplayResolver and UnifiedDataDisplayResolver.SelectEventTimestamp then
        return UnifiedDataDisplayResolver:SelectEventTimestamp(self, mapId, detectionTimestamp, currentPhaseId, detectedObjectGUID);
    end
    local fallback = detectionTimestamp or Utils:GetCurrentTimestamp();
    return fallback, false;
end

-- 设置持久化时间
function UnifiedDataManager:SetPersistentTime(mapId, timestamp, source, phaseId, metadata)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end

    local persistState = {
        lastRefresh = timestamp,
        lastRefreshSource = source,
        currentAirdropObjectGUID = metadata and metadata.currentAirdropObjectGUID or nil,
        currentAirdropTimestamp = metadata and (metadata.currentAirdropTimestamp or metadata.eventTimestamp) or timestamp,
    };
    if metadata and metadata.persistPhaseState == true then
        persistState.lastRefreshPhase = metadata.lastRefreshPhase;
    end
    local persisted = PersistAirdropState(mapId, persistState);
    if not persisted then
        return false;
    end

    local expansionID = ResolveMapExpansionID(mapId);
    local timeData = self:GetOrCreateTimeData(mapId, expansionID);
    if timeData and timeData.temporaryTime then
        timeData.temporaryTime = nil;
    end
    
    return true;
end

-- 获取显示时间
function UnifiedDataManager:GetDisplayTime(mapId, currentTime)
    local displayTime = {};
    if not self:GetDisplayTimeInto(mapId, currentTime, displayTime) then
        return nil;
    end
    return displayTime;
end

function UnifiedDataManager:GetDisplayTimeInto(mapId, currentTime, outDisplayTime, persistentRecordBuffer)
    if UnifiedDataDisplayResolver and UnifiedDataDisplayResolver.GetDisplayTimeInto then
        return UnifiedDataDisplayResolver:GetDisplayTimeInto(self, mapId, currentTime, outDisplayTime, persistentRecordBuffer);
    end
    return nil;
end

-- 统一位面设置接口
function UnifiedDataManager:SetPhase(mapId, phaseId, source, isPersistent)
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
        PhaseStateStore:SetTemporary(self, mapId, phaseId, source, Utils:GetCurrentTimestamp(), GetPhaseCacheStore(), expansionID);
    end
    
    return true;
end

-- 设置持久化位面
function UnifiedDataManager:SetPersistentPhase(mapId, phaseId, source)
    if not self.isInitialized then
        Logger:Error("UnifiedDataManager", "错误", "UnifiedDataManager未初始化");
        return false;
    end
    if PersistAirdropState(mapId, {
        lastRefreshPhase = phaseId or false,
    }) ~= true then
        return false;
    end
    
    return true;
end

function UnifiedDataManager:GetObservedHistoricalPhase(mapId)
    if UnifiedPhaseDisplayService and UnifiedPhaseDisplayService.GetObservedHistoricalPhase then
        return UnifiedPhaseDisplayService:GetObservedHistoricalPhase(self, mapId);
    end
    return nil;
end

function UnifiedDataManager:GetObservedHistoricalPhaseRecordInto(mapId, outRecord)
    if UnifiedPhaseDisplayService and UnifiedPhaseDisplayService.GetObservedHistoricalPhaseRecordInto then
        return UnifiedPhaseDisplayService:GetObservedHistoricalPhaseRecordInto(self, mapId, outRecord);
    end
    return nil;
end

function UnifiedDataManager:PersistObservedHistoricalPhase(mapId, phaseId, observedAt)
    if UnifiedPhaseDisplayService and UnifiedPhaseDisplayService.PersistObservedHistoricalPhase then
        return UnifiedPhaseDisplayService:PersistObservedHistoricalPhase(self, mapId, phaseId, observedAt);
    end
    return false;
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
        return PhaseStateStore:GetCurrent(self, mapId, Utils:GetCurrentTimestamp(), ResolveMapExpansionID(mapId));
    end
    return nil;
end

function UnifiedDataManager:GetCurrentPhaseInfoInto(mapId, outInfo)
    if not self.isInitialized or type(outInfo) ~= "table" then
        return nil;
    end

    if PhaseStateStore and PhaseStateStore.GetCurrentInfoInto then
        return PhaseStateStore:GetCurrentInfoInto(self, mapId, outInfo, Utils:GetCurrentTimestamp(), ResolveMapExpansionID(mapId));
    end
    return nil;
end

-- 获取持久化位面
function UnifiedDataManager:GetPersistentPhase(mapId)
    if not self.isInitialized then
        return nil;
    end
    local mapData = GetTrackedMapData(mapId);
    if mapData and PersistentMapStateStore and PersistentMapStateStore.GetPhase then
        return PersistentMapStateStore:GetPhase(mapData);
    end
    return nil;
end

-- 位面数据比对
function UnifiedDataManager:ComparePhases(mapId)
    local result = {};
    if not self:ComparePhasesInto(mapId, result) then
        return nil;
    end
    return result;
end

function UnifiedDataManager:ComparePhasesInto(mapId, outResult)
    if UnifiedPhaseDisplayService and UnifiedPhaseDisplayService.ComparePhasesInto then
        return UnifiedPhaseDisplayService:ComparePhasesInto(self, mapId, outResult);
    end
    return nil;
end

-- 获取位面显示信息
function UnifiedDataManager:GetPhaseDisplayInfo(mapId)
    local info = {};
    if not self:GetPhaseDisplayInfoInto(mapId, info) then
        return nil;
    end
    return info;
end

function UnifiedDataManager:GetPhaseDisplayInfoInto(mapId, outInfo, comparisonBuffer)
    if UnifiedPhaseDisplayService and UnifiedPhaseDisplayService.GetPhaseDisplayInfoInto then
        return UnifiedPhaseDisplayService:GetPhaseDisplayInfoInto(self, mapId, outInfo, comparisonBuffer);
    end
    return nil;
end

-- 获取剩余时间
function UnifiedDataManager:GetRemainingTime(mapId, currentTime, displayTime)
    if not self.isInitialized then
        return nil;
    end
    
    local now = currentTime or Utils:GetCurrentTimestamp();
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
