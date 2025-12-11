-- 箱子追踪器数据管理文件

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义数据命名空间
local Data = BuildEnv('Data')

-- 确保Utils命名空间存在
if not Utils then
    Utils = BuildEnv('Utils')
end

-- 模拟魔兽世界API（仅用于语法检查）
if not time then
    time = function() return os.time() end;
    date = function(format, timestamp) return os.date(format, timestamp) end;
end

-- 默认刷新间隔设置为18分20秒（1100秒）
Data.DEFAULT_REFRESH_INTERVAL = 1100;

-- 内置地图列表（作为代码常量，不会被打包到数据文件中）
Data.DEFAULT_MAPS = {
    {name = "多恩岛", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "卡雷什", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "陨圣峪", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "艾基-卡赫特", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "安德麦", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "喧鸣深窟", interval = Data.DEFAULT_REFRESH_INTERVAL},
    {name = "海妖岛", interval = Data.DEFAULT_REFRESH_INTERVAL},
};

-- 运行时地图数据（合并内置地图列表和可变数据）
Data.maps = {};

-- 初始化数据
function Data:Initialize()
    -- 初始化或检查 SavedVariables（通用存储，所有角色共享）
    if not CRATETRACKER_DB then
        CRATETRACKER_DB = {
            version = 1,
            mapData = {}, -- 使用地图名称作为键，只存储可变数据
        }
    end
    
    -- 数据迁移1：从角色数据迁移到通用数据（如果存在角色数据）
    if CRATETRACKER_CHARACTER_DB and CRATETRACKER_CHARACTER_DB.mapData and next(CRATETRACKER_CHARACTER_DB.mapData) then
        -- 如果通用数据为空，则迁移角色数据
        if not CRATETRACKER_DB.mapData or not next(CRATETRACKER_DB.mapData) then
            CRATETRACKER_DB.mapData = {};
            for mapName, mapData in pairs(CRATETRACKER_CHARACTER_DB.mapData) do
                CRATETRACKER_DB.mapData[mapName] = mapData;
            end
            if Utils and Utils.Debug then
                Utils.Debug("数据迁移: 已从角色数据迁移到通用数据");
            end
        end
    end
    
    -- 数据迁移2：如果存在旧的数据结构（maps数组），转换为新结构（mapData字典）
    if CRATETRACKER_DB.maps and type(CRATETRACKER_DB.maps) == "table" and #CRATETRACKER_DB.maps > 0 then
        if not CRATETRACKER_DB.mapData then
            CRATETRACKER_DB.mapData = {};
        end
        
        -- 迁移旧数据
        for _, oldMapData in ipairs(CRATETRACKER_DB.maps) do
            if oldMapData.mapName then
                CRATETRACKER_DB.mapData[oldMapData.mapName] = {
                    instance = oldMapData.instance,
                    lastInstance = oldMapData.lastInstance,
                    lastRefreshInstance = oldMapData.lastRefreshInstance,
                    lastRefresh = oldMapData.lastRefresh,
                    createTime = oldMapData.createTime,
                };
            end
        end
        
        -- 清除旧数据结构
        CRATETRACKER_DB.maps = nil;
        
        if Utils and Utils.Debug then
            Utils.Debug("数据迁移: 已从旧结构迁移到新结构");
        end
    end
    
    -- 确保 mapData 字段存在
    if not CRATETRACKER_DB.mapData then
        CRATETRACKER_DB.mapData = {};
    end
    
    -- 构建完整的地图数据（合并内置地图列表和可变数据）
    self.maps = {};
    for i, defaultMap in ipairs(self.DEFAULT_MAPS) do
        local mapName = defaultMap.name;
        local savedData = CRATETRACKER_DB.mapData[mapName] or {};
        
        -- 合并内置数据和保存的可变数据
        local mapData = {
            id = i,
            mapName = mapName,
            interval = defaultMap.interval, -- 始终使用内置的间隔
            -- 可变数据从 SavedVariables 读取，如果不存在则为 nil
            instance = savedData.instance or nil,
            lastInstance = savedData.lastInstance or nil,
            lastRefreshInstance = savedData.lastRefreshInstance or nil,
            lastRefresh = savedData.lastRefresh or nil,
            nextRefresh = nil, -- 稍后计算
            createTime = savedData.createTime or time(),
        }
        
        -- 计算下次刷新时间
        if mapData.lastRefresh then
            local interval = mapData.interval;
            local currentTime = time();
            local cycles = math.floor((currentTime - mapData.lastRefresh) / interval);
            mapData.nextRefresh = mapData.lastRefresh + (cycles + 1) * interval;
            
            -- 如果仍未到当前时间，继续添加周期
            while mapData.nextRefresh <= currentTime do
                mapData.nextRefresh = mapData.nextRefresh + interval;
            end
        end
        
        -- 修复：如果instance有值但lastInstance为nil，初始化lastInstance（避免重新安装插件后显示红色）
        -- 这确保了重新安装插件时，如果SavedVariables中保留了instance数据，lastInstance也会被正确初始化
        if mapData.instance and not mapData.lastInstance then
            mapData.lastInstance = mapData.instance;
            -- 立即保存到SavedVariables，确保数据一致性
            if CRATETRACKER_DB and CRATETRACKER_DB.mapData then
                if not CRATETRACKER_DB.mapData[mapName] then
                    CRATETRACKER_DB.mapData[mapName] = {};
                end
                CRATETRACKER_DB.mapData[mapName].lastInstance = mapData.lastInstance;
            end
            if Utils and Utils.Debug then
                Utils.Debug("数据初始化: 自动初始化lastInstance", "地图名称=" .. mapName, "位面ID=" .. mapData.instance);
            end
        end
        
        table.insert(self.maps, mapData);
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("数据初始化完成", "地图数量=" .. #self.maps, "已保存数据的地图数量=" .. (function()
            local count = 0;
            for k, v in pairs(CRATETRACKER_DB.mapData) do
                if v.lastRefresh or v.instance then
                    count = count + 1;
                end
            end
            return count;
        end)());
    end
