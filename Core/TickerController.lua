-- TickerController.lua - Core 定时器与检测协调

local TickerController = BuildEnv("CrateTrackerZKTickerController")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")

local function UpdatePhaseNowIfActive()
    if CoreShared:IsAreaActive() and Phase then
        local currentMapID = CoreShared:GetCurrentMapID()
        Phase:UpdatePhaseInfo(currentMapID)
    end
end

function TickerController:StartPhaseTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.phaseTimerTicker then
        owner.phaseTimerTicker:Cancel()
    end

    owner.phaseTimerTicker = C_Timer.NewTicker(10, function()
        if CoreShared:IsAreaActive() and Phase then
            local tickerMapID = CoreShared:GetCurrentMapID()
            Phase:UpdatePhaseInfo(tickerMapID)
        end
    end)
    owner.phaseTimerPaused = false
    Logger:Debug("Core", "状态", "已启动位面检测定时器（间隔10秒）")
    UpdatePhaseNowIfActive()
end

function TickerController:StopPhaseTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.phaseTimerTicker then
        owner.phaseTimerTicker:Cancel()
        owner.phaseTimerTicker = nil
        owner.phaseTimerPaused = true
        Logger:Debug("Core", "状态", "已停止位面检测定时器")
    end
end

function TickerController:PauseAllDetections(owner)
    owner = owner or CrateTrackerZK
    Logger:Debug("Core", "状态", "暂停所有检测功能")

    self:StopPhaseTicker(owner)

    if owner.mapIconDetectionTicker then
        owner.mapIconDetectionTicker:Cancel()
        owner.mapIconDetectionTicker = nil
        Logger:Debug("Core", "状态", "已停止地图图标检测")
    end

    if owner.cleanupTicker then
        owner.cleanupTicker:Cancel()
        owner.cleanupTicker = nil
        Logger:Debug("Core", "状态", "已停止临时数据清理定时器")
    end

    if owner.autoReportTicker then
        owner.autoReportTicker:Cancel()
        owner.autoReportTicker = nil
        Logger:Debug("Core", "状态", "已停止自动团队播报")
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

    Logger:Debug("Core", "状态", string.format("已启动地图图标检测（间隔%d秒）", interval))
    return true
end

function TickerController:StopMapIconDetection(owner)
    owner = owner or CrateTrackerZK
    if owner.mapIconDetectionTicker then
        owner.mapIconDetectionTicker:Cancel()
        owner.mapIconDetectionTicker = nil
        Logger:Debug("Core", "状态", "已停止地图图标检测")
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
        UnifiedDataManager:ClearExpiredTemporaryData()
    end)
    Logger:Debug("Core", "状态", "已启动临时数据清理定时器（间隔300秒）")
end

function TickerController:StopCleanupTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.cleanupTicker then
        owner.cleanupTicker:Cancel()
        owner.cleanupTicker = nil
        Logger:Debug("Core", "状态", "已停止临时数据清理定时器")
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
    if not CoreShared:IsAreaActive() then
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
        if not CoreShared:IsAreaActive() then
            return
        end
        if Notification and Notification.SendAutoTeamReport then
            Notification:SendAutoTeamReport()
        end
    end)
    Logger:Debug("Core", "状态", string.format("已启动自动团队播报（间隔%d秒）", interval))
end

function TickerController:StopAutoTeamReportTicker(owner)
    owner = owner or CrateTrackerZK
    if owner.autoReportTicker then
        owner.autoReportTicker:Cancel()
        owner.autoReportTicker = nil
        Logger:Debug("Core", "状态", "已停止自动团队播报")
    end
end

function TickerController:RestartAutoTeamReportTicker(owner)
    owner = owner or CrateTrackerZK
    self:StopAutoTeamReportTicker(owner)
    self:StartAutoTeamReportTicker(owner)
end

function TickerController:ResumeAllDetections(owner)
    owner = owner or CrateTrackerZK
    Logger:Debug("Core", "状态", "恢复所有检测功能")

    self:StartMapIconDetection(owner, 1)
    self:StartCleanupTicker(owner)
    self:StartAutoTeamReportTicker(owner)
    self:StartPhaseTicker(owner)
end

return TickerController
