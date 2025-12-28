-- Data.lua
-- 管理地图数据、刷新时间计算和持久化

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Data = BuildEnv('Data');

Data.DEFAULT_REFRESH_INTERVAL = (Data.MAP_CONFIG and Data.MAP_CONFIG.defaults and Data.MAP_CONFIG.defaults.interval) or 1100;
Data.maps = {};

local function ensureDB()
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {};
    end
    if type(CRATETRACKERZK_DB.mapData) ~= "table" then
        CRATETRACKERZK_DB.mapData = {};
    end
end

local function sanitizeTimestamp(ts)
    if not ts or type(ts) ~= "number" then return nil end
    local maxFuture = time() + 86400 * 365;
    if ts < 0 or ts > maxFuture then return nil end
    return ts;
end

function Data:Initialize()
    Logger:Debug("Data", "初始化", "开始初始化数据模块");
    ensureDB();
    self.maps = {};

    local mapConfig = self.MAP_CONFIG and self.MAP_CONFIG.current_maps or {};
    if not mapConfig or #mapConfig == 0 then
        Logger:Error("Data", "错误", "MAP_CONFIG.current_maps 为空或 nil");
        return;
    end

    local defaults = (self.MAP_CONFIG and self.MAP_CONFIG.defaults) or {};
    local nextId = 1;
    local loadedCount = 0;
    local skippedCount = 0;

    for _, cfg in ipairs(mapConfig) do
        if cfg and cfg.mapID and (cfg.enabled ~= false) then
            local mapID = cfg.mapID;
            local savedData = CRATETRACKERZK_DB.mapData[mapID];
            if type(savedData) ~= "table" then savedData = {}; end

            local lastRefresh = sanitizeTimestamp(savedData.lastRefresh);
            local createTime = sanitizeTimestamp(savedData.createTime) or time();
            local interval = cfg.interval or defaults.interval or self.DEFAULT_REFRESH_INTERVAL;

            local mapData = {
                id = nextId,
                mapID = mapID,
                interval = interval,
                instance = savedData.instance,
                lastInstance = savedData.lastInstance,
                lastRefreshInstance = savedData.lastRefreshInstance,
                lastRefresh = lastRefresh,
                nextRefresh = nil,
                createTime = createTime,
            };

            if mapData.lastRefresh then
                self:UpdateNextRefresh(nextId, mapData);
                Logger:Debug("Data", "加载", string.format("地图 ID=%d，已加载时间记录：%s，下次刷新：%s", 
                    mapID, 
                    self:FormatDateTime(mapData.lastRefresh),
                    mapData.nextRefresh and self:FormatDateTime(mapData.nextRefresh) or "无"));
            else
                Logger:Debug("Data", "加载", string.format("地图 ID=%d，无时间记录", mapID));
            end

            if mapData.instance and not mapData.lastInstance then
                mapData.lastInstance = mapData.instance;
                CRATETRACKERZK_DB.mapData[mapID] = CRATETRACKERZK_DB.mapData[mapID] or {};
                CRATETRACKERZK_DB.mapData[mapID].lastInstance = mapData.lastInstance;
                Logger:Debug("Data", "加载", string.format("地图 ID=%d，位面=%s", mapID, mapData.instance));
            end

            table.insert(self.maps, mapData);
            nextId = nextId + 1;
            loadedCount = loadedCount + 1;
        else
            skippedCount = skippedCount + 1;
        end
    end
    
    -- 调试模式下显示初始化信息
    Logger:DebugLimited("data:init_complete", "Data", "初始化", string.format("数据模块初始化完成：已加载 %d 个地图，跳过 %d 个", loadedCount, skippedCount));
end

function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    if not mapData or not mapData.mapID then 
        Logger:DebugLimited("data_save:invalid", "Data", "保存", "保存失败：无效的地图ID " .. tostring(mapId));
        return 
    end

    ensureDB();

    CRATETRACKERZK_DB.mapData[mapData.mapID] = {
        instance = mapData.instance,
        lastInstance = mapData.lastInstance,
        lastRefreshInstance = mapData.lastRefreshInstance,
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime or time(),
    };
    
    Logger:DebugLimited("data_save:map_" .. mapData.mapID, "Data", "保存", 
        string.format("已保存地图数据：地图ID=%d，上次刷新=%s", 
            mapData.mapID,
            mapData.lastRefresh and self:FormatDateTime(mapData.lastRefresh) or "无"));
