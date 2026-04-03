-- NotificationDedupService.lua - 通知去重与运行时状态

local NotificationDedupService = BuildEnv("NotificationDedupService")
local AirdropEventService = BuildEnv("AirdropEventService")

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

local function PruneVisibleAutoEventState(stateByMap, expireBefore)
    if type(stateByMap) ~= "table" then
        return 0
    end

    local removedCount = 0
    for mapKey, state in pairs(stateByMap) do
        local lastRelevantTime = 0
        if type(state) == "table" then
            if type(state.firstVisibleSendTime) == "number" and state.firstVisibleSendTime > lastRelevantTime then
                lastRelevantTime = state.firstVisibleSendTime
            end
            if type(state.lastReceivedSyncTime) == "number" and state.lastReceivedSyncTime > lastRelevantTime then
                lastRelevantTime = state.lastReceivedSyncTime
            end
            if type(state.eventTimestamp) == "number" and state.eventTimestamp > lastRelevantTime then
                lastRelevantTime = state.eventTimestamp
            end
        end
        if lastRelevantTime <= expireBefore then
            stateByMap[mapKey] = nil
            removedCount = removedCount + 1
        end
    end
    return removedCount
end

local function NormalizeMapNotificationKey(mapRef, eventContext)
    local candidate = eventContext
    if type(candidate) == "table" then
        local mapKey = candidate.mapKey or candidate.mapId or candidate.mapID or candidate.id
        if mapKey ~= nil then
            return tostring(mapKey)
        end
        if type(candidate.mapName) == "string" and candidate.mapName ~= "" then
            return candidate.mapName
        end
    end

    if type(mapRef) == "number" then
        return tostring(mapRef)
    end
    if type(mapRef) == "string" and mapRef ~= "" then
        return mapRef
    end
    if type(mapRef) == "table" then
        local mapKey = mapRef.mapKey or mapRef.mapId or mapRef.mapID or mapRef.id
        if mapKey ~= nil then
            return tostring(mapKey)
        end
        if type(mapRef.mapName) == "string" and mapRef.mapName ~= "" then
            return mapRef.mapName
        end
    end
    return nil
end

local function NormalizeEventTimestamp(eventContext)
    if type(eventContext) ~= "table" then
        return nil
    end
    local timestamp = tonumber(eventContext.eventTimestamp or eventContext.timestamp)
    if not timestamp then
        return nil
    end
    return math.floor(timestamp)
end

local function NormalizeObjectGUID(eventContext)
    if type(eventContext) ~= "table" then
        return nil
    end
    if type(eventContext.objectGUID) ~= "string" or eventContext.objectGUID == "" then
        return nil
    end
    return eventContext.objectGUID
end

local function GetEventNotificationWindow(notification)
    return tonumber(notification.NOTIFICATION_WINDOW)
        or (AirdropEventService and AirdropEventService.DEFAULT_NOTIFICATION_WINDOW)
        or 15
end

local function IsWithinWindow(baseTimestamp, currentTime, windowSeconds)
    if AirdropEventService and AirdropEventService.HasRecentTimestamp then
        return AirdropEventService:HasRecentTimestamp(baseTimestamp, currentTime, windowSeconds) == true
    end
    return type(baseTimestamp) == "number"
        and type(currentTime) == "number"
        and currentTime >= baseTimestamp
        and (currentTime - baseTimestamp) <= (windowSeconds or 0)
end

local function IsSameTrackedAirdropEvent(notification, state, eventContext)
    if type(state) ~= "table" or type(eventContext) ~= "table" then
        return false
    end

    local incomingGUID = NormalizeObjectGUID(eventContext)
    local incomingTimestamp = NormalizeEventTimestamp(eventContext)

    if type(state.objectGUID) == "string" and type(incomingGUID) == "string" then
        return state.objectGUID == incomingGUID
    end

    if type(state.eventTimestamp) == "number" and type(incomingTimestamp) == "number" then
        local eventWindow = GetEventNotificationWindow(notification)
        return math.abs(state.eventTimestamp - incomingTimestamp) <= eventWindow
    end

    return false
