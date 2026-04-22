-- AirdropTrajectoryService.lua - 空投轨迹实时记录与落点预测

local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Data = BuildEnv("Data")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

AirdropTrajectoryService.MIN_SAMPLE_DELTA = 0.0025
AirdropTrajectoryService.MIN_OBSERVATION_DISTANCE = 0.025
AirdropTrajectoryService.MATCH_DISTANCE_TOLERANCE = 0.015
AirdropTrajectoryService.MATCH_PROJECTION_MARGIN = 0.08
AirdropTrajectoryService.MATCH_CONFIRM_DURATION = 20
AirdropTrajectoryService.MATCH_MIN_SAMPLES = 20
AirdropTrajectoryService.MATCH_GAP_GRACE = 3
AirdropTrajectoryService.MATCH_MIN_PROGRESS_ABSOLUTE = 0.05
AirdropTrajectoryService.MATCH_MIN_PROGRESS_RATIO = 0.20
AirdropTrajectoryService.MATCH_MIN_DIRECTION_DOT = 0.92
AirdropTrajectoryService.MATCH_DIRECTION_MIN_DISTANCE = 0.0035
AirdropTrajectoryService.MATCH_RECENT_MOTION_WINDOW = 0.6
AirdropTrajectoryService.STATIONARY_TOLERANCE = 0.006
AirdropTrajectoryService.MOVE_CONFIRM_DISTANCE = 0.0045
AirdropTrajectoryService.START_STATIONARY_CONFIRM_TIME = 1.0
AirdropTrajectoryService.END_STATIONARY_CONFIRM_TIME = 2.0
AirdropTrajectoryService.MISSING_FINALIZE_DELAY = 2.2

local function ComputeDistance(x1, y1, x2, y2)
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function ComputeRouteVector(route)
    if type(route) ~= "table" then
        return 0, 0, 0
    end
    local dx = (route.endX or 0) - (route.startX or 0)
    local dy = (route.endY or 0) - (route.startY or 0)
    local length = math.sqrt((dx * dx) + (dy * dy))
    return dx, dy, length
end

local function BuildObservationState(targetMapData, iconResult, currentTime)
    if type(targetMapData) ~= "table" or type(iconResult) ~= "table" then
        return nil
    end
    local positionX = tonumber(iconResult.positionX)
    local positionY = tonumber(iconResult.positionY)
    if type(positionX) ~= "number" or type(positionY) ~= "number" then
        return nil
    end
    return {
        runtimeMapId = targetMapData.id,
        mapID = targetMapData.mapID,
        objectGUID = iconResult.objectGUID,
        firstX = positionX,
        firstY = positionY,
        startX = positionX,
        startY = positionY,
        startAnchorX = positionX,
        startAnchorY = positionY,
        startAnchorSamples = 1,
        startStationarySince = currentTime,
        startConfirmed = false,
        movingStarted = false,
        lastX = positionX,
        lastY = positionY,
        endX = positionX,
        endY = positionY,
        endStationarySince = nil,
        endAnchorX = nil,
        endAnchorY = nil,
        endAnchorSamples = 0,
        endConfirmed = false,
        firstSeenAt = currentTime,
        lastSeenAt = currentTime,
        sampleCount = 1,
        announcedRouteKey = nil,
        missingSince = nil,
        uniqueMatchState = nil,
        motionDX = nil,
        motionDY = nil,
        motionRecordedAt = nil,
    }
end

local function EvaluateRouteMatch(route, positionX, positionY, motionDX, motionDY, minDirectionDot, minDirectionDistance)
    local dx, dy, length = ComputeRouteVector(route)
    if type(length) ~= "number" or length <= 0 then
        return nil
    end

    local unitX = dx / length
    local unitY = dy / length
    local relX = positionX - route.startX
    local relY = positionY - route.startY
    local projection = (relX * unitX) + (relY * unitY)
    local projectionMargin = length * (AirdropTrajectoryService.MATCH_PROJECTION_MARGIN or 0.08)
    if projection < -projectionMargin or projection > (length + projectionMargin) then
        return nil
    end

    local closestX = route.startX + (projection * unitX)
    local closestY = route.startY + (projection * unitY)
    local distance = ComputeDistance(positionX, positionY, closestX, closestY)
    if distance > (AirdropTrajectoryService.MATCH_DISTANCE_TOLERANCE or 0.015) then
        return nil
    end

    local motionLength = ComputeDistance(0, 0, motionDX or 0, motionDY or 0)
    if motionLength < (minDirectionDistance or 0.0035) then
        return nil
    end

    local directionDot = (((motionDX or 0) * unitX) + ((motionDY or 0) * unitY)) / motionLength
    if directionDot < (minDirectionDot or 0.92) then
        return nil
    end

    return {
        route = route,
        distance = distance,
        projection = projection,
        routeLength = length,
        progress = projection / length,
        directionDot = directionDot,
    }
