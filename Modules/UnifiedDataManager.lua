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

local function IsPlayerCurrentlyOnTrackedMap(mapId)
    if type(mapId) ~= "number" then
        return false;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    if type(mapData) ~= "table" or type(mapData.mapID) ~= "number" then
        return false;
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil;
    return currentMapID == mapData.mapID;
end

local function CanUseTemporaryRecordForPhase(manager, mapId, phaseId, tempRecord)
    if type(tempRecord) ~= "table" then
        return false;
    end
    if type(phaseId) ~= "string" or phaseId == "" then
        return true;
    end

    if type(tempRecord.phaseId) == "string" and tempRecord.phaseId ~= "" then
        return tempRecord.phaseId == phaseId;
    end

    local sharedStateByMap = manager and manager.sharedDisplayStateByMap or nil;
    local state = type(sharedStateByMap) == "table" and sharedStateByMap[mapId] or nil;
    local phaseChangedAt = type(state) == "table" and tonumber(state.phaseChangedAt) or nil;
    if type(phaseChangedAt) ~= "number" then
        return true;
    end

    local setTime = tonumber(tempRecord.setTime);
    if type(setTime) ~= "number" then
        return true;
    end

    return setTime >= phaseChangedAt;
end

local function PopulatePhaseColor(outColor, r, g, b)
    outColor.r = r;
    outColor.g = g;
    outColor.b = b;
    return outColor;
end

local function AssignDisplayTime(outDisplayTime, record, isPersistent)
    if type(outDisplayTime) ~= "table" or type(record) ~= "table" then
        return nil;
    end

    outDisplayTime.time = record.timestamp;
    outDisplayTime.source = record.source;
    outDisplayTime.isPersistent = isPersistent == true;
    return outDisplayTime;
end

local function ResetDisplayTime(outDisplayTime)
    if type(outDisplayTime) ~= "table" then
        return nil;
    end
    outDisplayTime.time = nil;
    outDisplayTime.source = nil;
    outDisplayTime.isPersistent = nil;
    return outDisplayTime;
end

local function ReleaseSharedDisplay(manager, mapId)
    if manager and manager.OnSharedDisplayReleased then
        manager:OnSharedDisplayReleased(mapId);
    end
end

local function ActivateSharedDisplay(manager, mapId, currentPhaseID, sharedRecord, outDisplayTime)
    if type(outDisplayTime) ~= "table" or type(sharedRecord) ~= "table" then
        return nil;
    end

    outDisplayTime.time = sharedRecord.timestamp;
    outDisplayTime.source = sharedRecord.source or manager.TimeSource.PUBLIC_CHANNEL_SYNC;
    outDisplayTime.isPersistent = false;
    if manager and manager.OnSharedDisplayActivated then
        manager:OnSharedDisplayActivated(mapId, currentPhaseID, sharedRecord);
    end
    return outDisplayTime;
end

local function SelectLatestLocalDisplayRecord(tempRecord, persistentRecord)
    if tempRecord and persistentRecord then
        if tempRecord.timestamp > persistentRecord.timestamp then
            return tempRecord, false;
        end
        return persistentRecord, true;
    end
    if persistentRecord then
        return persistentRecord, true;
    end
    if tempRecord then
        return tempRecord, false;
    end
    return nil, nil;
end

local function GetActiveTemporaryTimeRecord(manager, timeData, now)
    if not manager or type(timeData) ~= "table" or type(timeData.temporaryTime) ~= "table" then
        return nil;
    end

    local temporaryTime = timeData.temporaryTime;
    if now - temporaryTime.setTime <= manager.TEMPORARY_TIME_EXPIRE then
        return temporaryTime;
    end

    timeData.temporaryTime = nil;
    return nil;
end

local function ResolveLocalDisplay(manager, mapId, tempRecord, persistentRecord, outDisplayTime)
    local localRecord, isPersistent = SelectLatestLocalDisplayRecord(tempRecord, persistentRecord);
    if not localRecord then
        ReleaseSharedDisplay(manager, mapId);
        return nil;
    end

    AssignDisplayTime(outDisplayTime, localRecord, isPersistent == true);
    ReleaseSharedDisplay(manager, mapId);
    return outDisplayTime;
