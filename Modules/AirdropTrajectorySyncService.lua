-- AirdropTrajectorySyncService.lua - 空投轨迹隐藏共享与请求同步

local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local CoreShared = BuildEnv("CrateTrackerZKCoreShared")
local SharedSyncSchedulerHelpers = BuildEnv("SharedSyncSchedulerHelpers")
local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")
local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local TeamSharedSyncProtocol = BuildEnv("TeamSharedSyncProtocol")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")

AirdropTrajectorySyncService.FEATURE_ENABLED = true
AirdropTrajectorySyncService.REQUEST_COOLDOWN = 15
AirdropTrajectorySyncService.FULL_BROADCAST_COOLDOWN = 8
AirdropTrajectorySyncService.RESPONSE_JITTER_MIN = 0.35
AirdropTrajectorySyncService.RESPONSE_JITTER_MAX = 1.10
AirdropTrajectorySyncService.REQUEST_STATE_TTL = 60

-- WoW 的 AddonMessage 发送额度是“每前缀 10 条初始额度，每秒恢复 1 条”。
-- 轨迹路由改走独立前缀后，仍需要按额度模型调度，不能继续固定间隔盲发。
AirdropTrajectorySyncService.ROUTE_ALLOWANCE_MAX = 10
AirdropTrajectorySyncService.ROUTE_ALLOWANCE_REFILL_PER_SECOND = 1
AirdropTrajectorySyncService.ROUTE_SUCCESS_DELAY = 0.05
AirdropTrajectorySyncService.ROUTE_THROTTLE_COOLDOWN = 1.10
AirdropTrajectorySyncService.ROUTE_FAILURE_RETRY_DELAY = 1.25
AirdropTrajectorySyncService.MAX_NON_THROTTLE_RETRIES = 2

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

local function BuildRouteQueueKey(routeState)
    if type(routeState) ~= "table" then
        return nil
    end
    if type(routeState.routeKey) == "string" and routeState.routeKey ~= "" then
        return routeState.routeKey
    end
    if type(routeState.mapID) == "number"
        and type(routeState.routeFamilyKey) == "string"
        and routeState.routeFamilyKey ~= ""
        and type(routeState.landingKey) == "string"
        and routeState.landingKey ~= "" then
        return table.concat({
            tostring(routeState.mapID),
            routeState.routeFamilyKey,
            routeState.landingKey,
        }, ":")
    end
    return nil
end

local function ClearBroadcastState(owner)
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.CancelOwnedTimer then
        SharedSyncSchedulerHelpers:CancelOwnedTimer(owner, "broadcastTimer")
    elseif owner.broadcastTimer and owner.broadcastTimer.Cancel then
        owner.broadcastTimer:Cancel()
        owner.broadcastTimer = nil
    end
    owner.broadcastTimerDueAt = nil
    owner.broadcastQueue = ClearArray(owner.broadcastQueue)
    owner.broadcastQueueMembership = ClearMap(owner.broadcastQueueMembership)
    owner.pendingRouteByKey = ClearMap(owner.pendingRouteByKey)
    return true
end

local function RefreshRouteAllowance(owner, currentTime)
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local maxAllowance = math.max(1, tonumber(owner.ROUTE_ALLOWANCE_MAX) or 10)
    local refillRate = math.max(0.01, tonumber(owner.ROUTE_ALLOWANCE_REFILL_PER_SECOND) or 1)
    owner.routeAllowance = tonumber(owner.routeAllowance)
    if type(owner.routeAllowance) ~= "number" then
        owner.routeAllowance = maxAllowance
    end
    owner.routeAllowanceUpdatedAt = tonumber(owner.routeAllowanceUpdatedAt) or now

    if now > owner.routeAllowanceUpdatedAt then
        local elapsed = now - owner.routeAllowanceUpdatedAt
        owner.routeAllowance = math.min(maxAllowance, owner.routeAllowance + (elapsed * refillRate))
        owner.routeAllowanceUpdatedAt = now
    end
    return owner.routeAllowance
end

local function ConsumeRouteAllowance(owner, currentTime)
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local allowance = RefreshRouteAllowance(owner, now)
    if allowance >= 1 then
        owner.routeAllowance = allowance - 1
        owner.routeAllowanceUpdatedAt = now
        return true, 0
    end

    local refillRate = math.max(0.01, tonumber(owner.ROUTE_ALLOWANCE_REFILL_PER_SECOND) or 1)
    local waitDelay = (1 - allowance) / refillRate
    if waitDelay < 0 then
        waitDelay = 0
    end
    return false, waitDelay