end

local function UpdateAnchorAverage(anchorX, anchorY, sampleCount, positionX, positionY)
    local count = math.max(1, tonumber(sampleCount) or 1)
    local nextCount = count + 1
    return ((anchorX * count) + positionX) / nextCount, ((anchorY * count) + positionY) / nextCount, nextCount
end

local function BuildPredictionMessage(targetMapData, route)
    if type(targetMapData) ~= "table" or type(route) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local endX = (route.endX or 0) * 100
    local endY = (route.endY or 0) * 100
    local format = (L and L["TrajectoryPredictionMatched"]) or "【%s】已匹配空投轨迹，预测落点坐标：%.1f, %.1f"
    return string.format(format, mapName, endX, endY)
end

function AirdropTrajectoryService:Initialize()
    self.isInitialized = true
    self.activeObservationByMap = self.activeObservationByMap or {}
    if AirdropTrajectoryStore and AirdropTrajectoryStore.Initialize and not AirdropTrajectoryStore.routesByMap then
        AirdropTrajectoryStore:Initialize()
    end
    return true
end

function AirdropTrajectoryService:Reset()
    self.activeObservationByMap = {}
    self.isInitialized = false
    return true
end

function AirdropTrajectoryService:NotifyPrediction(targetMapData, route)
    local message = BuildPredictionMessage(targetMapData, route)
    if type(message) ~= "string" or message == "" then
        return false
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        return NotificationOutputService:SendLocalMessage(message) == true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "预测", message)
        return true
    end
    return false
end

