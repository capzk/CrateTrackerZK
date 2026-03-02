-- MapConfig.lua - 地图配置（支持按资料片版本切换）

local Data = BuildEnv("Data")
local ExpansionConfig = BuildEnv("ExpansionConfig")

local DEFAULT_INTERVAL = 1100

local function BuildFallbackMaps()
    return {
        { mapID = 2248, interval = DEFAULT_INTERVAL, enabled = true, priority = 1 },
        { mapID = 2369, interval = DEFAULT_INTERVAL, enabled = true, priority = 2 },
        { mapID = 2371, interval = DEFAULT_INTERVAL, enabled = true, priority = 3 },
        { mapID = 2346, interval = DEFAULT_INTERVAL, enabled = true, priority = 4 },
        { mapID = 2215, interval = DEFAULT_INTERVAL, enabled = true, priority = 5 },
        { mapID = 2214, interval = DEFAULT_INTERVAL, enabled = true, priority = 6 },
        { mapID = 2255, interval = DEFAULT_INTERVAL, enabled = true, priority = 7 },
    }
end

local function BuildFallbackCrates()
    return {
        {
            code = "WarSupplyCrate",
            interval = DEFAULT_INTERVAL,
            enabled = true,
        },
    }
end

local function BuildFallbackVignetteIDs()
    return {}
end

local function BuildMapsFromExpansion()
    if ExpansionConfig and ExpansionConfig.GetActiveMapConfigs then
        local maps, expansionID = ExpansionConfig:GetActiveMapConfigs()
        if maps and #maps > 0 then
            return maps, expansionID
        end
    end
    return BuildFallbackMaps(), "fallback"
end

local function BuildCratesFromExpansion()
    if ExpansionConfig and ExpansionConfig.GetCurrentAirdropCrates then
        local crates = ExpansionConfig:GetCurrentAirdropCrates()
        if crates and #crates > 0 then
            return crates
        end
    end
    return BuildFallbackCrates()
end

local function BuildVignetteIDsFromExpansion()
    if ExpansionConfig and ExpansionConfig.GetCurrentAirdropPlaneVignetteIDs then
        local ids = ExpansionConfig:GetCurrentAirdropPlaneVignetteIDs()
        if ids and #ids > 0 then
            return ids
        end
    end
    return BuildFallbackVignetteIDs()
end

local function ResolveDefaultInterval(crates, maps)
    if crates then
        for _, crate in ipairs(crates) do
            if crate.enabled and crate.interval and crate.interval > 0 then
                return crate.interval
            end
        end
    end
    if maps and maps[1] and maps[1].interval and maps[1].interval > 0 then
        return maps[1].interval
    end
    return DEFAULT_INTERVAL
end

Data.MAP_CONFIG = {
    version = "2.0.0",
    activeExpansion = nil,

    current_maps = {},
    airdrop_plane_vignette_ids = {},

    airdrop_crates = {},

    defaults = {
        interval = DEFAULT_INTERVAL,
        enabled = true,
    },
}

function Data:ReloadMapConfigForExpansion()
    local maps, expansionID = BuildMapsFromExpansion()
    local crates = BuildCratesFromExpansion()
    local vignetteIDs = BuildVignetteIDsFromExpansion()
    local defaultInterval = ResolveDefaultInterval(crates, maps)

    self.MAP_CONFIG.current_maps = maps or {}
    self.MAP_CONFIG.activeExpansion = expansionID
    self.MAP_CONFIG.airdrop_crates = crates or {}
    self.MAP_CONFIG.airdrop_plane_vignette_ids = vignetteIDs or {}
    self.MAP_CONFIG.defaults.interval = defaultInterval
    self.DEFAULT_REFRESH_INTERVAL = defaultInterval
end

function Data:GetMapConfig(mapID)
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.mapID == mapID then
            return mapConfig
        end
    end
    return nil
end

function Data:GetEnabledMaps()
    local enabledMaps = {}
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if mapConfig.enabled then
            table.insert(enabledMaps, mapConfig)
        end
    end
    return enabledMaps
end

function Data:GetAirdropCrateConfig(crateCode)
    for _, crateConfig in ipairs(self.MAP_CONFIG.airdrop_crates) do
        if crateConfig.code == crateCode then
            return crateConfig
        end
    end
    return nil
end

function Data:GetAirdropPlaneVignetteIDs()
    local ids = self.MAP_CONFIG and self.MAP_CONFIG.airdrop_plane_vignette_ids
    if type(ids) ~= "table" then
        return {}
    end
    return ids
end

function Data:IsAirdropPlaneVignetteID(vignetteID)
    if type(vignetteID) ~= "number" then
        return false
    end
    for _, id in ipairs(self:GetAirdropPlaneVignetteIDs()) do
        if id == vignetteID then
            return true
        end
    end
    return false
end

function Data:SetMapEnabled(mapID, enabled)
    local mapConfig = self:GetMapConfig(mapID)
    if mapConfig then
        mapConfig.enabled = enabled
        return true
    end
    return false
end

function Data:SetMapInterval(mapID, interval)
    local mapConfig = self:GetMapConfig(mapID)
    if mapConfig then
        mapConfig.interval = interval
        return true
    end
    return false
end

function Data:AddMapConfig(mapID, interval, enabled, priority)
    if self:GetMapConfig(mapID) then
        return false, "地图ID已存在"
    end

    local newConfig = {
        mapID = mapID,
        interval = interval or self.MAP_CONFIG.defaults.interval,
        enabled = enabled ~= false,
        priority = priority or (#self.MAP_CONFIG.current_maps + 1),
    }

    table.insert(self.MAP_CONFIG.current_maps, newConfig)
    return true
end

function Data:ValidateMapConfig()
    local issues = {}

    local seenMapIDs = {}
    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if seenMapIDs[mapConfig.mapID] then
            table.insert(issues, {
                type = "duplicate_mapID",
                mapID = mapConfig.mapID,
                message = "重复的地图ID",
            })
        else
            seenMapIDs[mapConfig.mapID] = true
        end
    end

    for _, mapConfig in ipairs(self.MAP_CONFIG.current_maps) do
        if not mapConfig.mapID or type(mapConfig.mapID) ~= "number" then
            table.insert(issues, {
                type = "missing_mapID",
                config = mapConfig,
                message = "缺少或无效的地图ID",
            })
        end

        if not mapConfig.interval or mapConfig.interval <= 0 then
            table.insert(issues, {
                type = "invalid_interval",
                mapID = mapConfig.mapID,
                message = "无效的刷新间隔",
            })
        end
    end

    return issues
end

Data:ReloadMapConfigForExpansion()

return Data
