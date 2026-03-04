-- Area.lua - 检查玩家所在区域是否有效，控制检测功能开关

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local Area = BuildEnv("Area");
local MapTracker = BuildEnv("MapTracker");
local ExpansionConfig = BuildEnv("ExpansionConfig");

Area.lastAreaValidState = nil;
Area.detectionPaused = false;

local function DT(key)
    return Logger:GetDebugText(key);
end

function Area:GetCurrentMapId(currentMapID)
    if currentMapID then
        return currentMapID;
    end
    return C_Map.GetBestMapForUnit("player");
end

function Area:IsActive()
    if IsInInstance and IsInInstance() then
        return false;
    end
    return self.lastAreaValidState == true and not self.detectionPaused;
end

function Area:PauseAllDetections()
    if self.detectionPaused then
        return;
    end
    self.detectionPaused = true;
    Logger:Debug("Area", "状态", "区域无效，暂停所有检测");
    if CrateTrackerZK.PauseAllDetections then
        CrateTrackerZK:PauseAllDetections();
    end
end

function Area:ResumeAllDetections()
    if not self.detectionPaused then
        return;
    end
    self.detectionPaused = false;
    Logger:Debug("Area", "状态", "区域有效，恢复所有检测");
    if CrateTrackerZK.ResumeAllDetections then
        CrateTrackerZK:ResumeAllDetections();
    end
end

function Area:CheckAndUpdateAreaValid(currentMapID)
    local inInstance, instanceType = IsInInstance();
    local isInstance = inInstance == true;
    local playerMapID = nil;
    
    if Logger and Logger.debugEnabled then
        playerMapID = self:GetCurrentMapId(currentMapID);
        local mapName = playerMapID and (Localization and Localization:GetMapName(playerMapID) or tostring(playerMapID)) or "未知";
        Logger:DebugLimited("area:check_" .. (playerMapID or 0), "Area", "状态", 
            string.format("【区域检查】地图=%s，副本类型=%s，区域有效=%s", 
                mapName,
                instanceType or "无",
                not isInstance and "是" or "否"));
    end
    
    if isInstance then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            Logger:Debug("Area", "区域", DT("DebugAreaInvalidInstance"));
        end
        self:PauseAllDetections();
        return false;
    end
    
    playerMapID = playerMapID or self:GetCurrentMapId(currentMapID);
    if not playerMapID then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            Logger:Debug("Area", "区域", DT("DebugAreaCannotGetMapID"));
            self:PauseAllDetections();
        end
        return false;
    end

    if ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(playerMapID) then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            Logger:Debug("Area", "区域", string.format("区域变化：有效 -> 无效，地图ID=%d（主城已排除）", playerMapID));
            self:PauseAllDetections();
        end
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(playerMapID);
    if not mapInfo then return false end

    local targetMapData = nil;
    if MapTracker and MapTracker.GetTargetMapData then
        targetMapData = MapTracker:GetTargetMapData(playerMapID);
    end

    if targetMapData then
        if self.lastAreaValidState ~= true then
            self.lastAreaValidState = true;
            local matchedMapName = (Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData))
                or (Localization and Localization:GetMapName(targetMapData.mapID))
                or (mapInfo.name or tostring(playerMapID));
            Logger:Debug("Area", "区域", string.format("区域变化：无效 -> 有效，地图=%s", matchedMapName));
            self:ResumeAllDetections();
        end
        return true;
    end

    if self.lastAreaValidState ~= false then
        self.lastAreaValidState = false;
        Logger:Debug("Area", "区域", string.format("区域变化：有效 -> 无效，地图=%s（不在列表中）", 
            mapInfo.name or tostring(playerMapID)));
        self:PauseAllDetections();
    end
    return false;
end