end

local function ScheduleBroadcastPump(owner, delaySeconds)
    local delay = math.max(0, tonumber(delaySeconds) or 0)
    local dueAt = Utils:GetCurrentTimestamp() + delay
    if type(owner.broadcastTimerDueAt) == "number" and dueAt >= (owner.broadcastTimerDueAt - 0.01) then
        return true
    end

    owner.broadcastTimerDueAt = dueAt
    if SharedSyncSchedulerHelpers and SharedSyncSchedulerHelpers.ScheduleOwnedTimer then
        return SharedSyncSchedulerHelpers:ScheduleOwnedTimer(owner, "broadcastTimer", delay, function()
            owner.broadcastTimerDueAt = nil
            owner.broadcastTimer = nil
            owner:ProcessNextBroadcast()
        end)
    end

    if owner.broadcastTimer and owner.broadcastTimer.Cancel then
        owner.broadcastTimer:Cancel()
        owner.broadcastTimer = nil
    end
    owner.broadcastTimer = C_Timer.NewTimer(delay, function()
        owner.broadcastTimerDueAt = nil
        owner.broadcastTimer = nil
        owner:ProcessNextBroadcast()
    end)
    return true
end

local function GetHeadQueueItem(owner)
    while type(owner.broadcastQueue) == "table" and owner.broadcastQueue[1] do
        local routeKey = owner.broadcastQueue[1]
        local queueItem = owner.pendingRouteByKey and owner.pendingRouteByKey[routeKey] or nil
        if type(queueItem) == "table" then
            return queueItem
        end

        table.remove(owner.broadcastQueue, 1)
        if type(owner.broadcastQueueMembership) == "table" then
            owner.broadcastQueueMembership[routeKey] = nil
        end
    end
    return nil
end

local function RemoveHeadQueueItem(owner, routeKey)
    if type(owner.broadcastQueue) == "table" and owner.broadcastQueue[1] == routeKey then
        table.remove(owner.broadcastQueue, 1)
    end
    if type(owner.broadcastQueueMembership) == "table" then
        owner.broadcastQueueMembership[routeKey] = nil
    end
    if type(owner.pendingRouteByKey) == "table" then
        owner.pendingRouteByKey[routeKey] = nil
    end
end

