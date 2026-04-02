-- Phase.lua - 位面检测模块

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");
local Area = BuildEnv("Area");
local MapTracker = BuildEnv("MapTracker");
local ExpansionConfig = BuildEnv("ExpansionConfig");
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator");

Phase.lastReportedInstanceID = nil;
Phase.lastReportedMapPhaseKey = nil;
Phase.phaseCache = {};  -- 位面ID缓存，使用 版本+mapID 作为key
Phase.lastUpdateAt = Phase.lastUpdateAt or 0;
Phase.pendingUpdateTimer = Phase.pendingUpdateTimer or nil;
Phase.pendingMapID = Phase.pendingMapID or nil;
Phase.MIN_UPDATE_INTERVAL = 0.12;

local function GetExpansionAwareCacheKey(expansionID, mapID)
    return tostring(expansionID or "default") .. ":" .. tostring(mapID);
end

local function SafeSplitGuid(guid)
    if not guid or type(guid) ~= "string" then
        return nil;
    end
    local ok, unitType, _, serverID, _, zoneUID = pcall(strsplit, "-", guid);
    if not ok then
        return nil;
    end
    return unitType, serverID, zoneUID;
end

local function ResolveTargetMapData(currentMapID)
    if MapTracker and MapTracker.GetTargetMapData then
        return MapTracker:GetTargetMapData(currentMapID);
    end

    if not Data or not Data.GetAllMaps then
        return nil;
    end

    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(currentMapID);
    if not mapInfo then
        return nil;
    end

    local maps = Data:GetAllMaps();
    for _, mapData in ipairs(maps) do
        if mapData.mapID == currentMapID then
            return mapData;
        end
    end

    if mapInfo.parentMapID then
        for _, mapData in ipairs(maps) do
            if mapData.mapID == mapInfo.parentMapID then
                return mapData;
            end
        end
    end

    return nil;
end

function Phase:Reset()
    self.lastReportedInstanceID = nil;
    self.lastReportedMapPhaseKey = nil;
    self.phaseCache = {};
    self.lastUpdateAt = 0;
    self.pendingMapID = nil;
    if self.pendingUpdateTimer and self.pendingUpdateTimer.Cancel then
        self.pendingUpdateTimer:Cancel();
    end
    self.pendingUpdateTimer = nil;
end

function Phase:RequestUpdate(currentMapID, delay)
    local now = GetTime and GetTime() or 0;
    local minInterval = self.MIN_UPDATE_INTERVAL or 0.12;
    local resolvedDelay = tonumber(delay);
    if resolvedDelay == nil then
        local elapsed = now - (self.lastUpdateAt or 0);
        if elapsed >= minInterval then
            resolvedDelay = 0;
        else
            resolvedDelay = minInterval - elapsed;
        end
    end

    self.pendingMapID = currentMapID;
    if resolvedDelay <= 0 then
        if self.pendingUpdateTimer and self.pendingUpdateTimer.Cancel then
            self.pendingUpdateTimer:Cancel();
        end
        self.pendingUpdateTimer = nil;
        local pendingMapID = self.pendingMapID;
        self.pendingMapID = nil;
        return self:UpdatePhaseInfo(pendingMapID);
    end

    if self.pendingUpdateTimer then
        return true;
    end

    if C_Timer and C_Timer.NewTimer then
        self.pendingUpdateTimer = C_Timer.NewTimer(resolvedDelay, function()
            self.pendingUpdateTimer = nil;
            local pendingMapID = self.pendingMapID;
            self.pendingMapID = nil;
            self:UpdatePhaseInfo(pendingMapID);
        end);
        return true;
    end

    if C_Timer and C_Timer.After then
        self.pendingUpdateTimer = true;
        C_Timer.After(resolvedDelay, function()
            self.pendingUpdateTimer = nil;
            local pendingMapID = self.pendingMapID;
            self.pendingMapID = nil;
            self:UpdatePhaseInfo(pendingMapID);
        end);
        return true;
    end

    local pendingMapID = self.pendingMapID;
    self.pendingMapID = nil;
    return self:UpdatePhaseInfo(pendingMapID);
end

