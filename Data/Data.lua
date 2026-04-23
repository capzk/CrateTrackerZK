-- Data.lua - 数据管理模块

local Data = BuildEnv("Data");
local AppContext = BuildEnv("AppContext");
local ExpansionConfig = BuildEnv("ExpansionConfig");
local StateBuckets = BuildEnv("StateBuckets");
local PersistentMapStateStore = BuildEnv("PersistentMapStateStore");

Data.DEFAULT_REFRESH_INTERVAL = (Data.MAP_CONFIG and Data.MAP_CONFIG.defaults and Data.MAP_CONFIG.defaults.interval) or 1100;
Data.maps = {};
Data.mapsById = {};
Data.mapsByMapID = {};
Data.SCHEMA_VERSION = 4;

local function ensureDB(clearLegacyMapData)
    AppContext:EnsurePersistentState();
    if clearLegacyMapData == true then
        CRATETRACKERZK_DB.mapData = nil;
    end
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
    local maxFuture = Utils:GetCurrentTimestamp() + 86400 * 365;
    if ts < 0 or ts > maxFuture then return nil end
    return ts;
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

local function resolveMapExpansionID(mapID)
    if type(mapID) ~= "number" then
        return nil;
    end
    if ExpansionConfig and ExpansionConfig.GetMapExpansionID then
        return ExpansionConfig:GetMapExpansionID(mapID);
    end
    return nil;
end

local function ensureSchemaExpansionBucket(db, expansionID)
    expansionID = expansionID or "default";
    if type(db.expansionData) ~= "table" then
        db.expansionData = {};
    end
    if type(db.expansionData[expansionID]) ~= "table" then
        db.expansionData[expansionID] = {};
    end
    if type(db.expansionData[expansionID].mapData) ~= "table" then
        db.expansionData[expansionID].mapData = {};
    end
    return db.expansionData[expansionID].mapData;
end

local function migrateLegacyMapData(db, legacyMapData)
    if type(legacyMapData) ~= "table" then
        return 0;
    end
    local movedCount = 0;
    for rawMapID, savedData in pairs(legacyMapData) do
        local mapID = tonumber(rawMapID);
        if mapID and type(savedData) == "table" then
            local expansionID = resolveMapExpansionID(mapID) or "default";
            local mapStore = ensureSchemaExpansionBucket(db, expansionID);
            if type(mapStore[mapID]) ~= "table" then
                mapStore[mapID] = savedData;
                movedCount = movedCount + 1;
            end
        end
    end
    return movedCount;
end

local function migrateLegacyHiddenState(uiDB)
    local legacyHiddenMaps = uiDB.hiddenMaps;
    local legacyHiddenRemaining = uiDB.hiddenRemaining;
    if type(legacyHiddenMaps) ~= "table" and type(legacyHiddenRemaining) ~= "table" then
        return 0;
    end

    if type(uiDB.expansionUIData) ~= "table" then
        uiDB.expansionUIData = {};
    end

    local movedCount = 0;
    for rawMapID, isHidden in pairs(legacyHiddenMaps or {}) do
        local mapID = tonumber(rawMapID);
        if mapID and isHidden == true then
            local expansionID = resolveMapExpansionID(mapID) or "default";
            if type(uiDB.expansionUIData[expansionID]) ~= "table" then
                uiDB.expansionUIData[expansionID] = {};
            end
            local bucket = uiDB.expansionUIData[expansionID];
            if type(bucket.hiddenMaps) ~= "table" then
                bucket.hiddenMaps = {};
            end
            if type(bucket.hiddenRemaining) ~= "table" then
                bucket.hiddenRemaining = {};
            end

            bucket.hiddenMaps[mapID] = true;
            local remainingValue = legacyHiddenRemaining and (legacyHiddenRemaining[rawMapID] or legacyHiddenRemaining[mapID]) or nil;
            if remainingValue ~= nil then
                bucket.hiddenRemaining[mapID] = remainingValue;
            end
            movedCount = movedCount + 1;
        end
    end

    uiDB.hiddenMaps = nil;
    uiDB.hiddenRemaining = nil;
    return movedCount;
end

