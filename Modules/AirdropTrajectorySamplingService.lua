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
        and state.continuityBroken ~= true
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

local function IncrementPredictionObservationCount(state)
    if type(state) ~= "table" then
        return 0
    end
    state.predictionObservationCount = math.max(0, math.floor(tonumber(state.predictionObservationCount) or 0)) + 1
    return state.predictionObservationCount
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
        "【%s】本次轨迹采样：起点 %s, %s -> 终点 %s, %s | 样本 %d | 预测观测 %d | 点链 %d | start=%s | end=%s",
        mapName,
        startX,
        startY,
        endX,
        endY,
        math.floor(tonumber(state.sampleCount) or 0),
        math.floor(tonumber(state.predictionObservationCount) or 0),
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

local function BuildMissingCrateSummaryMessage(targetMapData, state)
    if type(targetMapData) ~= "table" or type(state) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local lastX = FormatCoordinatePercent(state.lastX or 0)
    local lastY = FormatCoordinatePercent(state.lastY or 0)
    return string.format(
        "【%s】轨迹终点确认超时，未检测到箱子图标，已放弃本次未完成轨迹。最后飞机坐标：%s, %s",
        mapName,
        lastX,
        lastY
    )
end

local function EmitMissingCrateDebugOutput(service, targetMapData, state)
    if type(service) ~= "table"
        or not service.IsTraceDebugEnabled
        or service:IsTraceDebugEnabled() ~= true then
        return false
    end

    local message = BuildMissingCrateSummaryMessage(targetMapData, state)
    if type(message) ~= "string" or message == "" then
        return false
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        NotificationOutputService:SendLocalMessage(message)
        return true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "调试", message)
        return true
    end
    return false
end

local function BuildContinuityInterruptedMessage(targetMapData, state)
    if type(state) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring((targetMapData and targetMapData.mapID) or state.mapID or "")
    local lastX = FormatCoordinatePercent(state.lastX or 0)
    local lastY = FormatCoordinatePercent(state.lastY or 0)
    return string.format(
        "【%s】轨迹链路已中断，已放弃本次样本：最后飞机坐标=%s, %s | 样本=%d",
        mapName,
        lastX,
        lastY,
        math.floor(tonumber(state.sampleCount) or 0)
    )
end

local function EmitContinuityInterruptedDebugOutput(service, targetMapData, state)
    if type(service) ~= "table"
        or not service.IsTraceDebugEnabled
        or service:IsTraceDebugEnabled() ~= true then
        return false
    end

    local message = BuildContinuityInterruptedMessage(targetMapData, state)
    if type(message) ~= "string" or message == "" then
        return false
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        NotificationOutputService:SendLocalMessage(message)
        return true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "调试", message)
        return true
    end
    return false
end

local function BuildEndConfirmedSummaryMessage(targetMapData, iconResult, state)
    if type(targetMapData) ~= "table" or type(iconResult) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local positionX = FormatCoordinatePercent(iconResult.positionX or 0)
    local positionY = FormatCoordinatePercent(iconResult.positionY or 0)
    return string.format(
        "【%s】轨迹终点确认：vignetteID=%s | vignetteGUID=%s | objectGUID=%s | 坐标=%s, %s | 样本=%d",
        mapName,
        tostring(iconResult.vignetteID or "nil"),
        tostring(iconResult.vignetteGUID or "nil"),
        tostring(iconResult.objectGUID or "nil"),
        positionX,
        positionY,
        math.floor(tonumber(state and state.sampleCount) or 0)
    )
end

