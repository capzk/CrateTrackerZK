-- Area.lua - 检查玩家所在区域是否有效，控制检测功能开关

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local Area = BuildEnv("Area");
local MapTracker = BuildEnv("MapTracker");
local ExpansionConfig = BuildEnv("ExpansionConfig");

Area.lastAreaValidState = nil;
Area.lastAccessMode = nil;
Area.detectionPaused = false;
Area.AccessMode = {
    DISABLED = "disabled",
    FULL_TRACKING = "full_tracking",
    SYNC_ONLY = "sync_only",
};

local function DT(key)
    return Logger:GetDebugText(key);
end

local function ResolveAreaAccess(self, currentMapID)
    local inInstance, instanceType = false, nil;
    if IsInInstance then
        inInstance, instanceType = IsInInstance();
    end

    local playerMapID = self:GetCurrentMapId(currentMapID);
    if inInstance == true then
        return self.AccessMode.DISABLED, playerMapID, nil, instanceType, true;
    end

    if not playerMapID then
        return self.AccessMode.DISABLED, nil, nil, instanceType, false;
    end

    if ExpansionConfig and ExpansionConfig.IsMainCityMap and ExpansionConfig:IsMainCityMap(playerMapID) then
        return self.AccessMode.SYNC_ONLY, playerMapID, nil, instanceType, false;
    end

    local targetMapData = nil;
    if MapTracker and MapTracker.GetTargetMapData then
        targetMapData = MapTracker:GetTargetMapData(playerMapID);
    end

    if targetMapData then
        return self.AccessMode.FULL_TRACKING, playerMapID, targetMapData, instanceType, false;
    end

    return self.AccessMode.DISABLED, playerMapID, nil, instanceType, false;
end

function Area:GetCurrentMapId(currentMapID)
    if currentMapID then
        return currentMapID;
    end
    return C_Map.GetBestMapForUnit("player");
end

function Area:GetAccessMode(currentMapID)
    local accessMode = ResolveAreaAccess(self, currentMapID);
    return accessMode;
end

function Area:CanUseTrackedMapFeatures(currentMapID)
    local accessMode = self:GetAccessMode(currentMapID);
    return accessMode == self.AccessMode.FULL_TRACKING or accessMode == self.AccessMode.SYNC_ONLY;
end

function Area:CanProcessTeamMessages(currentMapID)
    if IsInInstance and IsInInstance() then
        return false;
    end

    local playerMapID = self:GetCurrentMapId(currentMapID);
    if not playerMapID then
        return false;
    end

    return true;
end

function Area:IsActive()
    if IsInInstance and IsInInstance() then
        return false;
    end
    return self.lastAreaValidState == true and not self.detectionPaused;
end

function Area:PauseLocalDetections()
    local wasPaused = self.detectionPaused == true;
    self.detectionPaused = true;
    if not wasPaused then
        Logger:Debug("Area", "状态", "区域不允许本地检测，暂停空投与位面检测");
    end
    if CrateTrackerZK.PauseLocalDetections then
        CrateTrackerZK:PauseLocalDetections();
    end
end

function Area:PauseAllDetections()
    local wasPaused = self.detectionPaused == true;
    self.detectionPaused = true;
    if not wasPaused then
        Logger:Debug("Area", "状态", "区域无效，暂停所有检测");
    end
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
    local accessMode, playerMapID, targetMapData, instanceType, isInstance = ResolveAreaAccess(self, currentMapID);
    local previousAccessMode = self.lastAccessMode;
    local canProcessTeamMessages = accessMode == self.AccessMode.FULL_TRACKING or accessMode == self.AccessMode.SYNC_ONLY;
    
    if Logger and Logger.debugEnabled then
        local mapName = playerMapID and (Localization and Localization:GetMapName(playerMapID) or tostring(playerMapID)) or "未知";
        Logger:DebugLimited("area:check_" .. (playerMapID or 0), "Area", "状态", 
            string.format("【区域检查】地图=%s，副本类型=%s，访问模式=%s，区域有效=%s，团队消息=%s", 
                mapName,
                instanceType or "无",
                accessMode or "unknown",
                accessMode == self.AccessMode.FULL_TRACKING and "是" or "否",
                canProcessTeamMessages and "是" or "否"));
    end
    
    if isInstance then
        self.lastAccessMode = self.AccessMode.DISABLED;
        self.lastAreaValidState = false;
        if previousAccessMode ~= self.AccessMode.DISABLED then
            Logger:Debug("Area", "区域", DT("DebugAreaInvalidInstance"));
        end
        self:PauseAllDetections();
        return false;
    end
    
    if not playerMapID then
        self.lastAccessMode = self.AccessMode.DISABLED;
        self.lastAreaValidState = false;
        if previousAccessMode ~= self.AccessMode.DISABLED then
            Logger:Debug("Area", "区域", DT("DebugAreaCannotGetMapID"));
        end
        self:PauseAllDetections();
        return false;
    end

    if accessMode == self.AccessMode.SYNC_ONLY then
        local syncStateChanged = previousAccessMode ~= self.AccessMode.SYNC_ONLY;
        self.lastAccessMode = self.AccessMode.SYNC_ONLY;
        self.lastAreaValidState = false;
        self:PauseLocalDetections();

        if syncStateChanged then
            Logger:Debug("Area", "区域", string.format(
                "区域变化：有效 -> 同步模式，地图ID=%d（主城禁用本地检测，保留团队消息同步）",
                playerMapID
            ));
        end

        if CrateTrackerZK.StartCleanupTicker and not CrateTrackerZK.cleanupTicker then
            CrateTrackerZK:StartCleanupTicker();
        end
        if CrateTrackerZK.StartAutoTeamReportTicker and not CrateTrackerZK.autoReportTicker then
            CrateTrackerZK:StartAutoTeamReportTicker();
        end
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(playerMapID);
    if not mapInfo then return false end

    if targetMapData then
        self.lastAccessMode = self.AccessMode.FULL_TRACKING;
        if previousAccessMode ~= self.AccessMode.FULL_TRACKING or self.lastAreaValidState ~= true or self.detectionPaused then
            self.lastAreaValidState = true;
            local matchedMapName = (Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData))
                or (Localization and Localization:GetMapName(targetMapData.mapID))
                or (mapInfo.name or tostring(playerMapID));
            Logger:Debug("Area", "区域", string.format("区域变化：无效 -> 有效，地图=%s", matchedMapName));
            self:ResumeAllDetections();
        end
        return true;
    end

    self.lastAccessMode = self.AccessMode.DISABLED;
    self.lastAreaValidState = false;
    if previousAccessMode ~= self.AccessMode.DISABLED then
        Logger:Debug("Area", "区域", string.format("区域变化：有效 -> 无效，地图=%s（不在列表中）", 
            mapInfo.name or tostring(playerMapID)));
    end
    self:PauseAllDetections();
    return false;
end
