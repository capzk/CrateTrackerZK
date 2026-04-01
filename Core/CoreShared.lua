-- CoreShared.lua - Core 共享状态与辅助函数

local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")

function CoreShared:EnsureReloadHook()
    if hooksecurefunc and not CrateTrackerZK.reloadHooked then
        hooksecurefunc("ReloadUI", function()
            CrateTrackerZK.isReloading = true
        end)
        CrateTrackerZK.reloadHooked = true
    end
end

function CoreShared:DebugPrint(msg, ...)
    Logger:Debug("Core", "调试", msg, ...)
end

function CoreShared:IsAddonEnabled()
    if not CRATETRACKERZK_UI_DB or CRATETRACKERZK_UI_DB.addonEnabled == nil then
        return true
    end
    return CRATETRACKERZK_UI_DB.addonEnabled == true
end

function CoreShared:IsAreaActive()
    if Area and Area.IsActive then
        return Area:IsActive()
    end
    if IsInInstance and IsInInstance() then
        return false
    end
    return Area and Area.lastAreaValidState == true and not Area.detectionPaused
end

function CoreShared:CanUseTrackedMapFeatures()
    if Area and Area.CanUseTrackedMapFeatures then
        return Area:CanUseTrackedMapFeatures()
    end
    return self:IsAreaActive()
end

function CoreShared:CanProcessTeamMessages()
    if Area and Area.CanProcessTeamMessages then
        return Area:CanProcessTeamMessages()
    end
    if IsInInstance and IsInInstance() then
        return false
    end
    return true
end

function CoreShared:GetCurrentMapID()
    if Area and Area.GetCurrentMapId then
        return Area:GetCurrentMapId()
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

function CoreShared:ClearAllPhaseCaches()
    if CRATETRACKERZK_UI_DB and type(CRATETRACKERZK_UI_DB.expansionUIData) == "table" then
        for _, bucket in pairs(CRATETRACKERZK_UI_DB.expansionUIData) do
            if type(bucket) == "table" and type(bucket.phaseCache) == "table" then
                for key in pairs(bucket.phaseCache) do
                    bucket.phaseCache[key] = nil
                end
            end
        end
    end

    if CRATETRACKERZK_UI_DB and type(CRATETRACKERZK_UI_DB.phaseCache) == "table" then
        for key in pairs(CRATETRACKERZK_UI_DB.phaseCache) do
            CRATETRACKERZK_UI_DB.phaseCache[key] = nil
        end
    end
end

return CoreShared