end

local function ResolvePhaseScopedDisplay(manager, mapId, currentPhaseID, tempRecord, persistentRecord, sharedRecord, outDisplayTime)
    local phaseTransitionEligible = manager.CanUseSharedDisplayForPhase
        and manager:CanUseSharedDisplayForPhase(mapId, currentPhaseID) == true;
    local tempRecordMatchesCurrentPhase = CanUseTemporaryRecordForPhase(manager, mapId, currentPhaseID, tempRecord);
    local persistentMatchesCurrentPhase = persistentRecord
        and type(persistentRecord.phaseId) == "string"
        and persistentRecord.phaseId == currentPhaseID;
    local hasLocalCurrentPhaseSource = persistentMatchesCurrentPhase
        or (tempRecord and tempRecordMatchesCurrentPhase) == true;
    local shouldTrySharedDisplay = (not hasLocalCurrentPhaseSource) or phaseTransitionEligible;

    if persistentMatchesCurrentPhase then
        AssignDisplayTime(outDisplayTime, persistentRecord, true);
        ReleaseSharedDisplay(manager, mapId);
        return outDisplayTime;
    end

    if tempRecord and tempRecordMatchesCurrentPhase then
        AssignDisplayTime(outDisplayTime, tempRecord, false);
        ReleaseSharedDisplay(manager, mapId);
        return outDisplayTime;
    end

    if sharedRecord and shouldTrySharedDisplay then
        return ActivateSharedDisplay(manager, mapId, currentPhaseID, sharedRecord, outDisplayTime);
    end

    return ResolveLocalDisplay(manager, mapId, tempRecord, persistentRecord, outDisplayTime);
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

    local record = Data and Data.GetPersistentTimeRecordInto and Data:GetPersistentTimeRecordInto(mapId, outRecord) or nil;
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

    local state = Data and Data.GetPersistentAirdropStateInto and Data:GetPersistentAirdropStateInto(mapId, outState) or nil;
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

-- 选择事件时间戳：优先采用未过期且与检测时间相近的临时时间
function UnifiedDataManager:SelectEventTimestamp(mapId, detectionTimestamp, currentPhaseId)
    local fallback = detectionTimestamp or Utils:GetCurrentTimestamp();
    local record = self:GetValidTemporaryTime(mapId);
    if not record then
        return fallback, false;
    end

    if type(currentPhaseId) == "string"
        and currentPhaseId ~= ""
        and not CanUseTemporaryRecordForPhase(self, mapId, currentPhaseId, record) then
        return fallback, false;
    end
    
    local delta = math.abs(fallback - record.timestamp);
    if delta <= self.TEMPORARY_TIME_ADOPTION_WINDOW then
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
    if not self.isInitialized then
        return nil;
    end
    if type(outDisplayTime) ~= "table" then
        return nil;
    end
    
    local scopedKey = GetTimeScopedKey(mapId);
    local timeData = scopedKey and self.temporaryTimes[scopedKey] or nil;
    local now = currentTime or Utils:GetCurrentTimestamp();

    local tempRecord = nil;
    local recordBuffer = persistentRecordBuffer or outDisplayTime.__ctkPersistentRecordBuffer or {};
    local persistentRecord = self:GetPersistentTimeRecordInto(mapId, recordBuffer);
    outDisplayTime.__ctkPersistentRecordBuffer = recordBuffer;
    local currentPhaseID = self.GetCurrentPhase and self:GetCurrentPhase(mapId) or nil;
    local sharedRecordBuffer = outDisplayTime.__ctkSharedRecordBuffer or {};
    local sharedRecord = nil;
    if type(currentPhaseID) == "string" and self.GetSharedPhaseTimeRecordInto then
        sharedRecord = self:GetSharedPhaseTimeRecordInto(mapId, currentPhaseID, sharedRecordBuffer);
    end
    outDisplayTime.__ctkSharedRecordBuffer = sharedRecordBuffer;
    ResetDisplayTime(outDisplayTime);

    tempRecord = GetActiveTemporaryTimeRecord(self, timeData, now);

    local isPlayerOnCurrentMap = IsPlayerCurrentlyOnTrackedMap(mapId);
    if not isPlayerOnCurrentMap and self.ClearSharedDisplayPhaseGate then
        self:ClearSharedDisplayPhaseGate(mapId);
    end

    if isPlayerOnCurrentMap and type(currentPhaseID) == "string" and currentPhaseID ~= "" then
        return ResolvePhaseScopedDisplay(self, mapId, currentPhaseID, tempRecord, persistentRecord, sharedRecord, outDisplayTime);
    end

    return ResolveLocalDisplay(self, mapId, tempRecord, persistentRecord, outDisplayTime);
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
    if Data and Data.PersistAirdropState then
        local success = Data:PersistAirdropState(mapId, {
            lastRefreshPhase = phaseId or false,
        }) == true;
        if not success then
            return false;
        end
    end
    
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
        return PhaseStateStore:GetCurrent(self, mapId, Utils:GetCurrentTimestamp(), ResolveMapExpansionID(mapId));
    end
    return nil;
