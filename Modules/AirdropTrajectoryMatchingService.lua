-- AirdropTrajectoryMatchingService.lua - 空投轨迹预测匹配决策

local AirdropTrajectoryMatchingService = BuildEnv("AirdropTrajectoryMatchingService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local Utils = BuildEnv("Utils")

local function ComputeDistance(x1, y1, x2, y2)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeDistance then
        return AirdropTrajectoryGeometryService:ComputeDistance(x1, y1, x2, y2)
    end
    return 0
end

local function GetRuntimeNow()
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)
        if ok and type(value) == "number" then
            return value
        end
    end
    return Utils:GetCurrentTimestamp()
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

local function EvaluateRouteMatch(service, route, positionX, positionY, motionDX, motionDY)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.EvaluateRouteMatch then
        return AirdropTrajectoryGeometryService:EvaluateRouteMatch(route, positionX, positionY, motionDX, motionDY, {
            projectionMargin = service.MATCH_PROJECTION_MARGIN or 0.08,
            distanceTolerance = service.MATCH_DISTANCE_TOLERANCE or 0.015,
            minDirectionDot = service.MATCH_MIN_DIRECTION_DOT or 0.92,
            minDirectionDistance = service.MATCH_DIRECTION_MIN_DISTANCE or 0.0035,
        })
    end
    return nil
end

local function ResolveAdaptiveMatchThreshold(baseValue, floorValue, ratioValue, route)
    local resolvedBase = math.max(1, math.floor(tonumber(baseValue) or 1))
    local resolvedFloor = math.max(1, math.floor(tonumber(floorValue) or 1))
    local sampleCount = type(route) == "table" and tonumber(route.sampleCount) or nil
    if type(sampleCount) ~= "number" or sampleCount <= 0 then
        return resolvedBase
    end

    local ratioThreshold = math.floor((sampleCount * (tonumber(ratioValue) or 0.35)) + 0.5)
    if ratioThreshold < resolvedFloor then
        ratioThreshold = resolvedFloor
    end
    if ratioThreshold > resolvedBase then
        ratioThreshold = resolvedBase
    end
    return ratioThreshold
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

local function EnrichPredictionCandidate(state, matched)
    if type(state) ~= "table" or type(matched) ~= "table" or type(matched.route) ~= "table" then
        return nil
    end

    local observationStartX, observationStartY = ResolveObservationStart(state)
    if type(observationStartX) ~= "number" or type(observationStartY) ~= "number" then
        return matched
    end

    matched.startDistance = ComputeDistance(observationStartX, observationStartY, matched.route.startX, matched.route.startY)
    matched.observationCount = tonumber(matched.route.observationCount) or 0
    matched.sampleCount = tonumber(matched.route.sampleCount) or 0
    matched.confidenceScore = AirdropTrajectoryStore
        and AirdropTrajectoryStore.GetPredictionConfidence
        and AirdropTrajectoryStore:GetPredictionConfidence(matched.route)
        or 0
    matched.verifiedPredictionCount = tonumber(matched.route.verifiedPredictionCount) or 0
    return matched
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

local function SortPredictionCandidates(candidates)
    table.sort(candidates, function(left, right)
        local leftDistance = tonumber(left and left.distance) or math.huge
        local rightDistance = tonumber(right and right.distance) or math.huge
        if leftDistance ~= rightDistance then
            return leftDistance < rightDistance
        end

        local leftStartDistance = tonumber(left and left.startDistance) or math.huge
        local rightStartDistance = tonumber(right and right.startDistance) or math.huge
        if leftStartDistance ~= rightStartDistance then
            return leftStartDistance < rightStartDistance
        end

        local leftConfidence = tonumber(left and left.confidenceScore) or 0
        local rightConfidence = tonumber(right and right.confidenceScore) or 0
        if leftConfidence ~= rightConfidence then
            return leftConfidence > rightConfidence
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

        local leftSampleCount = tonumber(left and left.sampleCount) or 0
        local rightSampleCount = tonumber(right and right.sampleCount) or 0
        if leftSampleCount ~= rightSampleCount then
            return leftSampleCount > rightSampleCount
        end

        return (left.route and left.route.routeKey or "") < (right.route and right.route.routeKey or "")
    end)
    return candidates
