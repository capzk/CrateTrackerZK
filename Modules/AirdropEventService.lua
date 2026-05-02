-- AirdropEventService.lua - 空投事件领域规则

local AirdropEventService = BuildEnv("AirdropEventService")

AirdropEventService.DEFAULT_NOTIFICATION_WINDOW = 15
AirdropEventService.DEFAULT_SHOUT_DEDUP_WINDOW = 20
AirdropEventService.TimeType = {
    NPC_SHOUT = "npc_shout",
    ICON_DETECTION = "icon_detection",
}

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

function AirdropEventService:IsDuplicateTeamMessage(temporaryTimestamp, currentTime, windowSeconds)
    if type(temporaryTimestamp) ~= "number" or type(currentTime) ~= "number" then
        return false
    end

    if currentTime < temporaryTimestamp then
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

function AirdropEventService:NormalizeTimeType(timeType, source)
    if timeType == self.TimeType.NPC_SHOUT or timeType == self.TimeType.ICON_DETECTION then
        return timeType
    end
    if source == self.TimeType.ICON_DETECTION then
        return self.TimeType.ICON_DETECTION
    end
    return self.TimeType.NPC_SHOUT
end

function AirdropEventService:IsShoutTimeType(timeType, source)
    return self:NormalizeTimeType(timeType, source) == self.TimeType.NPC_SHOUT
end

function AirdropEventService:ShouldPreferIncomingSameEventTime(existingTimestamp, existingTimeType, incomingTimestamp, incomingTimeType)
    local existingValue = tonumber(existingTimestamp)
    local incomingValue = tonumber(incomingTimestamp)
    if type(incomingValue) ~= "number" then
        return false
    end
    if type(existingValue) ~= "number" then
        return true
    end
    if incomingValue < existingValue then
        return true
    end
    if incomingValue > existingValue then
        return false
    end

    local normalizedExistingType = self:NormalizeTimeType(existingTimeType)
    local normalizedIncomingType = self:NormalizeTimeType(incomingTimeType)
    return normalizedExistingType ~= self.TimeType.NPC_SHOUT
        and normalizedIncomingType == self.TimeType.NPC_SHOUT
end

function AirdropEventService:ShouldReplaceStoredEvent(existingTimestamp, existingObjectGUID, existingTimeType, incomingTimestamp, incomingObjectGUID, incomingTimeType)
    local incomingValue = tonumber(incomingTimestamp)
    if type(incomingValue) ~= "number" then
        return false
    end

    local sameObjectGUID = self:HasSameObjectGUID(existingObjectGUID, incomingObjectGUID)
    if sameObjectGUID == true then
        return self:ShouldPreferIncomingSameEventTime(
            existingTimestamp,
            existingTimeType,
            incomingValue,
            incomingTimeType
        )
    end

    local existingValue = tonumber(existingTimestamp)
    if type(existingValue) ~= "number" then
        return true
    end
    return incomingValue > existingValue
end

function AirdropEventService:BuildEventTimeCandidate(timestamp, source, timeType, objectGUID)
    local resolvedTimestamp = tonumber(timestamp)
    if type(resolvedTimestamp) ~= "number" then
        return nil
    end

    return {
        timestamp = resolvedTimestamp,
        source = source,
        timeType = self:NormalizeTimeType(timeType, source),
        objectGUID = type(objectGUID) == "string" and objectGUID ~= "" and objectGUID or nil,
    }
end

function AirdropEventService:SelectPreferredSameEventCandidate(currentCandidate, incomingCandidate)
    if type(incomingCandidate) ~= "table" or type(incomingCandidate.timestamp) ~= "number" then
        return currentCandidate
    end
    if type(currentCandidate) ~= "table" or type(currentCandidate.timestamp) ~= "number" then
        return incomingCandidate
    end

    if self:ShouldPreferIncomingSameEventTime(
        currentCandidate.timestamp,
        currentCandidate.timeType,
        incomingCandidate.timestamp,
        incomingCandidate.timeType
    ) == true then
        return incomingCandidate
    end

    return currentCandidate
end

return AirdropEventService
