-- TickerController.lua - Core 定时器与检测协调

local TickerController = BuildEnv("CrateTrackerZKTickerController")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")

local PHASE_TICK_INTERVAL = 10
local DEFAULT_TEAM_SHARED_WARMUP_INTERVAL = 540

local function CanRunPhasePolling()
    if not CoreShared:IsAreaActive() or not Phase then
        return false
    end
    if Phase.HasProbeUnit then
        return Phase:HasProbeUnit() == true
    end
    return true
end

local function UpdatePhaseNowIfActive()
    if CanRunPhasePolling() then
        local currentMapID = CoreShared:GetCurrentMapID()
        Phase:UpdatePhaseInfo(currentMapID)
        return true
    end
    return false
end

local function CanRunTeamSharedWarmup()
    if not CoreShared:IsAddonEnabled() then
        return false
    end
    if not TeamSharedWarmupService or not TeamSharedWarmupService.CanBroadcast then
        return false
    end
    return TeamSharedWarmupService:CanBroadcast() == true
end

function TickerController:StartPhaseTicker(owner)
    owner = owner or CrateTrackerZK
    if not CanRunPhasePolling() then
        self:StopPhaseTicker(owner)
        return false
    end
    if owner.phaseTimerTicker then
        return true
    end

    owner.phaseTimerTicker = C_Timer.NewTicker(PHASE_TICK_INTERVAL, function()
        if not CanRunPhasePolling() then
            self:StopPhaseTicker(owner)
            return
        end
        local tickerMapID = CoreShared:GetCurrentMapID()
        Phase:UpdatePhaseInfo(tickerMapID)
    end)
    owner.phaseTimerPaused = false
    UpdatePhaseNowIfActive()
    return true
end

function TickerController:StopPhaseTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.phaseTimerTicker then
        owner.phaseTimerTicker:Cancel()
        owner.phaseTimerTicker = nil
        owner.phaseTimerPaused = true
    end
end

function TickerController:RefreshPhaseTicker(owner)
    owner = owner or CrateTrackerZK
    if CanRunPhasePolling() then
        return self:StartPhaseTicker(owner)
    end
    self:StopPhaseTicker(owner)
    return false
end

function TickerController:PauseLocalDetections(owner)
    owner = owner or CrateTrackerZK

    self:StopPhaseTicker(owner)

    if owner.mapIconDetectionTicker then
        owner.mapIconDetectionTicker:Cancel()
        owner.mapIconDetectionTicker = nil
    end
end

function TickerController:PauseAllDetections(owner)
    owner = owner or CrateTrackerZK

    self:PauseLocalDetections(owner)

    if owner.cleanupTicker then
        owner.cleanupTicker:Cancel()
        owner.cleanupTicker = nil
    end

    if owner.autoReportTicker then
        owner.autoReportTicker:Cancel()
        owner.autoReportTicker = nil
    end
end

function TickerController:StartMapIconDetection(owner, interval)
    owner = owner or CrateTrackerZK
    if not TimerManager or not TimerManager.DetectMapIcons then
        Logger:Error("Core", "错误", "TimerManager不可用，无法启动地图图标检测")
        return false
    end

    if owner.mapIconDetectionTicker then
        owner.mapIconDetectionTicker:Cancel()
        owner.mapIconDetectionTicker = nil
    end

    interval = interval or 1
    owner.mapIconDetectionTicker = C_Timer.NewTicker(interval, function()
        if CoreShared:IsAreaActive() then
            local currentMapID = CoreShared:GetCurrentMapID()
            TimerManager:DetectMapIcons(currentMapID)
        end
    end)

    return true
end

function TickerController:StopMapIconDetection(owner)
    owner = owner or CrateTrackerZK
    if owner.mapIconDetectionTicker then
        owner.mapIconDetectionTicker:Cancel()
        owner.mapIconDetectionTicker = nil
    end
    return true
end

function TickerController:StartCleanupTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.cleanupTicker then
        return
    end
    if not UnifiedDataManager or not UnifiedDataManager.ClearExpiredTemporaryData then
        return
    end
    owner.cleanupTicker = C_Timer.NewTicker(300, function()
        local cleanupTime = Utils:GetCurrentTimestamp()
        UnifiedDataManager:ClearExpiredTemporaryData()
        if Notification and Notification.ClearExpiredTransientState then
            Notification:ClearExpiredTransientState(cleanupTime)
        end
        if PhaseTeamAlertCoordinator and PhaseTeamAlertCoordinator.PruneExpiredState then
            PhaseTeamAlertCoordinator:PruneExpiredState(cleanupTime)
        end
        if Logger and Logger.PruneMessageCache then
            Logger:PruneMessageCache(cleanupTime)
        end
    end)