end

local function IsCandidateSelectionAmbiguous(service, candidates)
    if type(service) ~= "table" or type(candidates) ~= "table" or #candidates <= 1 then
        return false
    end

    local best = candidates[1]
    local second = candidates[2]
    if type(best) ~= "table" or type(second) ~= "table" then
        return false
    end

    local distanceMargin = tonumber(service.MATCH_AMBIGUITY_DISTANCE_MARGIN) or 0.004
    local startMargin = tonumber(service.MATCH_AMBIGUITY_START_MARGIN) or 0.015
    local distanceDelta = math.abs((tonumber(second.distance) or math.huge) - (tonumber(best.distance) or math.huge))
    local startDelta = math.abs((tonumber(second.startDistance) or math.huge) - (tonumber(best.startDistance) or math.huge))
    return distanceDelta <= distanceMargin and startDelta <= startMargin
end

local function ResolveRouteFamilyStartTolerance(service, route, sibling)
    if type(service) ~= "table" then
        return 0.03
    end

    local defaultTolerance = tonumber(service.MATCH_ROUTE_FAMILY_START_TOLERANCE) or 0.03
    if type(route) == "table"
        and type(sibling) == "table"
        and route.startConfirmed == true
        and sibling.startConfirmed == true then
        return math.min(defaultTolerance, 0.015)
    end
    return defaultTolerance
end

local function BuildProjectedPoint(route, unitX, unitY, routeLength, travelDistance)
    if type(route) ~= "table"
        or type(unitX) ~= "number"
        or type(unitY) ~= "number"
        or type(routeLength) ~= "number"
        or routeLength <= 0
        or type(travelDistance) ~= "number" then
        return nil, nil
    end

    local clampedDistance = math.max(0, math.min(routeLength, travelDistance))
    return route.startX + (clampedDistance * unitX), route.startY + (clampedDistance * unitY)
end

local function IsSiblingRoutePlausible(service, siblingContext, siblingLength, positionX, positionY, candidateDistance)
    if type(service) ~= "table"
        or type(siblingContext) ~= "table"
        or type(siblingLength) ~= "number"
        or siblingLength <= 0
        or type(positionX) ~= "number"
        or type(positionY) ~= "number" then
        return false
    end

    local lineTolerance = tonumber(service.MATCH_ROUTE_FAMILY_LINE_TOLERANCE) or 0.02
    local extensionMargin = tonumber(service.MATCH_ROUTE_FAMILY_EXTENSION_MARGIN) or 0.02
    local distanceMargin = tonumber(service.MATCH_ROUTE_FAMILY_DISTANCE_MARGIN) or 0.003
    local siblingFitDistance, siblingProjection = DistancePointToLine(siblingContext, positionX, positionY)
    if type(siblingFitDistance) ~= "number" or type(siblingProjection) ~= "number" then
        return false
    end

    local projectionMargin = siblingLength * extensionMargin
    if siblingProjection < -projectionMargin or siblingProjection > (siblingLength + projectionMargin) then
        return false
    end
    if siblingFitDistance > lineTolerance then
        return false
    end
    return siblingFitDistance <= ((tonumber(candidateDistance) or math.huge) + distanceMargin)
end