local function RecordEndConfirmedTraceEvent(service, targetMapData, iconResult, state, currentTime)
    if type(service) ~= "table" or not service.RecordTraceEvent then
        return false
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData and targetMapData.mapID or "")
    return service:RecordTraceEvent({
        recordedAt = tonumber(currentTime) or Utils:GetCurrentTimestamp(),
        eventType = "end_confirmed",
        mapName = mapName,
        mapID = targetMapData and targetMapData.mapID or nil,
        runtimeMapId = targetMapData and targetMapData.id or nil,
        vignetteID = iconResult and iconResult.vignetteID or nil,
        vignetteGUID = iconResult and iconResult.vignetteGUID or nil,
        objectGUID = iconResult and iconResult.objectGUID or nil,
        sourceObjectGUID = state and state.objectGUID or nil,
        positionX = iconResult and iconResult.positionX or nil,
        positionY = iconResult and iconResult.positionY or nil,
        sampleCount = state and state.sampleCount or nil,
        startSource = state and state.startSource or nil,
        endSource = state and state.endSource or nil,
        startConfirmed = state and state.startConfirmed == true,
        endConfirmed = state and state.endConfirmed == true,
    }) == true
end

local function EmitEndConfirmedDebugOutput(service, targetMapData, iconResult, state)
    if type(service) ~= "table"
        or not service.IsTraceDebugEnabled
        or service:IsTraceDebugEnabled() ~= true then
        return false
    end

    local message = BuildEndConfirmedSummaryMessage(targetMapData, iconResult, state)
    if type(message) ~= "string" or message == "" then
        return false
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        NotificationOutputService:SendLocalMessage(message)
        return true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "调试", message)
        return true
    end
    return false
end

local function ResolveFinalizeRejectReason(state)
    if type(state) ~= "table" then
        return "invalid_state"
    end
    if state.continuityBroken == true then
        return "continuous_tracking_interrupted"
    end
    if state.startConfirmed ~= true then
        return "start_not_confirmed"
    end
    if state.endConfirmed ~= true then
        return "end_not_confirmed"
    end
    if state.startSource ~= "npc_shout" then
        return "invalid_start_source"
    end
    if state.endSource ~= "crate_vignette" then
        return "invalid_end_source"
    end
    return "incomplete_route"
end

local function ShouldSuppressFinalizeRejectNoise(state, reason)
    if type(state) ~= "table" then
        return false
    end
    if reason ~= "start_not_confirmed" then
        return false
    end

    local sampleCount = math.max(0, math.floor(tonumber(state.sampleCount) or 0))
    return state.startConfirmed ~= true
        and state.endConfirmed ~= true
        and type(state.startSource) ~= "string"
        and type(state.endSource) ~= "string"
        and sampleCount <= 1
end

local function BuildFinalizeRejectedMessage(targetMapData, state, reason)
    if type(state) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring((targetMapData and targetMapData.mapID) or state.mapID or "")
    return string.format(
        "【%s】轨迹未入库：reason=%s | start=%s(%s) | end=%s(%s) | 样本=%d",
        mapName,
        tostring(reason or "unknown"),
        tostring(state.startConfirmed == true),
        tostring(state.startSource or "nil"),
        tostring(state.endConfirmed == true),
        tostring(state.endSource or "nil"),
        math.floor(tonumber(state.sampleCount) or 0)
    )
end

local function EmitFinalizeRejectedDebugOutput(service, targetMapData, state, reason)
    if type(service) ~= "table"
        or not service.IsTraceDebugEnabled
        or service:IsTraceDebugEnabled() ~= true then
        return false
    end

    local message = BuildFinalizeRejectedMessage(targetMapData, state, reason)
    if type(message) ~= "string" or message == "" then
        return false
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        NotificationOutputService:SendLocalMessage(message)
        return true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "调试", message)
        return true
    end
    return false
end

