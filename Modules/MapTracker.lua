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

local function ApplyMapChange(self, currentMapID, targetMapData)
    local oldMapId = self.lastDetectedMapId;
    local oldGameMapID = self.lastDetectedGameMapID;
    if not targetMapData or not currentMapID then
        return false, false, false, oldMapId, oldGameMapID;
    end

    local gameMapChanged = (oldGameMapID and oldGameMapID ~= currentMapID);
    local configMapChanged = (oldMapId and oldMapId ~= targetMapData.id);
    local configIdSame = (oldMapId and oldMapId == targetMapData.id);

    self.lastDetectedMapId = targetMapData.id;
    self.lastDetectedGameMapID = currentMapID;

    return gameMapChanged, configMapChanged, configIdSame, oldMapId, oldGameMapID;
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
        return nil;
    end

    if ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(currentMapID) then
        return nil;
    end
    
    local validMaps = Data:GetAllMaps();
    if not validMaps or #validMaps == 0 then
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
        self.lastMatchedMapID = currentMapID;
    end
    
    return targetMapData;
end

function MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
    local gameMapChanged, configMapChanged, configIdSame, oldMapId, oldGameMapID =
        ApplyMapChange(self, currentMapID, targetMapData);

    return {
        gameMapChanged = gameMapChanged,
        configMapChanged = configMapChanged,
        configIdSame = configIdSame,
        oldMapId = oldMapId,
        oldGameMapID = oldGameMapID
    };
end

function MapTracker:UpdateCurrentMapState(currentMapID, targetMapData, currentTime)
    ApplyMapChange(self, currentMapID, targetMapData);
end

MapTracker:Initialize();

return MapTracker;