local function IsCandidatePredictionAmbiguous(service, candidate, routes, positionX, positionY)
    if type(service) ~= "table"
        or type(candidate) ~= "table"
        or type(routes) ~= "table"
        or type(positionX) ~= "number"
        or type(positionY) ~= "number" then
        return false
    end

    local route = candidate.route
    local projection = tonumber(candidate.projection)
    local routeLength = tonumber(candidate.routeLength)
    if type(route) ~= "table"
        or type(routeLength) ~= "number"
        or routeLength <= 0
        or type(projection) ~= "number" then
        return false
    end

    local familyDirectionDot = tonumber(service.MATCH_ROUTE_FAMILY_DIRECTION_DOT) or 0.985
    local separationMin = tonumber(service.MATCH_ROUTE_FAMILY_SEPARATION_MIN) or 0.012
    local routeDx, routeDy, routeVectorLength = ComputeRouteVector(route)
    if routeVectorLength <= 0 then
        return false
    end

    local routeUnitX = routeDx / routeVectorLength
    local routeUnitY = routeDy / routeVectorLength
    local travelDistance = math.max(0, projection)
    local candidatePointX, candidatePointY = BuildProjectedPoint(route, routeUnitX, routeUnitY, routeLength, travelDistance)
    if type(candidatePointX) ~= "number" or type(candidatePointY) ~= "number" then
        return false
    end

    for _, sibling in ipairs(routes) do
        if type(sibling) == "table"
            and sibling ~= route
            and sibling.startConfirmed == true
            and sibling.endConfirmed == true then
            local siblingDx, siblingDy, siblingLength = ComputeRouteVector(sibling)
            if siblingLength > 0 then
                local startTolerance = ResolveRouteFamilyStartTolerance(service, route, sibling)
                local startDistance = ComputeDistance(route.startX, route.startY, sibling.startX, sibling.startY)
                local directionDot = ((routeUnitX * (siblingDx / siblingLength)) + (routeUnitY * (siblingDy / siblingLength)))
                if startDistance <= startTolerance and directionDot >= familyDirectionDot then
                    local siblingContext = BuildProjectionContext(sibling)
                    if type(siblingContext) == "table"
                        and IsSiblingRoutePlausible(
                            service,
                            siblingContext,
                            siblingLength,
                            positionX,
                            positionY,
                            candidate.distance
                        ) == true then
                        local siblingUnitX = siblingDx / siblingLength
                        local siblingUnitY = siblingDy / siblingLength
                        local siblingPointX, siblingPointY = BuildProjectedPoint(
                            sibling,
                            siblingUnitX,
                            siblingUnitY,
                            siblingLength,
                            travelDistance
                        )
                        if type(siblingPointX) == "number" and type(siblingPointY) == "number" then
                            local familySeparation = ComputeDistance(
                                candidatePointX,
                                candidatePointY,
                                siblingPointX,
                                siblingPointY
                            )
                            if familySeparation < separationMin then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
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

    local runtimeNow = GetRuntimeNow()
    local motionRecordedAt = tonumber(state.motionRecordedAtRealtime) or tonumber(state.motionRecordedAt)
    local recentMotionAge = type(motionRecordedAt) == "number" and (runtimeNow - motionRecordedAt) or math.huge
    if type(state.motionDX) ~= "number"
        or type(state.motionDY) ~= "number"
        or recentMotionAge > (service.MATCH_RECENT_MOTION_WINDOW or 0.6) then
        if type(state.uniqueMatchState) == "table"
            and (runtimeNow - (tonumber(state.uniqueMatchState.lastMatchedAt) or 0)) > (service.MATCH_GAP_GRACE or 3) then
            state.uniqueMatchState = nil
        end
        return false
    end

    local completeMatches = {}
    local routes = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRoutes and AirdropTrajectoryStore:GetRoutes(targetMapData.mapID) or {}

    for _, route in ipairs(routes) do
        local predictionReady = AirdropTrajectoryStore and AirdropTrajectoryStore.IsPredictionReady
            and AirdropTrajectoryStore:IsPredictionReady(route) == true
        local routeKey = type(route) == "table" and route.routeKey or nil
        if predictionReady == true and type(routeKey) == "string" and routeKey ~= "" then
            local matched = EvaluateRouteMatch(service, route, positionX, positionY, state.motionDX, state.motionDY)
            if matched and type(matched.routeLength) == "number" then
                matched = EnrichPredictionCandidate(state, matched)
                if ShouldRejectByStartDistance(service, state, matched) ~= true then
                    completeMatches[#completeMatches + 1] = matched
                end
            end
        end
    end

    local currentMatches = SortPredictionCandidates(completeMatches)

    if #currentMatches == 0 then
        if type(state.uniqueMatchState) == "table"
            and (runtimeNow - (tonumber(state.uniqueMatchState.lastMatchedAt) or 0)) > (service.MATCH_GAP_GRACE or 3) then
            state.uniqueMatchState = nil
        end
        return false
    end

    local candidate = currentMatches[1]
    local route = candidate.route
    if type(route) ~= "table" or state.announcedRouteKey == route.routeKey then
        return false
    end

    local isSelectionAmbiguous = IsCandidateSelectionAmbiguous(service, currentMatches)
    if IsCandidatePredictionAmbiguous(service, candidate, routes, positionX, positionY) then
        return false
    end

    local uniqueState = state.uniqueMatchState
    if isSelectionAmbiguous == true
        and (type(uniqueState) ~= "table" or uniqueState.routeKey ~= route.routeKey) then
        state.uniqueMatchState = nil
        return false
    end

    local shouldResetUniqueState = type(uniqueState) ~= "table"
        or uniqueState.routeKey ~= route.routeKey
        or type(uniqueState.lastMatchedAt) ~= "number"
        or (runtimeNow - uniqueState.lastMatchedAt) > (service.MATCH_GAP_GRACE or 3)
    if shouldResetUniqueState then
        uniqueState = {
            routeKey = route.routeKey,
            route = route,
            routeLength = candidate.routeLength,
            accumulatedDuration = 0,
            matchedSamples = 1,
            minProjection = candidate.projection,
            maxProjection = candidate.projection,
            lastMatchedAt = runtimeNow,
        }
        state.uniqueMatchState = uniqueState
    else
        if isSelectionAmbiguous == true and uniqueState.routeKey ~= route.routeKey then
            state.uniqueMatchState = nil
            return false
        end
        local deltaTime = runtimeNow - uniqueState.lastMatchedAt
        if deltaTime > 0 and deltaTime <= (service.MATCH_GAP_GRACE or 3) then
            uniqueState.accumulatedDuration = (tonumber(uniqueState.accumulatedDuration) or 0) + deltaTime
        end
        uniqueState.lastMatchedAt = runtimeNow
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
    local requiredDuration = ResolveAdaptiveMatchThreshold(
        service.MATCH_CONFIRM_DURATION or 20,
        service.MATCH_CONFIRM_DURATION_FLOOR or 5,
        service.MATCH_CONFIRM_DURATION_RATIO or 0.35,
        route
    )
    local requiredSamples = ResolveAdaptiveMatchThreshold(
        service.MATCH_MIN_SAMPLES or 20,
        service.MATCH_MIN_SAMPLES_FLOOR or 5,
        service.MATCH_MIN_SAMPLES_RATIO or 0.35,
        route
    )
    local minProgress = math.max(
        tonumber(service.MATCH_MIN_PROGRESS_ABSOLUTE) or 0.05,
        routeLength * (tonumber(service.MATCH_MIN_PROGRESS_RATIO) or 0.20)
    )

    if matchedDuration < requiredDuration then
        return false
    end
    if matchedSamples < requiredSamples then
        return false
    end
    if progressSpan < minProgress then
        return false
    end

    local notified = service:NotifyPrediction(targetMapData, route)
    if notified == true then
        state.announcedRouteKey = route.routeKey
        state.predictedRouteKey = route.routeKey
        state.predictedEndX = route.endX
        state.predictedEndY = route.endY
        state.uniqueMatchState = nil
        if service.IsPredictionTestEnabled
            and service:IsPredictionTestEnabled() == true
            and AirdropTrajectoryAlertCoordinator
            and AirdropTrajectoryAlertCoordinator.HandleLocalPredictionMatched then
            AirdropTrajectoryAlertCoordinator:HandleLocalPredictionMatched(
                targetMapData,
                route,
                iconResult.objectGUID,
                Utils:GetCurrentTimestamp()
            )
        end
    end
    return notified == true
end

return AirdropTrajectoryMatchingService
