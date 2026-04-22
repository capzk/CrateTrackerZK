-- AirdropTrajectoryService.lua - 空投轨迹实时记录与落点预测

local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")
local AppSettingsStore = BuildEnv("AppSettingsStore")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Data = BuildEnv("Data")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

AirdropTrajectoryService.MIN_SAMPLE_DELTA = 0.0025
AirdropTrajectoryService.MIN_OBSERVATION_DISTANCE = 0.025
AirdropTrajectoryService.MATCH_DISTANCE_TOLERANCE = 0.015
AirdropTrajectoryService.MATCH_PROJECTION_MARGIN = 0.08
AirdropTrajectoryService.MATCH_CONFIRM_DURATION = 12
AirdropTrajectoryService.MATCH_CONFIRM_DURATION_FLOOR = 4
AirdropTrajectoryService.MATCH_CONFIRM_DURATION_RATIO = 0.18
AirdropTrajectoryService.MATCH_MIN_SAMPLES = 12
AirdropTrajectoryService.MATCH_MIN_SAMPLES_FLOOR = 4
AirdropTrajectoryService.MATCH_MIN_SAMPLES_RATIO = 0.18
AirdropTrajectoryService.MATCH_GAP_GRACE = 3
AirdropTrajectoryService.MATCH_MIN_PROGRESS_ABSOLUTE = 0.05
AirdropTrajectoryService.MATCH_MIN_PROGRESS_RATIO = 0.20
AirdropTrajectoryService.MATCH_START_DISTANCE_TOLERANCE = 0.08
AirdropTrajectoryService.MATCH_AMBIGUITY_DISTANCE_MARGIN = 0.004
AirdropTrajectoryService.MATCH_AMBIGUITY_START_MARGIN = 0.015
AirdropTrajectoryService.MATCH_MIN_DIRECTION_DOT = 0.92
AirdropTrajectoryService.MATCH_DIRECTION_MIN_DISTANCE = 0.0035
AirdropTrajectoryService.MATCH_RECENT_MOTION_WINDOW = 0.6
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_START_TOLERANCE = 0.03
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_DIRECTION_DOT = 0.985
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_LINE_TOLERANCE = 0.02
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_EXTENSION_MARGIN = 0.02
AirdropTrajectoryService.STATIONARY_TOLERANCE = 0.006
AirdropTrajectoryService.MOVE_CONFIRM_DISTANCE = 0.0045
AirdropTrajectoryService.START_STATIONARY_CONFIRM_TIME = 1.0
AirdropTrajectoryService.END_STATIONARY_CONFIRM_TIME = 6.0
AirdropTrajectoryService.MISSING_FINALIZE_DELAY = 2.2
AirdropTrajectoryService.PARTIAL_MIN_OBSERVATION_DISTANCE = 0.015
AirdropTrajectoryService.SHOUT_START_CONFIRM_WINDOW = 60
AirdropTrajectoryService.TRACE_DEBUG_SETTING_KEY = "trajectoryTraceDebugEnabled"

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
        sampledPoints = {},
        lastRecordedPointKey = nil,
    }
end

local function AppendObservedPoint(state, positionX, positionY)
    if type(state) ~= "table" then
        return false
    end

    local x = tonumber(positionX)
    local y = tonumber(positionY)
    if type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local pointX = math.floor((x * 100) + 0.5)
    local pointY = math.floor((y * 100) + 0.5)
    local pointKey = tostring(pointX) .. ":" .. tostring(pointY)
    if state.lastRecordedPointKey == pointKey then
        return false
    end

    state.sampledPoints = state.sampledPoints or {}
    state.sampledPoints[#state.sampledPoints + 1] = {
        x = pointX,
        y = pointY,
    }
    state.lastRecordedPointKey = pointKey
    return true
end

local function EvaluateRouteMatch(route, positionX, positionY, motionDX, motionDY, minDirectionDot, minDirectionDistance)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.EvaluateRouteMatch then
        return AirdropTrajectoryGeometryService:EvaluateRouteMatch(route, positionX, positionY, motionDX, motionDY, {
            projectionMargin = AirdropTrajectoryService.MATCH_PROJECTION_MARGIN or 0.08,
            distanceTolerance = AirdropTrajectoryService.MATCH_DISTANCE_TOLERANCE or 0.015,
            minDirectionDot = minDirectionDot or 0.92,
            minDirectionDistance = minDirectionDistance or 0.0035,
        })
    end
    return nil
