-- AirdropTrajectorySyncService.lua - 空投轨迹隐藏共享与请求同步

local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local SharedSyncSchedulerHelpers = BuildEnv("SharedSyncSchedulerHelpers")
local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")
local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")

AirdropTrajectorySyncService.FEATURE_ENABLED = true
AirdropTrajectorySyncService.REQUEST_COOLDOWN = 15
AirdropTrajectorySyncService.FULL_BROADCAST_COOLDOWN = 8
AirdropTrajectorySyncService.SEND_INTERVAL = 0.15
AirdropTrajectorySyncService.RESPONSE_JITTER_MIN = 0.35
AirdropTrajectorySyncService.RESPONSE_JITTER_MAX = 1.10
AirdropTrajectorySyncService.REQUEST_STATE_TTL = 60

local function ClearArray(buffer)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ClearArray then
        return SharedSyncSchedulerHelpers:ClearArray(buffer)
    end
    return {}
end

local function ClearMap(buffer)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ClearMap then
        return SharedSyncSchedulerHelpers:ClearMap(buffer)
    end
    return {}
end

local function BuildHandledRequestKey(sender, requestID)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.BuildRequestKey then
        return SharedSyncSchedulerHelpers:BuildRequestKey(sender, requestID)
    end
    return tostring(sender or "unknown") .. ":" .. tostring(requestID or "unknown")
end

local function NormalizeJitterDelay(minDelay, maxDelay)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.NormalizeJitterDelay then
        return SharedSyncSchedulerHelpers:NormalizeJitterDelay(minDelay, maxDelay)
    end
    return 0
end

local function GetTeamContextKey()
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.GetTeamContextKey then
        return SharedSyncSchedulerHelpers:GetTeamContextKey(TeamSharedSyncChannelService)
    end
    return nil
end

function AirdropTrajectorySyncService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function AirdropTrajectorySyncService:Initialize()
    self.broadcastQueue = self.broadcastQueue or {}
    self.handledRequestKeys = self.handledRequestKeys or {}
    self.requestSequence = self.requestSequence or 0
    self.lastSyncRequestAt = self.lastSyncRequestAt or 0
    self.lastFullBroadcastAt = self.lastFullBroadcastAt or 0
    self.lastTeamChannelReady = self.lastTeamChannelReady or false
    self.lastTeamContextKey = self.lastTeamContextKey or nil
    return true
end

function AirdropTrajectorySyncService:Reset()
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.CancelOwnedTimer then
        SharedSyncSchedulerHelpers:CancelOwnedTimer(self, "broadcastTimer")
    elseif self.broadcastTimer and self.broadcastTimer.Cancel then
        self.broadcastTimer:Cancel()
        self.broadcastTimer = nil
    end
    self.broadcastQueue = ClearArray(self.broadcastQueue)
    self.handledRequestKeys = ClearMap(self.handledRequestKeys)
    self.requestSequence = 0
    self.lastSyncRequestAt = 0
    self.lastFullBroadcastAt = 0
    self.lastTeamChannelReady = false
    self.lastTeamContextKey = nil
    return true
end

function AirdropTrajectorySyncService:CanSync()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not CoreShared or not CoreShared.IsAddonEnabled or CoreShared:IsAddonEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncListener
        or not TeamSharedSyncListener.IsFeatureEnabled
        or TeamSharedSyncListener:IsFeatureEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncListener.CanSendSharedSync
        or TeamSharedSyncListener:CanSendSharedSync() ~= true then
        return false
    end
    return true
end

function AirdropTrajectorySyncService:PruneHandledRequests(currentTime)
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local ttl = tonumber(self.REQUEST_STATE_TTL) or 60
    self.handledRequestKeys = self.handledRequestKeys or {}
    for requestKey, handledAt in pairs(self.handledRequestKeys) do
        if type(handledAt) ~= "number" or (now - handledAt) > ttl then
            self.handledRequestKeys[requestKey] = nil
        end
    end
    return self.handledRequestKeys
