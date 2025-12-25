local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");

Phase.anyInstanceIDAcquired = false;
Phase.lastReportedInstanceID = nil;

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

local function DebugPrintLimited(key, msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:PrintLimited(key, msg, ...);
    end
end

function Phase:GetLayerFromNPC()
    local unit = "mouseover";
    local guid = UnitGUID(unit);
    
    if not guid then
        unit = "target";
        guid = UnitGUID(unit);
    end
    
    if guid then
        local unitType, _, serverID, _, layerUID = strsplit("-", guid);
        if (unitType == "Creature" or unitType == "Vehicle") and serverID and layerUID then
            return serverID .. "-" .. layerUID;
        end
    end
    return nil;
end

function Phase:UpdatePhaseInfo()
    if Area and Area.detectionPaused then
        DebugPrintLimited("phase_detection_paused", DT("DebugPhaseDetectionPaused"));
        return;
    end
    
    if not Data then return end
    
    local currentMapID = Area:GetCurrentMapId();
    if not currentMapID then
        DebugPrintLimited("no_map_id_phase", DT("DebugPhaseNoMapID"));
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
        local instanceID = self:GetLayerFromNPC();
        
        if instanceID ~= targetMapData.instance then
            if instanceID then
                local oldInstance = targetMapData.instance;
                Data:UpdateMap(targetMapData.id, { lastInstance = oldInstance, instance = instanceID });
                
                if oldInstance then
                    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. string.format(L["InstanceChangedTo"], Data:GetMapDisplayName(targetMapData), instanceID));
                    DebugPrintLimited("phase_changed_" .. targetMapData.id, L["Prefix"] .. string.format(L["InstanceChangedTo"], Data:GetMapDisplayName(targetMapData), instanceID));
                else
                    if not self.lastReportedInstanceID or self.lastReportedInstanceID ~= instanceID then
                        DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. string.format(L["CurrentInstanceID"], instanceID));
                        self.lastReportedInstanceID = instanceID;
                    end
                end
                
                if MainPanel and MainPanel.UpdateTable then
                    MainPanel:UpdateTable();
                end
            end
        elseif instanceID and instanceID == targetMapData.instance and not targetMapData.lastInstance then
            Data:UpdateMap(targetMapData.id, { lastInstance = targetMapData.instance });
        end
        
        if not self.anyInstanceIDAcquired then
            local hasAny = false;
            for _, m in ipairs(maps) do
                if m.instance then hasAny = true; break end
            end
            if not hasAny then
                DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. L["NoInstanceAcquiredHint"]);
                self.anyInstanceIDAcquired = true;
            end
        end
    end
end

