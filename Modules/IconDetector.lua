-- IconDetector.lua - 图标检测模块

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local IconDetector = BuildEnv('IconDetector');
local Data = BuildEnv("Data");

local CrateTrackerZK = BuildEnv("CrateTrackerZK");

if not Utils then
    Utils = BuildEnv('Utils')
end

local function IsTargetAirdropVignetteID(vignetteID)
    if type(vignetteID) ~= "number" then
        return false;
    end

    if Data and Data.IsAirdropPlaneVignetteID and Data:IsAirdropPlaneVignetteID(vignetteID) then
        return true;
    end

    return false;
end

-- 提取 SpawnUID（GUID 第7部分）
local function ExtractSpawnUID(objectGUID)
    if not objectGUID or type(objectGUID) ~= "string" then 
        return nil;
    end

    return select(7, strsplit("-", objectGUID));
end

-- 提取位面ID（GUID 第3和第5部分：ServerID-ZoneUID）
local function ExtractPhaseID(objectGUID)
    if not objectGUID or type(objectGUID) ~= "string" then 
        return nil;
    end

    local _, _, serverID, _, zoneUID = strsplit("-", objectGUID);
    if serverID and zoneUID then
        return serverID .. "-" .. zoneUID;
    end

    return nil;
end

local function ResetDetectionResult(outResult)
    outResult.detected = false;
    outResult.objectGUID = nil;
    outResult.spawnUID = nil;
    outResult.phaseID = nil;
    outResult.vignetteGUID = nil;
    outResult.vignetteID = nil;
    return outResult;
end

local function HasVignettePositionOnMap(vignetteGUID, mapID)
    if type(mapID) ~= "number" then
        return false;
    end
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettePosition then
        return false;
    end

    local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, mapID);
    if not position then
        return false;
    end
    if type(position) ~= "table" then
        return true;
    end

    return position.x ~= nil or position.y ~= nil;
end

local function IsMapWithinTrackedHierarchy(currentMapID, trackedMapID)
    if type(currentMapID) ~= "number" or type(trackedMapID) ~= "number" then
        return false;
    end
    if currentMapID == trackedMapID then
        return true;
    end
    if not C_Map or not C_Map.GetMapInfo then
        return false;
    end

    local inspectMapID = currentMapID;
    local visited = {};
    while type(inspectMapID) == "number" and not visited[inspectMapID] do
        if inspectMapID == trackedMapID then
            return true;
        end
        visited[inspectMapID] = true;

        local mapInfo = C_Map.GetMapInfo(inspectMapID);
        inspectMapID = mapInfo and mapInfo.parentMapID or nil;
    end

    return false;
end

local function IsVignetteOnMapHierarchy(vignetteGUID, currentMapID, trackedMapID)
    if type(currentMapID) ~= "number" then
        return true;
    end
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettePosition then
        return true;
    end

    if type(trackedMapID) == "number"
        and not IsMapWithinTrackedHierarchy(currentMapID, trackedMapID) then
        return false;
    end

    local inspectMapID = currentMapID;
    local visited = {};
    while type(inspectMapID) == "number" and not visited[inspectMapID] do
        if HasVignettePositionOnMap(vignetteGUID, inspectMapID) then
            return true;
        end
        visited[inspectMapID] = true;

        if type(trackedMapID) == "number" and inspectMapID == trackedMapID then
            break;
        end

        if not C_Map or not C_Map.GetMapInfo then
            break;
        end

        local mapInfo = C_Map.GetMapInfo(inspectMapID);
        inspectMapID = mapInfo and mapInfo.parentMapID or nil;
    end

    return false;
end

function IconDetector:DetectIconInto(currentMapID, trackedMapID, outResult)
    if type(trackedMapID) == "table" and outResult == nil then
        outResult = trackedMapID;
        trackedMapID = nil;
    end

    outResult = type(outResult) == "table" and outResult or {};
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes or not C_VignetteInfo.GetVignetteInfo then
        return ResetDetectionResult(outResult);
    end
    
    local vignettes = C_VignetteInfo.GetVignettes();
    if not vignettes then
        return ResetDetectionResult(outResult);
    end
    
    -- 仅检测空投飞机图标
    for _, vignetteGUID in ipairs(vignettes) do
        local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID);
        if vignetteInfo then
            if IsTargetAirdropVignetteID(vignetteInfo.vignetteID)
                and IsVignetteOnMapHierarchy(vignetteGUID, currentMapID, trackedMapID) then
                local objectGUID = vignetteInfo.objectGUID;
                local spawnUID = nil;
                
                if objectGUID then
                    spawnUID = ExtractSpawnUID(objectGUID);
                end
                
                local phaseID = ExtractPhaseID(objectGUID);
                outResult.detected = true;
                outResult.objectGUID = objectGUID;
                outResult.spawnUID = spawnUID;
                outResult.phaseID = phaseID;
                outResult.vignetteGUID = vignetteGUID;
                outResult.vignetteID = vignetteInfo.vignetteID;
                return outResult;
            end
        end
    end
    
    return ResetDetectionResult(outResult);
end

function IconDetector:DetectIcon(currentMapID, trackedMapID)
    return self:DetectIconInto(currentMapID, trackedMapID, {});
end

IconDetector.ExtractSpawnUID = ExtractSpawnUID;
IconDetector.ExtractPhaseID = ExtractPhaseID;

return IconDetector;