end

-- 保存地图的可变数据到 SavedVariables（通用存储）
function Data:SaveMapData(mapId)
    local mapData = self.maps[mapId];
    if not mapData then
        return false;
    end
    
    -- 确保数据库存在（通用存储，所有角色共享）
    if not CRATETRACKER_DB then
        CRATETRACKER_DB = {
            version = 1,
            mapData = {},
        }
    end
    if not CRATETRACKER_DB.mapData then
        CRATETRACKER_DB.mapData = {};
    end
    
    -- 只保存可变数据，不保存内置数据
    CRATETRACKER_DB.mapData[mapData.mapName] = {
        instance = mapData.instance,
        lastInstance = mapData.lastInstance,
        lastRefreshInstance = mapData.lastRefreshInstance,
        lastRefresh = mapData.lastRefresh,
        createTime = mapData.createTime,
    };
    
    if Utils and Utils.Debug then
        Utils.Debug("保存地图数据", "地图名称=" .. mapData.mapName);
    end
    
    return true;
end

-- 添加新地图数据已禁用
function Data:AddMap(mapName, instance, interval)
    -- 始终忽略传入的interval参数，使用默认值
    return nil;
end

-- 更新地图数据
function Data:UpdateMap(mapId, mapData)
    if self.maps[mapId] then
        if Utils and Utils.Debug then
            local updateInfo = {};
            for k, v in pairs(mapData) do
                table.insert(updateInfo, k .. "=" .. tostring(v));
            end
            Utils.Debug("接口调用: Data:UpdateMap", "地图ID=" .. mapId, "地图名称=" .. self.maps[mapId].mapName, "更新字段=" .. table.concat(updateInfo, ", "));
        end
        
        -- 只允许更新可变数据字段，不允许修改内置数据
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
        
        -- 自动保存到 SavedVariables
        self:SaveMapData(mapId);
        
        return true;
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("接口调用: Data:UpdateMap失败", "地图ID=" .. mapId, "原因=地图数据不存在");
    end
    return false;
end

-- 更新上次刷新时间
function Data:UpdateLastRefresh(mapId, lastRefresh)
    local mapData = self:GetMap(mapId);
    if not mapData then return false end;
    
    -- 更新上次刷新时间
    mapData.lastRefresh = lastRefresh;
    
    -- 保存当前位面ID作为刷新时的位面ID
    mapData.lastRefreshInstance = mapData.instance;
    
    -- 更新下次刷新时间
    self:UpdateNextRefresh(mapId);
    
    -- 自动保存到 SavedVariables
    self:SaveMapData(mapId);
    
    -- 打印更新信息
    print('|cff00ff00[空投物资追踪器] 上次刷新时间已更新为: ' .. self:FormatDateTime(lastRefresh) .. '，下次刷新时间: ' .. self:FormatDateTime(mapData.nextRefresh) .. '|r');
    
    return true;
end

-- 删除地图数据已禁用
function Data:DeleteMap(mapId)
    return false;
end

-- 更新下次刷新时间
function Data:UpdateNextRefresh(mapId)
    local mapData = self.maps[mapId];
    if not mapData then return false end;
    
    if mapData.lastRefresh then
        mapData.nextRefresh = mapData.lastRefresh + mapData.interval;
    else
        mapData.nextRefresh = nil;
    end
    return true;
end