end

local function CreateVisibleAutoEventState(eventContext)
    return {
        eventTimestamp = NormalizeEventTimestamp(eventContext),
        objectGUID = NormalizeObjectGUID(eventContext),
        firstVisibleSendTime = nil,
        hasPlayerSentVisibleMessage = false,
        lastReceivedSyncTime = nil,
    }
end

local function AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    NotificationDedupService:EnsureState(notification)

    local mapKey = NormalizeMapNotificationKey(mapRef, eventContext)
    if not mapKey then
        return nil, nil
    end

    local stateByMap = notification.visibleAutoEventStateByMap
    local state = stateByMap[mapKey]
    local incomingTimestamp = NormalizeEventTimestamp(eventContext)
    local incomingGUID = NormalizeObjectGUID(eventContext)
    local hasIncomingIdentity = incomingTimestamp ~= nil or incomingGUID ~= nil

    if not state then
        state = CreateVisibleAutoEventState(eventContext)
        stateByMap[mapKey] = state
        return state, mapKey
    end

    if hasIncomingIdentity and not IsSameTrackedAirdropEvent(notification, state, eventContext) then
        state = CreateVisibleAutoEventState(eventContext)
        stateByMap[mapKey] = state
        return state, mapKey
    end

    if incomingTimestamp and (not state.eventTimestamp or incomingTimestamp < state.eventTimestamp) then
        state.eventTimestamp = incomingTimestamp
    end
    if incomingGUID and not state.objectGUID then
        state.objectGUID = incomingGUID
    end

    return state, mapKey
end

function NotificationDedupService:EnsureState(notification)
    notification.visibleAutoEventStateByMap = notification.visibleAutoEventStateByMap or {}
    notification.lastShoutTime = notification.lastShoutTime or {}
end

function NotificationDedupService:ClearExpiredTransientState(notification, currentTime)
    self:EnsureState(notification)

    local now = currentTime or Utils:GetCurrentTimestamp()
    local shoutGraceWindow = math.max((notification.SHOUT_DEDUP_WINDOW or 20) * 4, 120)
    local eventGraceWindow = math.max(
        math.max(
            GetEventNotificationWindow(notification),
            notification.RECEIVED_SYNC_VISIBLE_WINDOW or GetEventNotificationWindow(notification)
        ) * 4,
        120
    )

    local removedCount = 0
    removedCount = removedCount + PruneTimestampState(notification.lastShoutTime, now - shoutGraceWindow)
    removedCount = removedCount + PruneVisibleAutoEventState(notification.visibleAutoEventStateByMap, now - eventGraceWindow)
    return removedCount
end

function NotificationDedupService:CanSendNotification(notification, mapRef, eventContext, currentTime)
    local eventState = AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    if not eventState then
        return false
    end

    local eventTimestamp = eventState.eventTimestamp or NormalizeEventTimestamp(eventContext)
    if not eventTimestamp then
        return true
    end

    currentTime = currentTime or Utils:GetCurrentTimestamp()
    return IsWithinWindow(eventTimestamp, currentTime, GetEventNotificationWindow(notification))
end

function NotificationDedupService:ResetMapNotificationState(notification, mapRef, eventContext)
    self:EnsureState(notification)

    local mapKey = NormalizeMapNotificationKey(mapRef, eventContext)
    if not mapKey then
        return false
    end

    notification.visibleAutoEventStateByMap[mapKey] = nil
    return true
end

function NotificationDedupService:MarkPlayerSentNotification(notification, mapRef, eventContext, currentTime)
    local eventState = AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    if not eventState then
        return false
    end

    local sentTime = currentTime or Utils:GetCurrentTimestamp()
    if not eventState.firstVisibleSendTime then
        eventState.firstVisibleSendTime = sentTime
    end
    eventState.hasPlayerSentVisibleMessage = true
    return true
end

function NotificationDedupService:HasPlayerSentNotification(notification, mapRef, eventContext)
    local eventState = AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    return eventState and eventState.hasPlayerSentVisibleMessage == true or false
