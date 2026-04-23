-- MapConfig.lua - 地图配置（支持按资料片自定义勾选追踪）

local Data = BuildEnv("Data")
local ExpansionConfig = BuildEnv("ExpansionConfig")

local DEFAULT_INTERVAL = 1100

local function BuildTrackedMaps()
    if ExpansionConfig and ExpansionConfig.GetTrackedMapConfigs then
        local maps = ExpansionConfig:GetTrackedMapConfigs()
        if maps then
            return maps
        end
    end
    return {}
end

local function BuildTrackedCrates()
    if ExpansionConfig and ExpansionConfig.GetTrackedAirdropCrates then
        local crates = ExpansionConfig:GetTrackedAirdropCrates()
        if crates then
            return crates
        end
    end
    return {}
end

local function BuildTrackedVignetteIDs()
    if ExpansionConfig and ExpansionConfig.GetTrackedAirdropPlaneVignetteIDs then
        local ids = ExpansionConfig:GetTrackedAirdropPlaneVignetteIDs()
        if ids then
            return ids
        end
    end
    return {}
end

local function BuildTrackedCrateVignetteIDs()
    if ExpansionConfig and ExpansionConfig.GetTrackedAirdropCrateVignetteIDs then
        local ids = ExpansionConfig:GetTrackedAirdropCrateVignetteIDs()
        if ids then
            return ids
        end
    end
    return {}
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
    version = "3.0.0",
    activeExpansion = nil,
    current_maps = {},
    airdrop_plane_vignette_ids = {},
    airdrop_plane_vignette_lookup = {},
    airdrop_crate_vignette_ids = {},
    airdrop_crate_vignette_lookup = {},
    airdrop_crates = {},
    defaults = {
        interval = DEFAULT_INTERVAL,
        enabled = true,
    },
}

function Data:ReloadMapConfigForExpansion()
    local maps = BuildTrackedMaps()
    local crates = BuildTrackedCrates()
    local vignetteIDs = BuildTrackedVignetteIDs()
    local crateVignetteIDs = BuildTrackedCrateVignetteIDs()
    local defaultInterval = ResolveDefaultInterval(crates, maps)
    local vignetteLookup = {}
    local crateVignetteLookup = {}

    for _, vignetteID in ipairs(vignetteIDs or {}) do
        if type(vignetteID) == "number" then
            vignetteLookup[vignetteID] = true
        end
    end
    for _, vignetteID in ipairs(crateVignetteIDs or {}) do
        if type(vignetteID) == "number" then
            crateVignetteLookup[vignetteID] = true
        end
    end

    self.MAP_CONFIG.current_maps = maps or {}
    self.MAP_CONFIG.activeExpansion = nil
    self.MAP_CONFIG.airdrop_crates = crates or {}
    self.MAP_CONFIG.airdrop_plane_vignette_ids = vignetteIDs or {}
    self.MAP_CONFIG.airdrop_plane_vignette_lookup = vignetteLookup
    self.MAP_CONFIG.airdrop_crate_vignette_ids = crateVignetteIDs or {}
    self.MAP_CONFIG.airdrop_crate_vignette_lookup = crateVignetteLookup
    self.MAP_CONFIG.defaults.interval = defaultInterval
    self.DEFAULT_REFRESH_INTERVAL = defaultInterval
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

    local lookup = self.MAP_CONFIG and self.MAP_CONFIG.airdrop_plane_vignette_lookup
    if type(lookup) == "table" then
        return lookup[vignetteID] == true
    end

    if ExpansionConfig and ExpansionConfig.IsAirdropPlaneVignetteID then
        return ExpansionConfig:IsAirdropPlaneVignetteID(vignetteID)
    end
    return false
end

function Data:GetAirdropCrateVignetteIDs()
    local ids = self.MAP_CONFIG and self.MAP_CONFIG.airdrop_crate_vignette_ids
    if type(ids) ~= "table" then
        return {}
    end
    return ids
end

function Data:IsAirdropCrateVignetteID(vignetteID)
    if type(vignetteID) ~= "number" then
        return false
    end

    local lookup = self.MAP_CONFIG and self.MAP_CONFIG.airdrop_crate_vignette_lookup
    if type(lookup) == "table" then
        return lookup[vignetteID] == true
    end

    if ExpansionConfig and ExpansionConfig.IsAirdropCrateVignetteID then
        return ExpansionConfig:IsAirdropCrateVignetteID(vignetteID)
    end
    return false
end

Data:ReloadMapConfigForExpansion()

return Data