local function BuildRouteStoredMessage(targetMapData, routeRecord, routeChanged, storeMeta)
    if type(routeRecord) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring((targetMapData and targetMapData.mapID) or routeRecord.mapID or "")
    local quality = AirdropTrajectoryStore and AirdropTrajectoryStore.GetRouteQualityLabel
        and AirdropTrajectoryStore:GetRouteQualityLabel(routeRecord)
        or "unknown"
    local confidence = AirdropTrajectoryStore and AirdropTrajectoryStore.GetPredictionConfidence
        and AirdropTrajectoryStore:GetPredictionConfidence(routeRecord)
        or 0
    local status = type(storeMeta) == "table" and storeMeta.status or nil
    local inputRouteKey = type(storeMeta) == "table" and storeMeta.inputRouteKey or nil
    local storedRouteKey = type(storeMeta) == "table" and storeMeta.storedRouteKey or routeRecord.routeKey

    if status == "created_canonical_route" then
        return string.format(
            "【%s】规范轨迹已新增入库：route=%s | family=%s | landing=%s | 状态=%s | 可信度=%d | 样本=%d | 记录=%d | merged=%d",
            mapName,
            tostring(storedRouteKey or "unknown"),
            tostring(storeMeta and storeMeta.routeFamilyKey or routeRecord.routeFamilyKey or "unknown"),
            tostring(storeMeta and storeMeta.landingKey or routeRecord.landingKey or "unknown"),
            tostring(quality),
            confidence,
            math.floor(tonumber(routeRecord.sampleCount) or 0),
            math.floor(tonumber(routeRecord.observationCount) or 0),
            math.max(1, math.floor(tonumber(routeRecord.mergedRouteCount) or 1))
        )
    end

    if status == "updated_canonical_route" then
        return string.format(
            "【%s】轨迹已归并到既有规范路线：incoming=%s | stored=%s | family=%s | landing=%s | 状态=%s | 可信度=%d | merged=%d",
            mapName,
            tostring(inputRouteKey or "unknown"),
            tostring(storedRouteKey or "unknown"),
            tostring(storeMeta and storeMeta.routeFamilyKey or routeRecord.routeFamilyKey or "unknown"),
            tostring(storeMeta and storeMeta.landingKey or routeRecord.landingKey or "unknown"),
            tostring(quality),
            confidence,
            math.max(1, math.floor(tonumber(routeRecord.mergedRouteCount) or 1))
        )
    end

    return string.format(
        "【%s】轨迹已匹配现有规范路线，无新增写入：route=%s | family=%s | landing=%s | 状态=%s | 可信度=%d",
        mapName,
        tostring(storedRouteKey or routeRecord.routeKey or "unknown"),
        tostring(storeMeta and storeMeta.routeFamilyKey or routeRecord.routeFamilyKey or "unknown"),
        tostring(storeMeta and storeMeta.landingKey or routeRecord.landingKey or "unknown"),
        tostring(quality),
        confidence
    )
end

local function BuildObservationInputRouteKey(startX, startY, endX, endY)
    local scale = AirdropTrajectoryStore and AirdropTrajectoryStore.COORDINATE_SCALE or 1000
    local quantizedStartX = math.floor(((tonumber(startX) or 0) * scale) + 0.5)
    local quantizedStartY = math.floor(((tonumber(startY) or 0) * scale) + 0.5)
    local quantizedEndX = math.floor(((tonumber(endX) or 0) * scale) + 0.5)
    local quantizedEndY = math.floor(((tonumber(endY) or 0) * scale) + 0.5)
    return table.concat({
        tostring(quantizedStartX),
        tostring(quantizedStartY),
        tostring(quantizedEndX),
        tostring(quantizedEndY),
    }, ":")
end

local function EmitRouteStoredDebugOutput(service, targetMapData, routeRecord, routeChanged, storeMeta)
    if type(service) ~= "table"
        or not service.IsTraceDebugEnabled
        or service:IsTraceDebugEnabled() ~= true then
        return false
    end

    local message = BuildRouteStoredMessage(targetMapData, routeRecord, routeChanged, storeMeta)
    if type(message) ~= "string" or message == "" then
        return false
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        NotificationOutputService:SendLocalMessage(message)
        return true
    end
    if Logger and Logger.Info then
        Logger:Info("Trajectory", "调试", message)
        return true
    end
    return false
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
        predictionObservationCount = 0,
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
        continuityStartedAt = nil,
        continuityBroken = false,
    }
end

