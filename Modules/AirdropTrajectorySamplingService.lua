-- AirdropTrajectorySamplingService.lua - 空投轨迹采样与观测状态机

local AirdropTrajectorySamplingService = BuildEnv("AirdropTrajectorySamplingService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local Data = BuildEnv("Data")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Utils = BuildEnv("Utils")

local function ComputeDistance(x1, y1, x2, y2)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeDistance then
        return AirdropTrajectoryGeometryService:ComputeDistance(x1, y1, x2, y2)
    end
    return 0
end

local function IsCompleteReliableObservation(state)
    return type(state) == "table"
        and state.startConfirmed == true
        and state.endConfirmed == true
        and state.startSource == "npc_shout"
end

local function IsPredictionAccurate(service, state, routeRecord)
    if type(service) ~= "table" or type(state) ~= "table" or type(routeRecord) ~= "table" then
        return nil
    end
    if type(state.predictedRouteKey) ~= "string" or state.predictedRouteKey == "" then
        return nil
    end

    local predictedEndX = tonumber(state.predictedEndX)
    local predictedEndY = tonumber(state.predictedEndY)
    local finalEndX = tonumber(routeRecord.endX)
    local finalEndY = tonumber(routeRecord.endY)
    if type(predictedEndX) ~= "number"
        or type(predictedEndY) ~= "number"
        or type(finalEndX) ~= "number"
        or type(finalEndY) ~= "number" then
        return nil
    end

    if state.predictedRouteKey == routeRecord.routeKey then
        return true
    end

    local tolerance = tonumber(service.PREDICTION_VERIFICATION_TOLERANCE) or 0.015
    return ComputeDistance(predictedEndX, predictedEndY, finalEndX, finalEndY) <= tolerance
end

local function UpdateAnchorAverage(anchorX, anchorY, sampleCount, positionX, positionY)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.UpdateAnchorAverage then
        return AirdropTrajectoryGeometryService:UpdateAnchorAverage(anchorX, anchorY, sampleCount, positionX, positionY)
    end
    return anchorX, anchorY, sampleCount
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

local function ResetEndPhaseState(state)
    if type(state) ~= "table" then
        return nil
    end

    state.endPhaseActive = false
    state.endPhaseStartedAt = nil
    state.endPhaseLastSeenAt = nil
    state.endPhaseCenterX = nil
    state.endPhaseCenterY = nil
    state.endPhaseEntryX = nil
    state.endPhaseEntryY = nil
    state.endPhasePointCount = 0
    return state
end

local function ResetEndPhaseWindow(state)
    if type(state) ~= "table" then
        return nil
    end

    state.endPhaseWindowPoints = {}
    return ResetEndPhaseState(state)
end

local function AppendEndPhaseWindowPoint(service, state, currentTime, positionX, positionY)
    if type(service) ~= "table" or type(state) ~= "table" then
        return nil
    end

    state.endPhaseWindowPoints = type(state.endPhaseWindowPoints) == "table" and state.endPhaseWindowPoints or {}
    state.endPhaseWindowPoints[#state.endPhaseWindowPoints + 1] = {
        time = tonumber(currentTime) or Utils:GetCurrentTimestamp(),
        x = tonumber(positionX),
        y = tonumber(positionY),
        qx = math.floor(((tonumber(positionX) or 0) * 100) + 0.5),
        qy = math.floor(((tonumber(positionY) or 0) * 100) + 0.5),
    }

    local maxSamples = math.max(
        tonumber(service.END_PHASE_WINDOW_SAMPLES) or 5,
        tonumber(service.END_PHASE_MIN_SAMPLES) or 4
    )
    while #state.endPhaseWindowPoints > maxSamples do
        table.remove(state.endPhaseWindowPoints, 1)
    end

    return state.endPhaseWindowPoints
end

local function ComputeWindowCenter(windowPoints)
    if type(windowPoints) ~= "table" or #windowPoints == 0 then
        return nil, nil
    end

    local sumX = 0
    local sumY = 0
    for _, point in ipairs(windowPoints) do
        sumX = sumX + (tonumber(point.x) or 0)
        sumY = sumY + (tonumber(point.y) or 0)
    end

    return sumX / #windowPoints, sumY / #windowPoints
end

local function ComputeWindowMaxDistance(windowPoints, centerX, centerY)
    if type(windowPoints) ~= "table" or #windowPoints == 0 then
        return nil
    end

    local maxDistance = 0
    for _, point in ipairs(windowPoints) do
        local distance = ComputeDistance(point.x, point.y, centerX, centerY)
        if distance > maxDistance then
            maxDistance = distance
        end
    end
    return maxDistance
end

local function FindRepeatedPhaseEntry(windowPoints)
    if type(windowPoints) ~= "table" or #windowPoints < 2 then
        return nil
    end

    for index = 1, (#windowPoints - 1) do
        local currentPoint = windowPoints[index]
        if type(currentPoint) == "table" then
            for nextIndex = index + 1, #windowPoints do
                local laterPoint = windowPoints[nextIndex]
                if type(laterPoint) == "table"
                    and currentPoint.qx == laterPoint.qx
                    and currentPoint.qy == laterPoint.qy then
                    return currentPoint
                end
            end
        end
    end

    return nil
end

local function RefreshEndPhaseCandidate(service, state, currentTime, positionX, positionY)
    if type(service) ~= "table" or type(state) ~= "table" then
        return false
    end

    local windowPoints = AppendEndPhaseWindowPoint(service, state, currentTime, positionX, positionY)
    local minSamples = math.max(2, tonumber(service.END_PHASE_MIN_SAMPLES) or 4)
    if type(windowPoints) ~= "table" or #windowPoints < minSamples then
        ResetEndPhaseState(state)
        return false
    end

    local centerX, centerY = ComputeWindowCenter(windowPoints)
    if type(centerX) ~= "number" or type(centerY) ~= "number" then
        ResetEndPhaseState(state)
        return false
    end

    local maxDistance = ComputeWindowMaxDistance(windowPoints, centerX, centerY)
    local radius = tonumber(service.END_PHASE_RADIUS) or 0.015
    if type(maxDistance) ~= "number" or maxDistance > radius then
        ResetEndPhaseState(state)
        return false
    end

    local repeatedEntryPoint = FindRepeatedPhaseEntry(windowPoints)
    if type(repeatedEntryPoint) ~= "table" then
        ResetEndPhaseState(state)
        return false
    end

    if state.endPhaseActive ~= true then
        state.endPhaseActive = true
        state.endPhaseStartedAt = tonumber(windowPoints[1] and windowPoints[1].time) or tonumber(currentTime) or Utils:GetCurrentTimestamp()
    end

    state.endPhaseLastSeenAt = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    state.endPhaseCenterX = centerX
    state.endPhaseCenterY = centerY
    state.endPhaseEntryX = tonumber(repeatedEntryPoint.x)
    state.endPhaseEntryY = tonumber(repeatedEntryPoint.y)
    state.endPhasePointCount = #windowPoints
    return true
end

local function ConfirmEndPhase(service, state)
    if type(service) ~= "table" or type(state) ~= "table" then
        return false
    end
    if state.endConfirmed == true or state.endPhaseActive ~= true then
        return state.endConfirmed == true
    end

    local centerX = tonumber(state.endPhaseCenterX)
    local centerY = tonumber(state.endPhaseCenterY)
    local entryX = tonumber(state.endPhaseEntryX)
    local entryY = tonumber(state.endPhaseEntryY)
    local pointCount = tonumber(state.endPhasePointCount) or 0
    if type(centerX) ~= "number"
        or type(centerY) ~= "number"
        or type(entryX) ~= "number"
        or type(entryY) ~= "number" then
        return false
    end

    local minSamples = math.max(2, tonumber(service.END_PHASE_MIN_SAMPLES) or 4)
    if pointCount < minSamples then
        return false
    end

    state.endConfirmed = true
    state.endX = entryX
    state.endY = entryY
    return true
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

function AirdropTrajectorySamplingService:CreateObservationState(targetMapData, iconResult, currentTime)
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
        startSource = nil,
        startConfirmed = false,
        movingStarted = false,
        lastX = positionX,
        lastY = positionY,
        endX = positionX,
        endY = positionY,
        endConfirmed = false,
        firstSeenAt = currentTime,
        lastSeenAt = currentTime,
        sampleCount = 1,
        announcedRouteKey = nil,
        missingSince = nil,
        uniqueMatchState = nil,
        predictedRouteKey = nil,
        predictedEndX = nil,
        predictedEndY = nil,
        motionDX = nil,
        motionDY = nil,
        motionRecordedAt = nil,
        motionRecordedAtRealtime = nil,
        sampledPoints = {},
        lastRecordedPointKey = nil,
        endPhaseWindowPoints = {},
        endPhaseActive = false,
        endPhaseStartedAt = nil,
        endPhaseLastSeenAt = nil,
        endPhaseCenterX = nil,
        endPhaseCenterY = nil,
        endPhasePointCount = 0,
    }
end

function AirdropTrajectorySamplingService:ApplyConfirmedStartFromShout(state, shoutState)
    if type(state) ~= "table" or type(shoutState) ~= "table" then
        return false
    end

    local startX = tonumber(shoutState.positionX)
    local startY = tonumber(shoutState.positionY)
    if type(startX) ~= "number" or type(startY) ~= "number" then
        return false
    end

    local shoutObjectGUID = type(shoutState.objectGUID) == "string" and shoutState.objectGUID or nil
    if shoutObjectGUID
        and type(state.objectGUID) == "string"
        and state.objectGUID ~= shoutObjectGUID then
        return false
    end

    state.startConfirmed = true
    state.startX = startX
    state.startY = startY
    state.startAnchorX = startX
    state.startAnchorY = startY
    state.startAnchorSamples = 1
    state.startSource = "npc_shout"
    return true
end

function AirdropTrajectorySamplingService:AppendObservedPoint(state, positionX, positionY)
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

function AirdropTrajectorySamplingService:FinalizeObservedEndpoints(service, state)
    if type(service) ~= "table" or type(state) ~= "table" then
        return false
    end
    return ConfirmEndPhase(service, state)
end

function AirdropTrajectorySamplingService:ConfirmEndOnDetectionLoss(state)
    if type(state) ~= "table" or state.movingStarted ~= true then
        return false
    end
    return state.endConfirmed == true
end

function AirdropTrajectorySamplingService:FinalizeObservation(service, runtimeMapId, currentTime)
    if type(service) ~= "table"
        or type(service.activeObservationByMap) ~= "table"
        or type(runtimeMapId) ~= "number" then
        return false
    end

    local state = service.activeObservationByMap[runtimeMapId]
    service.activeObservationByMap[runtimeMapId] = nil
    if type(state) ~= "table" then
        return false
    end

    local finalizeTime = tonumber(currentTime) or tonumber(state.lastSeenAt) or Utils:GetCurrentTimestamp()
    local targetMapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(state.mapID) or nil

    self:FinalizeObservedEndpoints(service, state)

    if IsCompleteReliableObservation(state) ~= true then
        return false
    end

    local observedDistance = ComputeDistance(state.firstX, state.firstY, state.lastX, state.lastY)
    local minimumObservationDistance = service.MIN_OBSERVATION_DISTANCE or 0.025
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
                updatedAt = finalizeTime,
                source = "local",
                startSource = state.startSource,
                eventObjectGUID = state.objectGUID,
                eventStartedAt = state.firstSeenAt,
                startConfirmed = state.startConfirmed == true,
                endConfirmed = state.endConfirmed == true,
            },
            "local",
            finalizeTime
        )
    end

    local predictionAccurate = IsPredictionAccurate(service, state, routeRecord)
    if type(predictionAccurate) == "boolean" and type(state.predictedRouteKey) == "string" then
        local verifiedRouteKey = predictionAccurate == true
            and (type(routeRecord) == "table" and routeRecord.routeKey or state.predictedRouteKey)
            or state.predictedRouteKey
        if AirdropTrajectoryStore and AirdropTrajectoryStore.UpdatePredictionVerification then
            AirdropTrajectoryStore:UpdatePredictionVerification(
                state.mapID,
                verifiedRouteKey,
                predictionAccurate
            )
        end
    end

    if routeChanged == true
        and type(routeRecord) == "table"
        and AirdropTrajectorySyncService
        and AirdropTrajectorySyncService.BroadcastRoute then
        AirdropTrajectorySyncService:BroadcastRoute(routeRecord)
    end

    if state.endConfirmed == true
        and service.IsTraceDebugEnabled
        and service:IsTraceDebugEnabled() == true then
        EmitTraceDebugOutput(targetMapData or { mapID = state.mapID }, state)
    end

    return routeChanged == true
