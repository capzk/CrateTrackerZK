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
    local defaultInterval = ResolveDefaultInterval(crates, maps)

    self.MAP_CONFIG.current_maps = maps or {}
    self.MAP_CONFIG.activeExpansion = nil
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