function AirdropTrajectoryService:TryMatchPrediction(targetMapData, state, iconResult)
    if type(targetMapData) ~= "table" or type(state) ~= "table" or type(iconResult) ~= "table" then
        return false
    end

    local positionX = tonumber(iconResult.positionX)
    local positionY = tonumber(iconResult.positionY)
    if type(positionX) ~= "number" or type(positionY) ~= "number" then
        return false
    end

    if state.movingStarted ~= true then
        return false
    end

    local currentTime = Utils:GetCurrentTimestamp()
    local recentMotionAge = type(state.motionRecordedAt) == "number" and (currentTime - state.motionRecordedAt) or math.huge
    if type(state.motionDX) ~= "number"
        or type(state.motionDY) ~= "number"
        or recentMotionAge > (self.MATCH_RECENT_MOTION_WINDOW or 0.6) then
        if type(state.uniqueMatchState) == "table"
            and (currentTime - (tonumber(state.uniqueMatchState.lastMatchedAt) or 0)) > (self.MATCH_GAP_GRACE or 3) then
            state.uniqueMatchState = nil
        end
        return false
    end
    local currentMatches = {}

    for _, route in ipairs(AirdropTrajectoryStore and AirdropTrajectoryStore.GetRoutes and AirdropTrajectoryStore:GetRoutes(targetMapData.mapID) or {}) do
        local predictionReady = AirdropTrajectoryStore and AirdropTrajectoryStore.IsPredictionReady
            and AirdropTrajectoryStore:IsPredictionReady(route) == true
            or (route and route.endConfirmed == true)
        local routeKey = type(route) == "table" and route.routeKey or nil
        if predictionReady == true and type(routeKey) == "string" and routeKey ~= "" then
            local matched = EvaluateRouteMatch(
                route,
                positionX,
                positionY,
                state.motionDX,
                state.motionDY,
                self.MATCH_MIN_DIRECTION_DOT or 0.92,
                self.MATCH_DIRECTION_MIN_DISTANCE or 0.0035
            )
            if matched and type(matched.routeLength) == "number" then
                currentMatches[#currentMatches + 1] = matched
            end
        end
    end

    if #currentMatches ~= 1 then
        state.uniqueMatchState = nil
        return false
    end

    local candidate = currentMatches[1]
    local route = candidate.route
    if type(route) ~= "table" or state.announcedRouteKey == route.routeKey then
        return false
    end

    local uniqueState = state.uniqueMatchState
    local shouldResetUniqueState = type(uniqueState) ~= "table"
        or uniqueState.routeKey ~= route.routeKey
        or type(uniqueState.lastMatchedAt) ~= "number"
        or (currentTime - uniqueState.lastMatchedAt) > (self.MATCH_GAP_GRACE or 3)
    if shouldResetUniqueState then
        uniqueState = {
            routeKey = route.routeKey,
            route = route,
            routeLength = candidate.routeLength,
            accumulatedDuration = 0,
            matchedSamples = 1,
            minProjection = candidate.projection,
            maxProjection = candidate.projection,
            lastMatchedAt = currentTime,
        }
        state.uniqueMatchState = uniqueState
    else
        local deltaTime = currentTime - uniqueState.lastMatchedAt
        if deltaTime > 0 and deltaTime <= (self.MATCH_GAP_GRACE or 3) then
            uniqueState.accumulatedDuration = (tonumber(uniqueState.accumulatedDuration) or 0) + deltaTime
        end
        uniqueState.lastMatchedAt = currentTime
        uniqueState.matchedSamples = (tonumber(uniqueState.matchedSamples) or 0) + 1
        uniqueState.route = route
        uniqueState.routeLength = candidate.routeLength
        if type(uniqueState.minProjection) ~= "number" or candidate.projection < uniqueState.minProjection then
            uniqueState.minProjection = candidate.projection
        end
        if type(uniqueState.maxProjection) ~= "number" or candidate.projection > uniqueState.maxProjection then
            uniqueState.maxProjection = candidate.projection
        end
    end

    local matchedDuration = tonumber(uniqueState.accumulatedDuration) or 0
    local matchedSamples = tonumber(uniqueState.matchedSamples) or 0
    local progressSpan = (tonumber(uniqueState.maxProjection) or 0) - (tonumber(uniqueState.minProjection) or 0)
    local routeLength = tonumber(uniqueState.routeLength) or 0
    local minProgress = math.max(
        tonumber(self.MATCH_MIN_PROGRESS_ABSOLUTE) or 0.05,
        routeLength * (tonumber(self.MATCH_MIN_PROGRESS_RATIO) or 0.20)
    )

    if matchedDuration < (tonumber(self.MATCH_CONFIRM_DURATION) or 20) then
        return false
    end
    if matchedSamples < (tonumber(self.MATCH_MIN_SAMPLES) or 20) then
        return false
    end
    if progressSpan < minProgress then
        return false
    end

    local notified = self:NotifyPrediction(targetMapData, route)
    if notified == true then
        state.announcedRouteKey = route.routeKey
        state.uniqueMatchState = nil
        if AirdropTrajectoryAlertCoordinator and AirdropTrajectoryAlertCoordinator.HandleLocalPredictionMatched then
            AirdropTrajectoryAlertCoordinator:HandleLocalPredictionMatched(
                targetMapData,
                route,
                iconResult.objectGUID,
                currentTime
            )
        end
    end
    return notified == true
end

function AirdropTrajectoryService:FinalizeObservation(runtimeMapId, currentTime)
    if not self.activeObservationByMap or type(runtimeMapId) ~= "number" then
        return false
    end

    local state = self.activeObservationByMap[runtimeMapId]
    self.activeObservationByMap[runtimeMapId] = nil
    if type(state) ~= "table" then
        return false
    end

    local observedDistance = ComputeDistance(state.firstX, state.firstY, state.lastX, state.lastY)
    if observedDistance < (self.MIN_OBSERVATION_DISTANCE or 0.025) then
        return false
    end

    local startX = state.startConfirmed == true and state.startX or state.firstX
    local startY = state.startConfirmed == true and state.startY or state.firstY
    local endX = state.endConfirmed == true and state.endX or state.lastX
    local endY = state.endConfirmed == true and state.endY or state.lastY

    local routeChanged = false
    local routeRecord = nil
    if AirdropTrajectoryStore and AirdropTrajectoryStore.UpsertRoute then
        routeChanged, routeRecord = AirdropTrajectoryStore:UpsertRoute(
            state.mapID,
            {
                mapID = state.mapID,
                startX = startX,
                startY = startY,
                endX = endX,
                endY = endY,
                observationCount = 1,
                sampleCount = state.sampleCount or 2,
                createdAt = state.firstSeenAt,
                updatedAt = currentTime or state.lastSeenAt,
                source = "local",
                startConfirmed = state.startConfirmed == true,
                endConfirmed = state.endConfirmed == true,
            },
            "local",
            currentTime or state.lastSeenAt
        )
    end

    if routeChanged == true
        and type(routeRecord) == "table"
        and AirdropTrajectorySyncService
        and AirdropTrajectorySyncService.BroadcastRoute then
        AirdropTrajectorySyncService:BroadcastRoute(routeRecord)
    end
    return routeChanged == true
end

function AirdropTrajectoryService:HandleMapSwitch(previousRuntimeMapId, currentTime)
    return self:FinalizeObservation(previousRuntimeMapId, currentTime or Utils:GetCurrentTimestamp())
end

function AirdropTrajectoryService:HandleNoDetection(targetMapData, currentTime)
    if type(targetMapData) ~= "table" or type(targetMapData.id) ~= "number" then
        return false
    end

    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local state = self.activeObservationByMap and self.activeObservationByMap[targetMapData.id] or nil
    if type(state) ~= "table" then
        return false
    end

    if type(state.missingSince) ~= "number" then
        state.missingSince = now
        return false
    end
    if (now - state.missingSince) < (self.MISSING_FINALIZE_DELAY or 2.2) then
        return false
    end

    return self:FinalizeObservation(targetMapData.id, now)
end

function AirdropTrajectoryService:HandleDetectedIcon(targetMapData, iconResult, currentTime)
    if type(targetMapData) ~= "table"
        or type(targetMapData.id) ~= "number"
        or type(targetMapData.mapID) ~= "number"
        or type(iconResult) ~= "table"
        or type(iconResult.objectGUID) ~= "string"
        or iconResult.objectGUID == "" then
        return false
    end

    if not self.isInitialized then
        self:Initialize()
    end

    currentTime = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local runtimeMapId = targetMapData.id
    local positionX = tonumber(iconResult.positionX)
    local positionY = tonumber(iconResult.positionY)
    if type(positionX) ~= "number" or type(positionY) ~= "number" then
        return false
    end
    local state = self.activeObservationByMap[runtimeMapId]

    if type(state) ~= "table" or state.objectGUID ~= iconResult.objectGUID then
        if type(state) == "table" then
            self:FinalizeObservation(runtimeMapId, currentTime)
        end
        state = BuildObservationState(targetMapData, iconResult, currentTime)
        if type(state) ~= "table" then
            return false
        end
        self.activeObservationByMap[runtimeMapId] = state
    else
        state.lastSeenAt = currentTime
        state.missingSince = nil
    end

    local moveConfirmDistance = self.MOVE_CONFIRM_DISTANCE or 0.0045
    local stationaryTolerance = self.STATIONARY_TOLERANCE or 0.006
    local sampleDelta = self.MIN_SAMPLE_DELTA or 0.0025

    if state.movingStarted ~= true then
        local startAnchorDistance = ComputeDistance(state.startAnchorX, state.startAnchorY, positionX, positionY)
        if startAnchorDistance <= stationaryTolerance then
            state.startAnchorX, state.startAnchorY, state.startAnchorSamples = UpdateAnchorAverage(
                state.startAnchorX,
                state.startAnchorY,
                state.startAnchorSamples,
                positionX,
                positionY
            )
            state.startX = state.startAnchorX
            state.startY = state.startAnchorY
            if (currentTime - (state.startStationarySince or currentTime)) >= (self.START_STATIONARY_CONFIRM_TIME or 1.0) then
                state.startConfirmed = true
            end
        elseif startAnchorDistance >= moveConfirmDistance then
            state.movingStarted = true
            state.startX = state.startAnchorX
            state.startY = state.startAnchorY
            state.motionDX = positionX - state.startAnchorX
            state.motionDY = positionY - state.startAnchorY
            state.motionRecordedAt = currentTime
            state.lastX = positionX
            state.lastY = positionY
            state.endX = positionX
            state.endY = positionY
            state.endConfirmed = false
            state.endStationarySince = nil
            state.endAnchorX = nil
            state.endAnchorY = nil
            state.endAnchorSamples = 0
            state.uniqueMatchState = nil
            if state.sampleCount < 2 then
                state.sampleCount = 2
            end
        end
        return self:TryMatchPrediction(targetMapData, state, iconResult)
    end

    local moveDistance = ComputeDistance(state.lastX, state.lastY, positionX, positionY)
    local anchorDistance = state.endStationarySince
        and ComputeDistance(state.endAnchorX, state.endAnchorY, positionX, positionY)
        or math.huge

    if state.endStationarySince and anchorDistance <= stationaryTolerance then
        state.endAnchorX, state.endAnchorY, state.endAnchorSamples = UpdateAnchorAverage(
            state.endAnchorX,
            state.endAnchorY,
            state.endAnchorSamples,
            positionX,
            positionY
        )
        if state.endConfirmed ~= true
            and (currentTime - state.endStationarySince) >= (self.END_STATIONARY_CONFIRM_TIME or 2.0) then
            state.endConfirmed = true
            state.endX = state.endAnchorX
            state.endY = state.endAnchorY
        end
    elseif moveDistance >= sampleDelta then
        state.motionDX = positionX - state.lastX
        state.motionDY = positionY - state.lastY
        state.motionRecordedAt = currentTime
        state.lastX = positionX
        state.lastY = positionY
        state.sampleCount = (tonumber(state.sampleCount) or 1) + 1
        if state.endConfirmed == true and anchorDistance > stationaryTolerance then
            state.endConfirmed = false
        end
        state.endStationarySince = nil
        state.endAnchorX = nil
        state.endAnchorY = nil
        state.endAnchorSamples = 0
    else
        state.endStationarySince = currentTime
        state.endAnchorX = positionX
        state.endAnchorY = positionY
        state.endAnchorSamples = 1
    end

    return self:TryMatchPrediction(targetMapData, state, iconResult)
end

return AirdropTrajectoryService
