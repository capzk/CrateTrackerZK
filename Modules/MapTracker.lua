-- MapTracker.lua - 管理地图匹配和变化，支持父地图匹配

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local MapTracker = BuildEnv('MapTracker');
local ExpansionConfig = BuildEnv("ExpansionConfig");

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

local function DT(key)
    return Logger:GetDebugText(key);
end

local function IsDebugEnabled()
    return Logger and Logger.debugEnabled == true;
end

local function EnsureMapLookup(self, validMaps)
    local mapCount = #validMaps;
    if self.mapLookupMapsRef == validMaps and self.mapLookupCount == mapCount then
        return;
    end

    self.mapLookup = {};
    for _, mapData in ipairs(validMaps) do
        if mapData and mapData.mapID then
            self.mapLookup[mapData.mapID] = mapData;
        end
    end

    self.mapLookupMapsRef = validMaps;
    self.mapLookupCount = mapCount;
    self.mapLookupVersion = (self.mapLookupVersion or 0) + 1;
    self.resolvedMapCache = {};
end

local function GetMapInfoCached(self, mapID)
    if not mapID then
        return nil;
    end
    local cached = self.mapInfoCache and self.mapInfoCache[mapID];
    if cached then
        return cached;
    end
    local mapInfo = C_Map.GetMapInfo(mapID);
    if mapInfo then
        self.mapInfoCache[mapID] = mapInfo;
    end
    return mapInfo;
end

function MapTracker:Initialize()
    self.lastDetectedMapId = nil;
    self.lastDetectedGameMapID = nil;
    self.lastMatchedMapID = nil;
    self.lastUnmatchedMapID = nil;
    self.mapLookup = {};
    self.mapLookupMapsRef = nil;
    self.mapLookupCount = 0;
    self.mapLookupVersion = 0;
    self.resolvedMapCache = {};
    self.mapInfoCache = {};
end

function MapTracker:GetTargetMapData(currentMapID)
    if not currentMapID then
        return nil;
    end
    
    if not C_Map or not C_Map.GetMapInfo then
        Logger:DebugLimited("map_check:api_unavailable", "MapTracker", "匹配", "C_Map.GetMapInfo API 不可用");
        return nil;
    end

    if ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(currentMapID) then
        if IsDebugEnabled() then
            Logger:DebugLimited("map_check:main_city_" .. tostring(currentMapID), "MapTracker", "匹配", 
                string.format("主城地图已排除，跳过匹配：地图ID=%d", currentMapID));
        end
        return nil;
    end
    
    local validMaps = Data:GetAllMaps();
    if not validMaps or #validMaps == 0 then
        Logger:DebugLimited("map_check:empty_list", "MapTracker", "匹配", DT("DebugMapListEmpty"));
        return nil;
    end

    EnsureMapLookup(self, validMaps);

    local cachedResolution = self.resolvedMapCache[currentMapID];
    if cachedResolution and cachedResolution.version == self.mapLookupVersion then
        if cachedResolution.target ~= false then
            return cachedResolution.target;
        end
        return nil;
    end

    local mapInfo = GetMapInfoCached(self, currentMapID);
    if not mapInfo then
        Logger:DebugLimited("map_check:no_map_info", "MapTracker", "匹配", DT("DebugCannotGetMapName2"));
        self.resolvedMapCache[currentMapID] = {
            version = self.mapLookupVersion,
            target = false
        };
        return nil;
    end

    local targetMapData = self.mapLookup[currentMapID];
    local isParentMatch = false;
    if not targetMapData and mapInfo.parentMapID then
        targetMapData = self.mapLookup[mapInfo.parentMapID];
        isParentMatch = targetMapData ~= nil;
    end

    self.resolvedMapCache[currentMapID] = {
        version = self.mapLookupVersion,
        target = targetMapData or false
    };

    if targetMapData and (not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID) then
        if IsDebugEnabled() then
            if isParentMatch then
                local currentMapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                local parentMapDisplayName = Localization and Localization:GetMapName(mapInfo.parentMapID) or tostring(mapInfo.parentMapID);
                Logger:DebugLimited("map_check:parent_match_" .. tostring(currentMapID), "MapTracker", "地图", 
                    string.format("父地图匹配成功：当前地图=%s（ID=%d），父地图=%s（ID=%d，配置ID=%d）", 
                    currentMapDisplayName, currentMapID, parentMapDisplayName, mapInfo.parentMapID, targetMapData.id));
            else
                local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                Logger:DebugLimited("map_check:match_success_" .. tostring(currentMapID), "MapTracker", "地图", 
                    string.format("地图匹配成功：%s（地图ID=%d，配置ID=%d）", 
                    mapDisplayName, currentMapID, targetMapData.id));
            end
        end
        self.lastMatchedMapID = currentMapID;
    end

    if not targetMapData then
        if IsDebugEnabled() then
            local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
            local parentMapDisplayName = (mapInfo.parentMapID and Localization and Localization:GetMapName(mapInfo.parentMapID)) or (mapInfo.parentMapID and tostring(mapInfo.parentMapID)) or DT("DebugNoRecord");
            Logger:DebugLimited("map_check:not_in_list_" .. tostring(currentMapID), "MapTracker", "匹配", 
                string.format(DT("DebugMapNotInList"), mapDisplayName, parentMapDisplayName, currentMapID));
        end
    end
    
    return targetMapData;
end

function MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
    local changeInfo = {
        gameMapChanged = false,
        configMapChanged = false,
        configIdSame = false,
        oldMapId = self.lastDetectedMapId,
        oldGameMapID = self.lastDetectedGameMapID
    };
    
    if not targetMapData or not currentMapID then
        return changeInfo;
    end
    
    changeInfo.gameMapChanged = (self.lastDetectedGameMapID and self.lastDetectedGameMapID ~= currentMapID);
    changeInfo.configMapChanged = (self.lastDetectedMapId and self.lastDetectedMapId ~= targetMapData.id);
    changeInfo.configIdSame = (self.lastDetectedMapId and self.lastDetectedMapId == targetMapData.id);
    
    local mapInfo = C_Map and C_Map.GetMapInfo and GetMapInfoCached(self, currentMapID);
    if changeInfo.gameMapChanged then
        if IsDebugEnabled() then
            local oldMapName = self.lastDetectedGameMapID and (Localization and Localization:GetMapName(self.lastDetectedGameMapID) or tostring(self.lastDetectedGameMapID)) or "未知";
            local newMapName = Localization and Localization:GetMapName(currentMapID) or (mapInfo and mapInfo.name) or tostring(currentMapID);
            Logger:Debug("MapTracker", "地图", string.format("游戏地图变化：%s（ID=%d） -> %s（ID=%d）", 
                oldMapName, self.lastDetectedGameMapID or 0, newMapName, currentMapID));
        end
    end
    
    if changeInfo.configMapChanged then
        if IsDebugEnabled() then
            local oldMapData = self.lastDetectedMapId and Data:GetMap(self.lastDetectedMapId);
            local oldMapName = oldMapData and Data:GetMapDisplayName(oldMapData) or tostring(self.lastDetectedMapId);
            local newMapName = Data:GetMapDisplayName(targetMapData);
            Logger:Debug("MapTracker", "地图", string.format("配置地图变化：%s（配置ID=%d） -> %s（配置ID=%d）", 
                oldMapName, self.lastDetectedMapId or 0, newMapName, targetMapData.id));
        end
    end
    
    
    self.lastDetectedMapId = targetMapData.id;
    self.lastDetectedGameMapID = currentMapID;
    
    return changeInfo;
end

MapTracker:Initialize();

return MapTracker;

