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

local function EvaluateRouteMatch(service, route, observationLine)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.EvaluateRouteMatch then
        return AirdropTrajectoryGeometryService:EvaluateRouteMatch(
            route,
            observationLine.endX,
            observationLine.endY,
            observationLine.dx,
            observationLine.dy,
            {
                projectionMargin = service.MATCH_PROJECTION_MARGIN or 0.08,
                distanceTolerance = service.MATCH_DISTANCE_TOLERANCE or 0.015,
                minDirectionDot = service.MATCH_MIN_DIRECTION_DOT or 0.92,
                minDirectionDistance = service.MATCH_DIRECTION_MIN_DISTANCE or 0.0035,
            }
        )
    end
    return nil
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

local function EnrichPredictionCandidate(state, matched, observationLine)
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
    matched.observationLength = type(observationLine) == "table" and tonumber(observationLine.length) or 0
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

local function ShouldSuppressShortFamilyRoute(service, candidate, routes, positionX, positionY)
    if type(service) ~= "table"
        or type(candidate) ~= "table"
        or type(routes) ~= "table"
        or type(positionX) ~= "number"
        or type(positionY) ~= "number" then
        return false
    end

    local route = candidate.route
    local routeLength = tonumber(candidate.routeLength)
    if type(route) ~= "table" or type(routeLength) ~= "number" or routeLength <= 0 then
        return false
    end

    local shortRouteMaxLength = tonumber(service.MATCH_SHORT_ROUTE_MAX_LENGTH) or 0.18
    if routeLength > shortRouteMaxLength then
        return false
    end

    local familyDirectionDot = tonumber(service.MATCH_ROUTE_FAMILY_DIRECTION_DOT) or 0.985
    local longerRatio = math.max(1.0, tonumber(service.MATCH_SHORT_ROUTE_LONGER_RATIO) or 1.6)
    local lengthGap = math.max(0, tonumber(service.MATCH_SHORT_ROUTE_LENGTH_GAP) or 0.05)
    local routeDx, routeDy, routeVectorLength = ComputeRouteVector(route)
    if routeVectorLength <= 0 then
        return false
    end

    local routeUnitX = routeDx / routeVectorLength
    local routeUnitY = routeDy / routeVectorLength

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
                local longerEnough = siblingLength >= math.max(routeLength * longerRatio, routeLength + lengthGap)
                if longerEnough == true and startDistance <= startTolerance and directionDot >= familyDirectionDot then
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
                        return true
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
    if state.startConfirmed ~= true then
        return false
    end

    local observationLine = ResolveObservationLine(state, positionX, positionY)
    if type(observationLine) ~= "table" then
        state.uniqueMatchState = nil
        return false
    end

    local completeMatches = {}
    local routes = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRoutes and AirdropTrajectoryStore:GetRoutes(targetMapData.mapID) or {}

    for _, route in ipairs(routes) do
        local predictionReady = AirdropTrajectoryStore and AirdropTrajectoryStore.IsPredictionReady
            and AirdropTrajectoryStore:IsPredictionReady(route) == true
        local routeKey = type(route) == "table" and route.routeKey or nil
        if predictionReady == true and type(routeKey) == "string" and routeKey ~= "" then
            local matched = EvaluateRouteMatch(service, route, observationLine)
            if matched and type(matched.routeLength) == "number" then
                matched = EnrichPredictionCandidate(state, matched, observationLine)
                if ShouldRejectByStartDistance(service, state, matched) ~= true then
                    completeMatches[#completeMatches + 1] = matched
                end
            end
        end
    end

    local currentMatches = SortPredictionCandidates(completeMatches)

    if #currentMatches == 0 then
        state.uniqueMatchState = nil
        return false
    end

    local candidate = currentMatches[1]
    local route = candidate.route
    if type(route) ~= "table" or state.announcedRouteKey == route.routeKey then
        return false
    end

    if ShouldSuppressShortFamilyRoute(service, candidate, routes, observationLine.endX, observationLine.endY) == true then
        state.uniqueMatchState = nil
        return false
    end

    local isSelectionAmbiguous = IsCandidateSelectionAmbiguous(service, currentMatches)
    if IsCandidatePredictionAmbiguous(service, candidate, routes, observationLine.endX, observationLine.endY) then
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
    if shouldResetUniqueState then
        uniqueState = {
            routeKey = route.routeKey,
            route = route,
            routeLength = candidate.routeLength,
            matchedSamples = 1,
        }
        state.uniqueMatchState = uniqueState
    else
        if isSelectionAmbiguous == true and uniqueState.routeKey ~= route.routeKey then
            state.uniqueMatchState = nil
            return false
        end
        uniqueState.matchedSamples = (tonumber(uniqueState.matchedSamples) or 0) + 1
        uniqueState.route = route
        uniqueState.routeLength = candidate.routeLength
    end

    local matchedSamples = tonumber(uniqueState.matchedSamples) or 0
    local routeLength = tonumber(uniqueState.routeLength) or 0
    local requiredSamples = math.max(1, math.floor(tonumber(service.MATCH_CONFIRM_STABLE_SAMPLES) or 2))
    local minProgress = math.max(
        tonumber(service.MATCH_MIN_PROGRESS_ABSOLUTE) or 0.05,
        routeLength * (tonumber(service.MATCH_MIN_PROGRESS_RATIO) or 0.20)
    )

    if matchedSamples < requiredSamples then
        return false
    end
    if (tonumber(observationLine.length) or 0) < minProgress then
        return false
    end
    if (tonumber(candidate.projection) or 0) < minProgress then
        return false
    end
    if ShouldRejectByRemainingDistance(service, candidate) == true then
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
