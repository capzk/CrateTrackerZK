-- Analytics.lua - Wago Analytics 最小接入

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)
local Analytics = BuildEnv("CrateTrackerZKAnalytics")
local ExpansionConfig = BuildEnv("ExpansionConfig")

local function GetTrackedExpansionLookup()
    local lookup = {}
    if ExpansionConfig and ExpansionConfig.GetTrackedExpansionIDs then
        for _, expansionID in ipairs(ExpansionConfig:GetTrackedExpansionIDs() or {}) do
            lookup[expansionID] = true
        end
    end
    return lookup
end

local function BuildAnalyticsExpansionSwitchKey(expansionID)
    local normalized = tostring(expansionID or "unknown"):gsub("[^%w]+", "_"):lower()
    return "map_version_" .. normalized
end

function Analytics:GetClient()
    if self.client then
        return self.client
    end
    if not LibStub then
        return nil
    end

    self.client = LibStub("WagoAnalytics"):RegisterAddon(ADDON_NAME)
    CrateTrackerZK.WagoAnalytics = self.client
    return self.client
end

function Analytics:RecordSessionState()
    local analytics = self:GetClient()
    if not analytics then
        return false
    end

    local trackedExpansionLookup = GetTrackedExpansionLookup()

    analytics:Switch("addon_loaded", true)
    for _, expansionInfo in ipairs(ExpansionConfig and ExpansionConfig.GetAvailableExpansions and ExpansionConfig:GetAvailableExpansions() or {}) do
        analytics:Switch(
            BuildAnalyticsExpansionSwitchKey(expansionInfo.id),
            trackedExpansionLookup[expansionInfo.id] == true
        )
    end

    return true
end

Analytics:GetClient()

return Analytics
