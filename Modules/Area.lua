-- CrateTrackerZK - 区域管理模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);

-- 定义 Area 命名空间
local Area = BuildEnv("Area");

-- 状态变量
Area.lastAreaValidState = nil;
Area.detectionPaused = false;

-- 调试函数
local function DebugPrint(msg, ...)
    if Debug and Debug:IsEnabled() then
        Debug:Print(msg, ...);
    end
end

-- 获取当前地图ID
function Area:GetCurrentMapId()
    return C_Map.GetBestMapForUnit("player");
end

-- 暂停所有检测功能
function Area:PauseAllDetections()
    if self.detectionPaused then
        return;
    end
    self.detectionPaused = true;
    
    -- 通过 CrateTrackerZK 调用核心暂停逻辑
    if CrateTrackerZK.PauseAllDetections then
        CrateTrackerZK:PauseAllDetections();
    end
end

-- 恢复所有检测功能
function Area:ResumeAllDetections()
    if not self.detectionPaused then
        return;
    end
    self.detectionPaused = false;
    
    -- 通过 CrateTrackerZK 调用核心恢复逻辑
    if CrateTrackerZK.ResumeAllDetections then
        CrateTrackerZK:ResumeAllDetections();
    end
end

-- 地图有效性检测函数
function Area:CheckAndUpdateAreaValid()
    -- 检查是否在副本/战场/室内
    local isIndoors = IsIndoors();
    local instanceType = select(4, GetInstanceInfo());
    local isInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena" or instanceType == "scenario");
    
    if isIndoors or isInstance then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            local L = CrateTrackerZK.L;
            DebugPrint(L["DebugAreaInvalidInstance"]);
            self:PauseAllDetections();
        end
        return false;
    end
    
    local currentMapID = self:GetCurrentMapId();
    if not currentMapID then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            local L = CrateTrackerZK.L;
            DebugPrint(L["DebugAreaCannotGetMapID"]);
            self:PauseAllDetections();
        end
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if not mapInfo then return false end
    
    local currentMapName = mapInfo.name or "";
    local parentMapName = "";
    if mapInfo.parentMapID then
        local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
        parentMapName = parentMapInfo and parentMapInfo.name or "";
    end
    
    if Data then
        local maps = Data:GetAllMaps();
        local isValid = false;
        local matchedMapName = nil;
        
        for _, mapData in ipairs(maps) do
            if Data:IsMapNameMatch(mapData, currentMapName) then
                isValid = true;
                matchedMapName = currentMapName;
                break;
            elseif parentMapName ~= "" and Data:IsMapNameMatch(mapData, parentMapName) then
                isValid = true;
                matchedMapName = parentMapName;
                break;
            end
        end
        
        if isValid then
            if self.lastAreaValidState ~= true then
                self.lastAreaValidState = true;
                local L = CrateTrackerZK.L;
                DebugPrint(string.format(L["DebugAreaValid"], matchedMapName or currentMapName));
                self:ResumeAllDetections();
            end
            return true;
        else
            if self.lastAreaValidState ~= false then
                self.lastAreaValidState = false;
                local L = CrateTrackerZK.L;
                DebugPrint(string.format(L["DebugAreaInvalidNotInList"], currentMapName));
                self:PauseAllDetections();
            end
            return false;
        end
    end
    
    return false;
end