end

function Data:UpdateMap(mapId, mapData)
    if self.maps[mapId] then
        local allowedFields = {
            instance = true,
            lastInstance = true,
            lastRefreshInstance = true,
            lastRefresh = true,
            nextRefresh = true,
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
    if not lastRefresh or not interval or interval <= 0 then
        return nil;
    end
    
    currentTime = currentTime or time();
    
    local diffTime = currentTime - lastRefresh;
    local n = math.ceil(diffTime / interval);
    
    if n <= 0 then
        local forwardCount = math.floor((lastRefresh - currentTime) / interval);
        local candidateRefresh = lastRefresh - forwardCount * interval;
        
        if candidateRefresh <= currentTime then
            return candidateRefresh + interval;
        else
            local prevRefresh = candidateRefresh - interval;
            if prevRefresh > currentTime then
                while prevRefresh > currentTime do
                    candidateRefresh = prevRefresh;
                    prevRefresh = candidateRefresh - interval;
                end
            end
            return candidateRefresh;
        end
    else
        if n == 0 then
            n = 1;
        end
        return lastRefresh + n * interval;
    end
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
                mapData.nextRefresh and self:FormatDateTime(mapData.nextRefresh) or "无"));
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
    mapData.lastRefreshInstance = mapData.instance;
    
    self:UpdateNextRefresh(mapId);
    self:SaveMapData(mapId);
    
    Logger:Debug("Data", "更新", string.format("已更新刷新时间：地图=%s，旧时间=%s，新时间=%s，下次刷新=%s",
        self:GetMapDisplayName(mapData),
        oldLastRefresh and self:FormatDateTime(oldLastRefresh) or "无",
        self:FormatDateTime(timestamp),
        mapData.nextRefresh and self:FormatDateTime(mapData.nextRefresh) or "无"));
    
    return true;
end

function Data:GetAllMaps()
    return self.maps;
end

function Data:GetMap(mapId)
    return self.maps[mapId];
end

function Data:CalculateRemainingTime(nextRefresh)
    if not nextRefresh then return nil end;
    local remaining = nextRefresh - time();
    -- 当倒计时结束后，返回 nil 而不是 0，这样 UI 会显示 "--:--"
    return remaining > 0 and remaining or nil;
end

function Data:CheckAndUpdateRefreshTimes()
    if not self.maps then return end
    
    for mapId, mapData in ipairs(self.maps) do
        if mapData and mapData.lastRefresh then
            self:UpdateNextRefresh(mapId, mapData);
        end
    end
end

function Data:FormatTime(seconds, showOnlyMinutes)
    local L = CrateTrackerZK.L;
    if not seconds then return L["NoRecord"] end;
    
    local hours = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    local secs = seconds % 60;
    
    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"];
        return string.format(formatStr, minutes + hours * 60, secs);
    else
        return string.format("%02d:%02d:%02d", hours, minutes, secs);
    end
end

function Data:FormatDateTime(timestamp)
    local L = CrateTrackerZK.L;
    if not timestamp then return L["NoRecord"] end;
    return date("%H:%M:%S", timestamp);
end

function Data:ClearAllData()
    if not self.maps then return false end
    
    for i, mapData in ipairs(self.maps) do
        if mapData then
            mapData.lastRefresh = nil;
            mapData.nextRefresh = nil;
            mapData.instance = nil;
            mapData.lastInstance = nil;
            mapData.lastRefreshInstance = nil;
            
            if CRATETRACKERZK_DB.mapData and mapData.mapID then
                CRATETRACKERZK_DB.mapData[mapData.mapID] = nil;
            end
        end
    end
    
    -- 清除检测状态
    if DetectionState then
        -- 清除所有地图的处理状态
        for i, mapData in ipairs(self.maps) do
            if mapData then
                DetectionState:ClearProcessed(mapData.id);
            end
        end
    end
    if MapTracker then
        MapTracker.mapLeftTime = {};
        MapTracker.lastDetectedMapId = nil;
        MapTracker.lastDetectedGameMapID = nil;
    end
    if NotificationCooldown then
        NotificationCooldown.lastNotificationTime = {};
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