end

-- 获取持久化位面
function UnifiedDataManager:GetPersistentPhase(mapId)
    if not self.isInitialized then
        return nil;
    end
    if Data and Data.GetPersistentPhase then
        return Data:GetPersistentPhase(mapId);
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
    if not self.isInitialized then
        return nil;
    end
    if type(outResult) ~= "table" then
        return nil;
    end
    
    local currentPhase = self:GetCurrentPhase(mapId);
    local persistentPhase = self:GetPersistentPhase(mapId);
    
    outResult.match = false;
    outResult.current = currentPhase;
    outResult.persistent = persistentPhase;
    outResult.status = "unknown";
    
    if not currentPhase and not persistentPhase then
        outResult.status = "no_data";
    elseif not currentPhase then
        outResult.status = "no_current";
    elseif not persistentPhase then
        outResult.status = "no_persistent";
    elseif currentPhase == persistentPhase then
        outResult.match = true;
        outResult.status = "match";
    else
        outResult.match = false;
        outResult.status = "mismatch";
    end
    
    return outResult;
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
    if not self.isInitialized then
        return nil;
    end
    if type(outInfo) ~= "table" then
        return nil;
    end
    
    local comparison = self:ComparePhasesInto(mapId, comparisonBuffer or outInfo.__ctkComparisonBuffer or {});
    outInfo.__ctkComparisonBuffer = comparisonBuffer or outInfo.__ctkComparisonBuffer or comparison;
    if not comparison then
        return nil;
    end
    outInfo.color = outInfo.color or {};
    outInfo.phaseId = comparison.current or comparison.persistent or "未知";
    outInfo.status = "未知";
    outInfo.tooltip = "";
    outInfo.compareStatus = comparison.status;
    outInfo.currentPhaseID = comparison.current;
    outInfo.persistentPhaseID = comparison.persistent;
    PopulatePhaseColor(outInfo.color, 1, 1, 1);
    
    if comparison.status == "match" then
        PopulatePhaseColor(outInfo.color, 0, 1, 0);
        outInfo.status = "匹配";
        outInfo.tooltip = string.format("当前位面：%s\n持久化位面：%s\n状态：匹配", comparison.current, comparison.persistent);
    elseif comparison.status == "mismatch" then
        PopulatePhaseColor(outInfo.color, 1, 0, 0);
        outInfo.status = "不匹配";
        outInfo.tooltip = string.format("当前位面：%s\n持久化位面：%s\n状态：不匹配", comparison.current, comparison.persistent);
    elseif comparison.status == "no_data" then
        outInfo.status = "无数据";
        outInfo.tooltip = "无位面数据";
    elseif comparison.status == "no_current" then
        outInfo.status = "无当前位面";
        outInfo.tooltip = string.format("持久化位面：%s\n当前位面：未检测到", comparison.persistent);
        outInfo.phaseId = comparison.persistent;
    elseif comparison.status == "no_persistent" then
        PopulatePhaseColor(outInfo.color, 0, 1, 0);
        outInfo.status = "无持久化位面";
        outInfo.tooltip = string.format("当前位面：%s\n持久化位面：无", comparison.current);
        outInfo.phaseId = comparison.current;
    end
    
    return outInfo;
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
