-- NotificationDedupService.lua - 通知去重与运行时状态

local NotificationDedupService = BuildEnv("NotificationDedupService")
local AirdropEventService = BuildEnv("AirdropEventService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Logger = BuildEnv("Logger")

local function PruneTimestampState(state, expireBefore)
    if type(state) ~= "table" then
        return 0
    end

    local removedCount = 0
    for key, timestamp in pairs(state) do
        if type(timestamp) ~= "number" or timestamp <= expireBefore then
            state[key] = nil
            removedCount = removedCount + 1
        end
    end
    return removedCount
end

function NotificationDedupService:EnsureState(notification)
    notification.firstNotificationTime = notification.firstNotificationTime or {}
    notification.playerSentNotification = notification.playerSentNotification or {}
    notification.lastShoutTime = notification.lastShoutTime or {}
    notification.lastReceivedSyncTime = notification.lastReceivedSyncTime or {}
end

function NotificationDedupService:ClearExpiredTransientState(notification, currentTime)
    self:EnsureState(notification)

    local now = currentTime or Utils:GetCurrentTimestamp()
    local shoutGraceWindow = math.max((notification.SHOUT_DEDUP_WINDOW or 20) * 4, 120)
    local syncGraceWindow = math.max((notification.RECEIVED_SYNC_SUPPRESS_WINDOW or 15) * 4, 120)

    local removedCount = 0
    removedCount = removedCount + PruneTimestampState(notification.lastShoutTime, now - shoutGraceWindow)
    removedCount = removedCount + PruneTimestampState(notification.lastReceivedSyncTime, now - syncGraceWindow)
    return removedCount
end

function NotificationDedupService:UpdateFirstNotificationTime(notification, mapName, notificationTime)
    if not mapName or not notificationTime then
        return
    end
    self:EnsureState(notification)
    if not notification.firstNotificationTime[mapName] or notificationTime < notification.firstNotificationTime[mapName] then
        notification.firstNotificationTime[mapName] = notificationTime
    end
end

function NotificationDedupService:CanSendNotification(notification, mapName)
    if not mapName then
        return false
    end
    self:EnsureState(notification)
    local currentTime = Utils:GetCurrentTimestamp()
    local firstNotificationTime = notification.firstNotificationTime[mapName]
    if not firstNotificationTime then
        return true
    end
    local isAllowed = nil
    if AirdropEventService and AirdropEventService.HasRecentTimestamp then
        isAllowed = AirdropEventService:HasRecentTimestamp(firstNotificationTime, currentTime, notification.NOTIFICATION_WINDOW)
    else
        isAllowed = (currentTime - firstNotificationTime) <= notification.NOTIFICATION_WINDOW
    end
    return isAllowed == true
end

function NotificationDedupService:ResetMapNotificationState(notification, mapName)
    self:EnsureState(notification)
    if not mapName then
        return false
    end
    if AirdropEventService and AirdropEventService.ResetNotificationState then
        AirdropEventService:ResetNotificationState(
            notification.firstNotificationTime,
            notification.playerSentNotification,
            mapName
        )
    else
        notification.firstNotificationTime[mapName] = nil
        notification.playerSentNotification[mapName] = nil
    end
    notification.lastReceivedSyncTime[mapName] = nil
    return true
end

function NotificationDedupService:MarkPlayerSentNotification(notification, mapName)
    if not mapName then
        return
    end
    self:EnsureState(notification)
    if not notification.playerSentNotification[mapName] then
        notification.playerSentNotification[mapName] = true
    end
end

function NotificationDedupService:HasPlayerSentNotification(notification, mapName)
    self:EnsureState(notification)
    return notification.playerSentNotification[mapName] == true
end

function NotificationDedupService:RecordShout(notification, mapName, timestamp)
    if not mapName then
        return
    end
    self:EnsureState(notification)
    notification.lastShoutTime[mapName] = timestamp or Utils:GetCurrentTimestamp()
end

function NotificationDedupService:RecordReceivedSync(notification, mapName, timestamp)
    if not mapName then
        return
    end
    self:EnsureState(notification)
    notification.lastReceivedSyncTime[mapName] = timestamp or Utils:GetCurrentTimestamp()
end

function NotificationDedupService:HasRecentReceivedSync(notification, mapName, windowSeconds, currentTime)
    if not mapName then
        return false, nil
    end
    self:EnsureState(notification)
    local lastTime = notification.lastReceivedSyncTime[mapName]
    if not lastTime then
        return false, nil
    end
    currentTime = currentTime or Utils:GetCurrentTimestamp()
    local isRecent = AirdropEventService and AirdropEventService.HasRecentTimestamp
        and AirdropEventService:HasRecentTimestamp(lastTime, currentTime, windowSeconds)
        or ((currentTime - lastTime) <= (windowSeconds or 0))
    return isRecent, lastTime
end

function NotificationDedupService:IsRecentShout(notification, mapName, windowSeconds, currentTime)
    if not mapName then
        return false, nil
    end
    self:EnsureState(notification)
    local lastTime = notification.lastShoutTime[mapName]
    if not lastTime then
        return false, nil
    end
    windowSeconds = windowSeconds or notification.SHOUT_DEDUP_WINDOW or 20
    currentTime = currentTime or Utils:GetCurrentTimestamp()
    local isRecent = AirdropEventService and AirdropEventService.HasRecentTimestamp
        and AirdropEventService:HasRecentTimestamp(lastTime, currentTime, windowSeconds)
        or ((currentTime - lastTime) <= windowSeconds)
    return isRecent, lastTime
end

return NotificationDedupService
