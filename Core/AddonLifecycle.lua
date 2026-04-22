-- AddonLifecycle.lua - Core 初始化与重建流程

local AddonLifecycle = BuildEnv("CrateTrackerZKAddonLifecycle")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local Analytics = BuildEnv("CrateTrackerZKAnalytics")
local AddonRuntimeCoordinator = BuildEnv("AddonRuntimeCoordinator")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local TickerController = BuildEnv("CrateTrackerZKTickerController")
local RuntimeResetManager = BuildEnv("RuntimeResetManager")

local function ResetRuntimeState()
    if RuntimeResetManager and RuntimeResetManager.ResetSharedRuntimeState then
        RuntimeResetManager:ResetSharedRuntimeState()
    end
end

local function EnsureSavedVariables()
    if RuntimeResetManager and RuntimeResetManager.EnsureSavedVariables then
        RuntimeResetManager:EnsureSavedVariables()
        return
    end

    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {}
    end
    if type(CRATETRACKERZK_DB) ~= "table" then
        CRATETRACKERZK_DB = {}
    end
    if type(CRATETRACKERZK_TRAJECTORY_DB) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB = {}
    end
end

function AddonLifecycle:OnLogin()
    EnsureSavedVariables()

    if Localization and Localization.Initialize and not Localization.isInitialized then
        Localization:Initialize()
    end
    if AddonRuntimeCoordinator and AddonRuntimeCoordinator.BootstrapOnLogin then
        return AddonRuntimeCoordinator:BootstrapOnLogin()
    end
end

function AddonLifecycle:Reinitialize()
    return self:OnLogin()
end

return AddonLifecycle
