-- Phase.lua
-- 检测和更新位面（Phase）信息，通过鼠标悬停NPC获取位面ID

local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");

Phase.anyInstanceIDAcquired = false;
Phase.lastReportedInstanceID = nil;

function Phase:Reset()
    self.anyInstanceIDAcquired = false;
    self.lastReportedInstanceID = nil;
    Logger:Debug("Phase", "重置", "已重置位面检测状态");
end

local function DT(key)
    return Logger:GetDebugText(key);
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
        local instanceID = self:GetLayerFromNPC();
        
        if instanceID ~= targetMapData.instance then
            if instanceID then
                local oldInstance = targetMapData.instance;
                Data:UpdateMap(targetMapData.id, { lastInstance = oldInstance, instance = instanceID });
                
                if oldInstance then
                    Logger:Info("Phase", "位面", string.format(L["InstanceChangedTo"], Data:GetMapDisplayName(targetMapData), instanceID));
                    Logger:Debug("Phase", "位面", string.format("位面变化：%s -> %s，地图=%s", 
                        oldInstance, instanceID, Data:GetMapDisplayName(targetMapData)));
                else
                    if not self.lastReportedInstanceID or self.lastReportedInstanceID ~= instanceID then
                        Logger:Info("Phase", "位面", string.format(L["CurrentInstanceID"], instanceID));
                        Logger:Debug("Phase", "位面", string.format("首次获取到位面ID：%s，地图=%s", 
                            instanceID, Data:GetMapDisplayName(targetMapData)));
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
                Logger:Info("Phase", "位面", L["NoInstanceAcquiredHint"]);
                self.anyInstanceIDAcquired = true;
            end
        end
    end
end