end

local function UpdateAnchorAverage(anchorX, anchorY, sampleCount, positionX, positionY)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.UpdateAnchorAverage then
        return AirdropTrajectoryGeometryService:UpdateAnchorAverage(anchorX, anchorY, sampleCount, positionX, positionY)
    end
    return anchorX, anchorY, sampleCount
end

local function BuildPredictionMessage(targetMapData, route)
    if type(targetMapData) ~= "table" or type(route) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local endX = math.floor(((route.endX or 0) * 100) + 0.5)
    local endY = math.floor(((route.endY or 0) * 100) + 0.5)
    local format = (L and L["TrajectoryPredictionMatched"]) or "【%s】已匹配空投轨迹，预测落点坐标：%d, %d"
    return string.format(format, mapName, endX, endY)
end

local function BuildTraceSummaryMessage(targetMapData, state)
    if type(targetMapData) ~= "table" or type(state) ~= "table" then
        return nil
    end
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local startX = math.floor((((state.startConfirmed == true and state.startX) or state.firstX or 0) * 100) + 0.5)
    local startY = math.floor((((state.startConfirmed == true and state.startY) or state.firstY or 0) * 100) + 0.5)
    local endX = math.floor((((state.endConfirmed == true and state.endX) or state.lastX or 0) * 100) + 0.5)
    local endY = math.floor((((state.endConfirmed == true and state.endY) or state.lastY or 0) * 100) + 0.5)
    return string.format(
        "【%s】本次轨迹采样：起点 %d, %d -> 终点 %d, %d | 样本 %d | 点链 %d | start=%s | end=%s",
        mapName,
        startX,
        startY,
        endX,
        endY,
        math.floor(tonumber(state.sampleCount) or 0),
        #((state.sampledPoints) or {}),
        tostring(state.startConfirmed == true),
        tostring(state.endConfirmed == true)
    )
end

