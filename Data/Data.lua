-- CrateTrackerZK - 数据管理模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local Data = BuildEnv('Data')

Data.maps = {};
Data.manualInputLock = {};

function Data:Initialize()
    if not CRATETRACKERZK_DB then
        CRATETRACKERZK_DB = {
            version = 1,
            mapData = {},
        }
    end
    
    if CRATETRACKER_CHARACTER_DB and CRATETRACKER_CHARACTER_DB.mapData and next(CRATETRACKER_CHARACTER_DB.mapData) then
        if not CRATETRACKERZK_DB.mapData or not next(CRATETRACKERZK_DB.mapData) then
            CRATETRACKERZK_DB.mapData = {};
            for mapName, mapData in pairs(CRATETRACKER_CHARACTER_DB.mapData) do
                CRATETRACKERZK_DB.mapData[mapName] = mapData;
            end
        end
    end
    
    CRATETRACKERZK_DB.mapData = CRATETRACKERZK_DB.mapData or {};
    
    self.maps = {};
    for i, defaultMap in ipairs(self.DEFAULT_MAPS) do
        local mapName = defaultMap.name;
        local mapNameEn = defaultMap.nameEn or mapName;
        local savedData = CRATETRACKERZK_DB.mapData[mapName] or {};
        
        local mapData = {
            id = i,
            mapName = mapName,
            mapNameEn = mapNameEn,
            interval = defaultMap.interval,
            instance = savedData.instance,
            lastInstance = savedData.lastInstance,
            lastRefreshInstance = savedData.lastRefreshInstance,
            lastRefresh = savedData.lastRefresh,
            nextRefresh = nil,
            createTime = savedData.createTime or time(),
        }
        
        if mapData.lastRefresh then
            self:UpdateNextRefresh(i, mapData);
        end
        
        if mapData.instance and not mapData.lastInstance then
            mapData.lastInstance = mapData.instance;
            -- 确保 CRATETRACKERZK_DB.mapData[mapName] 存在后再访问
            if not CRATETRACKERZK_DB.mapData[mapName] then
                CRATETRACKERZK_DB.mapData[mapName] = {};
            end
            CRATETRACKERZK_DB.mapData[mapName].lastInstance = mapData.lastInstance;
        end
        
        table.insert(self.maps, mapData);
    end
end

function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    if not mapData then return end
    
    CRATETRACKERZK_DB.mapData = CRATETRACKERZK_DB.mapData or {};
    CRATETRACKERZK_DB.mapData[mapData.mapName] = {
        instance = mapData.instance,
        lastInstance = mapData.lastInstance,
        lastRefreshInstance = mapData.lastRefreshInstance,
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime,
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

-- 计算离当前时间最近的下一次刷新时间
-- 无论lastRefresh是过去时间还是未来时间，都找到离currentTime最近且大于currentTime的刷新点
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
    if not mapData or not mapData.lastRefresh then 
        mapData.nextRefresh = nil;
        return;
    end;
    
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
    for mapId, mapData in ipairs(self.maps) do
        if mapData.lastRefresh then
            self:UpdateNextRefresh(mapId, mapData);
        end
    end
end

function Data:FormatTime(seconds, showOnlyMinutes)
    local L = CrateTrackerZK.L;
    if not seconds then return L["NoRecord"] or "No Record" end;
    
    local hours = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    local secs = seconds % 60;
    
    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"] or "%dm%02ds";
        return string.format(formatStr, minutes + hours * 60, secs);
    else
        return string.format("%02d:%02d:%02d", hours, minutes, secs);
    end
end

function Data:FormatDateTime(timestamp)
    local L = CrateTrackerZK.L;
    if not timestamp then return L["NoRecord"] or "No Record" end;
    return date("%H:%M:%S", timestamp);
end

function Data:ClearAllData()
    if not self.maps then return false end
    
    for i, mapData in ipairs(self.maps) do
        mapData.lastRefresh = nil;
        mapData.nextRefresh = nil;
        mapData.instance = nil;
        mapData.lastInstance = nil;
        mapData.lastRefreshInstance = nil;
        
        if CRATETRACKERZK_DB.mapData then
            CRATETRACKERZK_DB.mapData[mapData.mapName] = nil;
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
    local locale = GetLocale();
    if locale == "zhCN" or locale == "zhTW" then
        return mapData.mapName or "";
    else
        return mapData.mapNameEn or mapData.mapName or "";
    end
end

function Data:IsMapNameMatch(mapData, mapName)
    if not mapData or not mapName then return false end;
    
    local cleanName = string.lower(string.gsub(mapName, "[%p ]", ""));
    local cleanMapName = string.lower(string.gsub(mapData.mapName or "", "[%p ]", ""));
    local cleanMapNameEn = string.lower(string.gsub(mapData.mapNameEn or "", "[%p ]", ""));
    
    return cleanName == cleanMapName or cleanName == cleanMapNameEn;
end

function Data:IsCapitalCity(mapName)
    if not mapName then return false end;
    
    local cleanName = string.lower(string.gsub(mapName, "[%p ]", ""));
    local capitalNames = self.CAPITAL_CITY_NAMES or {};
    local cleanCapitalZh = string.lower(string.gsub(capitalNames.zhCN or "", "[%p ]", ""));
    local cleanCapitalEn = string.lower(string.gsub(capitalNames.enUS or "", "[%p ]", ""));
    
    return cleanName == cleanCapitalZh or cleanName == cleanCapitalEn;
end
