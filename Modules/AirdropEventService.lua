-- AirdropEventService.lua - 空投事件领域规则

local AirdropEventService = BuildEnv("AirdropEventService")

AirdropEventService.DEFAULT_NOTIFICATION_WINDOW = 30
AirdropEventService.DEFAULT_SHOUT_DEDUP_WINDOW = 20

local function NormalizeWindow(windowSeconds, defaultValue)
    local value = tonumber(windowSeconds)
    if not value or value < 0 then
        return defaultValue
    end
    return value
end

function AirdropEventService:IsWithinWindow(baseTimestamp, currentTime, windowSeconds, defaultWindow)
    if type(baseTimestamp) ~= "number" or type(currentTime) ~= "number" then
        return false
    end

    if currentTime < baseTimestamp then
        return false
    end

    local resolvedWindow = NormalizeWindow(windowSeconds, defaultWindow or 0)
    return (currentTime - baseTimestamp) <= resolvedWindow
end

function AirdropEventService:HasRecentTimestamp(lastTimestamp, currentTime, windowSeconds)
    return self:IsWithinWindow(lastTimestamp, currentTime, windowSeconds, 0)
end

function AirdropEventService:ShouldBroadcastByEventAge(eventTimestamp, currentTime, windowSeconds)
    if type(eventTimestamp) ~= "number" or type(currentTime) ~= "number" then
        return true
    end

    return self:IsWithinWindow(
        eventTimestamp,
        currentTime,
        windowSeconds,
        self.DEFAULT_NOTIFICATION_WINDOW
    )
end

function AirdropEventService:ShouldSuppressMapIconNotification(lastShoutTime, currentTime, windowSeconds)
    return self:HasRecentTimestamp(
        lastShoutTime,
        currentTime,
        windowSeconds or self.DEFAULT_SHOUT_DEDUP_WINDOW
    )
end

function AirdropEventService:ShouldResetNotificationStateForNewEvent(lastShoutTime, currentTime, windowSeconds)
    return not self:ShouldSuppressMapIconNotification(lastShoutTime, currentTime, windowSeconds)
end

function AirdropEventService:ResetNotificationState(firstNotificationTime, playerSentNotification, mapName)
    if type(mapName) ~= "string" or mapName == "" then
        return false
    end

    if type(firstNotificationTime) == "table" then
        firstNotificationTime[mapName] = nil
    end
    if type(playerSentNotification) == "table" then
        playerSentNotification[mapName] = nil
    end

    return true
end

function AirdropEventService:IsDuplicateTeamMessage(temporaryTimestamp, currentTime, windowSeconds)
    if type(temporaryTimestamp) ~= "number" or type(currentTime) ~= "number" then
        return false
    end

    if currentTime <= temporaryTimestamp then
        return false
    end

    local resolvedWindow = NormalizeWindow(windowSeconds, self.DEFAULT_NOTIFICATION_WINDOW)
    return (currentTime - temporaryTimestamp) <= resolvedWindow
end

function AirdropEventService:CreateDetectionState(firstDetectedTime, objectGUID)
    return {
        firstDetectedTime = firstDetectedTime,
        detectedObjectGUID = objectGUID
    }
end

function AirdropEventService:HasSameObjectGUID(previousObjectGUID, objectGUID)
    return type(previousObjectGUID) == "string"
        and type(objectGUID) == "string"
        and previousObjectGUID == objectGUID
end

function AirdropEventService:HasDifferentObjectGUID(previousObjectGUID, objectGUID)
    return type(previousObjectGUID) == "string"
        and type(objectGUID) == "string"
        and previousObjectGUID ~= objectGUID
end

return AirdropEventService
