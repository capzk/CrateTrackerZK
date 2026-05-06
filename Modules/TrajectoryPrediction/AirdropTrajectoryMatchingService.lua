-- AirdropTrajectoryMatchingService.lua - 轨迹预测匹配主模块（独立于采集链）

local AirdropTrajectoryMatchingService = BuildEnv("AirdropTrajectoryMatchingService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local Data = BuildEnv("Data")
local Utils = BuildEnv("Utils")

AirdropTrajectoryMatchingService.MIN_OBSERVATION_COUNT_FORMAL = 6
AirdropTrajectoryMatchingService.MIN_OBSERVATION_COUNT_CANDIDATE = 4
AirdropTrajectoryMatchingService.MIN_PROGRESS_RATIO_FORMAL = 0.22
AirdropTrajectoryMatchingService.MIN_PROGRESS_RATIO_CANDIDATE = 0.16
AirdropTrajectoryMatchingService.MIN_REMAINING_RATIO_FORMAL = 0.15
AirdropTrajectoryMatchingService.MIN_REMAINING_RATIO_CANDIDATE = 0.08
AirdropTrajectoryMatchingService.MIN_REMAINING_ABSOLUTE_FORMAL = 0.04
AirdropTrajectoryMatchingService.MIN_REMAINING_ABSOLUTE_CANDIDATE = 0.03
AirdropTrajectoryMatchingService.START_TOLERANCE = 0.08
AirdropTrajectoryMatchingService.CORRIDOR_TOLERANCE = 0.018
AirdropTrajectoryMatchingService.PROJECTION_MARGIN = 0.015
AirdropTrajectoryMatchingService.MIN_DIRECTION_DOT = 0.90
AirdropTrajectoryMatchingService.FORMAL_MIN_SCORE = 0.68
AirdropTrajectoryMatchingService.FORMAL_MIN_MARGIN = 0.10
AirdropTrajectoryMatchingService.FORMAL_MIN_RATIO = 1.28
AirdropTrajectoryMatchingService.CANDIDATE_MIN_SCORE = 0.50
AirdropTrajectoryMatchingService.CANDIDATE_MIN_SECOND_SCORE = 0.38
AirdropTrajectoryMatchingService.PREFIX_PROGRESS_TOLERANCE_RATIO = 0.35
AirdropTrajectoryMatchingService.CANDIDATE_PAIR_CONFIRM_OBSERVATIONS = 6

local function ComputeDistance(x1, y1, x2, y2)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeDistance then
        return AirdropTrajectoryGeometryService:ComputeDistance(x1, y1, x2, y2)
    end
    local dx = (tonumber(x2) or 0) - (tonumber(x1) or 0)
    local dy = (tonumber(y2) or 0) - (tonumber(y1) or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function Clamp01(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" then
        return 0
    end
    if numberValue < 0 then
        return 0
    end
    if numberValue > 1 then
        return 1
    end
    return numberValue
end

local function QuantizeDiagnosticBucket(value, step)
    local numberValue = tonumber(value)
    local stepValue = tonumber(step) or 0.05
    if type(numberValue) ~= "number" or stepValue <= 0 then
        return "nil"
    end
    return tostring(math.floor((numberValue / stepValue) + 0.5))
end

local function BuildStablePairKey(leftValue, rightValue)
    local leftText = tostring(leftValue or "")
    local rightText = tostring(rightValue or "")
    if leftText == "" or rightText == "" then
        return nil
    end
    if rightText < leftText then
        leftText, rightText = rightText, leftText
    end
    return leftText .. "|" .. rightText
end

local function EnsureCandidatePairState(state)
    if type(state) ~= "table" then
        return nil
    end
    state.candidatePairState = type(state.candidatePairState) == "table" and state.candidatePairState or {
        firstPairKey = nil,
        latestPairKey = nil,
        multiplePairsObserved = false,
        firstObservedObservationCount = nil,
        latestObservedObservationCount = nil,
    }
    return state.candidatePairState
end

local function ObserveCandidatePair(state, pairKey, observationCount)
    if type(pairKey) ~= "string" or pairKey == "" then
        return nil
    end
    local pairState = EnsureCandidatePairState(state)
    if type(pairState) ~= "table" then
        return nil
    end

    if type(pairState.firstPairKey) ~= "string" or pairState.firstPairKey == "" then
        pairState.firstPairKey = pairKey
        pairState.firstObservedObservationCount = math.max(0, math.floor(tonumber(observationCount) or 0))
    elseif pairState.firstPairKey ~= pairKey then
        pairState.multiplePairsObserved = true
    end
    pairState.latestPairKey = pairKey
    pairState.latestObservedObservationCount = math.max(0, math.floor(tonumber(observationCount) or 0))
    return pairState
end

local function ResolveDiagnosticMapName(targetMapData, state)
    if type(targetMapData) == "table" and Data and Data.GetMapDisplayName then
        return Data:GetMapDisplayName(targetMapData)
    end
    if type(targetMapData) == "table" and type(targetMapData.mapID) == "number" then
        return tostring(targetMapData.mapID)
    end
    if type(state) == "table" and type(state.mapID) == "number" then
        return tostring(state.mapID)
    end
    return nil
end

local function RecordPredictionEvent(service, targetMapData, state, iconResult, eventType, decision)
    if type(service) ~= "table" or not service.RecordTraceEvent or type(state) ~= "table" then
        return false
    end

    decision = type(decision) == "table" and decision or {}
    local traceKey = table.concat({
        tostring(eventType or ""),
        tostring(decision.routeKey or ""),
        tostring(decision.bestDestinationKey or ""),
        tostring(decision.secondDestinationKey or ""),
        tostring(decision.reason or ""),
        tostring(decision.candidateRouteCount or ""),
        tostring(decision.bestRouteKey or ""),
        QuantizeDiagnosticBucket(decision.bestScore, 0.05),
        QuantizeDiagnosticBucket(decision.secondScore, 0.05),
        QuantizeDiagnosticBucket(decision.scoreRatio, 0.10),
        QuantizeDiagnosticBucket(decision.scoreMargin, 0.05),
    }, "|")
    if state.lastPredictionTraceKey == traceKey then
        return false
    end
    state.lastPredictionTraceKey = traceKey

    service:RecordTraceEvent({
        recordedAt = Utils:GetCurrentTimestamp(),
        eventType = eventType,
        mapName = ResolveDiagnosticMapName(targetMapData, state),
        mapID = type(targetMapData) == "table" and targetMapData.mapID or state.mapID,
        runtimeMapId = type(targetMapData) == "table" and targetMapData.id or nil,
        objectGUID = type(iconResult) == "table" and iconResult.objectGUID or nil,
        sourceObjectGUID = state.objectGUID,
        positionX = type(iconResult) == "table" and tonumber(iconResult.positionX) or tonumber(state.lastX),
        positionY = type(iconResult) == "table" and tonumber(iconResult.positionY) or tonumber(state.lastY),
        sampleCount = state.sampleCount,
        observationCount = state.predictionObservationCount,
        routeKey = decision.routeKey,
        trackKey = decision.bestDestinationKey,
        firstRouteKey = decision.bestRouteKey,
        secondRouteKey = decision.secondRouteKey,
        candidateCount = decision.candidateRouteCount,
        selectionScore = decision.bestScore,
        selectionScoreMargin = decision.scoreMargin,
        stableWins = nil,
        stableSeconds = nil,
        projection = decision.projection,
        observationLength = decision.observationLength,
        remainingDistance = decision.remainingDistance,
        startSource = state.startSource,
        endSource = state.endSource,
        startConfirmed = state.startConfirmed == true,
        endConfirmed = state.endConfirmed == true,
        note = decision.reason,
        bestDestinationKey = decision.bestDestinationKey,
        secondDestinationKey = decision.secondDestinationKey,
        bestScore = decision.bestScore,
        secondScore = decision.secondScore,
        scoreRatio = decision.scoreRatio,
        scoreMargin = decision.scoreMargin,
        bestRouteKey = decision.bestRouteKey,
        totalRouteCount = decision.totalRouteCount,
        rejectedByStart = decision.rejectedByStart,
        rejectedByDirection = decision.rejectedByDirection,
        rejectedByCorridor = decision.rejectedByCorridor,
        rejectedByProjection = decision.rejectedByProjection,
        observationStartX = decision.observationStartX,
        observationStartY = decision.observationStartY,
        observationEndX = decision.observationEndX,
        observationEndY = decision.observationEndY,
        candidateConfirmObservations = decision.candidateConfirmObservations,
    })
    return true
end

local function ResolveObservationStart(state)
    if type(state) ~= "table" then
        return nil, nil
    end
    local startX = tonumber((state.startConfirmed == true and state.startX) or state.firstX)
    local startY = tonumber((state.startConfirmed == true and state.startY) or state.firstY)
    if type(startX) ~= "number" or type(startY) ~= "number" then
        return nil, nil
    end
    return startX, startY
end

local function ResolveObservationEnd(state, iconResult)
    if type(state) ~= "table" then
        return nil, nil
    end
    local endX = tonumber(state.cruiseEndX) or tonumber(state.lastX) or (type(iconResult) == "table" and tonumber(iconResult.positionX) or nil)
    local endY = tonumber(state.cruiseEndY) or tonumber(state.lastY) or (type(iconResult) == "table" and tonumber(iconResult.positionY) or nil)
    if type(endX) ~= "number" or type(endY) ~= "number" then
        return nil, nil
    end
    return endX, endY
end

local function ResolveObservation(state, iconResult)
    local startX, startY = ResolveObservationStart(state)
    local endX, endY = ResolveObservationEnd(state, iconResult)
    if type(startX) ~= "number" or type(startY) ~= "number" or type(endX) ~= "number" or type(endY) ~= "number" then
        return nil
    end

    local observationLength = ComputeDistance(startX, startY, endX, endY)
    if observationLength <= 0 then
        return nil
    end

    return {
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        length = observationLength,
        directionX = (endX - startX) / observationLength,
        directionY = (endY - startY) / observationLength,
        observationCount = math.max(0, math.floor(tonumber(state.predictionObservationCount) or 0)),
    }
end

local function BuildRouteVector(route)
    local startX = tonumber(route.startX)
    local startY = tonumber(route.startY)
    local endX = tonumber(route.endX)
    local endY = tonumber(route.endY)
    if type(startX) ~= "number"
        or type(startY) ~= "number"
        or type(endX) ~= "number"
        or type(endY) ~= "number" then
        return nil
    end

    local routeLength = ComputeDistance(startX, startY, endX, endY)
    if routeLength <= 0 then
        return nil
    end

    return {
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        length = routeLength,
        unitX = (endX - startX) / routeLength,
        unitY = (endY - startY) / routeLength,
    }
end

local function DistancePointToRoute(routeVector, x, y)
    if type(routeVector) ~= "table" then
        return math.huge, nil
    end
    local projection = ((x - routeVector.startX) * routeVector.unitX) + ((y - routeVector.startY) * routeVector.unitY)
    local closestX = routeVector.startX + (routeVector.unitX * projection)
    local closestY = routeVector.startY + (routeVector.unitY * projection)
    return ComputeDistance(x, y, closestX, closestY), projection
end

local function BuildDestinationKey(route)
    if type(route) ~= "table" then
        return nil
    end
    if type(route.landingKey) == "string" and route.landingKey ~= "" then
        return route.landingKey
    end
    local endX = math.floor(((tonumber(route.endX) or 0) * 100) + 0.5)
    local endY = math.floor(((tonumber(route.endY) or 0) * 100) + 0.5)
    return table.concat({ tostring(tonumber(route.mapID) or 0), tostring(endX), tostring(endY) }, ":")
end

local function ResolveRouteFamilyKey(route)
    if type(route) ~= "table" then
        return nil
    end
    local routeFamilyKey = route.routeFamilyKey
    if type(routeFamilyKey) == "string" and routeFamilyKey ~= "" then
        return routeFamilyKey
    end
    return nil
end

local function ScoreRoute(observation, route)
    local routeVector = BuildRouteVector(route)
    if type(routeVector) ~= "table" then
        return nil
    end

    local startDistance = ComputeDistance(observation.startX, observation.startY, routeVector.startX, routeVector.startY)
    if startDistance > AirdropTrajectoryMatchingService.START_TOLERANCE then
        return nil
    end

    local directionDot = (observation.directionX * routeVector.unitX) + (observation.directionY * routeVector.unitY)
    if directionDot < AirdropTrajectoryMatchingService.MIN_DIRECTION_DOT then
        return nil
    end

    local corridorDistance, projection = DistancePointToRoute(routeVector, observation.endX, observation.endY)
    if corridorDistance > AirdropTrajectoryMatchingService.CORRIDOR_TOLERANCE then
        return nil
    end
    if type(projection) ~= "number"
        or projection < -AirdropTrajectoryMatchingService.PROJECTION_MARGIN
        or projection > (routeVector.length + AirdropTrajectoryMatchingService.PROJECTION_MARGIN) then
        return nil
    end

    local startFit = 1 - Clamp01(startDistance / AirdropTrajectoryMatchingService.START_TOLERANCE)
    local directionFit = Clamp01((directionDot - AirdropTrajectoryMatchingService.MIN_DIRECTION_DOT) / math.max(0.000001, 1 - AirdropTrajectoryMatchingService.MIN_DIRECTION_DOT))
    local corridorFit = 1 - Clamp01(corridorDistance / AirdropTrajectoryMatchingService.CORRIDOR_TOLERANCE)
    local progressTolerance = math.max(0.02, observation.length * AirdropTrajectoryMatchingService.PREFIX_PROGRESS_TOLERANCE_RATIO)
    local progressFit = 1 - Clamp01(math.abs(observation.length - projection) / progressTolerance)

    local routeScore = 0
    routeScore = routeScore + (startFit * 0.18)
    routeScore = routeScore + (directionFit * 0.30)
    routeScore = routeScore + (corridorFit * 0.34)
    routeScore = routeScore + (progressFit * 0.18)

    return {
        route = route,
        routeKey = route.routeKey,
        destinationKey = BuildDestinationKey(route),
        routeScore = routeScore,
        projection = projection,
        routeLength = routeVector.length,
        remainingDistance = routeVector.length - projection,
        observationLength = observation.length,
        observationProgress = routeVector.length > 0 and Clamp01(observation.length / routeVector.length) or 0,
        projectionProgress = routeVector.length > 0 and Clamp01(projection / routeVector.length) or 0,
    }
end

local function CompareScoredRoutes(left, right)
    if type(left) ~= "table" then
        return false
    end
    if type(right) ~= "table" then
        return true
    end

    local leftScore = tonumber(left.routeScore) or -math.huge
    local rightScore = tonumber(right.routeScore) or -math.huge
    if leftScore ~= rightScore then
        return leftScore > rightScore
    end

    local leftKey = tostring(left.routeKey or "")
    local rightKey = tostring(right.routeKey or "")
    return leftKey < rightKey
end

local function BuildDestinationRankings(scoredRoutes)
    local groups = {}
    for _, scoredRoute in ipairs(scoredRoutes or {}) do
        local destinationKey = type(scoredRoute.destinationKey) == "string" and scoredRoute.destinationKey or nil
        if type(destinationKey) == "string" and destinationKey ~= "" then
            local group = groups[destinationKey]
            if type(group) ~= "table" then
                group = {
                    destinationKey = destinationKey,
                    routes = {},
                    bestRoute = nil,
                }
                groups[destinationKey] = group
            end
            group.routes[#group.routes + 1] = scoredRoute
            if CompareScoredRoutes(scoredRoute, group.bestRoute) then
                group.bestRoute = scoredRoute
            end
        end
    end

    local rankings = {}
    for _, group in pairs(groups) do
        table.sort(group.routes, CompareScoredRoutes)
        rankings[#rankings + 1] = {
            destinationKey = group.destinationKey,
            bestRoute = group.bestRoute,
            destinationScore = tonumber(group.bestRoute and group.bestRoute.routeScore) or 0,
            routeCount = #group.routes,
        }
    end

    table.sort(rankings, function(left, right)
        local leftScore = tonumber(left and left.destinationScore) or -math.huge
        local rightScore = tonumber(right and right.destinationScore) or -math.huge
        if leftScore ~= rightScore then
            return leftScore > rightScore
        end
        return tostring(left and left.destinationKey or "") < tostring(right and right.destinationKey or "")
    end)
    return rankings
end

local function BuildDecision(action, reason, fields)
    local decision = {
        action = action,
        reason = reason,
    }
    for key, value in pairs(fields or {}) do
        decision[key] = value
    end
    return decision
end

local function ApplyFormalPrediction(service, targetMapData, state, iconResult, decision)
    if type(decision) ~= "table" or type(decision.route) ~= "table" or type(decision.routeKey) ~= "string" then
        return false
    end

    local notified = service.NotifyPrediction and service:NotifyPrediction(targetMapData, decision.route) == true or false
    local queuedForTeam = false
    local teamReason = nil
    if service.IsPredictionTestEnabled
        and service:IsPredictionTestEnabled() == true
        and AirdropTrajectoryAlertCoordinator
        and AirdropTrajectoryAlertCoordinator.HandleLocalPredictionMatched then
        queuedForTeam, teamReason = AirdropTrajectoryAlertCoordinator:HandleLocalPredictionMatched(
            targetMapData,
            decision.route,
            iconResult.objectGUID,
            Utils:GetCurrentTimestamp()
        )
    end

    if notified ~= true and queuedForTeam ~= true then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", {
            reason = string.format(
                "formal_notify_failed route=%s local=%s team=%s(%s)",
                tostring(decision.routeKey),
                tostring(notified == true),
                tostring(queuedForTeam == true),
                tostring(teamReason or "not_requested")
            ),
            routeKey = decision.routeKey,
            bestDestinationKey = decision.bestDestinationKey,
            secondDestinationKey = decision.secondDestinationKey,
            bestRouteKey = decision.bestRouteKey,
            bestScore = decision.bestScore,
            secondScore = decision.secondScore,
            scoreRatio = decision.scoreRatio,
            scoreMargin = decision.scoreMargin,
            projection = decision.projection,
            observationLength = decision.observationLength,
            remainingDistance = decision.remainingDistance,
            candidateRouteCount = decision.candidateRouteCount,
        })
        return false
    end

    state.announcedRouteKey = decision.routeKey
    state.predictedRouteKey = decision.routeKey
    state.predictedEndX = decision.route.endX
    state.predictedEndY = decision.route.endY
    state.formalPrediction = {
        routeKey = decision.routeKey,
        destinationClusterKey = decision.bestDestinationKey,
        sent = true,
    }

    RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_formal", decision)
    if queuedForTeam == true then
        state.teamFormalPrediction = {
            routeKey = decision.routeKey,
            queued = true,
            visibleSent = false,
        }
    end
    return true
end

local function ApplyCandidatePrediction(service, targetMapData, state, iconResult, decision)
    if type(decision) ~= "table" or type(decision.candidates) ~= "table" or #decision.candidates ~= 2 then
        return false
    end

    local localSent, localReason = false, "candidate_notify_unavailable"
    if service.NotifyPredictionCandidates then
        localSent, localReason = service:NotifyPredictionCandidates(targetMapData, decision.candidates, state)
    end

    local queued, coordinationReason = false, nil
    if AirdropTrajectoryAlertCoordinator and AirdropTrajectoryAlertCoordinator.HandleLocalPredictionCandidates then
        local stablePairKey = BuildStablePairKey(decision.bestDestinationKey, decision.secondDestinationKey)
        local alertToken = type(stablePairKey) == "string" and stablePairKey ~= ""
            and ("ambig:" .. stablePairKey)
            or nil
        if type(alertToken) == "string" and alertToken ~= "" then
            queued, coordinationReason = AirdropTrajectoryAlertCoordinator:HandleLocalPredictionCandidates(
                targetMapData,
                alertToken,
                iconResult.objectGUID,
                decision.candidates,
                Utils:GetCurrentTimestamp()
            )
        end
    end

    if localSent == true then
        state.localCandidate = {
            candidateKey = decision.candidateKey,
            sent = true,
        }
    end
    if queued == true then
        state.teamCandidate = {
            candidateKey = decision.candidateKey,
            queued = true,
            visibleSent = false,
        }
        state.teamCandidateAlertQueued = true
    end

    local trace = {}
    for key, value in pairs(decision) do
        trace[key] = value
    end
    trace.reason = string.format(
        "%s local=%s(%s) team=%s(%s)",
        tostring(decision.reason or "candidate"),
        tostring(localSent == true),
        tostring(localReason or "unknown"),
        tostring(queued == true),
        tostring(coordinationReason or "not_requested")
    )

    RecordPredictionEvent(
        service,
        targetMapData,
        state,
        iconResult,
        (localSent == true or queued == true) and "prediction_candidate" or "prediction_wait",
        trace
    )
    return localSent == true or queued == true
end

function AirdropTrajectoryMatchingService:TryMatchPrediction(service, targetMapData, state, iconResult)
    if type(service) ~= "table"
        or type(targetMapData) ~= "table"
        or type(state) ~= "table"
        or type(iconResult) ~= "table" then
        return false
    end
    if type(state.announcedRouteKey) == "string" and state.announcedRouteKey ~= "" then
        return false
    end
    if state.movingStarted ~= true then
        return false
    end

    if AirdropTrajectoryStore and AirdropTrajectoryStore.Initialize and type(AirdropTrajectoryStore.routesByMap) ~= "table" then
        AirdropTrajectoryStore:Initialize()
    end

    local observation = ResolveObservation(state, iconResult)
    if type(observation) ~= "table" then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", { reason = "observation_unavailable" })
        return false
    end

    local mapID = tonumber(targetMapData.mapID) or tonumber(state.mapID)
    local routes = AirdropTrajectoryStore and AirdropTrajectoryStore.GetPredictionRoutes and AirdropTrajectoryStore:GetPredictionRoutes(mapID) or {}
    if type(routes) ~= "table" or #routes == 0 then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", { reason = "route_missing" })
        return false
    end

    local scoredRoutes = {}
    local rejectedByStart = 0
    local rejectedByDirection = 0
    local rejectedByCorridor = 0
    local rejectedByProjection = 0
    for _, route in ipairs(routes) do
        local routeVector = BuildRouteVector(route)
        if type(routeVector) ~= "table" then
            rejectedByProjection = rejectedByProjection + 1
        else
            local startDistance = ComputeDistance(observation.startX, observation.startY, routeVector.startX, routeVector.startY)
            if startDistance > self.START_TOLERANCE then
                rejectedByStart = rejectedByStart + 1
            else
                local directionDot = (observation.directionX * routeVector.unitX) + (observation.directionY * routeVector.unitY)
                if directionDot < self.MIN_DIRECTION_DOT then
                    rejectedByDirection = rejectedByDirection + 1
                else
                    local corridorDistance, projection = DistancePointToRoute(routeVector, observation.endX, observation.endY)
                    if corridorDistance > self.CORRIDOR_TOLERANCE then
                        rejectedByCorridor = rejectedByCorridor + 1
                    elseif type(projection) ~= "number"
                        or projection < -self.PROJECTION_MARGIN
                        or projection > (routeVector.length + self.PROJECTION_MARGIN) then
                        rejectedByProjection = rejectedByProjection + 1
                    else
                        local scoredRoute = ScoreRoute(observation, route)
                        if type(scoredRoute) == "table" then
                            scoredRoutes[#scoredRoutes + 1] = scoredRoute
                        end
                    end
                end
            end
        end
    end
    table.sort(scoredRoutes, CompareScoredRoutes)
    if #scoredRoutes == 0 then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", {
            reason = "candidate_missing",
            candidateRouteCount = 0,
            totalRouteCount = #routes,
            rejectedByStart = rejectedByStart,
            rejectedByDirection = rejectedByDirection,
            rejectedByCorridor = rejectedByCorridor,
            rejectedByProjection = rejectedByProjection,
            observationStartX = observation.startX,
            observationStartY = observation.startY,
            observationEndX = observation.endX,
            observationEndY = observation.endY,
            observationLength = observation.length,
        })
        return false
    end

    local rankings = BuildDestinationRankings(scoredRoutes)
    local bestDestination = rankings[1]
    local secondDestination = rankings[2]
    local bestRoute = bestDestination and bestDestination.bestRoute or nil
    if type(bestDestination) ~= "table" or type(bestRoute) ~= "table" then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", { reason = "destination_missing", candidateRouteCount = #scoredRoutes })
        return false
    end

    local bestScore = tonumber(bestDestination.destinationScore) or 0
    local secondScore = tonumber(secondDestination and secondDestination.destinationScore) or 0
    local scoreMargin = bestScore - secondScore
    local scoreRatio = secondScore > 0 and (bestScore / secondScore) or math.huge
    local progress = tonumber(bestRoute.projectionProgress) or 0
    local remainingDistance = tonumber(bestRoute.remainingDistance) or 0
    local routeLength = tonumber(bestRoute.routeLength) or 0
    local observationCount = observation.observationCount

    state.latestDecision = {
        bestDestinationKey = bestDestination.destinationKey,
        secondDestinationKey = secondDestination and secondDestination.destinationKey or nil,
        bestScore = bestScore,
        secondScore = secondScore,
        scoreRatio = scoreRatio,
        scoreMargin = scoreMargin,
        bestRouteKey = bestRoute.routeKey,
        observationCount = observationCount,
        observationLength = observation.length,
        candidateRouteCount = #scoredRoutes,
    }

    local decisionFields = {
        routeKey = bestRoute.routeKey,
        route = bestRoute.route,
        bestRouteKey = bestRoute.routeKey,
        secondRouteKey = secondDestination and secondDestination.bestRoute and secondDestination.bestRoute.routeKey or nil,
        bestDestinationKey = bestDestination.destinationKey,
        secondDestinationKey = secondDestination and secondDestination.destinationKey or nil,
        bestScore = bestScore,
        secondScore = secondScore,
        scoreRatio = scoreRatio,
        scoreMargin = scoreMargin,
        observationLength = observation.length,
        observationCount = observationCount,
        projection = bestRoute.projection,
        remainingDistance = remainingDistance,
        candidateRouteCount = #scoredRoutes,
        candidateKey = secondDestination and BuildStablePairKey(bestDestination.destinationKey, secondDestination.destinationKey) or nil,
        totalRouteCount = #routes,
        rejectedByStart = rejectedByStart,
        rejectedByDirection = rejectedByDirection,
        rejectedByCorridor = rejectedByCorridor,
        rejectedByProjection = rejectedByProjection,
        observationStartX = observation.startX,
        observationStartY = observation.startY,
        observationEndX = observation.endX,
        observationEndY = observation.endY,
    }

    if observationCount < self.MIN_OBSERVATION_COUNT_CANDIDATE then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", BuildDecision("wait", string.format("observation_short obs=%d required=%d", observationCount, self.MIN_OBSERVATION_COUNT_CANDIDATE), decisionFields))
        return false
    end

    if progress < self.MIN_PROGRESS_RATIO_CANDIDATE then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", BuildDecision("wait", string.format("progress_short progress=%.4f required=%.4f", progress, self.MIN_PROGRESS_RATIO_CANDIDATE), decisionFields))
        return false
    end

    local minRemainingCandidate = math.max(self.MIN_REMAINING_ABSOLUTE_CANDIDATE, routeLength * self.MIN_REMAINING_RATIO_CANDIDATE)
    if remainingDistance < minRemainingCandidate then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", BuildDecision("wait", string.format("remaining_short remain=%.4f required=%.4f", remainingDistance, minRemainingCandidate), decisionFields))
        return false
    end

    local minRemainingFormal = math.max(self.MIN_REMAINING_ABSOLUTE_FORMAL, routeLength * self.MIN_REMAINING_RATIO_FORMAL)
    if observationCount >= self.MIN_OBSERVATION_COUNT_FORMAL
        and progress >= self.MIN_PROGRESS_RATIO_FORMAL
        and remainingDistance >= minRemainingFormal
        and bestScore >= self.FORMAL_MIN_SCORE
        and (scoreRatio >= self.FORMAL_MIN_RATIO or scoreMargin >= self.FORMAL_MIN_MARGIN) then
        return ApplyFormalPrediction(
            service,
            targetMapData,
            state,
            iconResult,
            BuildDecision("formal", "formal_unique_destination", decisionFields)
        )
    end

    if type(secondDestination) ~= "table" or type(secondDestination.bestRoute) ~= "table" then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", BuildDecision("wait", "destination_single_but_not_formal", decisionFields))
        return false
    end

    local bestRouteFamilyKey = ResolveRouteFamilyKey(bestRoute.route)
    local secondRouteFamilyKey = ResolveRouteFamilyKey(secondDestination.bestRoute.route)
    decisionFields.bestRouteFamilyKey = bestRouteFamilyKey
    decisionFields.secondRouteFamilyKey = secondRouteFamilyKey
    if type(bestRouteFamilyKey) ~= "string"
        or bestRouteFamilyKey == ""
        or type(secondRouteFamilyKey) ~= "string"
        or secondRouteFamilyKey == ""
        or bestRouteFamilyKey ~= secondRouteFamilyKey then
        RecordPredictionEvent(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_wait",
            BuildDecision(
                "wait",
                string.format(
                    "candidate_cross_track_rejected bestFamily=%s secondFamily=%s",
                    tostring(bestRouteFamilyKey or ""),
                    tostring(secondRouteFamilyKey or "")
                ),
                decisionFields
            )
        )
        return false
    end

    local candidatePairKey = BuildStablePairKey(bestDestination.destinationKey, secondDestination.destinationKey)
    local pairState = ObserveCandidatePair(state, candidatePairKey, observationCount)
    decisionFields.candidateKey = candidatePairKey
    if type(pairState) == "table" and pairState.multiplePairsObserved == true then
        RecordPredictionEvent(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_wait",
            BuildDecision(
                "wait",
                string.format(
                    "candidate_pair_multiple_groups first=%s current=%s",
                    tostring(pairState.firstPairKey or ""),
                    tostring(pairState.latestPairKey or "")
                ),
                decisionFields
            )
        )
        return false
    end

    local firstObservedObservationCount = type(pairState) == "table"
        and math.max(0, math.floor(tonumber(pairState.firstObservedObservationCount) or 0))
        or 0
    local candidateConfirmObservations = observationCount - firstObservedObservationCount + 1
    decisionFields.candidateConfirmObservations = candidateConfirmObservations
    if candidateConfirmObservations < math.max(1, math.floor(tonumber(self.CANDIDATE_PAIR_CONFIRM_OBSERVATIONS) or 6)) then
        RecordPredictionEvent(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_wait",
            BuildDecision(
                "wait",
                string.format(
                    "candidate_pair_not_confirmed seen=%d required=%d",
                    candidateConfirmObservations,
                    math.max(1, math.floor(tonumber(self.CANDIDATE_PAIR_CONFIRM_OBSERVATIONS) or 6))
                ),
                decisionFields
            )
        )
        return false
    end

    if bestScore < self.CANDIDATE_MIN_SCORE or secondScore < self.CANDIDATE_MIN_SECOND_SCORE then
        RecordPredictionEvent(service, targetMapData, state, iconResult, "prediction_wait", BuildDecision("wait", string.format("candidate_score_short best=%.4f second=%.4f", bestScore, secondScore), decisionFields))
        return false
    end

    return ApplyCandidatePrediction(
        service,
        targetMapData,
        state,
        iconResult,
        BuildDecision("candidate", "candidate_dual_destination", {
            routeKey = bestRoute.routeKey,
            route = bestRoute.route,
            bestRouteKey = bestRoute.routeKey,
            secondRouteKey = secondDestination.bestRoute.routeKey,
            bestDestinationKey = bestDestination.destinationKey,
            secondDestinationKey = secondDestination.destinationKey,
            bestScore = bestScore,
            secondScore = secondScore,
            scoreRatio = scoreRatio,
            scoreMargin = scoreMargin,
            observationLength = observation.length,
            observationCount = observationCount,
            projection = bestRoute.projection,
            remainingDistance = remainingDistance,
            candidateRouteCount = #scoredRoutes,
            candidateKey = candidatePairKey,
            candidates = {
                bestDestination.bestRoute.route,
                secondDestination.bestRoute.route,
            },
        })
    )
end

return AirdropTrajectoryMatchingService
