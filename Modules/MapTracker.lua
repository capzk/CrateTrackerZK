-- MapTracker.lua
-- 职责：管理地图匹配和变化
-- 支持父地图匹配（符合设计文档）

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

-- 使用 Logger 模块统一输出
local function SafeDebug(...)
    Logger:Debug("MapTracker", "调试", ...);
end

local function DT(key)
    return Logger:GetDebugText(key);
end

-- 初始化状态
function MapTracker:Initialize()
    self.mapLeftTime = self.mapLeftTime or {}; -- 记录玩家离开某个地图的时间
    self.lastDetectedMapId = self.lastDetectedMapId or nil; -- 上次检测到的地图ID（配置ID）
    self.lastDetectedGameMapID = self.lastDetectedGameMapID or nil; -- 上次检测到的游戏地图ID（currentMapID）
    self.MAP_LEFT_CLEAR_TIME = 300; -- 离开地图后清除状态的时间（秒，5分钟）
    self.lastMatchedMapID = self.lastMatchedMapID or nil; -- 用于调试限流
    self.lastUnmatchedMapID = self.lastUnmatchedMapID or nil; -- 用于调试限流
end

-- 获取目标地图数据（支持父地图匹配）
-- 输入：currentMapID - 当前游戏地图ID
-- 输出：mapData or nil - 匹配的地图数据
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
    
    -- 1. 首先尝试直接匹配当前地图ID
    for _, mapData in ipairs(validMaps) do
        if mapData.mapID == currentMapID then
            targetMapData = mapData;
            if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                -- 地图匹配成功（关键信息，不限流）
                Logger:Debug("MapTracker", "地图", string.format("地图匹配成功：%s（地图ID=%d，配置ID=%d）", 
                    mapDisplayName, currentMapID, mapData.id));
                self.lastMatchedMapID = currentMapID;
            end
            break;
        end
    end
    
    -- 2. 如果未匹配，尝试匹配父地图（符合设计文档：支持父地图匹配）
    if not targetMapData and mapInfo.parentMapID then
        for _, mapData in ipairs(validMaps) do
            if mapData.mapID == mapInfo.parentMapID then
                targetMapData = mapData;
                if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                    local currentMapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                    local parentMapDisplayName = Localization and Localization:GetMapName(mapInfo.parentMapID) or tostring(mapInfo.parentMapID);
                    -- 父地图匹配成功（关键信息，不限流）
                    Logger:Debug("MapTracker", "地图", string.format("父地图匹配成功：当前地图=%s（ID=%d），父地图=%s（ID=%d，配置ID=%d）", 
                        currentMapDisplayName, currentMapID, parentMapDisplayName, mapInfo.parentMapID, mapData.id));
                    self.lastMatchedMapID = currentMapID;
                end
                break;
            end
        end
    end
    
    -- 3. 如果仍未匹配，记录调试信息（限流）
    if not targetMapData then
        local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
        local parentMapDisplayName = (mapInfo.parentMapID and Localization and Localization:GetMapName(mapInfo.parentMapID)) or (mapInfo.parentMapID and tostring(mapInfo.parentMapID)) or DT("DebugNoRecord");
        Logger:DebugLimited("map_check:not_in_list_" .. tostring(currentMapID), "MapTracker", "匹配", 
            string.format(DT("DebugMapNotInList"), mapDisplayName, parentMapDisplayName, currentMapID));
    end
    
    return targetMapData;
end

-- 处理地图变化
-- 输入：currentMapID - 当前游戏地图ID
--      targetMapData - 目标地图数据
--      currentTime - 当前时间戳
-- 输出：changeInfo - {gameMapChanged, configMapChanged, configIdSame, oldMapId, oldGameMapID}
function MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime)
    self:Initialize(); -- 确保初始化
    
    local changeInfo = {
        gameMapChanged = false,
        configMapChanged = false,
        configIdSame = false,
        oldMapId = self.lastDetectedMapId,
        oldGameMapID = self.lastDetectedGameMapID
    };
    
    -- 检查游戏地图ID是否变化
    changeInfo.gameMapChanged = (self.lastDetectedGameMapID and self.lastDetectedGameMapID ~= currentMapID);
    
    -- 检查配置地图ID是否变化
    changeInfo.configMapChanged = (self.lastDetectedMapId and self.lastDetectedMapId ~= targetMapData.id);
    
    -- 检查配置ID是否相同（用于判断主地图<->子地图切换）
    changeInfo.configIdSame = (self.lastDetectedMapId and self.lastDetectedMapId == targetMapData.id);
    
    -- 获取当前地图信息
    local mapInfo = C_Map and C_Map.GetMapInfo(currentMapID);
    
    -- 输出地图变化信息（关键信息，不限流）
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
    
    -- 记录离开旧地图的时间（符合设计文档）
    if changeInfo.configMapChanged and self.lastDetectedMapId then
        if not self.mapLeftTime[self.lastDetectedMapId] then
            self.mapLeftTime[self.lastDetectedMapId] = currentTime;
            local oldMapData = Data:GetMap(self.lastDetectedMapId);
            Logger:Debug("MapTracker", "地图", string.format("玩家离开地图：%s（配置ID=%d），记录离开时间", 
                oldMapData and Data:GetMapDisplayName(oldMapData) or tostring(self.lastDetectedMapId), self.lastDetectedMapId));
        end
    end
    
    -- 清除当前地图的离开时间（玩家已回到该地图）
    if self.mapLeftTime[targetMapData.id] then
        self.mapLeftTime[targetMapData.id] = nil;
        Logger:Debug("MapTracker", "地图", string.format("玩家回到地图：%s（配置ID=%d），清除离开时间", 
            Data:GetMapDisplayName(targetMapData), targetMapData.id));
    end
    
    -- 更新当前检测的地图ID
    self.lastDetectedMapId = targetMapData.id;
    self.lastDetectedGameMapID = currentMapID;
    
    return changeInfo;
end

-- 检查并清除超时的离开地图状态（符合设计文档：300秒）
-- 输入：currentTime - 当前时间戳
function MapTracker:CheckAndClearLeftMaps(currentTime)
    if not self.mapLeftTime or not currentTime then
        return;
    end
    
    local mapsToClear = {};
    
    for mapId, leftTime in pairs(self.mapLeftTime) do
        local timeSinceLeft = currentTime - leftTime;
        if timeSinceLeft >= self.MAP_LEFT_CLEAR_TIME then
            -- 超过阈值，标记为需要清除
            table.insert(mapsToClear, mapId);
        end
    end
    
    -- 清除标记的地图状态（但保留通知冷却期，防止误报）
    for _, mapId in ipairs(mapsToClear) do
        local mapData = Data:GetMap(mapId);
        if mapData then
            local mapDisplayName = Data:GetMapDisplayName(mapData);
            SafeDebug(string.format("自动清除离开地图的状态：%s（离开 %d 秒）", mapDisplayName, currentTime - self.mapLeftTime[mapId]));
        end
        
        -- 清除所有相关状态（但保留通知冷却期，防止误报）
        -- 注意：这里不清除 lastNotificationTime，保持通知冷却期
        -- 实际的清除操作由 DetectionState 模块处理
        self.mapLeftTime[mapId] = nil;
    end
end

-- 初始化
MapTracker:Initialize();

return MapTracker;