local function EmitTraceDebugOutput(targetMapData, state)
    if type(targetMapData) ~= "table" or type(state) ~= "table" then
        return false
    end

    local summary = BuildTraceSummaryMessage(targetMapData, state)
    if type(summary) == "string" and summary ~= "" then
        if NotificationOutputService and NotificationOutputService.SendLocalMessage then
            NotificationOutputService:SendLocalMessage(summary)
        elseif Logger and Logger.Info then
            Logger:Info("Trajectory", "调试", summary)
        end
    end

    local sampledPoints = state.sampledPoints or {}
    if #sampledPoints == 0 then
        return true
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local chunkIndex = 1
    local chunk = {}
    for _, point in ipairs(sampledPoints) do
        chunk[#chunk + 1] = string.format("%d,%d", tonumber(point.x) or 0, tonumber(point.y) or 0)
        if #chunk >= 8 then
            local line = string.format("【%s】轨迹点链(%d)：%s", mapName, chunkIndex, table.concat(chunk, " | "))
            if NotificationOutputService and NotificationOutputService.SendLocalMessage then
                NotificationOutputService:SendLocalMessage(line)
            elseif Logger and Logger.Info then
                Logger:Info("Trajectory", "调试", line)
            end
            chunkIndex = chunkIndex + 1
            chunk = {}
        end
    end

    if #chunk > 0 then
        local line = string.format("【%s】轨迹点链(%d)：%s", mapName, chunkIndex, table.concat(chunk, " | "))
        if NotificationOutputService and NotificationOutputService.SendLocalMessage then
            NotificationOutputService:SendLocalMessage(line)
        elseif Logger and Logger.Info then
            Logger:Info("Trajectory", "调试", line)
        end
    end
    return true
end

local function BuildWaypointMarkedMessage(targetMapData, route)
    if type(targetMapData) ~= "table" or type(route) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local endX = math.floor(((route.endX or 0) * 100) + 0.5)
    local endY = math.floor(((route.endY or 0) * 100) + 0.5)
    local format = (L and L["TrajectoryPredictionWaypointSet"]) or "【%s】已在地图上标记预测落点：%d, %d"
    return string.format(format, mapName, endX, endY)
end

local function SetPredictionWaypoint(targetMapData, route)
    if type(targetMapData) ~= "table" or type(route) ~= "table" then
        return false
    end
    if not C_Map or not C_Map.SetUserWaypoint or not UiMapPoint or not UiMapPoint.CreateFromCoordinates then
        return false
    end

    local mapID = tonumber(targetMapData.mapID)
    local endX = tonumber(route.endX)
    local endY = tonumber(route.endY)
    if not mapID or type(endX) ~= "number" or type(endY) ~= "number" then
        return false
    end

    local waypoint = UiMapPoint.CreateFromCoordinates(mapID, endX, endY)
    if not waypoint then
        return false
    end

    C_Map.SetUserWaypoint(waypoint)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

local function FinalizeObservedEndpoints(service, state)
    if type(service) ~= "table" or type(state) ~= "table" then
        return false
    end

    local stationarySince = tonumber(state.endStationarySince)
    local lastSeenAt = tonumber(state.lastSeenAt)
    local endAnchorX = tonumber(state.endAnchorX)
    local endAnchorY = tonumber(state.endAnchorY)
    if state.endConfirmed == true
        or type(stationarySince) ~= "number"
        or type(lastSeenAt) ~= "number"
        or type(endAnchorX) ~= "number"
        or type(endAnchorY) ~= "number" then
        return false
    end

    local observedStationaryDuration = lastSeenAt - stationarySince
    if observedStationaryDuration < (service.END_STATIONARY_CONFIRM_TIME or 6.0) then
        return false
    end

    state.endConfirmed = true
    state.endX = endAnchorX
    state.endY = endAnchorY
    return true
end

local function ConfirmEndOnDetectionLoss(state)
    if type(state) ~= "table" or state.movingStarted ~= true then
        return false
    end
    if state.endConfirmed == true then
        return true
    end

    local finalX = tonumber(state.endAnchorX) or tonumber(state.lastX)
    local finalY = tonumber(state.endAnchorY) or tonumber(state.lastY)
    if type(finalX) ~= "number" or type(finalY) ~= "number" then
        return false
    end

    state.endConfirmed = true
    state.endX = finalX
    state.endY = finalY
    return true
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

local function EnrichPredictionCandidate(service, state, matched)
    if type(service) ~= "table" or type(state) ~= "table" or type(matched) ~= "table" or type(matched.route) ~= "table" then
        return nil
    end

    local observationStartX, observationStartY = ResolveObservationStart(state)
    if type(observationStartX) ~= "number" or type(observationStartY) ~= "number" then
        return matched
    end

    matched.startDistance = ComputeDistance(observationStartX, observationStartY, matched.route.startX, matched.route.startY)
    matched.observationCount = tonumber(matched.route.observationCount) or 0
    matched.sampleCount = tonumber(matched.route.sampleCount) or 0
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

local function IsCandidatePredictionAmbiguous(service, candidate, routes)
    if type(candidate) ~= "table" or type(routes) ~= "table" then
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

    local startTolerance = tonumber(service.MATCH_ROUTE_FAMILY_START_TOLERANCE) or 0.03
    local familyDirectionDot = tonumber(service.MATCH_ROUTE_FAMILY_DIRECTION_DOT) or 0.985
    local familyLineTolerance = tonumber(service.MATCH_ROUTE_FAMILY_LINE_TOLERANCE) or 0.02
    local extensionMargin = tonumber(service.MATCH_ROUTE_FAMILY_EXTENSION_MARGIN) or 0.02
    local routeDx, routeDy, routeVectorLength = ComputeRouteVector(route)
    if routeVectorLength <= 0 then
        return false
    end

    local routeUnitX = routeDx / routeVectorLength
    local routeUnitY = routeDy / routeVectorLength
    local routeContext = AirdropTrajectoryGeometryService
        and AirdropTrajectoryGeometryService.BuildProjectionContext
        and AirdropTrajectoryGeometryService:BuildProjectionContext(route)
        or nil
    if type(routeContext) ~= "table" then
        return false
    end

    for _, sibling in ipairs(routes) do
        if type(sibling) == "table"
            and sibling ~= route
            and sibling.startConfirmed == true
            and sibling.endConfirmed == true then
            local siblingDx, siblingDy, siblingLength = ComputeRouteVector(sibling)
            if siblingLength > 0 then
                local startDistance = ComputeDistance(route.startX, route.startY, sibling.startX, sibling.startY)
                local directionDot = ((routeUnitX * (siblingDx / siblingLength)) + (routeUnitY * (siblingDy / siblingLength)))
                if startDistance <= startTolerance and directionDot >= familyDirectionDot then
                    local siblingEndDistance = AirdropTrajectoryGeometryService
                        and AirdropTrajectoryGeometryService.DistancePointToLine
                        and select(1, AirdropTrajectoryGeometryService:DistancePointToLine(routeContext, sibling.endX, sibling.endY))
                        or math.huge
                    if siblingEndDistance <= familyLineTolerance then
                        local shorterLength = math.min(routeLength, siblingLength)
                        if projection <= (shorterLength + extensionMargin) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

function AirdropTrajectoryService:Initialize()
    self.isInitialized = true
    self.activeObservationByMap = self.activeObservationByMap or {}
    self.pendingShoutStartByMap = self.pendingShoutStartByMap or {}
    if AirdropTrajectoryStore and AirdropTrajectoryStore.Initialize and not AirdropTrajectoryStore.routesByMap then
        AirdropTrajectoryStore:Initialize()
    end
    return true
end

function AirdropTrajectoryService:IsTraceDebugEnabled()
    if AppSettingsStore and AppSettingsStore.GetBoolean then
        return AppSettingsStore:GetBoolean(self.TRACE_DEBUG_SETTING_KEY, false)
    end
    local uiDB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    return uiDB[self.TRACE_DEBUG_SETTING_KEY] == true
end

function AirdropTrajectoryService:SetTraceDebugEnabled(enabled)
    local normalized = enabled == true
    if AppSettingsStore and AppSettingsStore.SetBoolean then
        AppSettingsStore:SetBoolean(self.TRACE_DEBUG_SETTING_KEY, normalized)
        return normalized
    end
    CRATETRACKERZK_UI_DB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    CRATETRACKERZK_UI_DB[self.TRACE_DEBUG_SETTING_KEY] = normalized
    return normalized
end

function AirdropTrajectoryService:Reset()
    self.activeObservationByMap = {}
    self.pendingShoutStartByMap = {}
    self.isInitialized = false
    return true
end

function AirdropTrajectoryService:HandleAirdropShout(targetMapData, currentTime)
    if type(targetMapData) ~= "table" or type(targetMapData.id) ~= "number" then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end

    self.pendingShoutStartByMap = self.pendingShoutStartByMap or {}
    self.pendingShoutStartByMap[targetMapData.id] = {
        timestamp = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    }
    return true
end

function AirdropTrajectoryService:NotifyPrediction(targetMapData, route)
    local message = BuildPredictionMessage(targetMapData, route)
    local waypointSet = SetPredictionWaypoint(targetMapData, route)
    if type(message) ~= "string" or message == "" then
        return waypointSet == true
    end

    local sentMessage = false
    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        sentMessage = NotificationOutputService:SendLocalMessage(message) == true
        if waypointSet == true then
            local waypointMessage = BuildWaypointMarkedMessage(targetMapData, route)
            if type(waypointMessage) == "string" and waypointMessage ~= "" then
                NotificationOutputService:SendLocalMessage(waypointMessage)
            end
        end
        return sentMessage == true or waypointSet == true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "预测", message)
        if waypointSet == true then
            local waypointMessage = BuildWaypointMarkedMessage(targetMapData, route)
            if type(waypointMessage) == "string" and waypointMessage ~= "" then
                Logger:Info("Trajectory", "预测", waypointMessage)
            end
        end
        return true
    end
    return waypointSet == true
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

    if type(state.announcedRouteKey) == "string" and state.announcedRouteKey ~= "" then
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
    local completeMatches = {}
    local fallbackMatches = {}

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
                matched = EnrichPredictionCandidate(self, state, matched)
                if ShouldRejectByStartDistance(self, state, matched) ~= true then
                if route.startConfirmed == true and route.endConfirmed == true then
                    completeMatches[#completeMatches + 1] = matched
                else
                    fallbackMatches[#fallbackMatches + 1] = matched
                end
                end
            end
        end
    end

    local currentMatches = nil
    if #completeMatches > 0 then
        currentMatches = SortPredictionCandidates(completeMatches)
    else
        currentMatches = SortPredictionCandidates(fallbackMatches)
    end

    if #currentMatches == 0 then
        if type(state.uniqueMatchState) == "table"
            and (currentTime - (tonumber(state.uniqueMatchState.lastMatchedAt) or 0)) > (self.MATCH_GAP_GRACE or 3) then
            state.uniqueMatchState = nil
        end
        return false
    end

    local candidate = currentMatches[1]
    local route = candidate.route
    if type(route) ~= "table" or state.announcedRouteKey == route.routeKey then
        return false
    end
    local isSelectionAmbiguous = IsCandidateSelectionAmbiguous(self, currentMatches)
    if IsCandidatePredictionAmbiguous(self, candidate, AirdropTrajectoryStore and AirdropTrajectoryStore.GetRoutes and AirdropTrajectoryStore:GetRoutes(targetMapData.mapID) or {}) then
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
        if isSelectionAmbiguous == true and uniqueState.routeKey ~= route.routeKey then
            state.uniqueMatchState = nil
            return false
        end
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
    local requiredDuration = ResolveAdaptiveMatchThreshold(
        self.MATCH_CONFIRM_DURATION or 20,
        self.MATCH_CONFIRM_DURATION_FLOOR or 5,
        self.MATCH_CONFIRM_DURATION_RATIO or 0.35,
        route
    )
    local requiredSamples = ResolveAdaptiveMatchThreshold(
        self.MATCH_MIN_SAMPLES or 20,
        self.MATCH_MIN_SAMPLES_FLOOR or 5,
        self.MATCH_MIN_SAMPLES_RATIO or 0.35,
        route
    )
    local minProgress = math.max(
        tonumber(self.MATCH_MIN_PROGRESS_ABSOLUTE) or 0.05,
        routeLength * (tonumber(self.MATCH_MIN_PROGRESS_RATIO) or 0.20)
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
    local targetMapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(state.mapID) or nil

    FinalizeObservedEndpoints(self, state)

    local observedDistance = ComputeDistance(state.firstX, state.firstY, state.lastX, state.lastY)
    local minimumObservationDistance = self.MIN_OBSERVATION_DISTANCE or 0.025
    if state.startConfirmed == true or state.endConfirmed == true then
        minimumObservationDistance = math.min(minimumObservationDistance, self.PARTIAL_MIN_OBSERVATION_DISTANCE or 0.015)
    end
    if observedDistance < minimumObservationDistance then
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
                eventObjectGUID = state.objectGUID,
                eventStartedAt = state.firstSeenAt,
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
    if state.endConfirmed == true
        and self.IsTraceDebugEnabled
        and self:IsTraceDebugEnabled() == true then
        EmitTraceDebugOutput(targetMapData or { mapID = state.mapID }, state)
    end
    return routeChanged == true
end

function AirdropTrajectoryService:FlushActiveObservations(currentTime)
    if type(self.activeObservationByMap) ~= "table" then
        return 0, 0
    end

    local runtimeMapIds = {}
    for runtimeMapId in pairs(self.activeObservationByMap) do
        if type(runtimeMapId) == "number" then
            runtimeMapIds[#runtimeMapIds + 1] = runtimeMapId
        end
    end
    table.sort(runtimeMapIds)

    local flushedCount = 0
    local changedCount = 0
    local flushTime = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    for _, runtimeMapId in ipairs(runtimeMapIds) do
        flushedCount = flushedCount + 1
        if self:FinalizeObservation(runtimeMapId, flushTime) == true then
            changedCount = changedCount + 1
        end
    end
    return flushedCount, changedCount
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
        if state.movingStarted == true then
            ConfirmEndOnDetectionLoss(state)
            return self:FinalizeObservation(targetMapData.id, now)
        end
        return false
    end
    if state.movingStarted == true then
        ConfirmEndOnDetectionLoss(state)
        return self:FinalizeObservation(targetMapData.id, now)
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
        local pendingShoutStart = self.pendingShoutStartByMap and self.pendingShoutStartByMap[runtimeMapId] or nil
        local pendingTimestamp = pendingShoutStart and tonumber(pendingShoutStart.timestamp) or nil
        if type(pendingTimestamp) == "number"
            and (currentTime - pendingTimestamp) >= 0
            and (currentTime - pendingTimestamp) <= (self.SHOUT_START_CONFIRM_WINDOW or 60) then
            state.startConfirmed = true
            state.startX = state.firstX
            state.startY = state.firstY
            state.startAnchorX = state.firstX
            state.startAnchorY = state.firstY
        end
        if self.pendingShoutStartByMap then
            self.pendingShoutStartByMap[runtimeMapId] = nil
        end
        self.activeObservationByMap[runtimeMapId] = state
    else
        state.lastSeenAt = currentTime
        state.missingSince = nil
    end

    AppendObservedPoint(state, positionX, positionY)

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
            and (currentTime - state.endStationarySince) >= (self.END_STATIONARY_CONFIRM_TIME or 6.0) then
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
