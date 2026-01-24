local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

Data.MAP_CONFIG = {
    version = "1.0.0",
    
    current_maps = {
        {
            mapID = 2248,
            interval = 1100,
            enabled = true,
            priority = 1,
        },
        {
            mapID = 2369,
            interval = 1100,
            enabled = true,
            priority = 2,
        },
        {
            mapID = 2371,
            interval = 1100,
            enabled = true,
            priority = 3,
        },
        {
            mapID = 2346,
            interval = 1100,
            enabled = true,
            priority = 4,
        },
        {
            mapID = 2215,
            interval = 1100,
            enabled = true,
            priority = 5,
        },
        {
            mapID = 2214,
            interval = 1100,
            enabled = true,
            priority = 6,
        },
        {
            mapID = 2255,
            interval = 1100,
            enabled = true,
            priority = 7,
        },
    },
    
    airdrop_crates = {
        {
            code = "WarSupplyCrate",
            enabled = true,
        },
    },
    
    defaults = {
        interval = 1100,
        enabled = true,
    },
};

function Data:GetMapConfig(mapID)
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.mapID == mapID then
            return mapConfig;
        end
    end
    return nil;
end

function Data:GetEnabledMaps()
    local enabledMaps = {};
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.enabled then
            table.insert(enabledMaps, mapConfig);
        end
    end
    return enabledMaps;
end

function Data:GetAirdropCrateConfig(crateCode)
    for _, crateConfig in ipairs(self.MAP_CONFIG.airdrop_crates) do
        if crateConfig.code == crateCode then
            return crateConfig;
        end
    end
    return nil;
end

function Data:SetMapEnabled(mapID, enabled)
    local mapConfig = self:GetMapConfig(mapID);
    if mapConfig then
        mapConfig.enabled = enabled;
        return true;
    end
    return false;
end

function Data:SetMapInterval(mapID, interval)
    local mapConfig = self:GetMapConfig(mapID);
    if mapConfig then
        mapConfig.interval = interval;
        return true;
    end
    return false;
end

function Data:AddMapConfig(mapID, interval, enabled, priority)
    if self:GetMapConfig(mapID) then
        return false, "地图ID已存在";
    end
    
    local newConfig = {
        mapID = mapID,
        interval = interval or self.MAP_CONFIG.defaults.interval,
        enabled = enabled ~= false, -- 默认启用
        priority = priority or (#self.MAP_CONFIG.current_maps + 1),
    };
    
    table.insert(self.MAP_CONFIG.current_maps, newConfig);
    return true;
end

function Data:ValidateMapConfig()
    local issues = {};
    
    local seenMapIDs = {};
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if seenMapIDs[mapConfig.mapID] then
            table.insert(issues, {
                type = "duplicate_mapID",
                mapID = mapConfig.mapID,
                message = "重复的地图ID"
            });
        else
            seenMapIDs[mapConfig.mapID] = true;
        end
    end
    
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if not mapConfig.mapID or type(mapConfig.mapID) ~= "number" then
            table.insert(issues, {
                type = "missing_mapID",
                config = mapConfig,
                message = "缺少或无效的地图ID"
            });
        end
        
        if not mapConfig.interval or mapConfig.interval <= 0 then
            table.insert(issues, {
                type = "invalid_interval",
                mapID = mapConfig.mapID,
                message = "无效的刷新间隔"
            });
        end
    end
    
    return issues;
end

return Data;