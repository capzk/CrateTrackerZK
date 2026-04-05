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

function Area:CanProcessTeamMessages()
    if IsInInstance and IsInInstance() then
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
    self.detectionPaused = true;
    if CrateTrackerZK.PauseLocalDetections then
        CrateTrackerZK:PauseLocalDetections();
    end
end

function Area:PauseAllDetections()
    self.detectionPaused = true;
    if CrateTrackerZK.PauseAllDetections then
        CrateTrackerZK:PauseAllDetections();
    end
end

function Area:ResumeAllDetections()
    if not self.detectionPaused then
        return;
    end
    self.detectionPaused = false;
    if CrateTrackerZK.ResumeAllDetections then
        CrateTrackerZK:ResumeAllDetections();
    end
end

function Area:CheckAndUpdateAreaValid(currentMapID)
    local accessMode, playerMapID, targetMapData, _, isInstance = ResolveAreaAccess(self, currentMapID);
    local previousAccessMode = self.lastAccessMode;
    
    if isInstance then
        self.lastAccessMode = self.AccessMode.DISABLED;
        self.lastAreaValidState = false;
        self:PauseAllDetections();
        return false;
    end
    
    if not playerMapID then
        self.lastAccessMode = self.AccessMode.DISABLED;
        self.lastAreaValidState = false;
        self:PauseAllDetections();
        return false;
    end

    if accessMode == self.AccessMode.SYNC_ONLY then
        self.lastAccessMode = self.AccessMode.SYNC_ONLY;
        self.lastAreaValidState = false;
        self:PauseLocalDetections();

        if CrateTrackerZK.StartCleanupTicker and not CrateTrackerZK.cleanupTicker then
            CrateTrackerZK:StartCleanupTicker();
        end
        if CrateTrackerZK.StartAutoTeamReportTicker and not CrateTrackerZK.autoReportTicker then
            CrateTrackerZK:StartAutoTeamReportTicker();
        end
        return false;
    end
    
    if not C_Map.GetMapInfo(playerMapID) then
        self.lastAccessMode = self.AccessMode.DISABLED;
        self.lastAreaValidState = false;
        self:PauseAllDetections();
        return false;
    end

    if targetMapData then
        self.lastAccessMode = self.AccessMode.FULL_TRACKING;
        if previousAccessMode ~= self.AccessMode.FULL_TRACKING or self.lastAreaValidState ~= true or self.detectionPaused then
            self.lastAreaValidState = true;
            self:ResumeAllDetections();
        end
        return true;
    end

    self.lastAccessMode = self.AccessMode.DISABLED;
    self.lastAreaValidState = false;
    self:PauseAllDetections();
    return false;
end