end

function AirdropTrajectorySyncService:BuildSyncRequestState(currentTime)
    self.requestSequence = (tonumber(self.requestSequence) or 0) + 1
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    return {
        requestID = tostring(now) .. "-" .. tostring(self.requestSequence),
        timestamp = now,
    }
end

function AirdropTrajectorySyncService:SendSyncRequest(currentTime, force)
    if self:CanSync() ~= true then
        return false
    end
    if not TeamSharedSyncListener
        or not TeamSharedSyncListener.SendTrajectorySyncRequest then
        return false
    end

    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    if force ~= true then
        local lastSentAt = tonumber(self.lastSyncRequestAt) or 0
        if (now - lastSentAt) < (tonumber(self.REQUEST_COOLDOWN) or 15) then
            return false
        end
    end

    local requestState = self:BuildSyncRequestState(now)
    if TeamSharedSyncListener:SendTrajectorySyncRequest(requestState) == true then
        self.lastSyncRequestAt = now
        return true
    end
    return false
end

function AirdropTrajectorySyncService:ProcessNextBroadcast()
    self.broadcastTimer = nil
    if self:CanSync() ~= true then
        self.broadcastQueue = ClearArray(self.broadcastQueue)
        return false
    end

    local routeState = table.remove(self.broadcastQueue, 1)
    if type(routeState) ~= "table" then
        return false
    end

    if TeamSharedSyncListener
        and TeamSharedSyncListener.SendTrajectoryRoute
        and TeamSharedSyncListener:SendTrajectoryRoute(routeState) == true then
        self.lastFullBroadcastAt = Utils:GetCurrentTimestamp()
    end

    if #self.broadcastQueue > 0 then
        if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ScheduleOwnedTimer then
            return SharedSyncSchedulerHelpers:ScheduleOwnedTimer(self, "broadcastTimer", self.SEND_INTERVAL, function()
                self:ProcessNextBroadcast()
            end)
        end
        self:ProcessNextBroadcast()
        return true
    end

    return true
end

