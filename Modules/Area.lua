-- Area.lua
-- 检查玩家所在区域是否有效（非副本/战场），控制检测功能开关

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local Area = BuildEnv("Area");

Area.lastAreaValidState = nil;
Area.detectionPaused = false;

local function DebugPrint(msg, ...)
    Logger:Debug("Area", "调试", msg, ...);
end

local function DT(key)
    return Logger:GetDebugText(key);
end

function Area:GetCurrentMapId()
    return C_Map.GetBestMapForUnit("player");
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

function Area:CheckAndUpdateAreaValid()
    local instanceType = select(4, GetInstanceInfo());
    local isInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario");
    
    if Logger and Logger.debugEnabled then
        local currentMapID = self:GetCurrentMapId();
        local mapName = currentMapID and (Localization and Localization:GetMapName(currentMapID) or tostring(currentMapID)) or "未知";
        Logger:DebugLimited("area:check_" .. (currentMapID or 0), "Area", "状态", 
            string.format("【区域检查】地图=%s，副本类型=%s，区域有效=%s", 
                mapName,
                instanceType or "无",
                not isInstance and "是" or "否"));
    end
    
    if isInstance then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            Logger:Debug("Area", "区域", DT("DebugAreaInvalidInstance"));
            self:PauseAllDetections();
        end
        return false;
    end
    
    local currentMapID = self:GetCurrentMapId();
    if not currentMapID then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            Logger:Debug("Area", "区域", DT("DebugAreaCannotGetMapID"));
            self:PauseAllDetections();
        end
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if not mapInfo then return false end
    
    if Data then
        local maps = Data:GetAllMaps();
        local isValid = false;
        local matchedMapName = nil;
        
        for _, mapData in ipairs(maps) do
            if mapData.mapID == currentMapID then
                isValid = true;
                if Localization then
                    matchedMapName = Localization:GetMapName(currentMapID);
                end
                break;
            end
        end
        
        if not isValid and mapInfo.parentMapID then
            for _, mapData in ipairs(maps) do
                if mapData.mapID == mapInfo.parentMapID then
                    isValid = true;
                    if Localization then
                        matchedMapName = Localization:GetMapName(mapInfo.parentMapID);
                    end
                    break;
                end
            end
        end
        
        if isValid then
            if self.lastAreaValidState ~= true then
                self.lastAreaValidState = true;
                Logger:Debug("Area", "区域", string.format("区域变化：无效 -> 有效，地图=%s", 
                    matchedMapName or (mapInfo.name or tostring(currentMapID))));
                self:ResumeAllDetections();
            end
            return true;
        else
            if self.lastAreaValidState ~= false then
                self.lastAreaValidState = false;
                Logger:Debug("Area", "区域", string.format("区域变化：有效 -> 无效，地图=%s（不在列表中）", 
                    mapInfo.name or tostring(currentMapID)));
                self:PauseAllDetections();
            end
            return false;
        end
    end
    
    return false;
end

