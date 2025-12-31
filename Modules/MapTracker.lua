-- MapTracker.lua - 管理地图匹配和变化，支持父地图匹配

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local MapTracker = BuildEnv('MapTracker');

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

local function DT(key)
    return Logger:GetDebugText(key);
end

function MapTracker:Initialize()
    self.lastDetectedMapId = nil;
    self.lastDetectedGameMapID = nil;
    self.lastMatchedMapID = nil;
    self.lastUnmatchedMapID = nil;
end

function MapTracker:GetTargetMapData(currentMapID)
    if not currentMapID then
        return nil;
    end
    
    if not C_Map or not C_Map.GetMapInfo then
        Logger:DebugLimited("map_check:api_unavailable", "MapTracker", "匹配", "C_Map.GetMapInfo API 不可用");
        return nil;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if not mapInfo then
        Logger:DebugLimited("map_check:no_map_info", "MapTracker", "匹配", DT("DebugCannotGetMapName2"));
        return nil;
    end
    
    local validMaps = Data:GetAllMaps();
    if not validMaps or #validMaps == 0 then
        Logger:DebugLimited("map_check:empty_list", "MapTracker", "匹配", DT("DebugMapListEmpty"));
        return nil;
    end
    
    local targetMapData = nil;
    
    for _, mapData in ipairs(validMaps) do
        if mapData.mapID == currentMapID then
            targetMapData = mapData;
            if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                Logger:DebugLimited("map_check:match_success_" .. tostring(currentMapID), "MapTracker", "地图", 
                    string.format("地图匹配成功：%s（地图ID=%d，配置ID=%d）", 
                    mapDisplayName, currentMapID, mapData.id));
                self.lastMatchedMapID = currentMapID;
            end
            break;
        end
    end
    
    if not targetMapData and mapInfo.parentMapID then
        for _, mapData in ipairs(validMaps) do
            if mapData.mapID == mapInfo.parentMapID then
                targetMapData = mapData;
                if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                    local currentMapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                    local parentMapDisplayName = Localization and Localization:GetMapName(mapInfo.parentMapID) or tostring(mapInfo.parentMapID);
                    Logger:DebugLimited("map_check:parent_match_" .. tostring(currentMapID), "MapTracker", "地图", 
                        string.format("父地图匹配成功：当前地图=%s（ID=%d），父地图=%s（ID=%d，配置ID=%d）", 
                        currentMapDisplayName, currentMapID, parentMapDisplayName, mapInfo.parentMapID, mapData.id));
                    self.lastMatchedMapID = currentMapID;
                end
                break;
            end
        end
    end
    if not targetMapData then
        local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
        local parentMapDisplayName = (mapInfo.parentMapID and Localization and Localization:GetMapName(mapInfo.parentMapID)) or (mapInfo.parentMapID and tostring(mapInfo.parentMapID)) or DT("DebugNoRecord");
        Logger:DebugLimited("map_check:not_in_list_" .. tostring(currentMapID), "MapTracker", "匹配", 
            string.format(DT("DebugMapNotInList"), mapDisplayName, parentMapDisplayName, currentMapID));
    end
    
    return targetMapData;
end

function MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
    self:Initialize();
    
    local changeInfo = {
        gameMapChanged = false,
        configMapChanged = false,
        configIdSame = false,
        oldMapId = self.lastDetectedMapId,
        oldGameMapID = self.lastDetectedGameMapID
    };
    
    changeInfo.gameMapChanged = (self.lastDetectedGameMapID and self.lastDetectedGameMapID ~= currentMapID);
    changeInfo.configMapChanged = (self.lastDetectedMapId and self.lastDetectedMapId ~= targetMapData.id);
    changeInfo.configIdSame = (self.lastDetectedMapId and self.lastDetectedMapId == targetMapData.id);
    
    local mapInfo = C_Map and C_Map.GetMapInfo(currentMapID);
    if changeInfo.gameMapChanged then
        local oldMapName = self.lastDetectedGameMapID and (Localization and Localization:GetMapName(self.lastDetectedGameMapID) or tostring(self.lastDetectedGameMapID)) or "未知";
        local newMapName = Localization and Localization:GetMapName(currentMapID) or (mapInfo and mapInfo.name) or tostring(currentMapID);
        Logger:Debug("MapTracker", "地图", string.format("游戏地图变化：%s（ID=%d） -> %s（ID=%d）", 
            oldMapName, self.lastDetectedGameMapID or 0, newMapName, currentMapID));
    end
    
    if changeInfo.configMapChanged then
        local oldMapData = self.lastDetectedMapId and Data:GetMap(self.lastDetectedMapId);
        local oldMapName = oldMapData and Data:GetMapDisplayName(oldMapData) or tostring(self.lastDetectedMapId);
        local newMapName = Data:GetMapDisplayName(targetMapData);
        Logger:Debug("MapTracker", "地图", string.format("配置地图变化：%s（配置ID=%d） -> %s（配置ID=%d）", 
            oldMapName, self.lastDetectedMapId or 0, newMapName, targetMapData.id));
    end
    
    
    self.lastDetectedMapId = targetMapData.id;
    self.lastDetectedGameMapID = currentMapID;
    
    return changeInfo;
end

MapTracker:Initialize();

return MapTracker;

