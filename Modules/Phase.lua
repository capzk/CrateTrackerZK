local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;
local Phase = BuildEnv("Phase");

Phase.anyInstanceIDAcquired = false;
Phase.lastReportedInstanceID = nil;

local function DebugPrint(msg, ...)
    Logger:Debug("Phase", "调试", msg, ...);
end

local function DT(key)
    return Logger:GetDebugText(key);
end

local function DebugPrintLimited(key, msg, ...)
    Logger:DebugLimited(key, "Phase", "调试", msg, ...);
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
        
        -- 输出位面检测状态（限流：每10秒一次，避免频繁输出）
        if Logger and Logger.debugEnabled then
            Logger:DebugLimited("phase:status_" .. (targetMapData.id or 0), "Phase", "状态", 
                string.format("【位面检测】地图=%s，当前位面=%s，尝试获取位面=%s", 
                    Data:GetMapDisplayName(targetMapData),
                    targetMapData.instance or "未获取",
                    instanceID and instanceID or "未获取（需要鼠标悬停NPC或选择目标）"));
        end
        
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
                        Logger:Debug("Phase", "位面", string.format("获取到位面ID：%s，地图=%s", 
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