-- 设置最后刷新时间
function Data:SetLastRefresh(mapId, timestamp)
    local mapData = self.maps[mapId];
    if not mapData then 
        if Utils and Utils.Debug then
            Utils.Debug("接口调用: Data:SetLastRefresh失败", "地图ID=" .. mapId, "原因=地图数据不存在");
        end
        return false 
    end
    
    timestamp = timestamp or time();
    
    if Utils and Utils.Debug then
        Utils.Debug("接口调用: Data:SetLastRefresh", "地图ID=" .. mapId, "地图名称=" .. mapData.mapName, "时间戳=" .. timestamp, "时间=" .. self:FormatDateTime(timestamp));
    end
    
    mapData.lastRefresh = timestamp;
    
    -- 保存当前位面ID作为刷新时的位面ID
    mapData.lastRefreshInstance = mapData.instance;
    
    self:UpdateNextRefresh(mapId);
    
    -- 自动保存到 SavedVariables
    self:SaveMapData(mapId);
    
    if Utils and Utils.Debug then
        Utils.Debug("刷新时间设置完成", "上次刷新=" .. self:FormatDateTime(mapData.lastRefresh), "下次刷新=" .. self:FormatDateTime(mapData.nextRefresh));
    end
    
    return true;
end

-- 获取所有地图数据
function Data:GetAllMaps()
    return self.maps;
end

-- 获取单个地图数据
function Data:GetMap(mapId)
    return self.maps[mapId];
end





-- 计算剩余时间（返回秒数）
function Data:CalculateRemainingTime(nextRefresh)
    if not nextRefresh then return nil end;
    local remaining = nextRefresh - time();
    return remaining > 0 and remaining or 0;
end

-- 检查并更新所有地图的下次刷新时间
function Data:CheckAndUpdateRefreshTimes()
    local currentTime = time();
    for mapId, mapData in ipairs(self.maps) do
        if mapData.nextRefresh and mapData.nextRefresh <= currentTime then
            -- 如果已到刷新时间，更新到下一个周期
            local interval = mapData.interval;
            local cycles = math.floor((currentTime - mapData.lastRefresh) / interval);
            
            -- 更新上次刷新时间和下次刷新时间
            mapData.lastRefresh = mapData.lastRefresh + cycles * interval;
            mapData.nextRefresh = mapData.lastRefresh + interval;
            
            -- 如果仍未到当前时间，继续添加周期
            while mapData.nextRefresh <= currentTime do
                mapData.lastRefresh = mapData.nextRefresh;
                mapData.nextRefresh = mapData.nextRefresh + interval;
            end
        end
    end
end

-- 格式化时间（将秒数转换为HH:MM:SS格式或MM:SS格式）
function Data:FormatTime(seconds, showOnlyMinutes)
    if not seconds then return "无记录" end;
    
    local hours = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    local secs = seconds % 60;
    
    if showOnlyMinutes then
        return string.format("%d分%02d秒", minutes + hours * 60, secs);
    else
        return string.format("%02d:%02d:%02d", hours, minutes, secs);
    end
end

-- 格式化日期时间（显示时:分:秒）
function Data:FormatDateTime(timestamp)
    if not timestamp then return "无记录" end;
    
    local date = date("%H:%M:%S", timestamp);
    return date;
end

-- 清除所有时间和位面数据（保留地图列表）
function Data:ClearAllData()
    if not self.maps or #self.maps == 0 then
        if Utils and Utils.Debug then
            Utils.Debug("清除数据: 地图列表为空，无需清除");
        end
        return false;
    end
    
    local clearedCount = 0;
    for i, mapData in ipairs(self.maps) do
        -- 清除时间和位面相关数据
        mapData.lastRefresh = nil;
        mapData.nextRefresh = nil;
        mapData.instance = nil;
        mapData.lastInstance = nil;
        mapData.lastRefreshInstance = nil;
        clearedCount = clearedCount + 1;
        
        -- 从 SavedVariables 中清除数据
        if CRATETRACKER_DB and CRATETRACKER_DB.mapData then
            CRATETRACKER_DB.mapData[mapData.mapName] = nil;
        end
        
        if Utils and Utils.Debug then
            Utils.Debug("清除数据: 已清除地图数据", "地图ID=" .. i, "地图名称=" .. mapData.mapName);
        end
    end
    
    -- 清除TimerManager的检测记录
    if TimerManager then
        TimerManager.lastDetectionTime = {};
        TimerManager.notificationCount = {};
        TimerManager.npcSpeechDetected = {};
        TimerManager.mapIconDetected = {};
        TimerManager.mapIconFirstDetectedTime = {};
        TimerManager.lastUpdateTime = {};
        if Utils and Utils.Debug then
            Utils.Debug("清除数据: 已清除TimerManager检测记录");
        end
    end
    
    if Utils and Utils.Debug then
        Utils.Debug("清除数据: 完成", "清除地图数量=" .. clearedCount);
    end
    
    -- 更新UI显示
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable();
    end
    
    return true;
end

-- 初始化数据
Data:Initialize();