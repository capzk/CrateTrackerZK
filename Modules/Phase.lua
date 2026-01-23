-- Phase.lua - 位面检测模块

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");

Phase.lastReportedInstanceID = nil;
Phase.lastReportedMapPhaseKey = nil;
Phase.phaseCache = {};  -- 位面ID缓存，使用 targetMapData.mapID 作为key

function Phase:Reset()
    self.lastReportedInstanceID = nil;
    self.lastReportedMapPhaseKey = nil;
    self.phaseCache = {};
    Logger:Debug("Phase", "重置", "已重置位面检测状态和缓存");
end

function Phase:GetLayerFromNPC()
    local unit = "mouseover";
    local guid = UnitGUID(unit);
    
    if not guid then
        unit = "target";
        guid = UnitGUID(unit);
    end
    
    if guid and type(guid) ~= "string" then
        return nil;
    end

    if guid then
        -- 位面ID = 分片ID-实例ID（GUID第3-4部分）
        local unitType, _, shardID, instancePart = strsplit("-", guid);
        if (unitType == "Creature" or unitType == "Vehicle") and shardID and instancePart then
            return shardID .. "-" .. instancePart;
        end
    end
    return nil;
end

function Phase:UpdatePhaseInfo()
    if not Data then return end
    
    local currentMapID = Area:GetCurrentMapId();
    if not currentMapID then
        return;
    end
    
    -- 排除主城区域（多恩诺嘉尔），不进行位面检测
    if currentMapID == 2339 then
        Logger:Debug("Phase", "排除", string.format("跳过主城区域位面检测：地图ID=%d（多恩诺嘉尔）", currentMapID));
        return;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if not mapInfo then return end
    
    local maps = Data:GetAllMaps();
    local targetMapData = nil;
    
    for _, mapData in ipairs(maps) do
        if mapData.mapID == currentMapID then
            targetMapData = mapData;
            break;
        end
    end
    
    -- 支持父地图匹配（子地图场景）
    if not targetMapData and mapInfo.parentMapID then
        for _, mapData in ipairs(maps) do
            if mapData.mapID == mapInfo.parentMapID then
                targetMapData = mapData;
                Logger:Debug("Phase", "匹配", string.format("父地图匹配成功：当前地图ID=%d，父地图ID=%d（配置ID=%d）", 
                    currentMapID, mapInfo.parentMapID, mapData.id));
                break;
            end
        end
    end
    
    if targetMapData then
        -- 隐藏地图：暂停位面检测
        if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps and CRATETRACKERZK_UI_DB.hiddenMaps[targetMapData.mapID] then
            return;
        end

        local detectedPhaseID = self:GetLayerFromNPC();
        -- 使用 targetMapData.mapID 作为缓存key，确保子地图和主地图共享同一缓存
        local cacheKey = targetMapData.mapID;
        local cachedPhaseID = self.phaseCache[cacheKey];
        
        local shouldUpdate = false;
        local isPhaseChanged = false;  -- 区分真正的位面变化和首次检测
        local currentPhaseID = nil;
        
        if detectedPhaseID then
            if cachedPhaseID ~= detectedPhaseID then
                self.phaseCache[cacheKey] = detectedPhaseID;
                currentPhaseID = detectedPhaseID;
                shouldUpdate = true;
                isPhaseChanged = (cachedPhaseID ~= nil);
                Logger:Debug("Phase", "缓存", string.format("位面ID已更新：配置地图ID=%d，当前地图ID=%d，旧位面=%s，新位面=%s，是否变化=%s", 
                    targetMapData.mapID, currentMapID, cachedPhaseID or "无", detectedPhaseID, isPhaseChanged and "是" or "否（首次检测）"));
            else
                currentPhaseID = detectedPhaseID;
            end
        elseif cachedPhaseID then
            currentPhaseID = cachedPhaseID;
            Logger:Debug("Phase", "缓存", string.format("使用缓存的位面ID：配置地图ID=%d，当前地图ID=%d，位面ID=%s", 
                targetMapData.mapID, currentMapID, cachedPhaseID));
        end
        
        if currentPhaseID then
            -- 通过UnifiedDataManager设置临时位面数据
            if UnifiedDataManager and UnifiedDataManager.SetPhase then
                UnifiedDataManager:SetPhase(targetMapData.id, currentPhaseID, UnifiedDataManager.PhaseSource.PHASE_DETECTION, false);
            end
            
            -- 保留原有的currentPhaseID设置以保持向后兼容
            targetMapData.currentPhaseID = currentPhaseID;
            
            -- 消息发送逻辑：使用 targetMapData.mapID 作为key，避免子地图和主地图重复发送
            if shouldUpdate then
                local mapPhaseKey = targetMapData.mapID .. "-" .. currentPhaseID;
                local lastReportedKey = self.lastReportedMapPhaseKey;
                
                local lastReportedMapID = nil;
                if lastReportedKey then
                    local parts = {strsplit("-", lastReportedKey)};
                    if #parts >= 1 then
                        lastReportedMapID = tonumber(parts[1]);
                    end
                end
                
                if lastReportedKey == mapPhaseKey then
                    if self.lastReportedMapPhaseKey ~= mapPhaseKey then
                        self.lastReportedMapPhaseKey = mapPhaseKey;
                    end
                elseif not lastReportedKey then
                    local mapName = Data:GetMapDisplayName(targetMapData);
                    Logger:Info("Phase", "位面", string.format(L["PhaseDetectedFirstTime"], mapName, currentPhaseID));
                    self.lastReportedInstanceID = currentPhaseID;
                    self.lastReportedMapPhaseKey = mapPhaseKey;
                elseif lastReportedMapID == targetMapData.mapID then
                    if isPhaseChanged then
                        local mapName = Data:GetMapDisplayName(targetMapData);
                        Logger:Info("Phase", "位面", string.format(L["InstanceChangedTo"], mapName, currentPhaseID));
                        self.lastReportedInstanceID = currentPhaseID;
                        self.lastReportedMapPhaseKey = mapPhaseKey;
                    else
                        local mapName = Data:GetMapDisplayName(targetMapData);
                        Logger:Info("Phase", "位面", string.format(L["PhaseDetectedFirstTime"], mapName, currentPhaseID));
                        self.lastReportedInstanceID = currentPhaseID;
                        self.lastReportedMapPhaseKey = mapPhaseKey;
                    end
                else
                    if isPhaseChanged then
                        self.lastReportedMapPhaseKey = mapPhaseKey;
                    else
                        local mapName = Data:GetMapDisplayName(targetMapData);
                        Logger:Info("Phase", "位面", string.format(L["PhaseDetectedFirstTime"], mapName, currentPhaseID));
                        self.lastReportedInstanceID = currentPhaseID;
                        self.lastReportedMapPhaseKey = mapPhaseKey;
                    end
                end
            end
            
            if MainPanel and MainPanel.UpdateTable then
                MainPanel:UpdateTable();
            end
        end
    end
end
