-- Data.lua - 数据管理模块

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Data = BuildEnv('Data');
local ExpansionConfig = BuildEnv('ExpansionConfig');

-- 引用UnifiedDataManager模块
local UnifiedDataManager = BuildEnv('UnifiedDataManager');

Data.DEFAULT_REFRESH_INTERVAL = (Data.MAP_CONFIG and Data.MAP_CONFIG.defaults and Data.MAP_CONFIG.defaults.interval) or 1100;
Data.maps = {};
Data.SCHEMA_VERSION = 4;

local function ensureDB()
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {};
    end
    -- 全新版本仅使用按版本分桶结构
    CRATETRACKERZK_DB.mapData = nil;
    if type(CRATETRACKERZK_DB.expansionData) ~= "table" then
        CRATETRACKERZK_DB.expansionData = {};
    end
end

local function getCurrentExpansionID()
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        return ExpansionConfig:GetCurrentExpansionID();
    end
    return "default";
end

local function ensureExpansionMapData(expansionID)
    ensureDB();
    expansionID = expansionID or getCurrentExpansionID() or "default";

    if type(CRATETRACKERZK_DB.expansionData[expansionID]) ~= "table" then
        CRATETRACKERZK_DB.expansionData[expansionID] = {};
    end
    if type(CRATETRACKERZK_DB.expansionData[expansionID].mapData) ~= "table" then
        CRATETRACKERZK_DB.expansionData[expansionID].mapData = {};
    end

    return CRATETRACKERZK_DB.expansionData[expansionID].mapData, expansionID;
end

local function ensureUIRoot()
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    -- 全新版本不保留旧全局字段
    CRATETRACKERZK_UI_DB.hiddenMaps = nil;
    CRATETRACKERZK_UI_DB.hiddenRemaining = nil;
    CRATETRACKERZK_UI_DB.phaseCache = nil;
    if type(CRATETRACKERZK_UI_DB.expansionUIData) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData = {};
    end
    return CRATETRACKERZK_UI_DB.expansionUIData;
end

local function ensureExpansionUIData(expansionID)
    expansionID = expansionID or getCurrentExpansionID() or "default";
    local expansionUIData = ensureUIRoot();

    if type(expansionUIData[expansionID]) ~= "table" then
        expansionUIData[expansionID] = {};
    end
    local bucket = expansionUIData[expansionID];
    if type(bucket.hiddenMaps) ~= "table" then
        bucket.hiddenMaps = {};
    end
    if type(bucket.hiddenRemaining) ~= "table" then
        bucket.hiddenRemaining = {};
    end
    if type(bucket.phaseCache) ~= "table" then
        bucket.phaseCache = {};
    end

    return bucket, expansionID;
end

local function sanitizeTimestamp(ts)
    if not ts or type(ts) ~= "number" then return nil end
    local maxFuture = time() + 86400 * 365;
    if ts < 0 or ts > maxFuture then return nil end
    return ts;
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
            -- 全新数据结构初始化时，仅重置与空投数据相关的版本分桶
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
    ensureExpansionMapData();
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

function Data:GetPhaseCache(expansionID)
    local bucket = ensureExpansionUIData(expansionID);
    return bucket.phaseCache;
end

function Data:SwitchExpansion(expansionID)
    if not ExpansionConfig or not ExpansionConfig.SetCurrentExpansionID then
        return false;
    end
    if not ExpansionConfig:SetCurrentExpansionID(expansionID) then
        return false;
    end
    ensureExpansionMapData(expansionID);
    ensureExpansionUIData(expansionID);
    if self.ReloadMapConfigForExpansion then
        self:ReloadMapConfigForExpansion();
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
    local mapStore, activeExpansionID = ensureExpansionMapData();
    ensureExpansionUIData(activeExpansionID);
    self.maps = {};

    local mapConfig = self.MAP_CONFIG and self.MAP_CONFIG.current_maps or {};
    if not mapConfig or #mapConfig == 0 then
        Logger:Warn("Data", "初始化", "当前资料片配置没有地图，数据模块将以空列表运行");
        return;
    end

    local defaults = (self.MAP_CONFIG and self.MAP_CONFIG.defaults) or {};
    local nextId = 1;
    local loadedCount = 0;
    local skippedCount = 0;
    local newInstallCount = 0;

    for _, cfg in ipairs(mapConfig) do
        if cfg and cfg.mapID and (cfg.enabled ~= false) then
            local mapID = cfg.mapID;
            local savedData = mapStore[mapID];
            local isNewInstall = false;
            
            if type(savedData) ~= "table" then 
                savedData = {};
                isNewInstall = true;
                newInstallCount = newInstallCount + 1;
            end

            local lastRefresh = sanitizeTimestamp(savedData.lastRefresh);
            local createTime = sanitizeTimestamp(savedData.createTime) or time();
            local interval = cfg.interval or defaults.interval or self.DEFAULT_REFRESH_INTERVAL;
            local currentAirdropObjectGUID = type(savedData.currentAirdropObjectGUID) == "string" and savedData.currentAirdropObjectGUID or nil;
            local lastRefreshPhase = type(savedData.lastRefreshPhase) == "string" and savedData.lastRefreshPhase or nil;
            
            local mapData = {
                id = nextId,
                mapID = mapID,
                interval = interval,
                lastRefresh = lastRefresh,
                nextRefresh = nil,
                createTime = createTime,
                currentAirdropObjectGUID = currentAirdropObjectGUID,
                currentAirdropTimestamp = sanitizeTimestamp(savedData.currentAirdropTimestamp),
                lastRefreshPhase = lastRefreshPhase,  -- 从空投的 objectGUID 提取的位面ID
                currentPhaseID = nil,  -- Phase 模块实时检测到的位面ID（不存储，仅用于UI显示）
            };
            

            if mapData.lastRefresh then
                self:UpdateNextRefresh(nextId, mapData);
                Logger:Debug("Data", "加载", string.format("地图 ID=%d，已加载时间记录：%s，下次刷新：%s", 
                    mapID, 
                    UnifiedDataManager:FormatDateTime(mapData.lastRefresh),
                    mapData.nextRefresh and UnifiedDataManager:FormatDateTime(mapData.nextRefresh) or "无"));
            else
                Logger:Debug("Data", "加载", string.format("地图 ID=%d，无时间记录（全新安装）", mapID));
            end


            table.insert(self.maps, mapData);
            nextId = nextId + 1;
            loadedCount = loadedCount + 1;
        else
            skippedCount = skippedCount + 1;
        end
    end
    
    
    Logger:DebugLimited("data:init_complete", "Data", "初始化", string.format("数据模块初始化完成：资料片=%s，已加载 %d 个地图，跳过 %d 个", tostring(activeExpansionID), loadedCount, skippedCount));
