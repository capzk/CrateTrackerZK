-- Data.lua - 数据管理模块

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Data = BuildEnv("Data");
local AppContext = BuildEnv("AppContext");
local ExpansionConfig = BuildEnv("ExpansionConfig");
local StateBuckets = BuildEnv("StateBuckets");
local UnifiedDataManager = BuildEnv("UnifiedDataManager");
local PersistentMapStateStore = BuildEnv("PersistentMapStateStore");
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator");

Data.DEFAULT_REFRESH_INTERVAL = (Data.MAP_CONFIG and Data.MAP_CONFIG.defaults and Data.MAP_CONFIG.defaults.interval) or 1100;
Data.maps = {};
Data.mapsById = {};
Data.mapsByMapID = {};
Data.SCHEMA_VERSION = 4;

local function ensureDB()
    AppContext:EnsurePersistentState();
    CRATETRACKERZK_DB.mapData = nil;
    if type(CRATETRACKERZK_DB.expansionData) ~= "table" then
        CRATETRACKERZK_DB.expansionData = {};
    end
end

local function getCurrentExpansionID()
    if AppContext and AppContext.GetCurrentExpansionID then
        return AppContext:GetCurrentExpansionID();
    end
    return "default";
end

local function ensureExpansionMapData(expansionID)
    ensureDB();
    if StateBuckets and StateBuckets.GetExpansionMapData then
        return StateBuckets:GetExpansionMapData(expansionID);
    end
    expansionID = expansionID or getCurrentExpansionID() or "default";
    return CRATETRACKERZK_DB.expansionData[expansionID].mapData, expansionID;
end

local function ensureExpansionUIData(expansionID)
    if StateBuckets and StateBuckets.GetExpansionUIBucket then
        return StateBuckets:GetExpansionUIBucket(expansionID);
    end
    expansionID = expansionID or getCurrentExpansionID() or "default";
    return CRATETRACKERZK_UI_DB.expansionUIData[expansionID], expansionID;
end

local function sanitizeTimestamp(ts)
    if not ts or type(ts) ~= "number" then return nil end
    local maxFuture = time() + 86400 * 365;
    if ts < 0 or ts > maxFuture then return nil end
    return ts;
end

local function getTrackedMapConfigs()
    if ExpansionConfig and ExpansionConfig.GetTrackedMapConfigs then
        return ExpansionConfig:GetTrackedMapConfigs() or {};
    end
    return {};
end

local function getStableMap(mapId)
    if Data.mapsById and Data.mapsById[mapId] then
        return Data.mapsById[mapId];
    end
    return Data.maps[mapId];
end

local function getScopedMapLookup(expansionID, mapID)
    if not Data.mapsByMapID or type(Data.mapsByMapID[mapID]) ~= "table" then
        return nil;
    end
    if expansionID then
        return Data.mapsByMapID[mapID][expansionID];
    end
    return Data.mapsByMapID[mapID];
end

function Data:ResetDatabaseIfNeeded(forceReset)
    ensureDB();
    local shouldReset = forceReset == true or CRATETRACKERZK_DB.schemaVersion ~= self.SCHEMA_VERSION;
    if shouldReset then
        CRATETRACKERZK_DB = {
            schemaVersion = self.SCHEMA_VERSION,
            expansionData = {},
        };
        if type(CRATETRACKERZK_UI_DB) == "table" then
            CRATETRACKERZK_UI_DB.expansionUIData = {};
            CRATETRACKERZK_UI_DB.hiddenMaps = nil;
            CRATETRACKERZK_UI_DB.hiddenRemaining = nil;
            CRATETRACKERZK_UI_DB.phaseCache = nil;
        end
        if Logger and Logger.Info then
            Logger:Info("Data", "初始化", string.format("检测到新数据结构版本，已重置数据（schema=%d）", self.SCHEMA_VERSION));
        end
    end
    ensureDB();
    CRATETRACKERZK_DB.schemaVersion = self.SCHEMA_VERSION;
end

function Data:GetCurrentExpansionInfo()
    local expansionID = nil;
    local label = nil;
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        expansionID = ExpansionConfig:GetCurrentExpansionID();
        if ExpansionConfig.GetCurrentExpansionLabel then
            label = ExpansionConfig:GetCurrentExpansionLabel();
        end
    end
    return expansionID, label or expansionID;
end

function Data:GetCurrentExpansionID()
    return getCurrentExpansionID();
