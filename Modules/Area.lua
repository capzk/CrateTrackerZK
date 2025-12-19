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
            DebugPrint("【地图有效性】区域无效（副本/战场/室内），插件已自动暂停");
            self:PauseAllDetections();
        end
        return false;
    end
    
    local currentMapID = self:GetCurrentMapId();
    if not currentMapID then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            DebugPrint("【地图有效性】无法获取地图ID");
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
    
    -- 检查是否在主城
    if currentMapName == "多恩诺嘉尔" then
        if self.lastAreaValidState ~= false then
            self.lastAreaValidState = false;
            DebugPrint("【地图有效性】区域无效（主城），插件已自动暂停: " .. currentMapName);
            self:PauseAllDetections();
        end
        return false;
    end
    
    -- 检查地图列表
    if Data then
        local maps = Data:GetAllMaps();
        local isValid = false;
        local matchedMapName = nil;
        
        local cleanCurrent = string.lower(string.gsub(currentMapName, "[%p ]", ""));
        local cleanParent = string.lower(string.gsub(parentMapName, "[%p ]", ""));
        
        for _, mapData in ipairs(maps) do
            local cleanMap = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
            if cleanMap == cleanCurrent then
                isValid = true;
                matchedMapName = currentMapName;
                break;
            elseif cleanParent ~= "" and cleanMap == cleanParent then
                isValid = true;
                matchedMapName = parentMapName;
                break;
            end
        end
        
        if isValid then
            if self.lastAreaValidState ~= true then
                self.lastAreaValidState = true;
                DebugPrint("【地图有效性】区域有效，插件已启用: " .. (matchedMapName or currentMapName));
                self:ResumeAllDetections();
            end
            return true;
        else
            if self.lastAreaValidState ~= false then
                self.lastAreaValidState = false;
                DebugPrint("【地图有效性】区域无效（不在有效地图列表中），插件已自动暂停: " .. currentMapName);
                self:PauseAllDetections();
            end
            return false;
        end
    end
    
    return false;
end

