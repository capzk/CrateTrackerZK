-- Analytics.lua - Wago Analytics 最小接入

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)
local Analytics = BuildEnv("CrateTrackerZKAnalytics")

local function GetCurrentExpansionID()
    if Data and Data.GetCurrentExpansionID then
        local expansionID = Data:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    if AppContext and AppContext.GetCurrentExpansionID then
        local expansionID = AppContext:GetCurrentExpansionID()
        if expansionID then
            return expansionID
        end
    end
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        return ExpansionConfig:GetCurrentExpansionID()
    end
    return nil
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

    local expansionID = GetCurrentExpansionID()

    analytics:Switch("addon_loaded", true)
    analytics:Switch("map_version_11_0", expansionID == "11.0")
    analytics:Switch("map_version_12_0", expansionID == "12.0")

    return true
end

Analytics:GetClient()

return Analytics
