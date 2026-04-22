-- Phase.lua - 位面检测模块

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");
local Area = BuildEnv("Area");
local MapTracker = BuildEnv("MapTracker");
local ExpansionConfig = BuildEnv("ExpansionConfig");
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator");
local PhaseTeamAlertCoordinator = BuildEnv("PhaseTeamAlertCoordinator");

Phase.lastReportedMapPhaseKey = nil;
Phase.phaseCache = {};  -- 位面ID缓存，使用 版本+mapID 作为key

local function GetExpansionAwareCacheKey(expansionID, mapID)
    return tostring(expansionID or "default") .. ":" .. tostring(mapID);
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

local function ResolveChangedBaselinePhase(previousPhaseID, historicalPhaseID, currentPhaseID)
    if type(previousPhaseID) == "string"
        and previousPhaseID ~= ""
        and previousPhaseID ~= currentPhaseID then
        return previousPhaseID;
    end

    if type(historicalPhaseID) == "string"
        and historicalPhaseID ~= ""
        and historicalPhaseID ~= currentPhaseID then
        return historicalPhaseID;
    end

    return nil;
end

function Phase:Reset()
    self.lastReportedMapPhaseKey = nil;
    self.phaseCache = {};
end

function Phase:GetLayerFromNPC()
    if PhaseProbeService and PhaseProbeService.GetPreferredPhase then
        return PhaseProbeService:GetPreferredPhase("mouseover", "target");
    end
    return nil;
end

function Phase:HasProbeUnit()
    if PhaseProbeService and PhaseProbeService.HasValidProbeUnit then
        return PhaseProbeService:HasValidProbeUnit("mouseover", "target");
    end
    return false;
end

function Phase:UpdatePhaseInfo(currentMapID)
    if not Data then return end
    if Area and Area.IsActive and not Area:IsActive() then
        return;
    end
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
        local currentPhaseID = nil;
        local uiNeedsRefresh = false;
        local previousPhaseID = UnifiedDataManager and UnifiedDataManager.GetCurrentPhase and UnifiedDataManager:GetCurrentPhase(targetMapData.id) or nil;
        local historicalPhaseID = UnifiedDataManager
            and UnifiedDataManager.GetObservedHistoricalPhase
            and UnifiedDataManager:GetObservedHistoricalPhase(targetMapData.id)
            or nil;
        
        if detectedPhaseID then
            if cachedPhaseID ~= detectedPhaseID then
                self.phaseCache[cacheKey] = detectedPhaseID;
                currentPhaseID = detectedPhaseID;
                shouldUpdate = true;
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
                if UnifiedDataManager and UnifiedDataManager.MarkSharedDisplayPhaseTransition then
                    UnifiedDataManager:MarkSharedDisplayPhaseTransition(
                        targetMapData.id,
                        previousPhaseID,
                        currentPhaseID,
                        Utils:GetCurrentTimestamp()
                    );
                end
                uiNeedsRefresh = true;
            end
            
            -- 消息发送逻辑：使用 targetMapData.mapID 作为key，避免子地图和主地图重复发送
            if shouldUpdate then
                uiNeedsRefresh = true;
                local mapPhaseKey = cacheKey .. "-" .. currentPhaseID;
                local lastReportedKey = self.lastReportedMapPhaseKey;

                if lastReportedKey ~= mapPhaseKey then
                    local mapName = Data:GetMapDisplayName(targetMapData);
                    local changedBaselinePhaseID = ResolveChangedBaselinePhase(
                        previousPhaseID,
                        historicalPhaseID,
                        currentPhaseID
                    );
                    local isPhaseChanged = (cachedPhaseID ~= nil) or (changedBaselinePhaseID ~= nil);
                    local messageKey = isPhaseChanged and "InstanceChangedTo" or "PhaseDetectedFirstTime";
                    Logger:Info("Phase", "位面", string.format(L[messageKey], mapName, currentPhaseID));
                    if PhaseTeamAlertCoordinator and PhaseTeamAlertCoordinator.HandleLocalPhaseDetected then
                        PhaseTeamAlertCoordinator:HandleLocalPhaseDetected(
                            targetMapData,
                            previousPhaseID,
                            historicalPhaseID,
                            currentPhaseID
                        );
                    end
                    if UnifiedDataManager and UnifiedDataManager.PersistObservedHistoricalPhase then
                        UnifiedDataManager:PersistObservedHistoricalPhase(
                            targetMapData.id,
                            currentPhaseID,
                            Utils:GetCurrentTimestamp()
                        );
                    end
                    self.lastReportedMapPhaseKey = mapPhaseKey;
                end
            end

            if UnifiedDataManager and UnifiedDataManager.RefreshSharedDisplayActivation then
                local sharedDisplayActivated = UnifiedDataManager:RefreshSharedDisplayActivation(
                    targetMapData.id,
                    Utils:GetCurrentTimestamp()
                );
                if sharedDisplayActivated == true then
                    uiNeedsRefresh = true;
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
