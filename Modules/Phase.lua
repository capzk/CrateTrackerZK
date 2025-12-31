-- Phase.lua - 检测和更新位面信息

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");

Phase.lastReportedInstanceID = nil;
Phase.lastReportedMapPhaseKey = nil;
-- 位面ID缓存（以mapID为key，存储每个地图的位面ID，用于UI显示）
-- 退出游戏或切换角色时清除
Phase.phaseCache = {};

function Phase:Reset()
    self.lastReportedInstanceID = nil;
    self.lastReportedMapPhaseKey = nil;
    -- 清除位面ID缓存（切换角色或退出游戏时清除）
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
    
    if guid then
        -- 位面ID = 分片ID-实例ID
        local unitType, _, shardID, instancePart = strsplit("-", guid);
        if (unitType == "Creature" or unitType == "Vehicle") and shardID and instancePart then
            return shardID .. "-" .. instancePart;
        end
    end
    return nil;
end

function Phase:UpdatePhaseInfo()
    if Area and Area.detectionPaused then
        return;
    end
    
    if not Data then return end
    
    local currentMapID = Area:GetCurrentMapId();
    if not currentMapID then
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
    
    if targetMapData then
        local detectedPhaseID = self:GetLayerFromNPC();
        local cachedPhaseID = self.phaseCache[currentMapID];
        
        -- 位面ID缓存机制：
        -- 1. 如果检测到新的位面ID，且与缓存不同，更新缓存和targetMapData.currentPhaseID
        -- 2. 如果检测不到位面ID，使用缓存的位面ID（如果存在）
        -- 3. 只有当位面发生变化时才更新缓存
        
        local shouldUpdate = false;
        local currentPhaseID = nil;
        
        if detectedPhaseID then
            -- 检测到新的位面ID
            if cachedPhaseID ~= detectedPhaseID then
                -- 位面发生变化，更新缓存
                self.phaseCache[currentMapID] = detectedPhaseID;
                currentPhaseID = detectedPhaseID;
                shouldUpdate = true;
                Logger:Debug("Phase", "缓存", string.format("位面ID已更新：地图ID=%d，旧位面=%s，新位面=%s", 
                    currentMapID, cachedPhaseID or "无", detectedPhaseID));
            else
                -- 位面未变化，使用缓存的位面ID
                currentPhaseID = detectedPhaseID;
            end
        elseif cachedPhaseID then
            -- 检测不到位面ID，但缓存中存在，使用缓存的位面ID
            currentPhaseID = cachedPhaseID;
            Logger:Debug("Phase", "缓存", string.format("使用缓存的位面ID：地图ID=%d，位面ID=%s", 
                currentMapID, cachedPhaseID));
        end
        
        -- 更新targetMapData.currentPhaseID（用于UI显示）
        if currentPhaseID then
            targetMapData.currentPhaseID = currentPhaseID;
            
            -- 检查是否需要发送消息（避免重复发送）
            -- 使用地图ID+位面ID作为唯一标识，避免跨地图的位面ID冲突
            if shouldUpdate then
                local mapPhaseKey = currentMapID .. "-" .. currentPhaseID;
                local lastReportedKey = self.lastReportedMapPhaseKey;
                
                if not lastReportedKey then
                    -- 首次获取到位面ID，发送系统消息提醒
                    local mapName = Data:GetMapDisplayName(targetMapData);
                    Logger:Info("Phase", "位面", string.format(L["PhaseDetectedFirstTime"], mapName, currentPhaseID));
                    self.lastReportedInstanceID = currentPhaseID;
                    self.lastReportedMapPhaseKey = mapPhaseKey;
                elseif lastReportedKey ~= mapPhaseKey then
                    -- 位面发生变化（可能是地图变化或位面变化），发送系统消息提醒
                    local mapName = Data:GetMapDisplayName(targetMapData);
                    Logger:Info("Phase", "位面", string.format(L["InstanceChangedTo"], mapName, currentPhaseID));
                    self.lastReportedInstanceID = currentPhaseID;
                    self.lastReportedMapPhaseKey = mapPhaseKey;
                end
            end
            
            -- 更新UI显示
            if MainPanel and MainPanel.UpdateTable then
                MainPanel:UpdateTable();
            end
        end
    end
end

