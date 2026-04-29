-- AirdropTrajectoryMatchingService.lua - 空投轨迹预测匹配决策

local AirdropTrajectoryMatchingService = BuildEnv("AirdropTrajectoryMatchingService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local Data = BuildEnv("Data")
local Utils = BuildEnv("Utils")

local function ComputeDistance(x1, y1, x2, y2)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeDistance then
        return AirdropTrajectoryGeometryService:ComputeDistance(x1, y1, x2, y2)
    end
    return 0
end

local function ComputeRouteVector(route)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeRouteVector then
        return AirdropTrajectoryGeometryService:ComputeRouteVector(route)
    end
    return 0, 0, 0
end

local function BuildProjectionContext(route)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.BuildProjectionContext then
        return AirdropTrajectoryGeometryService:BuildProjectionContext(route)
    end
    return nil
end

local function DistancePointToLine(context, x, y)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.DistancePointToLine then
        return AirdropTrajectoryGeometryService:DistancePointToLine(context, x, y)
    end
    return math.huge, nil
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

local function ResolveObservationLine(state, fallbackX, fallbackY)
    if type(state) ~= "table" then
        return nil
    end

    local startX, startY = ResolveObservationStart(state)
    if type(startX) ~= "number" or type(startY) ~= "number" then
        return nil
    end

    local endX = tonumber(state.cruiseEndX) or tonumber(state.lastX) or tonumber(fallbackX)
    local endY = tonumber(state.cruiseEndY) or tonumber(state.lastY) or tonumber(fallbackY)
    if type(endX) ~= "number" or type(endY) ~= "number" then
        return nil
    end

    local dx = endX - startX
    local dy = endY - startY
    local length = ComputeDistance(startX, startY, endX, endY)
    if type(length) ~= "number" or length <= 0 then
        return nil
    end

    return {
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        dx = dx,
        dy = dy,
        length = length,
    }
end

local function ShouldRejectByStartDistance(service, state, matched)
    if type(service) ~= "table" or type(state) ~= "table" or type(matched) ~= "table" then
        return false
    end

    local startDistance = tonumber(matched.startDistance)
    if type(startDistance) ~= "number" then
        return false
    end

    local tolerance = tonumber(service.MATCH_START_DISTANCE_TOLERANCE) or 0.08
    if state.startConfirmed == true then
        return startDistance > tolerance
    end
    return false
end

local function ShouldRejectByRemainingDistance(service, matched)
    if type(service) ~= "table" or type(matched) ~= "table" then
        return false
    end

    local routeLength = tonumber(matched.routeLength)
    local projection = tonumber(matched.projection)
    if type(routeLength) ~= "number" or routeLength <= 0 or type(projection) ~= "number" then
        return false
    end

    local remainingDistance = routeLength - projection
    local minRemainingDistance = math.max(
        tonumber(service.MATCH_MIN_REMAINING_ABSOLUTE) or 0.04,
        routeLength * (tonumber(service.MATCH_MIN_REMAINING_RATIO) or 0.15)
    )
    return remainingDistance < minRemainingDistance
end

local function ShouldRejectCandidateByRemainingDistance(service, matched)
    if type(service) ~= "table" or type(matched) ~= "table" then
        return false
    end

    local routeLength = tonumber(matched.routeLength)
    local projection = tonumber(matched.projection)
    if type(routeLength) ~= "number" or routeLength <= 0 or type(projection) ~= "number" then
        return false
    end

    local remainingDistance = routeLength - projection
    local minRemainingDistance = math.max(
        tonumber(service.MATCH_CANDIDATE_MIN_REMAINING_ABSOLUTE) or 0.03,
        routeLength * (tonumber(service.MATCH_CANDIDATE_MIN_REMAINING_RATIO) or 0.08)
    )
    return remainingDistance < minRemainingDistance
end

local function ResolveTrackUnitVector(track)
    if type(track) ~= "table" then
        return nil, nil
    end

    local ux = tonumber(track.ux)
    local uy = tonumber(track.uy)
    if type(ux) == "number" and type(uy) == "number" then
        return ux, uy
    end

    local referenceRoute = type(track.representativeRoute) == "table" and track.representativeRoute or track
    local dx, dy, length = ComputeRouteVector(referenceRoute)
    if length <= 0 then
        return nil, nil
    end
    return dx / length, dy / length
end

local function ComputeAngleDelta(observationDX, observationDY, referenceUX, referenceUY)
    local observationLength = ComputeDistance(0, 0, observationDX or 0, observationDY or 0)
    if observationLength <= 0 then
        return math.huge
    end

    local referenceLength = ComputeDistance(0, 0, referenceUX or 0, referenceUY or 0)
    if referenceLength <= 0 then
        return math.huge
    end

    local dot = (((observationDX or 0) / observationLength) * ((referenceUX or 0) / referenceLength))
        + (((observationDY or 0) / observationLength) * ((referenceUY or 0) / referenceLength))
    dot = math.max(-1, math.min(1, dot))
    return math.acos(dot)
end

local function EvaluateTrackCandidate(service, track, observationLine)
    if type(service) ~= "table" or type(track) ~= "table" or type(observationLine) ~= "table" then
        return nil
    end

    local referenceRoute = type(track.representativeRoute) == "table" and track.representativeRoute or track
    local trackUX, trackUY = ResolveTrackUnitVector(track)
    if type(trackUX) ~= "number"
        or type(trackUY) ~= "number"
        or type(referenceRoute) ~= "table" then
        return nil
    end

    local context = {
        startX = referenceRoute.startX,
        startY = referenceRoute.startY,
        unitX = trackUX,
        unitY = trackUY,
    }
    local distance = DistancePointToLine(context, observationLine.endX, observationLine.endY)
    if type(distance) ~= "number" or distance > (tonumber(service.MATCH_TRACK_DISTANCE_THRESHOLD) or 0.012) then
        return nil
    end

    local angleDelta = ComputeAngleDelta(observationLine.dx, observationLine.dy, trackUX, trackUY)
    if angleDelta > (tonumber(service.MATCH_TRACK_ANGLE_THRESHOLD) or 0.06) then
        return nil
    end

    return {
        track = track,
        distance = distance,
        angleDelta = angleDelta,
        currentProjection = (observationLine.endX * trackUX) + (observationLine.endY * trackUY),
        verifiedPredictionCount = tonumber(track.verifiedPredictionCount) or 0,
        observationCount = tonumber(track.observationCount) or 0,
        confidenceScore = AirdropTrajectoryStore
            and AirdropTrajectoryStore.GetPredictionConfidence
            and AirdropTrajectoryStore:GetPredictionConfidence(track)
            or 0,
        updatedAt = tonumber(track.updatedAt) or 0,
    }
end

local function SortTrackCandidates(candidates)
    table.sort(candidates, function(left, right)
        local leftDistance = tonumber(left and left.distance) or math.huge
        local rightDistance = tonumber(right and right.distance) or math.huge
        if leftDistance ~= rightDistance then
            return leftDistance < rightDistance
        end

        local leftAngleDelta = tonumber(left and left.angleDelta) or math.huge
        local rightAngleDelta = tonumber(right and right.angleDelta) or math.huge
        if leftAngleDelta ~= rightAngleDelta then
            return leftAngleDelta < rightAngleDelta
        end

        local leftVerifiedCount = tonumber(left and left.verifiedPredictionCount) or 0
        local rightVerifiedCount = tonumber(right and right.verifiedPredictionCount) or 0
        if leftVerifiedCount ~= rightVerifiedCount then
            return leftVerifiedCount > rightVerifiedCount
        end

        local leftObservationCount = tonumber(left and left.observationCount) or 0
        local rightObservationCount = tonumber(right and right.observationCount) or 0
        if leftObservationCount ~= rightObservationCount then
            return leftObservationCount > rightObservationCount
        end

        local leftConfidence = tonumber(left and left.confidenceScore) or 0
        local rightConfidence = tonumber(right and right.confidenceScore) or 0
        if leftConfidence ~= rightConfidence then
            return leftConfidence > rightConfidence
        end

        local leftUpdatedAt = tonumber(left and left.updatedAt) or 0
        local rightUpdatedAt = tonumber(right and right.updatedAt) or 0
        if leftUpdatedAt ~= rightUpdatedAt then
            return leftUpdatedAt > rightUpdatedAt
        end

        return tostring(left and left.track and left.track.trackKey or "") < tostring(right and right.track and right.track.trackKey or "")
    end)
    return candidates
end

local function IsTrackSelectionAmbiguous(service, candidates)
    if type(service) ~= "table" or type(candidates) ~= "table" or #candidates <= 1 then
        return false
    end

    local best = candidates[1]
    local second = candidates[2]
    if type(best) ~= "table" or type(second) ~= "table" then
        return false
    end

    local distanceMargin = tonumber(service.MATCH_TRACK_AMBIGUITY_DISTANCE_MARGIN) or 0.004
    local angleMargin = tonumber(service.MATCH_TRACK_AMBIGUITY_ANGLE_MARGIN) or 0.01
    local distanceDelta = math.abs((tonumber(second.distance) or math.huge) - (tonumber(best.distance) or math.huge))
    local angleDelta = math.abs((tonumber(second.angleDelta) or math.huge) - (tonumber(best.angleDelta) or math.huge))
    return distanceDelta <= distanceMargin and angleDelta <= angleMargin
end

local function GetForwardLandingClusters(service, track, currentProjection)
    if type(track) ~= "table" then
        return {}
    end

    local exclusionMargin = tonumber(service and service.MATCH_LANDING_EXCLUSION_ABSOLUTE) or 0.02
    local farthestProjection = nil
    for _, landingCluster in ipairs(track.landingClusters or {}) do
        local endProjection = type(landingCluster) == "table" and tonumber(landingCluster.endProjection) or nil
        if type(endProjection) == "number" then
            if type(farthestProjection) ~= "number" or endProjection > farthestProjection then
                farthestProjection = endProjection
            end
        end
    end
    if type(farthestProjection) == "number" and farthestProjection > 0 then
        exclusionMargin = math.max(
            exclusionMargin,
            farthestProjection * (tonumber(service and service.MATCH_LANDING_EXCLUSION_RATIO) or 0.05)
        )
    end

    local result = {}
    for _, landingCluster in ipairs(track.landingClusters or {}) do
        if type(landingCluster) == "table" then
            local endProjection = tonumber(landingCluster.endProjection)
            if type(endProjection) == "number" and endProjection > (currentProjection - exclusionMargin) then
                result[#result + 1] = landingCluster
            end
        end
    end
    table.sort(result, function(left, right)
        local leftProjection = tonumber(left and left.endProjection) or math.huge
        local rightProjection = tonumber(right and right.endProjection) or math.huge
        if leftProjection ~= rightProjection then
            return leftProjection < rightProjection
        end
        return (left and left.representativeRouteKey or left and left.routeKey or "") < (right and right.representativeRouteKey or right and right.routeKey or "")
    end)
    return result
end

local function BuildAmbiguousPredictionAlertToken(track, firstCluster, secondCluster)
    local trackKey = type(track) == "table" and track.trackKey or nil
    local firstRouteKey = type(firstCluster) == "table" and (firstCluster.representativeRouteKey or firstCluster.routeKey) or nil
    local secondRouteKey = type(secondCluster) == "table" and (secondCluster.representativeRouteKey or secondCluster.routeKey) or nil
    if type(trackKey) ~= "string" or trackKey == ""
        or type(firstRouteKey) ~= "string" or firstRouteKey == ""
        or type(secondRouteKey) ~= "string" or secondRouteKey == "" then
        return nil
    end

    if secondRouteKey < firstRouteKey then
        firstRouteKey, secondRouteKey = secondRouteKey, firstRouteKey
    end
    return table.concat({
        "ambig",
        trackKey,
        firstRouteKey,
        secondRouteKey,
    }, ":")
end

local function BuildLandingPredictionCandidate(state, trackCandidate, landingCluster, observationLine)
    if type(state) ~= "table"
        or type(trackCandidate) ~= "table"
        or type(landingCluster) ~= "table"
        or type(observationLine) ~= "table" then
        return nil
    end

    local predictionRoute = type(landingCluster.representativeRoute) == "table" and landingCluster.representativeRoute or landingCluster
    local projectionContext = BuildProjectionContext(predictionRoute)
    if type(predictionRoute) ~= "table" or type(projectionContext) ~= "table" then
        return nil
    end

    local observationStartX, observationStartY = ResolveObservationStart(state)
    if type(observationStartX) ~= "number" or type(observationStartY) ~= "number" then
        return nil
    end

    local _, projection = DistancePointToLine(projectionContext, observationLine.endX, observationLine.endY)
    if type(projection) ~= "number" then
        return nil
    end

    return {
        route = landingCluster,
        predictionRoute = predictionRoute,
        track = trackCandidate.track,
        distance = trackCandidate.distance,
        angleDelta = trackCandidate.angleDelta,
        startDistance = ComputeDistance(observationStartX, observationStartY, predictionRoute.startX, predictionRoute.startY),
        observationCount = tonumber(landingCluster.observationCount) or 0,
        sampleCount = tonumber(landingCluster.sampleCount) or 0,
        verificationCount = tonumber(landingCluster.verificationCount) or 0,
        confidenceScore = AirdropTrajectoryStore
            and AirdropTrajectoryStore.GetPredictionConfidence
            and AirdropTrajectoryStore:GetPredictionConfidence(landingCluster)
            or 0,
        verifiedPredictionCount = tonumber(landingCluster.verifiedPredictionCount) or 0,
        observationLength = tonumber(observationLine.length) or 0,
        projection = projection,
        routeLength = tonumber(projectionContext.length) or 0,
        currentProjection = tonumber(trackCandidate.currentProjection) or 0,
    }
end

local function FormatDiagnosticNumber(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" then
        return "nil"
    end
    return string.format("%.4f", numberValue)
end

local function ResolveDiagnosticMapName(targetMapData)
    if type(targetMapData) == "table" then
        if Data and Data.GetMapDisplayName then
            return Data:GetMapDisplayName(targetMapData)
        end
        if type(targetMapData.mapID) == "number" then
            return tostring(targetMapData.mapID)
        end
    end
    return nil
end

local function RecordPredictionTrace(service, targetMapData, state, iconResult, eventType, note, routeKey)
    if type(service) ~= "table"
        or not service.RecordTraceEvent
        or type(state) ~= "table"
        or type(eventType) ~= "string"
        or eventType == "" then
        return false
    end

    local traceKey = table.concat({
        tostring(eventType),
        tostring(routeKey or ""),
        tostring(note or ""),
    }, "|")
    if state.lastPredictionTraceKey == traceKey then
        return false
    end
    state.lastPredictionTraceKey = traceKey

    service:RecordTraceEvent({
        recordedAt = Utils:GetCurrentTimestamp(),
        eventType = eventType,
        mapName = ResolveDiagnosticMapName(targetMapData),
        mapID = type(targetMapData) == "table" and targetMapData.mapID or state.mapID,
        runtimeMapId = type(targetMapData) == "table" and targetMapData.id or nil,
        objectGUID = type(iconResult) == "table" and iconResult.objectGUID or nil,
        sourceObjectGUID = state.objectGUID,
        positionX = type(iconResult) == "table" and tonumber(iconResult.positionX) or tonumber(state.lastX),
        positionY = type(iconResult) == "table" and tonumber(iconResult.positionY) or tonumber(state.lastY),
        sampleCount = state.sampleCount,
        routeKey = routeKey,
        startSource = state.startSource,
        endSource = state.endSource,
        startConfirmed = state.startConfirmed == true,
        endConfirmed = state.endConfirmed == true,
        note = note,
    })
    return true
end

function AirdropTrajectoryMatchingService:TryMatchPrediction(service, targetMapData, state, iconResult)
    if type(service) ~= "table"
        or type(targetMapData) ~= "table"
        or type(state) ~= "table"
        or type(iconResult) ~= "table" then
        return false
    end

    local positionX = tonumber(iconResult.positionX)
    local positionY = tonumber(iconResult.positionY)
    if type(positionX) ~= "number" or type(positionY) ~= "number" then
        return false
    end

    if type(state.announcedRouteKey) == "string" and state.announcedRouteKey ~= "" then
        return false
    end

    if state.movingStarted ~= true then
        return false
    end

    local observationLine = ResolveObservationLine(state, positionX, positionY)
    if type(observationLine) ~= "table" then
        state.uniqueMatchState = nil
        RecordPredictionTrace(service, targetMapData, state, iconResult, "prediction_skip", "observation_line_unavailable")
        return false
    end

    local trackMatches = {}
    local tracks = AirdropTrajectoryStore
        and (
            (AirdropTrajectoryStore.GetPredictionTrackReferences and AirdropTrajectoryStore:GetPredictionTrackReferences(targetMapData.mapID))
            or (AirdropTrajectoryStore.GetPredictionTracks and AirdropTrajectoryStore:GetPredictionTracks(targetMapData.mapID))
        )
        or {}

    for _, track in ipairs(tracks) do
        local predictionReady = AirdropTrajectoryStore and AirdropTrajectoryStore.IsPredictionReady
            and AirdropTrajectoryStore:IsPredictionReady(track) == true
        local trackKey = type(track) == "table" and track.trackKey or nil
        if predictionReady == true and type(trackKey) == "string" and trackKey ~= "" then
            local matched = EvaluateTrackCandidate(service, track, observationLine)
            if type(matched) == "table" then
                trackMatches[#trackMatches + 1] = matched
            end
        end
    end

    local currentTrackMatches = SortTrackCandidates(trackMatches)
    if #currentTrackMatches == 0 then
        state.uniqueMatchState = nil
        RecordPredictionTrace(service, targetMapData, state, iconResult, "prediction_skip", "track_match_missing")
        return false
    end

    local viableTrackMatches = {}
    for _, matched in ipairs(currentTrackMatches) do
        local matchedTrack = type(matched) == "table" and matched.track or nil
        local currentTrackProjection = tonumber(matched and matched.currentProjection) or 0
        local forwardLandingClusters = GetForwardLandingClusters(service, matchedTrack, currentTrackProjection)
        if #forwardLandingClusters > 0 then
            matched.forwardLandingClusters = forwardLandingClusters
            viableTrackMatches[#viableTrackMatches + 1] = matched
        end
    end

    if #viableTrackMatches == 0 then
        local best = currentTrackMatches[1]
        state.uniqueMatchState = nil
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format("forward_landing_missing track=%s", tostring(best and best.track and best.track.trackKey or "")),
            tostring(best and best.track and best.track.trackKey or "")
        )
        return false
    end

    if IsTrackSelectionAmbiguous(service, viableTrackMatches) == true then
        local best = viableTrackMatches[1]
        local second = viableTrackMatches[2]
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format(
                "track_ambiguous best=%s second=%s dd=%s ad=%s",
                tostring(best and best.track and best.track.trackKey or ""),
                tostring(second and second.track and second.track.trackKey or ""),
                FormatDiagnosticNumber((tonumber(second and second.distance) or math.huge) - (tonumber(best and best.distance) or math.huge)),
                FormatDiagnosticNumber((tonumber(second and second.angleDelta) or math.huge) - (tonumber(best and best.angleDelta) or math.huge))
            )
        )
        state.uniqueMatchState = nil
        return false
    end

    local trackCandidate = viableTrackMatches[1]
    local track = trackCandidate.track
    if type(track) ~= "table" then
        state.uniqueMatchState = nil
        return false
    end

    local forwardLandingClusters = trackCandidate.forwardLandingClusters or {}

    local candidate = BuildLandingPredictionCandidate(state, trackCandidate, forwardLandingClusters[1], observationLine)
    local route = candidate and candidate.route
    local predictionRoute = candidate and candidate.predictionRoute
    local predictedRouteKey = type(route) == "table" and (route.representativeRouteKey or route.routeKey) or nil
    if type(candidate) ~= "table"
        or type(route) ~= "table"
        or type(predictionRoute) ~= "table"
        or type(predictedRouteKey) ~= "string"
        or predictedRouteKey == ""
        or state.announcedRouteKey == predictedRouteKey then
        RecordPredictionTrace(service, targetMapData, state, iconResult, "prediction_skip", "candidate_invalid", predictedRouteKey)
        return false
    end

    if ShouldRejectByStartDistance(service, state, candidate) == true then
        state.uniqueMatchState = nil
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format("start_distance_rejected route=%s start=%s", predictedRouteKey, FormatDiagnosticNumber(candidate.startDistance)),
            predictedRouteKey
        )
        return false
    end

    local uniqueState = state.uniqueMatchState
    local shouldResetUniqueState = type(uniqueState) ~= "table"
        or uniqueState.routeKey ~= predictedRouteKey
    if shouldResetUniqueState then
        local previousRouteKey = type(uniqueState) == "table" and uniqueState.routeKey or nil
        uniqueState = {
            routeKey = predictedRouteKey,
            route = predictionRoute,
            routeLength = candidate.routeLength,
            matchedSamples = 1,
        }
        state.uniqueMatchState = uniqueState
        if type(previousRouteKey) == "string" and previousRouteKey ~= "" and previousRouteKey ~= predictedRouteKey then
            RecordPredictionTrace(
                service,
                targetMapData,
                state,
                iconResult,
                "prediction_route_switched",
                string.format("from=%s to=%s", previousRouteKey, predictedRouteKey),
                predictedRouteKey
            )
        end
    else
        uniqueState.matchedSamples = (tonumber(uniqueState.matchedSamples) or 0) + 1
        uniqueState.route = predictionRoute
        uniqueState.routeLength = candidate.routeLength
    end

    local matchedSamples = tonumber(uniqueState.matchedSamples) or 0
    local predictionObservationCount = math.max(0, math.floor(tonumber(state.predictionObservationCount) or 0))
    if #forwardLandingClusters > 1 then
        local routeLength = tonumber(candidate.routeLength) or 0
        local requiredSamples = math.max(1, math.floor(tonumber(service.MATCH_CANDIDATE_CONFIRM_STABLE_SAMPLES) or 1))
        local minProgress = math.max(
            tonumber(service.MATCH_CANDIDATE_MIN_PROGRESS_ABSOLUTE) or 0.03,
            routeLength * (tonumber(service.MATCH_CANDIDATE_MIN_PROGRESS_RATIO) or 0.08)
        )
        local remainingRejected = ShouldRejectCandidateByRemainingDistance(service, candidate) == true
        if matchedSamples >= requiredSamples
            and predictionObservationCount >= requiredSamples
            and (tonumber(observationLine.length) or 0) >= minProgress
            and (tonumber(candidate.projection) or 0) >= minProgress
            and remainingRejected ~= true then
            local candidateNotificationSent, candidateNotificationReason = false, "candidate_notify_unavailable"
            if service.NotifyPredictionCandidates then
                candidateNotificationSent, candidateNotificationReason = service:NotifyPredictionCandidates(
                    targetMapData,
                    forwardLandingClusters,
                    state
                )
            end

            local queued, reason = false, nil
            if #forwardLandingClusters == 2
                and AirdropTrajectoryAlertCoordinator
                and AirdropTrajectoryAlertCoordinator.HandleLocalPredictionCandidates then
                local ambiguousAlertToken = BuildAmbiguousPredictionAlertToken(track, forwardLandingClusters[1], forwardLandingClusters[2])
                if type(ambiguousAlertToken) == "string" and ambiguousAlertToken ~= "" then
                    queued, reason = AirdropTrajectoryAlertCoordinator:HandleLocalPredictionCandidates(
                        targetMapData,
                        ambiguousAlertToken,
                        iconResult.objectGUID,
                        {
                            forwardLandingClusters[1],
                            forwardLandingClusters[2],
                        },
                        Utils:GetCurrentTimestamp()
                    )
                end
            end

            local candidateEventType = (candidateNotificationSent == true or queued == true)
                and "prediction_candidates"
                or "prediction_skip"

            RecordPredictionTrace(
                service,
                targetMapData,
                state,
                iconResult,
                candidateEventType,
                string.format(
                    "candidates local=%s(%s) team=%s(%s) track=%s count=%d",
                    tostring(candidateNotificationSent == true),
                    tostring(candidateNotificationReason or "unknown"),
                    tostring(queued == true),
                    tostring(reason or "not_requested"),
                    tostring(track.trackKey or ""),
                    #forwardLandingClusters
                ),
                predictedRouteKey
            )
        else
            local blockReason = nil
            if matchedSamples < requiredSamples then
                blockReason = string.format("candidates_not_stable matched=%d required=%d", matchedSamples, requiredSamples)
            elseif predictionObservationCount < requiredSamples then
                blockReason = string.format("candidates_observation_short obs=%d required=%d", predictionObservationCount, requiredSamples)
            elseif (tonumber(observationLine.length) or 0) < minProgress then
                blockReason = string.format(
                    "candidates_progress_short line=%s required=%s",
                    FormatDiagnosticNumber(observationLine.length),
                    FormatDiagnosticNumber(minProgress)
                )
            elseif (tonumber(candidate.projection) or 0) < minProgress then
                blockReason = string.format(
                    "candidates_projection_short projection=%s required=%s",
                    FormatDiagnosticNumber(candidate.projection),
                    FormatDiagnosticNumber(minProgress)
                )
            elseif remainingRejected == true then
                blockReason = string.format(
                    "candidates_remaining_short projection=%s route=%s",
                    FormatDiagnosticNumber(candidate.projection),
                    FormatDiagnosticNumber(candidate.routeLength)
                )
            end
            RecordPredictionTrace(
                service,
                targetMapData,
                state,
                iconResult,
                "prediction_skip",
                (blockReason or "candidates_not_allowed") .. string.format(" track=%s", tostring(track.trackKey or "")),
                predictedRouteKey
            )
        end
        return false
    end

    local routeLength = tonumber(uniqueState.routeLength) or 0
    local requiredSamples = math.max(1, math.floor(tonumber(service.MATCH_CONFIRM_STABLE_SAMPLES) or 2))
    local minProgress = math.max(
        tonumber(service.MATCH_MIN_PROGRESS_ABSOLUTE) or 0.05,
        routeLength * (tonumber(service.MATCH_MIN_PROGRESS_RATIO) or 0.20)
    )

    if matchedSamples < requiredSamples then
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format("formal_not_stable matched=%d required=%d", matchedSamples, requiredSamples),
            predictedRouteKey
        )
        return false
    end
    if predictionObservationCount < requiredSamples then
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format("formal_observation_short obs=%d required=%d", predictionObservationCount, requiredSamples),
            predictedRouteKey
        )
        return false
    end
    if (tonumber(observationLine.length) or 0) < minProgress then
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format(
                "formal_progress_short line=%s required=%s",
                FormatDiagnosticNumber(observationLine.length),
                FormatDiagnosticNumber(minProgress)
            ),
            predictedRouteKey
        )
        return false
    end
    if (tonumber(candidate.projection) or 0) < minProgress then
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format(
                "formal_projection_short projection=%s required=%s",
                FormatDiagnosticNumber(candidate.projection),
                FormatDiagnosticNumber(minProgress)
            ),
            predictedRouteKey
        )
        return false
    end
    if ShouldRejectByRemainingDistance(service, candidate) == true then
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format(
                "formal_remaining_short projection=%s route=%s",
                FormatDiagnosticNumber(candidate.projection),
                FormatDiagnosticNumber(candidate.routeLength)
            ),
            predictedRouteKey
        )
        return false
    end

    local notified = service:NotifyPrediction(targetMapData, predictionRoute)
    if notified == true then
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_sent",
            string.format("formal route=%s", predictedRouteKey),
            predictedRouteKey
        )
        state.announcedRouteKey = predictedRouteKey
        state.announcedCandidateKey = nil
        state.predictedRouteKey = predictedRouteKey
        state.predictedEndX = predictionRoute.endX
        state.predictedEndY = predictionRoute.endY
        state.uniqueMatchState = nil
        if service.IsPredictionTestEnabled
            and service:IsPredictionTestEnabled() == true
            and AirdropTrajectoryAlertCoordinator
            and AirdropTrajectoryAlertCoordinator.HandleLocalPredictionMatched then
                AirdropTrajectoryAlertCoordinator:HandleLocalPredictionMatched(
                    targetMapData,
                    predictionRoute,
                    iconResult.objectGUID,
                    Utils:GetCurrentTimestamp()
                )
        end
    else
        RecordPredictionTrace(
            service,
            targetMapData,
            state,
            iconResult,
            "prediction_skip",
            string.format("formal_notify_failed route=%s", predictedRouteKey),
            predictedRouteKey
        )
    end
    return notified == true
end

return AirdropTrajectoryMatchingService
