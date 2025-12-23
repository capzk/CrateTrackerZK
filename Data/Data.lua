-- CrateTrackerZK - 数据管理模块
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local L = CrateTrackerZK.L;

local Data = BuildEnv('Data')

Data.maps = {};
Data.manualInputLock = {};

function Data:Initialize()
    -- 初始化 SavedVariables（全新安装时可能不存在）
    if not CRATETRACKERZK_DB then
        CRATETRACKERZK_DB = {
            version = 1,
            mapData = {},
        }
    end
    
    -- 确保数据结构正确（处理旧版本或损坏的数据）
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {
            version = 1,
            mapData = {},
        }
    end
    
    -- 确保 version 字段存在
    if not CRATETRACKERZK_DB.version then
        CRATETRACKERZK_DB.version = 1;
    end
    
    -- 确保 mapData 字段存在且为表
    if type(CRATETRACKERZK_DB.mapData) ~= "table" then
        CRATETRACKERZK_DB.mapData = {};
    end
    
    self.maps = {};
    
    -- 检查 DEFAULT_MAPS 是否存在
    if not self.DEFAULT_MAPS or #self.DEFAULT_MAPS == 0 then
        if Utils then
            Utils.PrintError("Data:Initialize() - DEFAULT_MAPS is empty or nil");
        end
        return;
    end
    
    for i, defaultMap in ipairs(self.DEFAULT_MAPS) do
        if not defaultMap or not defaultMap.code then
            if Utils then
                Utils.PrintError("Data:Initialize() - Invalid map config at index " .. i);
            end
        else
            local mapCode = defaultMap.code;  -- 代号作为键（完全语言无关）
            local savedData = CRATETRACKERZK_DB.mapData[mapCode];
            
            -- 验证保存的数据结构（处理旧版本或损坏的数据）
            if savedData and type(savedData) ~= "table" then
                savedData = {};
            end
            savedData = savedData or {};
            
            -- 验证时间戳的有效性（必须是数字且在合理范围内）
            local lastRefresh = savedData.lastRefresh;
            if lastRefresh and (type(lastRefresh) ~= "number" or lastRefresh < 0 or lastRefresh > time() + 86400 * 365) then
                lastRefresh = nil;
            end
            
            local createTime = savedData.createTime;
            if createTime and (type(createTime) ~= "number" or createTime < 0 or createTime > time() + 86400 * 365) then
                createTime = time();
            end
            createTime = createTime or time();
            
            local mapData = {
                id = i,  -- 数组索引作为ID（可以任意调整数组顺序，ID会自动更新）
                code = mapCode,  -- 代号作为唯一标识符（MAP_001, MAP_002等）
                interval = defaultMap.interval or Data.DEFAULT_REFRESH_INTERVAL or 1100,
                instance = savedData.instance,
                lastInstance = savedData.lastInstance,
                lastRefreshInstance = savedData.lastRefreshInstance,
                lastRefresh = lastRefresh,
                nextRefresh = nil,
                createTime = createTime,
            }
            
            if mapData.lastRefresh then
                self:UpdateNextRefresh(i, mapData);
            end
            
            if mapData.instance and not mapData.lastInstance then
                mapData.lastInstance = mapData.instance;
                -- 确保 CRATETRACKERZK_DB.mapData[mapCode] 存在后再访问
                if not CRATETRACKERZK_DB.mapData[mapCode] then
                    CRATETRACKERZK_DB.mapData[mapCode] = {};
                end
                CRATETRACKERZK_DB.mapData[mapCode].lastInstance = mapData.lastInstance;
            end
            
            table.insert(self.maps, mapData);
        end
    end
end

function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    if not mapData or not mapData.code then return end
    
    -- 确保数据库结构存在
    if not CRATETRACKERZK_DB then
        CRATETRACKERZK_DB = {
            version = 1,
            mapData = {},
        }
    end
    
    if type(CRATETRACKERZK_DB.mapData) ~= "table" then
        CRATETRACKERZK_DB.mapData = {};
    end
    
    -- 只保存需要持久化的字段（不保存 nextRefresh，因为它是计算得出的）
    CRATETRACKERZK_DB.mapData[mapData.code] = {  -- 使用代号作为存储键
        instance = mapData.instance,
        lastInstance = mapData.lastInstance,
        lastRefreshInstance = mapData.lastRefreshInstance,
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime or time(),
    };
end

function Data:UpdateMap(mapId, mapData)
    if self.maps[mapId] then
        local allowedFields = {
            instance = true,
            lastInstance = true,
            lastRefreshInstance = true,
            lastRefresh = true,
            nextRefresh = true,
        };
        
        for k, v in pairs(mapData) do
            if allowedFields[k] then
                self.maps[mapId][k] = v;
            end
        end
        
        self:SaveMapData(mapId);
        return true;
    end
    return false;