function AirdropTrajectorySamplingService:ApplyConfirmedStartFromShout(state, shoutState)
    if type(state) ~= "table" or type(shoutState) ~= "table" then
        return false, "invalid_state"
    end

    local shoutObjectGUID = type(shoutState.objectGUID) == "string" and shoutState.objectGUID or nil
    local stateObjectGUID = type(state.objectGUID) == "string" and state.objectGUID or nil
    if type(shoutObjectGUID) ~= "string" or shoutObjectGUID == "" then
        return false, "missing_shout_object_guid"
    end
    if type(stateObjectGUID) ~= "string" or stateObjectGUID == "" then
        return false, "missing_state_object_guid"
    end
    if shoutObjectGUID ~= stateObjectGUID then
        return false, "object_guid_mismatch"
    end

    local startX = tonumber(shoutState.positionX)
    local startY = tonumber(shoutState.positionY)
    if type(startX) ~= "number" or type(startY) ~= "number" then
        return false, "missing_position"
    end

    state.startConfirmed = true
    state.startX = startX
    state.startY = startY
    state.startAnchorX = startX
    state.startAnchorY = startY
    state.startAnchorSamples = 1
    state.startSource = "npc_shout"
    state.continuityStartedAt = tonumber(shoutState.timestamp) or Utils:GetCurrentTimestamp()
    state.continuityBroken = false
    if state.movingStarted == true then
        local cruiseEndX = tonumber(state.cruiseEndX) or tonumber(state.lastX)
        local cruiseEndY = tonumber(state.cruiseEndY) or tonumber(state.lastY)
        if type(cruiseEndX) == "number" and type(cruiseEndY) == "number" then
            UpdateCruiseLineEndpoint(state, startX, startY, cruiseEndX, cruiseEndY)
        end
    end
    return true, nil
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
    IncrementPredictionObservationCount(state)
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
    RecordEndConfirmedTraceEvent(service, targetMapData, iconResult, state, state.lastSeenAt)
    EmitEndConfirmedDebugOutput(service, targetMapData, iconResult, state)
    if service and service.RememberRecentlyFinalizedObservation then
        service:RememberRecentlyFinalizedObservation(targetMapData.id, state.objectGUID, state.lastSeenAt)
    end
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
        local rejectReason = ResolveFinalizeRejectReason(state)
        if ShouldSuppressFinalizeRejectNoise(state, rejectReason) == true then
            return false
        end
        if service and service.RecordTraceEvent then
            local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring((targetMapData and targetMapData.mapID) or state.mapID or "")
            service:RecordTraceEvent({
                recordedAt = finalizeTime,
                eventType = "finalize_rejected",
                mapName = mapName,
                mapID = state.mapID,
                runtimeMapId = runtimeMapId,
                sourceObjectGUID = state.objectGUID,
                positionX = state.lastX,
                positionY = state.lastY,
                sampleCount = state.sampleCount,
                startSource = state.startSource,
                endSource = state.endSource,
                startConfirmed = state.startConfirmed == true,
                endConfirmed = state.endConfirmed == true,
                note = rejectReason,
            })
        end
        EmitFinalizeRejectedDebugOutput(service, targetMapData or { mapID = state.mapID }, state, rejectReason)
        return false
    end

    local startX = state.startConfirmed == true and state.startX or state.firstX
    local startY = state.startConfirmed == true and state.startY or state.firstY
    local endX = state.endConfirmed == true and state.endX or state.lastX
    local endY = state.endConfirmed == true and state.endY or state.lastY
    local routeDistance = ComputeDistance(startX, startY, endX, endY)
    local minimumObservationDistance = service.MIN_OBSERVATION_DISTANCE or 0.025
    if routeDistance < minimumObservationDistance then
        if service and service.RecordTraceEvent then
            local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring((targetMapData and targetMapData.mapID) or state.mapID or "")
            service:RecordTraceEvent({
                recordedAt = finalizeTime,
                eventType = "finalize_rejected",
                mapName = mapName,
                mapID = state.mapID,
                runtimeMapId = runtimeMapId,
                sourceObjectGUID = state.objectGUID,
                positionX = endX,
                positionY = endY,
                sampleCount = state.sampleCount,
                startSource = state.startSource,
                endSource = state.endSource,
                startConfirmed = state.startConfirmed == true,
                endConfirmed = state.endConfirmed == true,
                note = "route_too_short",
            })
        end
        EmitFinalizeRejectedDebugOutput(service, targetMapData or { mapID = state.mapID }, state, "route_too_short")
        return false
    end

    local routeChanged = false
    local routeRecord = nil
    local routeStoreMeta = nil
    if AirdropTrajectoryStore and AirdropTrajectoryStore.UpsertRoute then
        local inputRouteKey = BuildObservationInputRouteKey(startX, startY, endX, endY)
        routeChanged, routeRecord, routeStoreMeta = AirdropTrajectoryStore:UpsertRoute(
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
                continuityConfirmed = state.continuityBroken ~= true and state.continuityStartedAt ~= nil,
                startSource = state.startSource,
                endSource = state.endSource,
                eventObjectGUID = state.objectGUID,
                eventStartedAt = state.firstSeenAt,
                startConfirmed = state.startConfirmed == true,
                endConfirmed = state.endConfirmed == true,
                representativeLegacyRouteKey = inputRouteKey,
            },
            "local",
            finalizeTime
        )
    end

    if type(routeRecord) == "table" and service and service.RecordTraceEvent then
        local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring((targetMapData and targetMapData.mapID) or state.mapID or "")
        service:RecordTraceEvent({
            recordedAt = finalizeTime,
            eventType = routeChanged == true and "route_saved" or "route_unchanged",
            mapName = mapName,
            mapID = state.mapID,
            runtimeMapId = runtimeMapId,
            sourceObjectGUID = state.objectGUID,
            sampleCount = state.sampleCount,
            routeKey = routeStoreMeta and routeStoreMeta.storedRouteKey or routeRecord.routeKey,
            startSource = state.startSource,
            endSource = state.endSource,
            startConfirmed = state.startConfirmed == true,
            endConfirmed = state.endConfirmed == true,
            note = routeStoreMeta and routeStoreMeta.status or (routeChanged == true and "stored_immediately_on_end_confirm" or "matched_existing_route"),
        })
    end
    if type(routeRecord) == "table" then
        EmitRouteStoredDebugOutput(service, targetMapData or { mapID = state.mapID }, routeRecord, routeChanged == true, routeStoreMeta)
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

    if state.startConfirmed == true and state.endConfirmed ~= true then
        state.continuityBroken = true
        if service and service.RecordTraceEvent then
            local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
            service:RecordTraceEvent({
                recordedAt = now,
                eventType = "continuity_interrupted",
                mapName = mapName,
                mapID = targetMapData.mapID,
                runtimeMapId = targetMapData.id,
                sourceObjectGUID = state.objectGUID,
                positionX = state.lastX,
                positionY = state.lastY,
                sampleCount = state.sampleCount,
                startSource = state.startSource,
                endSource = state.endSource,
                startConfirmed = state.startConfirmed == true,
                endConfirmed = state.endConfirmed == true,
                note = "detection_interrupted_before_end_confirm",
            })
        end
        EmitContinuityInterruptedDebugOutput(service, targetMapData, state)
        service.activeObservationByMap[targetMapData.id] = nil
        return false
    end

    if state.movingStarted == true then
        if state.endConfirmed == true then
            return self:FinalizeObservation(service, targetMapData.id, now)
        end
        if type(state.missingSince) ~= "number" then
            state.missingSince = now
            return false
        end
        if (now - state.missingSince) < (service.END_CONFIRM_WAIT_TIMEOUT or 15) then
            return false
        end

        if service and service.RecordTraceEvent then
            local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
            service:RecordTraceEvent({
                recordedAt = now,
                eventType = "end_confirm_timeout",
                mapName = mapName,
                mapID = targetMapData.mapID,
                runtimeMapId = targetMapData.id,
                sourceObjectGUID = state.objectGUID,
                positionX = state.lastX,
                positionY = state.lastY,
                sampleCount = state.sampleCount,
                note = "crate_not_detected",
            })
        end
        EmitMissingCrateDebugOutput(service, targetMapData, state)
        service.activeObservationByMap[targetMapData.id] = nil
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

    if type(state) == "table" and state.objectGUID ~= iconResult.objectGUID then
        self:FinalizeObservation(service, runtimeMapId, currentTime)
        state = nil
    end

    if type(state) ~= "table"
        and service.ShouldSuppressObservationStart
        and service:ShouldSuppressObservationStart(runtimeMapId, iconResult.objectGUID, currentTime) == true then
        return false
    end

    if type(state) ~= "table" then
        state = self:CreateObservationState(targetMapData, iconResult, currentTime)
        if type(state) ~= "table" then
            return false
        end

        local pendingShoutStart = service.pendingShoutStartByMap and service.pendingShoutStartByMap[runtimeMapId] or nil
        local pendingTimestamp = pendingShoutStart and tonumber(pendingShoutStart.timestamp) or nil
        local pendingShoutHasIdentity = type(pendingShoutStart) == "table"
            and type(pendingShoutStart.objectGUID) == "string"
            and pendingShoutStart.objectGUID ~= ""
            and type(pendingShoutStart.positionX) == "number"
            and type(pendingShoutStart.positionY) == "number"
        local applySucceeded = false
        local applyReason = nil
        if type(pendingTimestamp) == "number"
            and (currentTime - pendingTimestamp) >= 0
            and (currentTime - pendingTimestamp) <= (service.SHOUT_START_CONFIRM_WINDOW or 60)
            and pendingShoutHasIdentity == true
        then
            applySucceeded, applyReason = self:ApplyConfirmedStartFromShout(state, pendingShoutStart)
            if applySucceeded == true and service.pendingShoutStartByMap then
                service.pendingShoutStartByMap[runtimeMapId] = nil
            end
        elseif type(pendingTimestamp) == "number" then
            applyReason = "pending_shout_expired"
            if service.pendingShoutStartByMap then
                service.pendingShoutStartByMap[runtimeMapId] = nil
            end
        end
        if service and service.RecordTraceEvent
            and type(pendingTimestamp) == "number"
            and (applySucceeded == true or type(applyReason) == "string") then
            local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
            service:RecordTraceEvent({
                recordedAt = currentTime,
                eventType = applySucceeded == true and "start_applied" or "start_apply_rejected",
                mapName = mapName,
                mapID = targetMapData.mapID,
                runtimeMapId = runtimeMapId,
                objectGUID = pendingShoutStart and pendingShoutStart.objectGUID or nil,
                sourceObjectGUID = state.objectGUID,
                positionX = pendingShoutStart and pendingShoutStart.positionX or nil,
                positionY = pendingShoutStart and pendingShoutStart.positionY or nil,
                sampleCount = state.sampleCount,
                startSource = state.startSource,
                startConfirmed = state.startConfirmed == true,
                note = applySucceeded == true and "pending_shout_applied" or applyReason,
            })
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
    local cruiseProgressMargin = service.CRUISE_PROGRESS_MARGIN or 0.0035

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
    else
        state.lastX = positionX
        state.lastY = positionY
    end

    local startX, startY = ResolveObservationStart(state)
    local currentCruiseLength = tonumber(state.cruiseLineLength) or 0
    if type(startX) == "number" and type(startY) == "number" then
        local newLength = ComputeDistance(startX, startY, positionX, positionY)
        if newLength > (currentCruiseLength + cruiseProgressMargin) then
            UpdateCruiseLineEndpoint(state, startX, startY, positionX, positionY)
        end
    end

    if state.endConfirmed ~= true then
        state.endX = state.lastX
        state.endY = state.lastY
    end

    return service:TryMatchPrediction(targetMapData, state, iconResult)
end

return AirdropTrajectorySamplingService