function AirdropTrajectorySyncService:QueueFullBroadcast(delaySeconds, force)
    if self:CanSync() ~= true then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    if force ~= true then
        local lastFullBroadcastAt = tonumber(self.lastFullBroadcastAt) or 0
        if (now - lastFullBroadcastAt) < (tonumber(self.FULL_BROADCAST_COOLDOWN) or 8) then
            return false
        end
    end

    local routes = {}
    routes = AirdropTrajectoryStore and AirdropTrajectoryStore.AppendShareableRoutesTo and AirdropTrajectoryStore:AppendShareableRoutesTo(routes) or routes
    if #routes == 0 then
        return false
    end

    self.broadcastQueue = ClearArray(self.broadcastQueue)
    for _, route in ipairs(routes) do
        self.broadcastQueue[#self.broadcastQueue + 1] = route
    end

    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.CancelOwnedTimer then
        SharedSyncSchedulerHelpers:CancelOwnedTimer(self, "broadcastTimer")
    elseif self.broadcastTimer and self.broadcastTimer.Cancel then
        self.broadcastTimer:Cancel()
        self.broadcastTimer = nil
    end

    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then
        delay = 0
    end
    if delay > 0 and SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ScheduleOwnedTimer then
        return SharedSyncSchedulerHelpers:ScheduleOwnedTimer(self, "broadcastTimer", delay, function()
            self:ProcessNextBroadcast()
        end)
    end
    return self:ProcessNextBroadcast()
end

function AirdropTrajectorySyncService:BroadcastRoute(routeState)
    if self:CanSync() ~= true then
        return false
    end
    if type(routeState) ~= "table" then
        return false
    end
    if AirdropTrajectoryStore
        and AirdropTrajectoryStore.IsShareEligible
        and AirdropTrajectoryStore:IsShareEligible(routeState) ~= true then
        return false
    end
    if TeamSharedSyncListener and TeamSharedSyncListener.SendTrajectoryRoute then
        return TeamSharedSyncListener:SendTrajectoryRoute(routeState) == true
    end
    return false
end

function AirdropTrajectorySyncService:HandleTeamContextChanged(forceRequest)
    local canSync = self:CanSync() == true
    local previousReady = self.lastTeamChannelReady == true
    local previousContextKey = self.lastTeamContextKey

    self.lastTeamChannelReady = canSync
    if canSync ~= true then
        self.lastTeamContextKey = nil
        if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.CancelOwnedTimer then
            SharedSyncSchedulerHelpers:CancelOwnedTimer(self, "broadcastTimer")
        elseif self.broadcastTimer and self.broadcastTimer.Cancel then
            self.broadcastTimer:Cancel()
            self.broadcastTimer = nil
        end
        self.broadcastQueue = ClearArray(self.broadcastQueue)
        return false
    end

    local currentContextKey = GetTeamContextKey()
    self.lastTeamContextKey = currentContextKey
    local contextChanged = previousReady == true
        and type(previousContextKey) == "string"
        and previousContextKey ~= ""
        and type(currentContextKey) == "string"
        and currentContextKey ~= ""
        and previousContextKey ~= currentContextKey

    if previousReady ~= true or contextChanged == true or forceRequest == true then
        self:SendSyncRequest(Utils:GetCurrentTimestamp(), true)
        return self:QueueFullBroadcast(
            NormalizeJitterDelay(self.RESPONSE_JITTER_MIN, self.RESPONSE_JITTER_MAX),
            true
        )
    end

    return false
end

function AirdropTrajectorySyncService:HandleSyncRequest(syncState, sender)
    if self:CanSync() ~= true or type(syncState) ~= "table" then
        return false
    end

    local requestID = syncState.requestID
    if type(requestID) ~= "string" or requestID == "" then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    self:PruneHandledRequests(now)
    local requestKey = BuildHandledRequestKey(sender, requestID)
    if self.handledRequestKeys[requestKey] ~= nil then
        return false
    end
    self.handledRequestKeys[requestKey] = now

    return self:QueueFullBroadcast(
        NormalizeJitterDelay(self.RESPONSE_JITTER_MIN, self.RESPONSE_JITTER_MAX),
        false
    )
end

function AirdropTrajectorySyncService:HandleTrajectoryRoute(syncState, sender)
    if type(syncState) ~= "table" then
        return false
    end

    local incomingRoute = {
        mapID = tonumber(syncState.mapID),
        startX = syncState.startX,
        startY = syncState.startY,
        endX = syncState.endX,
        endY = syncState.endY,
        sampleCount = syncState.sampleCount,
        observationCount = tonumber(syncState.observationCount) or 1,
        createdAt = syncState.timestamp,
        updatedAt = syncState.timestamp,
        source = "shared",
        continuityConfirmed = syncState.continuityConfirmed == true,
        startSource = type(syncState.startSource) == "string" and syncState.startSource or nil,
        endSource = type(syncState.endSource) == "string" and syncState.endSource or nil,
        startConfirmed = syncState.startConfirmed == true,
        endConfirmed = syncState.endConfirmed == true,
        verificationCount = tonumber(syncState.verificationCount) or 0,
        verifiedPredictionCount = tonumber(syncState.verifiedPredictionCount) or 0,
        sender = sender,
    }

    if AirdropTrajectoryStore
        and AirdropTrajectoryStore.IsShareEligible
        and AirdropTrajectoryStore:IsShareEligible(incomingRoute) ~= true then
        return false
    end

    local changed = AirdropTrajectoryStore
        and AirdropTrajectoryStore.UpsertRoute
        and AirdropTrajectoryStore:UpsertRoute(
            tonumber(syncState.mapID),
            incomingRoute,
            "shared",
            Utils:GetCurrentTimestamp()
        )
        or false

    return changed == true
end

return AirdropTrajectorySyncService