function Phase:GetLayerFromNPC()
    local unit = "mouseover";
    local guid = UnitGUID(unit);
    
    if not guid then
        unit = "target";
        guid = UnitGUID(unit);
    end
    
    if guid then
        -- 位面ID = ServerID-ZoneUID（GUID第3和第5部分）
        local unitType, serverID, zoneUID = SafeSplitGuid(guid);
        if (unitType == "Creature" or unitType == "Vehicle") and serverID and zoneUID then
            return serverID .. "-" .. zoneUID;
        end
    end
    return nil;
end

function Phase:HasProbeUnit()
    if not UnitGUID then
        return false;
    end
    if UnitGUID("mouseover") then
        return true;
    end
    if UnitGUID("target") then
        return true;
    end
    return false;
end

function Phase:UpdatePhaseInfo(currentMapID)
    if not Data then return end
    if Area and Area.IsActive and not Area:IsActive() then
        return;
    end
    self.lastUpdateAt = GetTime and GetTime() or 0;
    
    local playerMapID = Area:GetCurrentMapId(currentMapID);
    if not playerMapID then
        return;
    end
    
    -- 排除主城区域，不进行位面检测
    if ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(playerMapID) then
        return;
    end
    
    local targetMapData = ResolveTargetMapData(playerMapID);
    
    if targetMapData then
        -- 隐藏地图：暂停位面检测
        if Data and Data.IsMapHidden and Data:IsMapHidden(targetMapData.expansionID, targetMapData.mapID) then
            return;
        end

        local detectedPhaseID = self:GetLayerFromNPC();
        -- 使用 版本+mapID 作为缓存key，确保不同版本数据隔离
        local cacheKey = GetExpansionAwareCacheKey(targetMapData.expansionID, targetMapData.mapID);
        local cachedPhaseID = self.phaseCache[cacheKey];
        
        local shouldUpdate = false;
        local isPhaseChanged = false;  -- 区分真正的位面变化和首次检测
        local currentPhaseID = nil;
        local uiNeedsRefresh = false;
        local previousPhaseID = UnifiedDataManager and UnifiedDataManager.GetCurrentPhase and UnifiedDataManager:GetCurrentPhase(targetMapData.id) or nil;
        
        if detectedPhaseID then
            if cachedPhaseID ~= detectedPhaseID then
                self.phaseCache[cacheKey] = detectedPhaseID;
                currentPhaseID = detectedPhaseID;
                shouldUpdate = true;
                isPhaseChanged = (cachedPhaseID ~= nil);
            else
                currentPhaseID = detectedPhaseID;
            end
        elseif cachedPhaseID then
            currentPhaseID = cachedPhaseID;
        end
        
        if currentPhaseID then
            -- 通过UnifiedDataManager设置临时位面数据
            if UnifiedDataManager and UnifiedDataManager.SetPhase then
                UnifiedDataManager:SetPhase(targetMapData.id, currentPhaseID, UnifiedDataManager.PhaseSource.PHASE_DETECTION, false);
            end
            -- 保留旧版 currentPhaseID 回写，兼容仍读取 mapData 的链路
            targetMapData.currentPhaseID = currentPhaseID;
            if previousPhaseID ~= currentPhaseID then
                uiNeedsRefresh = true;
            end
            
            -- 消息发送逻辑：使用 targetMapData.mapID 作为key，避免子地图和主地图重复发送
            if shouldUpdate then
                uiNeedsRefresh = true;
                local mapPhaseKey = cacheKey .. "-" .. currentPhaseID;
                local lastReportedKey = self.lastReportedMapPhaseKey;
                
                local lastReportedMapID = nil;
                if lastReportedKey then
                    local mapPart = strsplit("-", lastReportedKey);
                    lastReportedMapID = tonumber(mapPart and mapPart:match(":(%d+)$")) or tonumber(mapPart);
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
            
            if uiNeedsRefresh and UIRefreshCoordinator then
                if UIRefreshCoordinator.RequestRowRefresh then
                    UIRefreshCoordinator:RequestRowRefresh(targetMapData.id, {
                        affectsSort = false,
                        delay = 0.08,
                    });
                elseif UIRefreshCoordinator.RefreshMainTable then
                    UIRefreshCoordinator:RefreshMainTable();
                end
            end
        end
    end
end
