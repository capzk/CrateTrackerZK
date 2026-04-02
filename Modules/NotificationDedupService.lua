-- NotificationDedupService.lua - 通知去重与运行时状态

local NotificationDedupService = BuildEnv("NotificationDedupService")
local AirdropEventService = BuildEnv("AirdropEventService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Logger = BuildEnv("Logger")

function NotificationDedupService:EnsureState(notification)
    notification.firstNotificationTime = notification.firstNotificationTime or {}
    notification.playerSentNotification = notification.playerSentNotification or {}
    notification.lastShoutTime = notification.lastShoutTime or {}
    notification.lastReceivedSyncTime = notification.lastReceivedSyncTime or {}
end

function NotificationDedupService:UpdateFirstNotificationTime(notification, mapName, notificationTime)
    if not mapName or not notificationTime then
        return
    end
    self:EnsureState(notification)
    if not notification.firstNotificationTime[mapName] or notificationTime < notification.firstNotificationTime[mapName] then
        notification.firstNotificationTime[mapName] = notificationTime
        Logger:Debug("Notification", "更新", string.format("更新首次通知时间：地图=%s，时间=%s",
            mapName, UnifiedDataManager:FormatDateTime(notificationTime)))
    end
end

function NotificationDedupService:CanSendNotification(notification, mapName)
    if not mapName then
        return false
    end
    self:EnsureState(notification)
    local currentTime = time()
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
    if not isAllowed then
        Logger:Debug("Notification", "限制", string.format("距离首次通知已超过30秒（%d秒），不允许发送：地图=%s",
            currentTime - firstNotificationTime, mapName))
        return false
    end
    return true
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
        Logger:Debug("Notification", "标记", string.format("标记玩家已发送通知：地图=%s", mapName))
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
    notification.lastShoutTime[mapName] = timestamp or time()
    Logger:Debug("Notification", "记录", string.format("记录喊话时间：地图=%s，时间=%s",
        mapName, UnifiedDataManager:FormatDateTime(notification.lastShoutTime[mapName])))
end

function NotificationDedupService:RecordReceivedSync(notification, mapName, timestamp)
    if not mapName then
        return
    end
    self:EnsureState(notification)
    notification.lastReceivedSyncTime[mapName] = timestamp or time()
    Logger:Debug("Notification", "记录", string.format("记录收到隐藏同步时间：地图=%s，时间=%s",
        mapName, UnifiedDataManager:FormatDateTime(notification.lastReceivedSyncTime[mapName])))
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
    currentTime = currentTime or time()
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
    currentTime = currentTime or time()
    local isRecent = AirdropEventService and AirdropEventService.HasRecentTimestamp
        and AirdropEventService:HasRecentTimestamp(lastTime, currentTime, windowSeconds)
        or ((currentTime - lastTime) <= windowSeconds)
    return isRecent, lastTime
end

return NotificationDedupService
