-- CrateTrackerZK - 地图配置
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

Data.MAP_CONFIG = {
    version = "1.0.0",
    
    current_maps = {
        {
            code = "MAP_001",
            interval = 1100,
            enabled = true,
            priority = 1,
        },
        {
            code = "MAP_002",
            interval = 1100,
            enabled = true,
            priority = 2,
        },
        {
            code = "MAP_003",
            interval = 1100,
            enabled = true,
            priority = 3,
        },
        {
            code = "MAP_004",
            interval = 1100,
            enabled = true,
            priority = 4,
        },
        {
            code = "MAP_005",
            interval = 1100,
            enabled = true,
            priority = 5,
        },
        {
            code = "MAP_006",
            interval = 1100,
            enabled = true,
            priority = 6,
        },
        {
            code = "MAP_007",
            interval = 1100,
            enabled = true,
            priority = 7,
        },
    },
    
    airdrop_crates = {
        {
            code = "AIRDROP_CRATE_001",
            enabled = true,
        },
    },
    
    defaults = {
        interval = 1100,
        enabled = true,
    },
};

function Data:GetMapConfig(mapCode)
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.code == mapCode then
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

function Data:SetMapEnabled(mapCode, enabled)
    local mapConfig = self:GetMapConfig(mapCode);
    if mapConfig then
        mapConfig.enabled = enabled;
        return true;
    end
    return false;
end

function Data:SetMapInterval(mapCode, interval)
    local mapConfig = self:GetMapConfig(mapCode);
    if mapConfig then
        mapConfig.interval = interval;
        return true;
    end
    return false;
end

function Data:AddMapConfig(mapCode, interval, enabled, priority)
    if self:GetMapConfig(mapCode) then
        return false, "地图代号已存在";
    end
    
    local newConfig = {
        code = mapCode,
        interval = interval or self.MAP_CONFIG.defaults.interval,
        enabled = enabled ~= false, -- 默认启用
        priority = priority or (#self.MAP_CONFIG.current_maps + 1),
    };
    
    table.insert(self.MAP_CONFIG.current_maps, newConfig);
    return true;
end

-- ============================================================================
-- 配置验证
-- ============================================================================

-- 验证配置完整性
function Data:ValidateMapConfig()
    local issues = {};
    
    -- 检查重复的代号
    local seenCodes = {};
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if seenCodes[mapConfig.code] then
            table.insert(issues, {
                type = "duplicate_code",
                code = mapConfig.code,
                message = "重复的地图代号"
            });
        else
            seenCodes[mapConfig.code] = true;
        end
    end
    
    -- 检查必需字段
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if not mapConfig.code or mapConfig.code == "" then
            table.insert(issues, {
                type = "missing_code",
                config = mapConfig,
                message = "缺少地图代号"
            });
        end
        
        if not mapConfig.interval or mapConfig.interval <= 0 then
            table.insert(issues, {
                type = "invalid_interval",
                code = mapConfig.code,
                message = "无效的刷新间隔"
            });
        end
    end
    
    return issues;
end

return Data;