end

function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    if not mapData or not mapData.mapID then 
        Logger:DebugLimited("data_save:invalid", "Data", "保存", "保存失败：无效的地图ID " .. tostring(mapId));
        return 
    end

    ensureDB();
    local mapStore, activeExpansionID = ensureExpansionMapData();

    local savedData = {
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime or time(),
        currentAirdropObjectGUID = mapData.currentAirdropObjectGUID,
        currentAirdropTimestamp = mapData.currentAirdropTimestamp,
        lastRefreshPhase = mapData.lastRefreshPhase,  -- 从空投的 objectGUID 提取的位面ID
    };

    mapStore[mapData.mapID] = savedData;
    
    Logger:DebugLimited("data_save:map_" .. mapData.mapID, "Data", "保存", 
        string.format("已保存地图数据：资料片=%s，地图ID=%d（配置ID=%d），上次刷新=%s，objectGUID=%s", 
            tostring(activeExpansionID), mapData.mapID, mapId,
            mapData.lastRefresh and UnifiedDataManager:FormatDateTime(mapData.lastRefresh) or "无",
            mapData.currentAirdropObjectGUID or "nil"));
    
    -- 验证保存的数据是否正确
    if Logger and Logger.Debug then
        local verifyData = mapStore[mapData.mapID];
        if verifyData then
            if verifyData.currentAirdropObjectGUID ~= mapData.currentAirdropObjectGUID then
                Logger:Error("Data", "错误", string.format("数据保存验证失败：地图ID=%d，期望objectGUID=%s，实际objectGUID=%s", 
                    mapData.mapID, mapData.currentAirdropObjectGUID or "nil", verifyData.currentAirdropObjectGUID or "nil"));
            end
        end
    end
end

function Data:UpdateMap(mapId, mapData)
    if self.maps[mapId] then
        local allowedFields = {
            lastRefresh = true,
            nextRefresh = true,
            currentAirdropObjectGUID = true,
            currentAirdropTimestamp = true,
        };
        
        for k, v in pairs(mapData) do
            if allowedFields[k] then
                self.maps[mapId][k] = v;
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
    mapData = mapData or self.maps[mapId];
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
    local mapData = self.maps[mapId];
    if not mapData then 
        Logger:Debug("Data", "更新", "设置刷新时间失败：无效的地图ID " .. tostring(mapId));
        return false 
    end
    
    timestamp = timestamp or time();
    local oldLastRefresh = mapData.lastRefresh;
    mapData.lastRefresh = timestamp;
    
    self:UpdateNextRefresh(mapId);
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
    return self.maps[mapId];
end

function Data:CheckAndUpdateRefreshTimes()
    if not self.maps then return end
    
    for mapId, mapData in ipairs(self.maps) do
        if mapData and mapData.lastRefresh then
            self:UpdateNextRefresh(mapId, mapData);
        end
    end
end

function Data:ClearAllData()
    if not self.maps then return false end
    
    ensureDB();
    if CRATETRACKERZK_DB.expansionData then
        for _, expansionBucket in pairs(CRATETRACKERZK_DB.expansionData) do
            if type(expansionBucket) == "table" then
                expansionBucket.mapData = {};
            end
        end
    end

    for i, mapData in ipairs(self.maps) do
        if mapData then
            mapData.lastRefresh = nil;
            mapData.nextRefresh = nil;
            mapData.currentAirdropObjectGUID = nil;
            mapData.currentAirdropTimestamp = nil;
        end
    end
    
    if MapTracker then
        MapTracker.lastDetectedMapId = nil;
        MapTracker.lastDetectedGameMapID = nil;
    end
    
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable();
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

function Data:GetMapByMapID(gameMapID)
    if not gameMapID then return nil end;
    
    for _, mapData in ipairs(self.maps) do
        if mapData.mapID == gameMapID then
            return mapData;
        end
    end
    
    return nil;
end
