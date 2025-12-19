-- CrateTrackerZK - 位面检测模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

-- 定义 Phase 命名空间
local Phase = BuildEnv("Phase");

-- 状态变量
Phase.anyInstanceIDAcquired = false;

-- 调试函数
local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

local function DebugPrintLimited(key, msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:PrintLimited(key, msg, ...);
    end
end

-- 获取位面信息（从NPC）
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

-- 更新位面信息
function Phase:UpdatePhaseInfo()
    -- 检查区域是否暂停（大前提）
    if Area and Area.detectionPaused then
        DebugPrintLimited("phase_detection_paused", "【位面检测】检测功能已暂停，跳过位面检测");
        return;
    end
    
    if not Data then return end
    
    local currentMapID = Area:GetCurrentMapId();
    if not currentMapID then
        DebugPrintLimited("no_map_id_phase", "无法获取当前地图ID，跳过位面信息更新");
        return;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if not mapInfo then return end
    
    local currentMapName = mapInfo.name or "";
    local parentMapName = "";
    if mapInfo.parentMapID then
        local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
        parentMapName = parentMapInfo and parentMapInfo.name or "";
    end
    
    -- 主城跳过
    if currentMapName == "多恩诺嘉尔" then
        DebugPrintLimited("capital_city_phase", "【位面检测】当前在主城（无效区域），跳过位面检测: " .. currentMapName);
        return;
    end
    
    -- 查找匹配地图
    local maps = Data:GetAllMaps();
    local targetMapData = nil;
    local isSubArea = false;
    
    local cleanCurrent = string.lower(string.gsub(currentMapName, "[%p ]", ""));
    local cleanParent = string.lower(string.gsub(parentMapName, "[%p ]", ""));
    
    for _, mapData in ipairs(maps) do
        local cleanMap = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
        if cleanMap == cleanCurrent then
            targetMapData = mapData;
            -- 判断子区域
            if parentMapName ~= "" then
                for _, pMap in ipairs(maps) do
                    if string.lower(string.gsub(pMap.mapName, "[%p ]", "")) == cleanParent then
                        isSubArea = true;
                        break;
                    end
                end
            end
            break;
        elseif cleanParent ~= "" and cleanMap == cleanParent then
            targetMapData = mapData;
            isSubArea = true;
            break;
        end
    end
    
    if targetMapData and not isSubArea then
        local instanceID = self:GetLayerFromNPC();
        
        if instanceID ~= targetMapData.instance then
            if instanceID then
                local oldInstance = targetMapData.instance;
                Data:UpdateMap(targetMapData.id, { lastInstance = oldInstance, instance = instanceID });
                
                if oldInstance then
                    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. string.format(L["InstanceChangedTo"], targetMapData.mapName, instanceID));
                else
                    DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. string.format(L["CurrentInstanceID"], instanceID));
                end
                
                if MainPanel and MainPanel.UpdateTable then
                    MainPanel:UpdateTable();
                end
            end
        elseif instanceID == targetMapData.instance and not targetMapData.lastInstance and targetMapData.instance then
            Data:UpdateMap(targetMapData.id, { lastInstance = targetMapData.instance });
        end
    end
    
    -- 提示获取位面
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