function Data:TryMigrateSchema(oldVersion)
    local db = AppContext and AppContext.EnsurePersistentState and AppContext:EnsurePersistentState() or nil;
    local uiDB = AppContext and AppContext.EnsureUIState and AppContext:EnsureUIState() or nil;
    if type(db) ~= "table" or type(uiDB) ~= "table" then
        return false;
    end

    local migratedCount = 0;
    if type(db.expansionData) ~= "table" then
        db.expansionData = {};
    end

    local movedMapDataCount = migrateLegacyMapData(db, db.mapData);
    if movedMapDataCount > 0 then
        migratedCount = migratedCount + movedMapDataCount;
    end
    db.mapData = nil;

    for expansionID, bucket in pairs(db.expansionData) do
        if type(bucket) ~= "table" then
            db.expansionData[expansionID] = { mapData = {} };
            migratedCount = migratedCount + 1;
        elseif type(bucket.mapData) ~= "table" then
            bucket.mapData = {};
            migratedCount = migratedCount + 1;
        end
    end

    local movedHiddenStateCount = migrateLegacyHiddenState(uiDB);
    if movedHiddenStateCount > 0 then
        migratedCount = migratedCount + movedHiddenStateCount;
    end

    if type(uiDB.expansionUIData) ~= "table" then
        uiDB.expansionUIData = {};
    end
    if uiDB.phaseCache ~= nil and type(uiDB.phaseCache) ~= "table" then
        uiDB.phaseCache = {};
        migratedCount = migratedCount + 1;
    end
    if uiDB.observedPhaseHistory ~= nil and type(uiDB.observedPhaseHistory) ~= "table" then
        uiDB.observedPhaseHistory = {};
        migratedCount = migratedCount + 1;
    end

    db.schemaVersion = self.SCHEMA_VERSION;
    if Logger and Logger.Info then
        Logger:Info("Data", "迁移", string.format(
            "数据结构迁移完成：%s -> %d（迁移项=%d）",
            tostring(oldVersion or "unknown"),
            self.SCHEMA_VERSION,
            migratedCount
        ));
    end
    return true;
end

function Data:ResetDatabaseIfNeeded(forceReset)
    ensureDB(false);
    local currentVersion = tonumber(CRATETRACKERZK_DB.schemaVersion) or 0;
    local shouldUpgrade = currentVersion ~= self.SCHEMA_VERSION;
    if forceReset == true then
        CRATETRACKERZK_DB = {
            schemaVersion = self.SCHEMA_VERSION,
            expansionData = {},
        };
        if type(CRATETRACKERZK_UI_DB) == "table" then
            CRATETRACKERZK_UI_DB.expansionUIData = {};
            CRATETRACKERZK_UI_DB.hiddenMaps = nil;
            CRATETRACKERZK_UI_DB.hiddenRemaining = nil;
            CRATETRACKERZK_UI_DB.phaseCache = nil;
            CRATETRACKERZK_UI_DB.observedPhaseHistory = nil;
        end
        if Logger and Logger.Info then
            Logger:Info("Data", "初始化", string.format("执行强制重置（schema=%d）", self.SCHEMA_VERSION));
        end
    elseif shouldUpgrade then
        local migrated = false;
        if currentVersion <= self.SCHEMA_VERSION and self.TryMigrateSchema then
            migrated = self:TryMigrateSchema(currentVersion) == true;
        end
        if not migrated then
            CRATETRACKERZK_DB = {
                schemaVersion = self.SCHEMA_VERSION,
                expansionData = {},
            };
            if type(CRATETRACKERZK_UI_DB) == "table" then
                CRATETRACKERZK_UI_DB.expansionUIData = {};
                CRATETRACKERZK_UI_DB.hiddenMaps = nil;
                CRATETRACKERZK_UI_DB.hiddenRemaining = nil;
                CRATETRACKERZK_UI_DB.phaseCache = nil;
                CRATETRACKERZK_UI_DB.observedPhaseHistory = nil;
            end
            if Logger and Logger.Warn then
                Logger:Warn("Data", "初始化", string.format(
                    "迁移失败，已回退为重置策略（from=%s,to=%d）",
                    tostring(currentVersion),
                    self.SCHEMA_VERSION
                ));
            end
        end
    end
    ensureDB(true);
    CRATETRACKERZK_DB.schemaVersion = self.SCHEMA_VERSION;
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

function Data:Initialize()
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

    for _, cfg in ipairs(mapConfig) do
        if cfg and cfg.id and cfg.mapID and cfg.expansionID and (cfg.enabled ~= false) then
            ensureExpansionUIData(cfg.expansionID);

            local savedData = PersistentMapStateStore and PersistentMapStateStore.GetSavedRecord
                and PersistentMapStateStore:GetSavedRecord(cfg.expansionID, cfg.mapID)
                or nil;
            if type(savedData) ~= "table" then
                savedData = {};
            end

            local createTime = sanitizeTimestamp(savedData.createTime) or Utils:GetCurrentTimestamp();
            local interval = cfg.interval or defaults.interval or self.DEFAULT_REFRESH_INTERVAL;

            local mapData = {
                id = cfg.id,
                expansionID = cfg.expansionID,
                mapID = cfg.mapID,
                interval = interval,
                order = cfg.order or cfg.priority or loadedCount + 1,
                createTime = createTime,
            };

            self.maps[#self.maps + 1] = mapData;
            self.mapsById[mapData.id] = mapData;
            self.mapsByMapID[mapData.mapID] = self.mapsByMapID[mapData.mapID] or {};
            self.mapsByMapID[mapData.mapID][mapData.expansionID] = mapData;
            loadedCount = loadedCount + 1;
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

    for index, mapData in ipairs(self.maps) do
        if type(mapData) == "table" then
            mapData.listIndex = index;
        end
    end

end
function Data:GetAllMaps()
    return self.maps;
end

function Data:GetMap(mapId)
    return getStableMap(mapId);
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