end

function AirdropTrajectorySamplingService:HandleNoDetection(service, targetMapData, currentTime)
    if type(service) ~= "table"
        or type(targetMapData) ~= "table"
        or type(targetMapData.id) ~= "number" then
        return false
    end

    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local state = service.activeObservationByMap and service.activeObservationByMap[targetMapData.id] or nil
    if type(state) ~= "table" then
        return false
    end

    if type(state.missingSince) ~= "number" then
        state.missingSince = now
        if state.movingStarted == true then
            self:ConfirmEndOnDetectionLoss(state)
            return self:FinalizeObservation(service, targetMapData.id, now)
        end
        return false
    end

    if state.movingStarted == true then
        self:ConfirmEndOnDetectionLoss(state)
        return self:FinalizeObservation(service, targetMapData.id, now)
    end

    if (now - state.missingSince) < (service.MISSING_FINALIZE_DELAY or 2.2) then
        return false
    end

    return self:FinalizeObservation(service, targetMapData.id, now)
end

function AirdropTrajectorySamplingService:HandleDetectedIcon(service, targetMapData, iconResult, currentTime)
    if type(service) ~= "table"
        or type(targetMapData) ~= "table"
        or type(targetMapData.id) ~= "number"
        or type(targetMapData.mapID) ~= "number"
        or type(iconResult) ~= "table"
        or type(iconResult.objectGUID) ~= "string"
        or iconResult.objectGUID == "" then
        return false
    end

    if not service.isInitialized then
        service:Initialize()
    end

    currentTime = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local runtimeMapId = targetMapData.id
    local positionX = tonumber(iconResult.positionX)
    local positionY = tonumber(iconResult.positionY)
    if type(positionX) ~= "number" or type(positionY) ~= "number" then
        return false
    end

    service.activeObservationByMap = service.activeObservationByMap or {}
    local state = service.activeObservationByMap[runtimeMapId]

    if type(state) ~= "table" or state.objectGUID ~= iconResult.objectGUID then
        if type(state) == "table" then
            self:FinalizeObservation(service, runtimeMapId, currentTime)
        end

        state = self:CreateObservationState(targetMapData, iconResult, currentTime)
        if type(state) ~= "table" then
            return false
        end

        local pendingShoutStart = service.pendingShoutStartByMap and service.pendingShoutStartByMap[runtimeMapId] or nil
        local pendingTimestamp = pendingShoutStart and tonumber(pendingShoutStart.timestamp) or nil
        if type(pendingTimestamp) == "number"
            and (currentTime - pendingTimestamp) >= 0
            and (currentTime - pendingTimestamp) <= (service.SHOUT_START_CONFIRM_WINDOW or 60)
            and self:ApplyConfirmedStartFromShout(state, pendingShoutStart) == true
            and service.pendingShoutStartByMap then
            service.pendingShoutStartByMap[runtimeMapId] = nil
        end
        service.activeObservationByMap[runtimeMapId] = state
    else
        state.lastSeenAt = currentTime
        state.missingSince = nil
    end

    self:AppendObservedPoint(state, positionX, positionY)

    local moveConfirmDistance = service.MOVE_CONFIRM_DISTANCE or 0.0045
    local stationaryTolerance = service.STATIONARY_TOLERANCE or 0.006
    local sampleDelta = service.MIN_SAMPLE_DELTA or 0.0025

    if state.movingStarted ~= true then
        local startAnchorDistance = ComputeDistance(state.startAnchorX, state.startAnchorY, positionX, positionY)
        if startAnchorDistance <= stationaryTolerance then
            if state.startConfirmed ~= true then
                state.startAnchorX, state.startAnchorY, state.startAnchorSamples = UpdateAnchorAverage(
                    state.startAnchorX,
                    state.startAnchorY,
                    state.startAnchorSamples,
                    positionX,
                    positionY
                )
                state.startX = state.startAnchorX
                state.startY = state.startAnchorY
            end
        elseif startAnchorDistance >= moveConfirmDistance then
            state.movingStarted = true
            if state.startConfirmed ~= true then
                state.startX = state.startAnchorX
                state.startY = state.startAnchorY
            end
            state.motionDX = positionX - state.startAnchorX
            state.motionDY = positionY - state.startAnchorY
            state.motionRecordedAt = currentTime
            state.motionRecordedAtRealtime = GetRuntimeNow()
            state.lastX = positionX
            state.lastY = positionY
            state.endX = positionX
            state.endY = positionY
            state.endConfirmed = false
            ResetEndPhaseWindow(state)
            state.uniqueMatchState = nil
            if state.sampleCount < 2 then
                state.sampleCount = 2
            end
        end
        return service:TryMatchPrediction(targetMapData, state, iconResult)
    end

    local moveDistance = ComputeDistance(state.lastX, state.lastY, positionX, positionY)
    if moveDistance >= sampleDelta then
        state.motionDX = positionX - state.lastX
        state.motionDY = positionY - state.lastY
        state.motionRecordedAt = currentTime
        state.motionRecordedAtRealtime = GetRuntimeNow()
        state.lastX = positionX
        state.lastY = positionY
        state.sampleCount = (tonumber(state.sampleCount) or 1) + 1
    else
        state.lastX = positionX
        state.lastY = positionY
    end

    if state.endConfirmed ~= true then
        state.endX = state.lastX
        state.endY = state.lastY
        if RefreshEndPhaseCandidate(service, state, currentTime, positionX, positionY) == true then
            ConfirmEndPhase(service, state)
        end
    end

    return service:TryMatchPrediction(targetMapData, state, iconResult)
end

return AirdropTrajectorySamplingService
