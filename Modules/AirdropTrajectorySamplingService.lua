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

local function FormatCoordinatePercent(value)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.FormatCoordinatePercent then
        return AirdropTrajectoryGeometryService:FormatCoordinatePercent(value)
    end
    return string.format("%.1f", (tonumber(value) or 0) * 100)
end

local function FormatQuantizedCoordinatePercent(value, scale)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.FormatQuantizedCoordinatePercent then
        return AirdropTrajectoryGeometryService:FormatQuantizedCoordinatePercent(value, scale)
    end
    local resolvedScale = tonumber(scale) or 1000
    return string.format("%.1f", ((tonumber(value) or 0) * 100) / resolvedScale)
end

local function IsCompleteReliableObservation(state)
    return type(state) == "table"
        and state.startConfirmed == true
        and state.endConfirmed == true
        and state.startSource == "npc_shout"
        and state.endSource == "crate_vignette"
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

local function UpdateCruiseLineEndpoint(state, startX, startY, endX, endY)
    if type(state) ~= "table"
        or type(startX) ~= "number"
        or type(startY) ~= "number"
        or type(endX) ~= "number"
        or type(endY) ~= "number" then
        return false
    end

    local lineLength = ComputeDistance(startX, startY, endX, endY)
    if type(lineLength) ~= "number" or lineLength <= 0 then
        return false
    end

    state.cruiseEndX = endX
    state.cruiseEndY = endY
    state.cruiseLineLength = lineLength
    return true
end

local function BuildTraceSummaryMessage(targetMapData, state)
    if type(targetMapData) ~= "table" or type(state) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local startX = FormatCoordinatePercent((state.startConfirmed == true and state.startX) or state.firstX or 0)
    local startY = FormatCoordinatePercent((state.startConfirmed == true and state.startY) or state.firstY or 0)
    local endX = FormatCoordinatePercent((state.endConfirmed == true and state.endX) or state.lastX or 0)
    local endY = FormatCoordinatePercent((state.endConfirmed == true and state.endY) or state.lastY or 0)
    return string.format(
        "【%s】本次轨迹采样：起点 %s, %s -> 终点 %s, %s | 样本 %d | 点链 %d | start=%s | end=%s",
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
    local pointScale = AirdropTrajectoryStore and AirdropTrajectoryStore.COORDINATE_SCALE or 1000
    local chunkIndex = 1
    local chunk = {}
    for _, point in ipairs(sampledPoints) do
        chunk[#chunk + 1] = string.format(
            "%s,%s",
            FormatQuantizedCoordinatePercent(point.x, pointScale),
            FormatQuantizedCoordinatePercent(point.y, pointScale)
        )
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
        endSource = nil,
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
        sampledPoints = {},
        lastRecordedPointKey = nil,
        cruiseEndX = nil,
        cruiseEndY = nil,
        cruiseLineLength = 0,
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
    if state.movingStarted == true then
        local cruiseEndX = tonumber(state.cruiseEndX) or tonumber(state.lastX)
        local cruiseEndY = tonumber(state.cruiseEndY) or tonumber(state.lastY)
        if type(cruiseEndX) == "number" and type(cruiseEndY) == "number" then
            UpdateCruiseLineEndpoint(state, startX, startY, cruiseEndX, cruiseEndY)
        end
    end
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

    local pointScale = AirdropTrajectoryStore and AirdropTrajectoryStore.COORDINATE_SCALE or 1000
    local pointX = math.floor((x * pointScale) + 0.5)
    local pointY = math.floor((y * pointScale) + 0.5)
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
    return type(service) == "table" and type(state) == "table" and state.endConfirmed == true
end

function AirdropTrajectorySamplingService:HandleDetectedCrate(service, targetMapData, iconResult, currentTime)
    if type(service) ~= "table"
        or type(targetMapData) ~= "table"
        or type(targetMapData.id) ~= "number"
        or type(iconResult) ~= "table"
        or iconResult.detected ~= true then
        return false
    end

    local state = service.activeObservationByMap and service.activeObservationByMap[targetMapData.id] or nil
    if type(state) ~= "table" or state.movingStarted ~= true then
        return false
    end

    local endX = tonumber(iconResult.positionX)
    local endY = tonumber(iconResult.positionY)
    if type(endX) ~= "number" or type(endY) ~= "number" then
        return false
    end

    state.lastSeenAt = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    state.missingSince = nil
    self:AppendObservedPoint(state, endX, endY)
    state.endConfirmed = true
    state.endX = endX
    state.endY = endY
    state.endSource = "crate_vignette"
    self:FinalizeObservation(service, targetMapData.id, state.lastSeenAt)
    return true
end

function AirdropTrajectorySamplingService:ConfirmEndOnDetectionLoss(service, state)
    return type(service) == "table"
        and type(state) == "table"
        and state.movingStarted == true
        and state.endConfirmed == true
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

    local startX = state.startConfirmed == true and state.startX or state.firstX
    local startY = state.startConfirmed == true and state.startY or state.firstY
    local endX = state.endConfirmed == true and state.endX or state.lastX
    local endY = state.endConfirmed == true and state.endY or state.lastY
    local routeDistance = ComputeDistance(startX, startY, endX, endY)
    local minimumObservationDistance = service.MIN_OBSERVATION_DISTANCE or 0.025
    if routeDistance < minimumObservationDistance then
        return false
    end

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
                endSource = state.endSource,
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

    if state.movingStarted == true then
        if state.endConfirmed == true then
            return self:FinalizeObservation(service, targetMapData.id, now)
        end
        return false
    end

    if type(state.missingSince) ~= "number" then
        state.missingSince = now
        return false
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
            state.lastX = positionX
            state.lastY = positionY
            state.endX = positionX
            state.endY = positionY
            state.endConfirmed = false
            UpdateCruiseLineEndpoint(state, state.startX, state.startY, positionX, positionY)
            state.uniqueMatchState = nil
            if state.sampleCount < 2 then
                state.sampleCount = 2
            end
        end
        return service:TryMatchPrediction(targetMapData, state, iconResult)
    end

    local moveDistance = ComputeDistance(state.lastX, state.lastY, positionX, positionY)
    if moveDistance >= sampleDelta then
        state.lastX = positionX
        state.lastY = positionY
        state.sampleCount = (tonumber(state.sampleCount) or 1) + 1
        local startX, startY = ResolveObservationStart(state)
        local currentCruiseLength = tonumber(state.cruiseLineLength) or 0
        if type(startX) == "number" and type(startY) == "number" then
            local newLength = ComputeDistance(startX, startY, positionX, positionY)
            if newLength > currentCruiseLength then
                UpdateCruiseLineEndpoint(state, startX, startY, positionX, positionY)
            end
        end
    else
        state.lastX = positionX
        state.lastY = positionY
    end

    if state.endConfirmed ~= true then
        state.endX = state.lastX
        state.endY = state.lastY
    end

    return service:TryMatchPrediction(targetMapData, state, iconResult)
end

return AirdropTrajectorySamplingService
