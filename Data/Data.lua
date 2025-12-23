-- CrateTrackerZK - 数据
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local Data = BuildEnv('Data');

-- Defaults
Data.DEFAULT_REFRESH_INTERVAL = (Data.MAP_CONFIG and Data.MAP_CONFIG.defaults and Data.MAP_CONFIG.defaults.interval) or 1100;
Data.maps = {};
Data.manualInputLock = {};

local function ensureDB()
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {};
    end
    if type(CRATETRACKERZK_DB.mapData) ~= "table" then
        CRATETRACKERZK_DB.mapData = {};
    end
end

local function sanitizeTimestamp(ts, allowFuture)
    if not ts or type(ts) ~= "number" then return nil end
    local maxFuture = allowFuture and (time() + 86400 * 365) or time() + 86400 * 365;
    if ts < 0 or ts > maxFuture then return nil end
    return ts;
end

function Data:Initialize()
    ensureDB();
    self.maps = {};

    local mapConfig = self.MAP_CONFIG and self.MAP_CONFIG.current_maps or {};
    if not mapConfig or #mapConfig == 0 then
        if Utils then Utils.PrintError("Data:Initialize() - MAP_CONFIG.current_maps is empty or nil"); end
        return;
    end

    local defaults = (self.MAP_CONFIG and self.MAP_CONFIG.defaults) or {};
    local nextId = 1;

    for _, cfg in ipairs(mapConfig) do
        if cfg and cfg.code and (cfg.enabled ~= false) then
            local mapCode = cfg.code;
            local savedData = CRATETRACKERZK_DB.mapData[mapCode];
            if type(savedData) ~= "table" then savedData = {}; end

            local lastRefresh = sanitizeTimestamp(savedData.lastRefresh, true);
            local createTime = sanitizeTimestamp(savedData.createTime, true) or time();
            local interval = cfg.interval or defaults.interval or self.DEFAULT_REFRESH_INTERVAL;

            local mapData = {
                id = nextId,
                code = mapCode,
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
            end

            if mapData.instance and not mapData.lastInstance then
                mapData.lastInstance = mapData.instance;
                CRATETRACKERZK_DB.mapData[mapCode] = CRATETRACKERZK_DB.mapData[mapCode] or {};
                CRATETRACKERZK_DB.mapData[mapCode].lastInstance = mapData.lastInstance;
            end

            table.insert(self.maps, mapData);
            nextId = nextId + 1;
        end
    end
end

function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    if not mapData or not mapData.code then return end

    ensureDB();

    CRATETRACKERZK_DB.mapData[mapData.code] = {
        instance = mapData.instance,
        lastInstance = mapData.lastInstance,
        lastRefreshInstance = mapData.lastRefreshInstance,
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime or time(),
    };
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
        return;
    end
    
    local interval = mapData.interval or 1100;
    local currentTime = time();
    local lastRefresh = mapData.lastRefresh;
    
    mapData.nextRefresh = CalculateNextRefreshTime(lastRefresh, interval, currentTime);
end

function Data:SetLastRefresh(mapId, timestamp)
    local mapData = self.maps[mapId];
    if not mapData then return false end
    
    timestamp = timestamp or time();
    mapData.lastRefresh = timestamp;
    mapData.lastRefreshInstance = mapData.instance;
    
    self:UpdateNextRefresh(mapId);
    self:SaveMapData(mapId);
    
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
    return remaining > 0 and remaining or 0;
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
            
            if CRATETRACKERZK_DB.mapData and mapData.code then
                CRATETRACKERZK_DB.mapData[mapData.code] = nil;  -- 使用代号作为键
            end
        end
    end
    
    if TimerManager then
        TimerManager.mapIconDetected = {};
        TimerManager.mapIconFirstDetectedTime = {};
        TimerManager.lastUpdateTime = {};
    end
    
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable();
    end
    
    return true;
end

function Data:GetMapDisplayName(mapData)
    if not mapData then return "" end;
    
    if Localization and mapData.code then
        return Localization:GetMapName(mapData.code);
    end
    
    return mapData.code or "";
end

function Data:IsMapNameMatch(mapData, mapName)
    if not mapData or not mapName then return false end;
    
    if Localization and mapData.code then
        return Localization:IsMapNameMatch(mapData, mapName);
    end
    
    return false;
end