end

function NotificationDedupService:RecordShout(notification, mapRef, timestamp)
    local mapKey = NormalizeMapNotificationKey(mapRef)
    if not mapKey then
        return
    end
    self:EnsureState(notification)
    notification.lastShoutTime[mapKey] = timestamp or Utils:GetCurrentTimestamp()
end

function NotificationDedupService:RecordReceivedSync(notification, mapRef, timestamp, eventContext)
    local eventState = AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    if not eventState then
        return false
    end
    eventState.lastReceivedSyncTime = timestamp or Utils:GetCurrentTimestamp()
    return true
end

function NotificationDedupService:HasRecentReceivedSync(notification, mapRef, windowSeconds, currentTime, eventContext)
    local eventState = AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    if not eventState then
        return false, nil
    end
    local lastTime = eventState.lastReceivedSyncTime
    if not lastTime then
        return false, nil
    end
    currentTime = currentTime or Utils:GetCurrentTimestamp()
    local resolvedWindow = windowSeconds or notification.RECEIVED_SYNC_VISIBLE_WINDOW or GetEventNotificationWindow(notification)
    local isRecent = IsWithinWindow(lastTime, currentTime, resolvedWindow)
    return isRecent, lastTime
end

function NotificationDedupService:IsRecentShout(notification, mapRef, windowSeconds, currentTime)
    local mapKey = NormalizeMapNotificationKey(mapRef)
    if not mapKey then
        return false, nil
    end
    self:EnsureState(notification)
    local lastTime = notification.lastShoutTime[mapKey]
    if not lastTime then
        return false, nil
    end
    windowSeconds = windowSeconds or notification.SHOUT_DEDUP_WINDOW or 20
    currentTime = currentTime or Utils:GetCurrentTimestamp()
    local isRecent = IsWithinWindow(lastTime, currentTime, windowSeconds)
    return isRecent, lastTime
end

function NotificationDedupService:ResolveVisibleAutoDispatchState(notification, mapRef, eventContext, outboundChatType, currentTime)
    local state = {
        outboundChatType = outboundChatType,
        shouldAbortNotification = false,
        shouldTrackVisibleSend = false,
        blockReason = nil,
    }

    if not outboundChatType or notification.teamNotificationEnabled ~= true then
        return state
    end

    currentTime = currentTime or Utils:GetCurrentTimestamp()

    local hasRecentReceivedSync, lastReceivedSyncTime = self:HasRecentReceivedSync(
        notification,
        mapRef,
        notification.RECEIVED_SYNC_VISIBLE_WINDOW,
        currentTime,
        eventContext
    )
    if lastReceivedSyncTime and not hasRecentReceivedSync then
        state.outboundChatType = nil
        state.blockReason = "hidden_sync_window_expired"
        return state
    end

    if self:HasPlayerSentNotification(notification, mapRef, eventContext) then
        state.shouldAbortNotification = true
        state.blockReason = "player_already_sent"
        return state
    end

    if not self:CanSendNotification(notification, mapRef, eventContext, currentTime) then
        state.shouldAbortNotification = true
        state.blockReason = "notification_window_expired"
        return state
    end

    state.shouldTrackVisibleSend = true
    return state
end

function NotificationDedupService:CommitVisibleAutoDispatch(notification, mapRef, eventContext, currentTime)
    return self:MarkPlayerSentNotification(notification, mapRef, eventContext, currentTime)
end

function NotificationDedupService:NoteSuppressedVisibleAutoDispatch(notification, mapRef, eventContext, timestamp)
    local eventState = AcquireVisibleAutoEventState(notification, mapRef, eventContext)
    if not eventState then
        return false
    end

    local noteTime = timestamp or Utils:GetCurrentTimestamp()
    if not eventState.firstVisibleSendTime or noteTime < eventState.firstVisibleSendTime then
        eventState.firstVisibleSendTime = noteTime
    end
    eventState.hasPlayerSentVisibleMessage = true
    return true
end

return NotificationDedupService
