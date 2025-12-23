-- CrateTrackerZK - 地图配置文件（代号系统）
local ADDON_NAME = "CrateTrackerZK";
local Data = BuildEnv("Data");

-- ============================================================================
-- 地图配置（代号系统）
-- ============================================================================

Data.MAP_CONFIG = {
    -- 配置版本（用于兼容性检查）
    version = "1.0.0",
    
    -- 当前启用的地图列表（使用代号系统）
    current_maps = {
        {
            code = "MAP_001",               -- 多恩岛/Isle of Dorn/多恩島
            interval = 1100,                -- 刷新间隔（秒）
            enabled = true,                 -- 是否启用
            priority = 1,                   -- 显示优先级
        },
        {
            code = "MAP_002",               -- 卡雷什/K'aresh/凱瑞西
            interval = 1100,
            enabled = true,
            priority = 2,
        },
        {
            code = "MAP_003",               -- 陨圣峪/Hallowfall/聖落之地
            interval = 1100,
            enabled = true,
            priority = 3,
        },
        {
            code = "MAP_004",               -- 艾基-卡赫特/Azj-Kahet/阿茲-卡罕特
            interval = 1100,
            enabled = true,
            priority = 4,
        },
        {
            code = "MAP_005",               -- 安德麦/Undermine/幽坑城
            interval = 1100,
            enabled = true,
            priority = 5,
        },
        {
            code = "MAP_006",               -- 喧鸣深窟/The Ringing Deeps/鳴響深淵
            interval = 1100,
            enabled = true,
            priority = 6,
        },
        {
            code = "MAP_007",               -- 海妖岛/Siren Isle/海妖島
            interval = 1100,
            enabled = true,
            priority = 7,
        },
    },
    
    -- 空投箱子配置（代号系统）
    airdrop_crates = {
        {
            code = "AIRDROP_CRATE_001",      -- 战争物资箱/War Supply Crate
            enabled = true,
        },
    },
    
    -- 默认配置
    defaults = {
        interval = 1100,                    -- 默认刷新间隔
        enabled = true,                     -- 默认启用状态
    },
};

-- ============================================================================
-- 配置访问API
-- ============================================================================

-- 获取地图配置
function Data:GetMapConfig(mapCode)
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.code == mapCode then
            return mapConfig;
        end
    end
    return nil;
end

-- 获取所有启用的地图
function Data:GetEnabledMaps()
    local enabledMaps = {};
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.enabled then
            table.insert(enabledMaps, mapConfig);
        end
    end
    return enabledMaps;
end

-- 获取空投箱子配置
function Data:GetAirdropCrateConfig(crateCode)
    for _, crateConfig in ipairs(self.MAP_CONFIG.airdrop_crates) do
        if crateConfig.code == crateCode then
            return crateConfig;
        end
    end
    return nil;
end

-- ============================================================================
-- 动态配置管理
-- ============================================================================

-- 启用/禁用地图
function Data:SetMapEnabled(mapCode, enabled)
    local mapConfig = self:GetMapConfig(mapCode);
    if mapConfig then
        mapConfig.enabled = enabled;
        return true;
    end
    return false;
end

-- 设置地图刷新间隔
function Data:SetMapInterval(mapCode, interval)
    local mapConfig = self:GetMapConfig(mapCode);
    if mapConfig then
        mapConfig.interval = interval;
        return true;
    end
    return false;
end

-- 添加新地图配置
function Data:AddMapConfig(mapCode, interval, enabled, priority)
    -- 检查是否已存在
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