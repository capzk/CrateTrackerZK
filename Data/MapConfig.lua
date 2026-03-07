-- MapConfig.lua - 地图配置（支持按资料片版本切换）

local Data = BuildEnv("Data")
local ExpansionConfig = BuildEnv("ExpansionConfig")

local DEFAULT_INTERVAL = 1100

local function BuildMapsFromExpansion()
    if ExpansionConfig and ExpansionConfig.GetActiveMapConfigs then
        local maps, expansionID = ExpansionConfig:GetActiveMapConfigs()
        if maps then
            return maps, expansionID
        end
    end
    local expansionID = (ExpansionConfig and ExpansionConfig.GetCurrentExpansionID and ExpansionConfig:GetCurrentExpansionID()) or "unknown"
    return {}, expansionID
end

local function BuildCratesFromExpansion()
    if ExpansionConfig and ExpansionConfig.GetCurrentAirdropCrates then
        local crates = ExpansionConfig:GetCurrentAirdropCrates()
        if crates then
            return crates
        end
    end
    return {}
end

local function BuildVignetteIDsFromExpansion()
    if ExpansionConfig and ExpansionConfig.GetCurrentAirdropPlaneVignetteIDs then
        local ids = ExpansionConfig:GetCurrentAirdropPlaneVignetteIDs()
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
    if ExpansionConfig and ExpansionConfig.IsAirdropPlaneVignetteID then
        return ExpansionConfig:IsAirdropPlaneVignetteID(vignetteID)
    end
    return false
end

Data:ReloadMapConfigForExpansion()

return Data
