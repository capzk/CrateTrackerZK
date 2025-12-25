local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local Area = BuildEnv("Area");

Area.lastAreaValidState = nil;
Area.detectionPaused = false;

local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

local function DT(key)
    if Debug and Debug.GetText then
        return Debug:GetText(key);
    end
    return key;
end

function Area:GetCurrentMapId()
    return C_Map.GetBestMapForUnit("player");
end

function Area:PauseAllDetections()
    if self.detectionPaused then
        return;
    end
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

function Area:CheckAndUpdateAreaValid()
    local isIndoors = IsIndoors();
    local instanceType = select(4, GetInstanceInfo());
    local isInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario");
    
    if isIndoors or isInstance then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            DebugPrint(DT("DebugAreaInvalidInstance"));
            self:PauseAllDetections();
        end
        return false;
    end
    
    local currentMapID = self:GetCurrentMapId();
    if not currentMapID then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            DebugPrint(DT("DebugAreaCannotGetMapID"));
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
                DebugPrint(string.format(DT("DebugAreaValid"), matchedMapName or (mapInfo.name or tostring(currentMapID))));
                self:ResumeAllDetections();
            end
            return true;
        else
            if self.lastAreaValidState ~= false then
                self.lastAreaValidState = false;
                DebugPrint(string.format(DT("DebugAreaInvalidNotInList"), mapInfo.name or tostring(currentMapID)));
                self:PauseAllDetections();
            end
            return false;
        end
    end
    
    return false;
end