end

function Data:GetTrackedExpansionIDs()
    if ExpansionConfig and ExpansionConfig.GetTrackedExpansionIDs then
        return ExpansionConfig:GetTrackedExpansionIDs();
    end
    return {};
end

function Data:GetExpansionUIData(expansionID)
    local bucket = ensureExpansionUIData(expansionID);
    return bucket;
end

function Data:GetHiddenMaps(expansionID)
    local bucket = ensureExpansionUIData(expansionID);
    return bucket.hiddenMaps;
end

function Data:GetHiddenRemaining(expansionID)
    local bucket = ensureExpansionUIData(expansionID);
    return bucket.hiddenRemaining;
end

function Data:GetPhaseCache()
    if StateBuckets and StateBuckets.GetPhaseCache then
        return StateBuckets:GetPhaseCache();
    end
    local uiState = AppContext and AppContext.EnsureUIState and AppContext:EnsureUIState() or {};
    if type(uiState.phaseCache) ~= "table" then
        uiState.phaseCache = {};
    end
    return uiState.phaseCache;
end

function Data:IsMapHidden(expansionID, mapID)
    if type(mapID) ~= "number" then
        return false;
    end
    local hiddenMaps = self:GetHiddenMaps(expansionID);
    return hiddenMaps and hiddenMaps[mapID] == true or false;
end

function Data:GetHiddenRemainingValue(expansionID, mapID)
    if type(mapID) ~= "number" then
        return nil;
    end
    local hiddenRemaining = self:GetHiddenRemaining(expansionID);
    return hiddenRemaining and hiddenRemaining[mapID] or nil;
end

function Data:SetMapHiddenState(expansionID, mapID, hidden, frozenRemaining)
    if type(mapID) ~= "number" then
        return false;
    end

    local hiddenMaps = self:GetHiddenMaps(expansionID);
    local hiddenRemaining = self:GetHiddenRemaining(expansionID);
    if type(hiddenMaps) ~= "table" or type(hiddenRemaining) ~= "table" then
        return false;
    end

    if hidden == true then
        hiddenMaps[mapID] = true;
        hiddenRemaining[mapID] = frozenRemaining;
    else
        hiddenMaps[mapID] = nil;
        hiddenRemaining[mapID] = nil;
    end
    return true;
end

function Data:IsMapTracked(expansionID, mapID)
    if ExpansionConfig and ExpansionConfig.IsMapTracked then
        return ExpansionConfig:IsMapTracked(expansionID, mapID);
    end
    return false;
end

function Data:SetMapTracked(expansionID, mapID, tracked)
    if ExpansionConfig and ExpansionConfig.SetMapTracked then
        return ExpansionConfig:SetMapTracked(expansionID, mapID, tracked);
    end
    return false;
end

function Data:SetAllMapsTracked(expansionID, tracked)
    if ExpansionConfig and ExpansionConfig.SetAllMapsTracked then
        return ExpansionConfig:SetAllMapsTracked(expansionID, tracked);
    end
    return false;
end

function Data:InvertTrackedMaps(expansionID)
    if ExpansionConfig and ExpansionConfig.InvertTrackedMaps then
        return ExpansionConfig:InvertTrackedMaps(expansionID);
    end
    return false;
end

function Data:SwitchExpansion(expansionID)
    if not ExpansionConfig or not ExpansionConfig.SetCurrentExpansionID then
        return false;
    end
    if not ExpansionConfig:SetCurrentExpansionID(expansionID) then
        return false;
    end
    return true;
end