end

-- 计算离当前时间最近的下一次刷新时间
-- 无论lastRefresh是过去时间还是未来时间，都找到离currentTime最近且大于currentTime的刷新点
local function CalculateNextRefreshTime(lastRefresh, interval, currentTime)
    if not lastRefresh or not interval or interval <= 0 then
        return nil;
    end
    
    currentTime = currentTime or time();
    
    local diffTime = currentTime - lastRefresh;
    local n = math.ceil(diffTime / interval);
    
    if n <= 0 then
        local forwardCount = math.floor((lastRefresh - currentTime) / interval);
        local candidateRefresh = lastRefresh - forwardCount * interval;
        
        if candidateRefresh <= currentTime then
            return candidateRefresh + interval;
        else
            local prevRefresh = candidateRefresh - interval;
            if prevRefresh > currentTime then
                while prevRefresh > currentTime do
                    candidateRefresh = prevRefresh;
                    prevRefresh = candidateRefresh - interval;
                end
            end
            return candidateRefresh;
        end
    else
        if n == 0 then
            n = 1;
        end
        return lastRefresh + n * interval;
    end
end

function Data:UpdateNextRefresh(mapId, mapData)
    mapData = mapData or self.maps[mapId];
    if not mapData then
        return;
    end
    
    if not mapData.lastRefresh then
        mapData.nextRefresh = nil;
        return;
    end
    
    local interval = mapData.interval or 1100;
    local currentTime = time();
    local lastRefresh = mapData.lastRefresh;
    
    mapData.nextRefresh = CalculateNextRefreshTime(lastRefresh, interval, currentTime);
end

function Data:SetLastRefresh(mapId, timestamp)
    local mapData = self.maps[mapId];
    if not mapData then return false end
    
    timestamp = timestamp or time();
    mapData.lastRefresh = timestamp;
    mapData.lastRefreshInstance = mapData.instance;
    
    self:UpdateNextRefresh(mapId);
    self:SaveMapData(mapId);
    
    return true;
end

function Data:GetAllMaps()
    return self.maps;
end

function Data:GetMap(mapId)
    return self.maps[mapId];
end

function Data:CalculateRemainingTime(nextRefresh)
    if not nextRefresh then return nil end;
    local remaining = nextRefresh - time();
    return remaining > 0 and remaining or 0;
end

function Data:CheckAndUpdateRefreshTimes()
    if not self.maps then return end
    
    for mapId, mapData in ipairs(self.maps) do
        if mapData and mapData.lastRefresh then
            self:UpdateNextRefresh(mapId, mapData);
        end
    end
end

function Data:FormatTime(seconds, showOnlyMinutes)
    local L = CrateTrackerZK.L;
    if not seconds then return L["NoRecord"] end;
    
    local hours = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    local secs = seconds % 60;
    
    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"];
        return string.format(formatStr, minutes + hours * 60, secs);
    else
        return string.format("%02d:%02d:%02d", hours, minutes, secs);
    end
end

function Data:FormatDateTime(timestamp)
    local L = CrateTrackerZK.L;
    if not timestamp then return L["NoRecord"] end;
    return date("%H:%M:%S", timestamp);
end

function Data:ClearAllData()
    if not self.maps then return false end
    
    for i, mapData in ipairs(self.maps) do
        if mapData then
            mapData.lastRefresh = nil;
            mapData.nextRefresh = nil;
            mapData.instance = nil;
            mapData.lastInstance = nil;
            mapData.lastRefreshInstance = nil;
            
            if CRATETRACKERZK_DB.mapData and mapData.code then
                CRATETRACKERZK_DB.mapData[mapData.code] = nil;  -- 使用代号作为键
            end
        end
    end
    
    if TimerManager then
        TimerManager.mapIconDetected = {};
        TimerManager.mapIconFirstDetectedTime = {};
        TimerManager.lastUpdateTime = {};
    end
    
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable();
    end
    
    return true;
end

function Data:GetMapDisplayName(mapData)
    if not mapData then return "" end;
    
    -- 使用本地化API通过代号获取当前语言的名称
    if Localization and mapData.code then
        return Localization:GetMapName(mapData.code);
    end
    
    -- 回退到代号（格式化显示）
    return mapData.code or "";
end

function Data:IsMapNameMatch(mapData, mapName)
    if not mapData or not mapName then return false end;
    
    -- 使用本地化API通过代号进行多语言匹配
    if Localization and mapData.code then
        return Localization:IsMapNameMatch(mapData, mapName);
    end
    
    -- 回退到简单的名称匹配（不应该到达这里）
    return false;
end