local function EnqueueRoute(owner, routeState, delaySeconds)
    if type(routeState) ~= "table" then
        return false
    end
    local routeKey = BuildRouteQueueKey(routeState)
    if type(routeKey) ~= "string" or routeKey == "" then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    local nextEligibleAt = now + math.max(0, tonumber(delaySeconds) or 0)
    owner.pendingRouteByKey = owner.pendingRouteByKey or {}
    owner.broadcastQueue = owner.broadcastQueue or {}
    owner.broadcastQueueMembership = owner.broadcastQueueMembership or {}

    local queueItem = owner.pendingRouteByKey[routeKey]
    if type(queueItem) ~= "table" then
        queueItem = {
            routeKey = routeKey,
            routeState = routeState,
            attemptCount = 0,
            nextEligibleAt = nextEligibleAt,
        }
        owner.pendingRouteByKey[routeKey] = queueItem
    else
        queueItem.routeState = routeState
        queueItem.nextEligibleAt = math.min(tonumber(queueItem.nextEligibleAt) or nextEligibleAt, nextEligibleAt)
    end

    if owner.broadcastQueueMembership[routeKey] ~= true then
        owner.broadcastQueue[#owner.broadcastQueue + 1] = routeKey
        owner.broadcastQueueMembership[routeKey] = true
    end
    return true
end

function AirdropTrajectorySyncService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function AirdropTrajectorySyncService:Initialize()
    self.broadcastQueue = self.broadcastQueue or {}
    self.broadcastQueueMembership = self.broadcastQueueMembership or {}
    self.pendingRouteByKey = self.pendingRouteByKey or {}
    self.handledRequestKeys = self.handledRequestKeys or {}
    self.requestSequence = self.requestSequence or 0
    self.lastSyncRequestAt = self.lastSyncRequestAt or 0
    self.lastFullBroadcastAt = self.lastFullBroadcastAt or 0
    self.lastTeamChannelReady = self.lastTeamChannelReady or false
    self.lastTeamContextKey = self.lastTeamContextKey or nil
    self.routeAllowance = tonumber(self.routeAllowance) or math.max(1, tonumber(self.ROUTE_ALLOWANCE_MAX) or 10)
    self.routeAllowanceUpdatedAt = tonumber(self.routeAllowanceUpdatedAt) or Utils:GetCurrentTimestamp()
    return true
end

function AirdropTrajectorySyncService:Reset()
    ClearBroadcastState(self)
    self.handledRequestKeys = ClearMap(self.handledRequestKeys)
    self.requestSequence = 0
    self.lastSyncRequestAt = 0
    self.lastFullBroadcastAt = 0
    self.lastTeamChannelReady = false
    self.lastTeamContextKey = nil
    self.routeAllowance = math.max(1, tonumber(self.ROUTE_ALLOWANCE_MAX) or 10)
    self.routeAllowanceUpdatedAt = Utils:GetCurrentTimestamp()
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
    self.broadcastTimerDueAt = nil

    if self:CanSync() ~= true then
        ClearBroadcastState(self)
        return false
    end

    local queueItem = GetHeadQueueItem(self)
    if type(queueItem) ~= "table" then
        return false
    end

    local now = Utils:GetCurrentTimestamp()
    local nextEligibleAt = tonumber(queueItem.nextEligibleAt) or now
    if nextEligibleAt > now then
        return ScheduleBroadcastPump(self, nextEligibleAt - now)
    end

    local canSend, waitDelay = ConsumeRouteAllowance(self, now)
    if canSend ~= true then
        queueItem.nextEligibleAt = now + math.max(0, tonumber(waitDelay) or 0)
        return ScheduleBroadcastPump(self, waitDelay)
    end

    local sent = false
    local resultCode = nil
    if TeamSharedSyncListener and TeamSharedSyncListener.SendTrajectoryRoute then
        sent, resultCode = TeamSharedSyncListener:SendTrajectoryRoute(queueItem.routeState)
    end

    if sent == true then
        self.lastFullBroadcastAt = now
        RemoveHeadQueueItem(self, queueItem.routeKey)
        if GetHeadQueueItem(self) then
            return ScheduleBroadcastPump(self, tonumber(self.ROUTE_SUCCESS_DELAY) or 0.05)
        end
        return true
    end

    if resultCode == "AddonMessageThrottle" or resultCode == "ChannelThrottle" then
        self.routeAllowance = 0
        self.routeAllowanceUpdatedAt = now
        queueItem.nextEligibleAt = now + (tonumber(self.ROUTE_THROTTLE_COOLDOWN) or 1.10)
        return ScheduleBroadcastPump(self, self.ROUTE_THROTTLE_COOLDOWN)
    end

    queueItem.attemptCount = math.max(0, math.floor(tonumber(queueItem.attemptCount) or 0)) + 1
    if queueItem.attemptCount > math.max(0, math.floor(tonumber(self.MAX_NON_THROTTLE_RETRIES) or 2)) then
        RemoveHeadQueueItem(self, queueItem.routeKey)
        if GetHeadQueueItem(self) then
            return ScheduleBroadcastPump(self, tonumber(self.ROUTE_SUCCESS_DELAY) or 0.05)
        end
        return false
    end

    queueItem.nextEligibleAt = now + (tonumber(self.ROUTE_FAILURE_RETRY_DELAY) or 1.25)
    return ScheduleBroadcastPump(self, self.ROUTE_FAILURE_RETRY_DELAY)
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

    local delay = math.max(0, tonumber(delaySeconds) or 0)
    for _, route in ipairs(routes) do
        EnqueueRoute(self, route, delay)
    end
    return ScheduleBroadcastPump(self, delay)
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

    if EnqueueRoute(self, routeState, 0) ~= true then
        return false
    end
    ScheduleBroadcastPump(self, 0)
    return true
end

function AirdropTrajectorySyncService:HandleTeamContextChanged(forceRequest)
    local canSync = self:CanSync() == true
    local previousReady = self.lastTeamChannelReady == true
    local previousContextKey = self.lastTeamContextKey

    self.lastTeamChannelReady = canSync
    if canSync ~= true then
        self.lastTeamContextKey = nil
        ClearBroadcastState(self)
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
        routeKey = syncState.routeKey,
        routeFamilyKey = syncState.routeFamilyKey,
        landingKey = syncState.landingKey,
        alertToken = syncState.alertToken,
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
        mergedRouteCount = tonumber(syncState.mergedRouteCount) or 1,
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