function Data:Initialize()
    Logger:Debug("Data", "初始化", "开始初始化数据模块");
    self:ResetDatabaseIfNeeded(false);
    if self.ReloadMapConfigForExpansion then
        self:ReloadMapConfigForExpansion();
    end

    ensureDB();

    self.maps = {};
    self.mapsById = {};
    self.mapsByMapID = {};

    local mapConfig = self.MAP_CONFIG and self.MAP_CONFIG.current_maps or {};
    if not mapConfig or #mapConfig == 0 then
        Logger:Warn("Data", "初始化", "当前没有任何已勾选追踪地图，数据模块将以空列表运行");
        return;
    end

    local defaults = (self.MAP_CONFIG and self.MAP_CONFIG.defaults) or {};
    local loadedCount = 0;
    local skippedCount = 0;

    for _, cfg in ipairs(mapConfig) do
        if cfg and cfg.id and cfg.mapID and cfg.expansionID and (cfg.enabled ~= false) then
            ensureExpansionUIData(cfg.expansionID);

            local savedData = PersistentMapStateStore and PersistentMapStateStore.GetSavedRecord
                and PersistentMapStateStore:GetSavedRecord(cfg.expansionID, cfg.mapID)
                or nil;
            if type(savedData) ~= "table" then
                savedData = {};
            end

            local lastRefresh = sanitizeTimestamp(savedData.lastRefresh);
            local createTime = sanitizeTimestamp(savedData.createTime) or time();
            local interval = cfg.interval or defaults.interval or self.DEFAULT_REFRESH_INTERVAL;
            local currentAirdropObjectGUID = type(savedData.currentAirdropObjectGUID) == "string" and savedData.currentAirdropObjectGUID or nil;
            local lastRefreshPhase = type(savedData.lastRefreshPhase) == "string" and savedData.lastRefreshPhase or nil;

            local mapData = {
                id = cfg.id,
                expansionID = cfg.expansionID,
                mapID = cfg.mapID,
                interval = interval,
                order = cfg.order or cfg.priority or loadedCount + 1,
                lastRefresh = lastRefresh,
                nextRefresh = nil,
                createTime = createTime,
                currentAirdropObjectGUID = currentAirdropObjectGUID,
                currentAirdropTimestamp = sanitizeTimestamp(savedData.currentAirdropTimestamp),
                lastRefreshPhase = lastRefreshPhase,
                currentPhaseID = nil,
            };

            if mapData.lastRefresh then
                self:UpdateNextRefresh(mapData.id, mapData);
                Logger:Debug("Data", "加载", string.format(
                    "地图 ID=%d，版本=%s，已加载时间记录：%s，下次刷新：%s",
                    cfg.mapID,
                    tostring(cfg.expansionID),
                    UnifiedDataManager:FormatDateTime(mapData.lastRefresh),
                    mapData.nextRefresh and UnifiedDataManager:FormatDateTime(mapData.nextRefresh) or "无"
                ));
            else
                Logger:Debug("Data", "加载", string.format(
                    "地图 ID=%d，版本=%s，无时间记录",
                    cfg.mapID,
                    tostring(cfg.expansionID)
                ));
            end

            self.maps[#self.maps + 1] = mapData;
            self.mapsById[mapData.id] = mapData;
            self.mapsByMapID[mapData.mapID] = self.mapsByMapID[mapData.mapID] or {};
            self.mapsByMapID[mapData.mapID][mapData.expansionID] = mapData;
            loadedCount = loadedCount + 1;
        else
            skippedCount = skippedCount + 1;
        end
    end

    table.sort(self.maps, function(a, b)
        if a.expansionID == b.expansionID then
            if (a.order or 0) == (b.order or 0) then
                return (a.id or 0) < (b.id or 0)
            end
            return (a.order or 0) < (b.order or 0)
        end

        local displayOrder = {}
        if ExpansionConfig and ExpansionConfig.GetDisplayExpansionOrder then
            for index, expansionID in ipairs(ExpansionConfig:GetDisplayExpansionOrder()) do
                displayOrder[expansionID] = index
            end
        end
        return (displayOrder[a.expansionID] or math.huge) < (displayOrder[b.expansionID] or math.huge)
    end)

    Logger:DebugLimited(
        "data:init_complete",
        "Data",
        "初始化",
        string.format("数据模块初始化完成：已加载 %d 个追踪地图，跳过 %d 个", loadedCount, skippedCount)
    );
end

function Data:SaveMapData(mapId)
    local mapData = self:GetMap(mapId);
    if not mapData or not mapData.mapID or not mapData.expansionID then
        Logger:DebugLimited("data_save:invalid", "Data", "保存", "保存失败：无效的地图ID " .. tostring(mapId));
        return;
    end

    local savedData = {
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime or time(),
        currentAirdropObjectGUID = mapData.currentAirdropObjectGUID,
        currentAirdropTimestamp = mapData.currentAirdropTimestamp,
        lastRefreshPhase = mapData.lastRefreshPhase,
    };

    ensureDB();
    local expansionID = mapData.expansionID;
    if PersistentMapStateStore and PersistentMapStateStore.SaveRecord then
        PersistentMapStateStore:SaveRecord(expansionID, mapData.mapID, savedData);
    else
        local mapStore = ensureExpansionMapData(expansionID);
        mapStore[mapData.mapID] = savedData;
    end

    Logger:DebugLimited("data_save:map_" .. mapData.mapID, "Data", "保存",
        string.format(
            "已保存地图数据：资料片=%s，地图ID=%d（配置ID=%d），上次刷新=%s，objectGUID=%s",
            tostring(expansionID),
            mapData.mapID,
            mapId,
            mapData.lastRefresh and UnifiedDataManager:FormatDateTime(mapData.lastRefresh) or "无",
            mapData.currentAirdropObjectGUID or "nil"
        ));

    if Logger and Logger.Debug then
        local verifyData = PersistentMapStateStore and PersistentMapStateStore.GetSavedRecord
            and PersistentMapStateStore:GetSavedRecord(expansionID, mapData.mapID)
            or (ensureExpansionMapData(expansionID))[mapData.mapID];
        if verifyData and verifyData.currentAirdropObjectGUID ~= mapData.currentAirdropObjectGUID then
            Logger:Error("Data", "错误", string.format(
                "数据保存验证失败：地图ID=%d，期望objectGUID=%s，实际objectGUID=%s",
                mapData.mapID,
                mapData.currentAirdropObjectGUID or "nil",
                verifyData.currentAirdropObjectGUID or "nil"
            ));
        end
    end
end

function Data:GetPersistentSnapshot(mapId)
    local mapData = self:GetMap(mapId);
    if not mapData then
        return nil;
    end
    return {
        expansionID = mapData.expansionID,
        mapID = mapData.mapID,
        lastRefresh = mapData.lastRefresh,
        currentAirdropObjectGUID = mapData.currentAirdropObjectGUID,
        currentAirdropTimestamp = mapData.currentAirdropTimestamp,
        lastRefreshPhase = mapData.lastRefreshPhase,
        currentPhaseID = mapData.currentPhaseID,
    };
end

function Data:PersistAirdropState(mapId, state)
    local mapData = self:GetMap(mapId);
    if not mapData or type(state) ~= "table" then
        return false;
    end

    if state.lastRefresh ~= nil then
        mapData.lastRefresh = state.lastRefresh;
    end
    if state.currentAirdropObjectGUID ~= nil then
        mapData.currentAirdropObjectGUID = state.currentAirdropObjectGUID;
    end
    if state.currentAirdropTimestamp ~= nil then
        mapData.currentAirdropTimestamp = state.currentAirdropTimestamp;
    end
    if state.lastRefreshPhase ~= nil or state.lastRefreshPhase == false then
        mapData.lastRefreshPhase = state.lastRefreshPhase or nil;
    end
    if state.currentPhaseID ~= nil or state.currentPhaseID == false then
        mapData.currentPhaseID = state.currentPhaseID or nil;
    end

    self:UpdateNextRefresh(mapId, mapData);
    self:SaveMapData(mapId);
    return true;
end

function Data:UpdateMap(mapId, mapData)
    local currentMap = self:GetMap(mapId);
    if currentMap then
        local allowedFields = {
            lastRefresh = true,
            nextRefresh = true,
            currentAirdropObjectGUID = true,
            currentAirdropTimestamp = true,
            lastRefreshPhase = true,
            currentPhaseID = true,
        };

        for key, value in pairs(mapData or {}) do
            if allowedFields[key] then
                currentMap[key] = value;
            end
        end

        self:SaveMapData(mapId);
        return true;
    end
    return false;
end

local function CalculateNextRefreshTime(lastRefresh, interval, currentTime)
    if UnifiedDataManager and UnifiedDataManager.CalculateNextRefreshTime then
        return UnifiedDataManager:CalculateNextRefreshTime(lastRefresh, interval, currentTime);
    end

    if not lastRefresh or not interval or interval <= 0 then
        return nil;
    end

    currentTime = currentTime or time();
    if currentTime <= lastRefresh then
        return lastRefresh + interval;
    end

    local cycles = math.ceil((currentTime - lastRefresh) / interval);
    if cycles < 1 then
        cycles = 1;
    end
    return lastRefresh + cycles * interval;
end

function Data:UpdateNextRefresh(mapId, mapData)
    mapData = mapData or self:GetMap(mapId);
    if not mapData then
        return;
    end

    if not mapData.lastRefresh then
        mapData.nextRefresh = nil;
        Logger:DebugLimited("data_update:no_refresh", "Data", "更新",
            string.format("地图 ID=%d 无刷新时间，跳过计算下次刷新", mapId));
        return;
    end

    local interval = mapData.interval or 1100;
    local currentTime = time();
    local lastRefresh = mapData.lastRefresh;
    local oldNextRefresh = mapData.nextRefresh;

    mapData.nextRefresh = CalculateNextRefreshTime(lastRefresh, interval, currentTime);

    if oldNextRefresh ~= mapData.nextRefresh then
        Logger:DebugLimited("data_update:map_" .. mapId, "Data", "更新",
            string.format("已更新下次刷新时间：地图=%s，间隔=%d秒，下次=%s",
                self:GetMapDisplayName(mapData),
                interval,
                mapData.nextRefresh and UnifiedDataManager:FormatDateTime(mapData.nextRefresh) or "无"));
    end
end

function Data:SetLastRefresh(mapId, timestamp)
    local mapData = self:GetMap(mapId);
    if not mapData then
        Logger:Debug("Data", "更新", "设置刷新时间失败：无效的地图ID " .. tostring(mapId));
        return false;
    end

    timestamp = timestamp or time();
    local oldLastRefresh = mapData.lastRefresh;
    mapData.lastRefresh = timestamp;

    self:UpdateNextRefresh(mapId, mapData);
    self:SaveMapData(mapId);

    Logger:Debug("Data", "更新", string.format("已更新刷新时间：地图=%s，旧时间=%s，新时间=%s，下次刷新=%s",
        self:GetMapDisplayName(mapData),
        oldLastRefresh and UnifiedDataManager:FormatDateTime(oldLastRefresh) or "无",
        UnifiedDataManager:FormatDateTime(timestamp),
        mapData.nextRefresh and UnifiedDataManager:FormatDateTime(mapData.nextRefresh) or "无"));

    return true;
end

function Data:GetAllMaps()
    return self.maps;
end

function Data:GetMap(mapId)
    return getStableMap(mapId);
end

function Data:CheckAndUpdateRefreshTimes()
    if not self.maps then return end

    for _, mapData in ipairs(self.maps) do
        if mapData and mapData.lastRefresh then
            self:UpdateNextRefresh(mapData.id, mapData);
        end
    end
end

function Data:ClearAllData()
    if not self.maps then return false end

    ensureDB();
    if PersistentMapStateStore and PersistentMapStateStore.ClearAll then
        PersistentMapStateStore:ClearAll();
    elseif CRATETRACKERZK_DB.expansionData then
        for _, expansionBucket in pairs(CRATETRACKERZK_DB.expansionData) do
            if type(expansionBucket) == "table" then
                expansionBucket.mapData = {};
            end
        end
    end

    for _, mapData in ipairs(self.maps) do
        if mapData then
            mapData.lastRefresh = nil;
            mapData.nextRefresh = nil;
            mapData.currentAirdropObjectGUID = nil;
            mapData.currentAirdropTimestamp = nil;
            mapData.lastRefreshPhase = nil;
            mapData.currentPhaseID = nil;
        end
    end

    if MapTracker then
        MapTracker.lastDetectedMapId = nil;
        MapTracker.lastDetectedGameMapID = nil;
    end

    if UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable();
    end

    return true;
end

function Data:GetMapDisplayName(mapData)
    if not mapData then return "" end;

    if Localization and mapData.mapID then
        return Localization:GetMapName(mapData.mapID);
    end

    return mapData.mapID and ("Map " .. tostring(mapData.mapID)) or "";
end

function Data:GetMapByMapID(gameMapID, expansionID)
    if not gameMapID then return nil end;
    local scopedLookup = getScopedMapLookup(expansionID, gameMapID);
    if expansionID then
        if scopedLookup then
            return scopedLookup;
        end
    elseif type(scopedLookup) == "table" then
        local singleMatch = nil;
        local count = 0;
        for _, mapData in pairs(scopedLookup) do
            singleMatch = mapData;
            count = count + 1;
            if count > 1 then
                singleMatch = nil;
                break;
            end
        end
        if singleMatch then
            return singleMatch;
        end
    end

    for _, mapData in ipairs(self.maps) do
        if mapData.mapID == gameMapID and (not expansionID or mapData.expansionID == expansionID) then
            return mapData;
        end
    end

    return nil;
end

return Data