end

function TickerController:StartTeamSharedWarmupTicker(owner)
    owner = owner or CrateTrackerZK
    if not CanRunTeamSharedWarmup() then
        self:StopTeamSharedWarmupTicker(owner)
        return false
    end
    if owner.teamSharedWarmupTicker then
        return true
    end

    local interval = TeamSharedWarmupService and TeamSharedWarmupService.BROADCAST_INTERVAL or DEFAULT_TEAM_SHARED_WARMUP_INTERVAL
    if type(interval) ~= "number" or interval <= 0 then
        interval = DEFAULT_TEAM_SHARED_WARMUP_INTERVAL
    end

    owner.teamSharedWarmupTicker = C_Timer.NewTicker(interval, function()
        if not CanRunTeamSharedWarmup() then
            self:StopTeamSharedWarmupTicker(owner)
            return
        end
        if TeamSharedWarmupService and TeamSharedWarmupService.StartBroadcastRound then
            TeamSharedWarmupService:StartBroadcastRound()
        end
    end)
    if TeamSharedWarmupService and TeamSharedWarmupService.StartBroadcastRound then
        TeamSharedWarmupService:StartBroadcastRound()
    end
    return true
end

function TickerController:StopTeamSharedWarmupTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.teamSharedWarmupTicker then
        owner.teamSharedWarmupTicker:Cancel()
        owner.teamSharedWarmupTicker = nil
    end
    if TeamSharedWarmupService and TeamSharedWarmupService.CancelPendingBroadcast then
        TeamSharedWarmupService:CancelPendingBroadcast()
    end
    return true
end

function TickerController:RefreshTeamSharedWarmupTicker(owner)
    owner = owner or CrateTrackerZK
    if CanRunTeamSharedWarmup() then
        return self:StartTeamSharedWarmupTicker(owner)
    end
    self:StopTeamSharedWarmupTicker(owner)
    return false
end

function TickerController:StopCleanupTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.cleanupTicker then
        owner.cleanupTicker:Cancel()
        owner.cleanupTicker = nil
    end
end

function TickerController:StartAutoTeamReportTicker(owner)
    owner = owner or CrateTrackerZK
    if not CoreShared:IsAddonEnabled() then
        return
    end
    if not Notification or not Notification.IsAutoTeamReportEnabled then
        return
    end
    if not Notification:IsAutoTeamReportEnabled() then
        return
    end
    if Notification.IsTeamNotificationEnabled and not Notification:IsTeamNotificationEnabled() then
        return
    end
    if not CoreShared:CanUseTrackedMapFeatures() then
        return
    end
    if owner.autoReportTicker then
        owner.autoReportTicker:Cancel()
        owner.autoReportTicker = nil
    end
    local interval = Notification.GetAutoTeamReportInterval and Notification:GetAutoTeamReportInterval() or 60
    if not interval or interval <= 0 then
        return
    end
    owner.autoReportTicker = C_Timer.NewTicker(interval, function()
        if not CoreShared:IsAddonEnabled() then
            return
        end
        if not CoreShared:CanUseTrackedMapFeatures() then
            return
        end
        if Notification and Notification.SendAutoTeamReport then
            Notification:SendAutoTeamReport()
        end
    end)
end

function TickerController:StopAutoTeamReportTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.autoReportTicker then
        owner.autoReportTicker:Cancel()
        owner.autoReportTicker = nil
    end
end

function TickerController:RestartAutoTeamReportTicker(owner)
    owner = owner or CrateTrackerZK
    self:StopAutoTeamReportTicker(owner)
    self:StartAutoTeamReportTicker(owner)
end

function TickerController:ResumeAllDetections(owner)
    owner = owner or CrateTrackerZK
    self:StartMapIconDetection(owner, 1)
    self:StartCleanupTicker(owner)
    self:StartAutoTeamReportTicker(owner)
    self:RefreshPhaseTicker(owner)
end

return TickerController
