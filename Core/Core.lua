-- Core.lua - 插件核心门面

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)

local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local TickerController = BuildEnv("CrateTrackerZKTickerController")
local AddonLifecycle = BuildEnv("CrateTrackerZKAddonLifecycle")
local EventRouter = BuildEnv("CrateTrackerZKEventRouter")

CoreShared:EnsureReloadHook()

function CrateTrackerZK:IsAddonEnabled()
    return CoreShared:IsAddonEnabled()
end

function CrateTrackerZK:IsAreaActive()
    return CoreShared:IsAreaActive()
end

function CrateTrackerZK:GetCurrentMapID()
    return CoreShared:GetCurrentMapID()
end

function CrateTrackerZK:Reinitialize()
    return AddonLifecycle:Reinitialize()
end

function CrateTrackerZK:PauseAllDetections()
    return TickerController:PauseAllDetections(self)
end

function CrateTrackerZK:ResumeAllDetections()
    return TickerController:ResumeAllDetections(self)
end

function CrateTrackerZK:StartMapIconDetection(interval)
    return TickerController:StartMapIconDetection(self, interval)
end

function CrateTrackerZK:StopMapIconDetection()
    return TickerController:StopMapIconDetection(self)
end

function CrateTrackerZK:StartCleanupTicker()
    return TickerController:StartCleanupTicker(self)
end

function CrateTrackerZK:StopCleanupTicker()
    return TickerController:StopCleanupTicker(self)
end

function CrateTrackerZK:StartAutoTeamReportTicker()
    return TickerController:StartAutoTeamReportTicker(self)
end

function CrateTrackerZK:StopAutoTeamReportTicker()
    return TickerController:StopAutoTeamReportTicker(self)
end

function CrateTrackerZK:RestartAutoTeamReportTicker()
    return TickerController:RestartAutoTeamReportTicker(self)
end

EventRouter:RegisterEventFrame()
EventRouter:RegisterTooltipHooks()

return CrateTrackerZK
