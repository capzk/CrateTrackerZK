-- AirdropTrajectoryService.lua - 空投轨迹实时记录与落点预测

local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")
local AirdropTrajectoryMatchingService = BuildEnv("AirdropTrajectoryMatchingService")
local AirdropTrajectorySamplingService = BuildEnv("AirdropTrajectorySamplingService")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AppSettingsStore = BuildEnv("AppSettingsStore")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local Data = BuildEnv("Data")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")
local L = CrateTrackerZK and CrateTrackerZK.L or {}

local function FormatCoordinatePercent(value)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.FormatCoordinatePercent then
        return AirdropTrajectoryGeometryService:FormatCoordinatePercent(value)
    end
    return string.format("%.1f", (tonumber(value) or 0) * 100)
end

AirdropTrajectoryService.MIN_SAMPLE_DELTA = 0.0025
AirdropTrajectoryService.MIN_OBSERVATION_DISTANCE = 0.025
AirdropTrajectoryService.MATCH_DISTANCE_TOLERANCE = 0.015
AirdropTrajectoryService.MATCH_PROJECTION_MARGIN = 0.08
AirdropTrajectoryService.MATCH_TRACK_ANGLE_THRESHOLD = 0.06
AirdropTrajectoryService.MATCH_TRACK_DISTANCE_THRESHOLD = 0.012
AirdropTrajectoryService.MATCH_TRACK_AMBIGUITY_DISTANCE_MARGIN = 0.004
AirdropTrajectoryService.MATCH_TRACK_AMBIGUITY_ANGLE_MARGIN = 0.01
AirdropTrajectoryService.MATCH_CONFIRM_STABLE_SAMPLES = 2
AirdropTrajectoryService.MATCH_MIN_PROGRESS_ABSOLUTE = 0.05
AirdropTrajectoryService.MATCH_MIN_PROGRESS_RATIO = 0.20
AirdropTrajectoryService.MATCH_MIN_REMAINING_ABSOLUTE = 0.04
AirdropTrajectoryService.MATCH_MIN_REMAINING_RATIO = 0.15
AirdropTrajectoryService.MATCH_START_DISTANCE_TOLERANCE = 0.08
AirdropTrajectoryService.MATCH_AMBIGUITY_DISTANCE_MARGIN = 0.004
AirdropTrajectoryService.MATCH_AMBIGUITY_START_MARGIN = 0.015
AirdropTrajectoryService.MATCH_MIN_DIRECTION_DOT = 0.92
AirdropTrajectoryService.MATCH_DIRECTION_MIN_DISTANCE = 0.0035
AirdropTrajectoryService.STATIONARY_TOLERANCE = 0.006
AirdropTrajectoryService.MOVE_CONFIRM_DISTANCE = 0.0045
AirdropTrajectoryService.CRUISE_LINE_TOLERANCE = 0.012
AirdropTrajectoryService.CRUISE_PROGRESS_MARGIN = 0.0035
AirdropTrajectoryService.MISSING_FINALIZE_DELAY = 2.2
AirdropTrajectoryService.END_CONFIRM_WAIT_TIMEOUT = 15
AirdropTrajectoryService.PARTIAL_MIN_OBSERVATION_DISTANCE = 0.015
AirdropTrajectoryService.PREDICTION_VERIFICATION_TOLERANCE = 0.015
AirdropTrajectoryService.FINALIZED_OBSERVATION_SUPPRESSION_WINDOW = 120
AirdropTrajectoryService.SHOUT_START_CONFIRM_WINDOW = 60
AirdropTrajectoryService.SHOUT_CAPTURE_RETRY_INTERVAL = 1.0
AirdropTrajectoryService.SHOUT_CAPTURE_RETRY_ATTEMPTS = 5
AirdropTrajectoryService.TRACE_DEBUG_SETTING_KEY = "trajectoryTraceDebugEnabled"
AirdropTrajectoryService.PREDICTION_ENABLED_SETTING_KEY = "trajectoryPredictionEnabled"
AirdropTrajectoryService.LEGACY_MATCH_DEBUG_SETTING_KEY = "trajectoryMatchDebugEnabled"
AirdropTrajectoryService.MAX_TRACE_EVENTS = 30

local function NormalizeTraceText(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function NormalizeTraceNumber(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" then
        return nil
    end
    return numberValue
end

local function BuildPredictionMessage(targetMapData, route)
    if type(targetMapData) ~= "table" or type(route) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local endX = FormatCoordinatePercent(route.endX or 0)
    local endY = FormatCoordinatePercent(route.endY or 0)
    local format = (L and L["TrajectoryPredictionMatched"]) or "【%s】已匹配空投轨迹，预测落点坐标：%s, %s"
    return string.format(format, mapName, endX, endY)
end

local function BuildWaypointMarkedMessage(targetMapData, route)
    if type(targetMapData) ~= "table" or type(route) ~= "table" then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local endX = FormatCoordinatePercent(route.endX or 0)
    local endY = FormatCoordinatePercent(route.endY or 0)
    local format = (L and L["TrajectoryPredictionWaypointSet"]) or "【%s】已在地图上标记预测落点：%s, %s"
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

function AirdropTrajectoryService:Initialize()
    self.isInitialized = true
    self.activeObservationByMap = self.activeObservationByMap or {}
    self.pendingShoutStartByMap = self.pendingShoutStartByMap or {}
    self.recentFinalizedObservationByMap = self.recentFinalizedObservationByMap or {}
    self.traceEvents = self.traceEvents or {}
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

function AirdropTrajectoryService:IsMatchingDebugEnabled()
    return self:IsPredictionEnabled()
end

function AirdropTrajectoryService:SetMatchingDebugEnabled(enabled)
    return self:SetPredictionEnabled(enabled)
end

function AirdropTrajectoryService:IsPredictionEnabled()
    local uiState = AppSettingsStore and AppSettingsStore.GetUIState and AppSettingsStore:GetUIState() or nil
    if type(uiState) == "table" then
        local explicitValue = uiState[self.PREDICTION_ENABLED_SETTING_KEY]
        if explicitValue ~= nil then
            return explicitValue == true
        end
        return uiState[self.LEGACY_MATCH_DEBUG_SETTING_KEY] == true
    end

    local uiDB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    if uiDB[self.PREDICTION_ENABLED_SETTING_KEY] ~= nil then
        return uiDB[self.PREDICTION_ENABLED_SETTING_KEY] == true
    end
    return uiDB[self.LEGACY_MATCH_DEBUG_SETTING_KEY] == true
end

function AirdropTrajectoryService:SetPredictionEnabled(enabled)
    local normalized = enabled == true
    if AppSettingsStore and AppSettingsStore.GetUIState then
        local uiState = AppSettingsStore:GetUIState()
        uiState[self.PREDICTION_ENABLED_SETTING_KEY] = normalized
        uiState[self.LEGACY_MATCH_DEBUG_SETTING_KEY] = nil
        return normalized
    end

    CRATETRACKERZK_UI_DB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    CRATETRACKERZK_UI_DB[self.PREDICTION_ENABLED_SETTING_KEY] = normalized
    CRATETRACKERZK_UI_DB[self.LEGACY_MATCH_DEBUG_SETTING_KEY] = nil
    return normalized
end

function AirdropTrajectoryService:IsPredictionTestEnabled()
    return self:IsPredictionEnabled()
end

function AirdropTrajectoryService:SetPredictionTestEnabled(enabled)
    return self:SetPredictionEnabled(enabled)
end

function AirdropTrajectoryService:Reset()
    self.activeObservationByMap = {}
    self.pendingShoutStartByMap = {}
    self.recentFinalizedObservationByMap = {}
    self.isInitialized = false
    return true
end

function AirdropTrajectoryService:RememberRecentlyFinalizedObservation(runtimeMapId, objectGUID, currentTime)
    if type(runtimeMapId) ~= "number" then
        return false
    end

    self.recentFinalizedObservationByMap = self.recentFinalizedObservationByMap or {}
    if type(objectGUID) ~= "string" or objectGUID == "" then
        self.recentFinalizedObservationByMap[runtimeMapId] = nil
        return false
    end

    self.recentFinalizedObservationByMap[runtimeMapId] = {
        objectGUID = objectGUID,
        finalizedAt = tonumber(currentTime) or Utils:GetCurrentTimestamp(),
    }
    return true
end

function AirdropTrajectoryService:ShouldSuppressObservationStart(runtimeMapId, objectGUID, currentTime)
    if type(runtimeMapId) ~= "number"
        or type(objectGUID) ~= "string"
        or objectGUID == "" then
        return false
    end

    local recentByMap = self.recentFinalizedObservationByMap
    local recentState = type(recentByMap) == "table" and recentByMap[runtimeMapId] or nil
    if type(recentState) ~= "table" then
        return false
    end

    local finalizedAt = tonumber(recentState.finalizedAt)
    local now = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    local suppressionWindow = math.max(0, tonumber(self.FINALIZED_OBSERVATION_SUPPRESSION_WINDOW) or 120)
    if type(finalizedAt) ~= "number" or (now - finalizedAt) > suppressionWindow then
        recentByMap[runtimeMapId] = nil
        return false
    end

    if recentState.objectGUID ~= objectGUID then
        return false
    end

    return true
end

function AirdropTrajectoryService:RecordTraceEvent(event)
    if type(event) ~= "table" then
        return false
    end

    self.traceEvents = self.traceEvents or {}
    local entry = {
        recordedAt = NormalizeTraceNumber(event.recordedAt) or Utils:GetCurrentTimestamp(),
        eventType = NormalizeTraceText(event.eventType) or "unknown",
        mapName = NormalizeTraceText(event.mapName),
        mapID = NormalizeTraceNumber(event.mapID),
        runtimeMapId = NormalizeTraceNumber(event.runtimeMapId),
        vignetteID = NormalizeTraceNumber(event.vignetteID),
        vignetteGUID = NormalizeTraceText(event.vignetteGUID),
        objectGUID = NormalizeTraceText(event.objectGUID),
        sourceObjectGUID = NormalizeTraceText(event.sourceObjectGUID),
        positionX = NormalizeTraceNumber(event.positionX),
        positionY = NormalizeTraceNumber(event.positionY),
        sampleCount = NormalizeTraceNumber(event.sampleCount),
        routeKey = NormalizeTraceText(event.routeKey),
        startSource = NormalizeTraceText(event.startSource),
        endSource = NormalizeTraceText(event.endSource),
        startConfirmed = event.startConfirmed == nil and nil or event.startConfirmed == true,
        endConfirmed = event.endConfirmed == nil and nil or event.endConfirmed == true,
        note = NormalizeTraceText(event.note),
    }

    self.traceEvents[#self.traceEvents + 1] = entry

    local maxCount = math.max(1, math.floor(tonumber(self.MAX_TRACE_EVENTS) or 30))
    while #self.traceEvents > maxCount do
        table.remove(self.traceEvents, 1)
    end
    return true
end

function AirdropTrajectoryService:GetRecentTraceEvents(maxAgeSeconds)
    local result = {}
    local now = Utils:GetCurrentTimestamp()
    local maxAge = tonumber(maxAgeSeconds) or 3600

    for _, entry in ipairs(self.traceEvents or {}) do
        local recordedAt = tonumber(entry and entry.recordedAt)
        if type(recordedAt) == "number" and (now - recordedAt) <= maxAge then
            result[#result + 1] = entry
        end
    end

    return result
end

function AirdropTrajectoryService:HandleAirdropShout(targetMapData, currentTime, iconResult)
    if type(targetMapData) ~= "table" or type(targetMapData.id) ~= "number" then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(targetMapData) or tostring(targetMapData.mapID or "")
    local shoutState = {
        timestamp = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    }
    if type(iconResult) == "table" and iconResult.detected == true then
        shoutState.objectGUID = type(iconResult.objectGUID) == "string" and iconResult.objectGUID or nil
        shoutState.positionX = tonumber(iconResult.positionX)
        shoutState.positionY = tonumber(iconResult.positionY)
    end

    if self.RecordTraceEvent then
        self:RecordTraceEvent({
            recordedAt = shoutState.timestamp,
            eventType = type(iconResult) == "table" and iconResult.detected == true and "start_capture" or "start_capture_pending",
            mapName = mapName,
            mapID = targetMapData.mapID,
            runtimeMapId = targetMapData.id,
            vignetteID = iconResult and iconResult.vignetteID or nil,
            vignetteGUID = iconResult and iconResult.vignetteGUID or nil,
            objectGUID = shoutState.objectGUID,
            positionX = shoutState.positionX,
            positionY = shoutState.positionY,
            note = type(iconResult) == "table" and iconResult.detected == true and "shout_icon_captured" or "shout_icon_missing",
        })
    end

    self.pendingShoutStartByMap = self.pendingShoutStartByMap or {}
    self.pendingShoutStartByMap[targetMapData.id] = shoutState

    local activeState = self.activeObservationByMap and self.activeObservationByMap[targetMapData.id] or nil
    if type(activeState) == "table"
        and AirdropTrajectorySamplingService
        and AirdropTrajectorySamplingService.ApplyConfirmedStartFromShout then
        local applied, reason = AirdropTrajectorySamplingService:ApplyConfirmedStartFromShout(activeState, shoutState)
        if applied == true and self.pendingShoutStartByMap then
            self.pendingShoutStartByMap[targetMapData.id] = nil
        end
        if self.RecordTraceEvent then
            self:RecordTraceEvent({
                recordedAt = shoutState.timestamp,
                eventType = applied == true and "start_applied" or "start_apply_rejected",
                mapName = mapName,
                mapID = targetMapData.mapID,
                runtimeMapId = targetMapData.id,
                objectGUID = shoutState.objectGUID,
                sourceObjectGUID = activeState.objectGUID,
                positionX = shoutState.positionX,
                positionY = shoutState.positionY,
                sampleCount = activeState.sampleCount,
                startSource = activeState.startSource,
                startConfirmed = activeState.startConfirmed == true,
                note = reason,
            })
        end
    end
    return true
end

function AirdropTrajectoryService:NotifyPrediction(targetMapData, route)
    local predictionEnabled = self.IsPredictionEnabled and self:IsPredictionEnabled() == true
    if predictionEnabled ~= true then
        return true
    end

    local message = BuildPredictionMessage(targetMapData, route)
    local waypointSet = SetPredictionWaypoint(targetMapData, route)
    local sentMessage = false

    if type(message) == "string" and message ~= "" and NotificationOutputService and NotificationOutputService.SendLocalMessage then
        sentMessage = NotificationOutputService:SendLocalMessage(message) == true
        if waypointSet == true then
            local waypointMessage = BuildWaypointMarkedMessage(targetMapData, route)
            if type(waypointMessage) == "string" and waypointMessage ~= "" then
                NotificationOutputService:SendLocalMessage(waypointMessage)
            end
        end
        return sentMessage == true or waypointSet == true
    end
    if type(message) == "string" and message ~= "" and Logger and Logger.Info then
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
    if self.IsPredictionEnabled and self:IsPredictionEnabled() ~= true then
        return false
    end
    if AirdropTrajectoryMatchingService and AirdropTrajectoryMatchingService.TryMatchPrediction then
        return AirdropTrajectoryMatchingService:TryMatchPrediction(self, targetMapData, state, iconResult)
    end
    return false
end

function AirdropTrajectoryService:FinalizeObservation(runtimeMapId, currentTime)
    if AirdropTrajectorySamplingService and AirdropTrajectorySamplingService.FinalizeObservation then
        return AirdropTrajectorySamplingService:FinalizeObservation(self, runtimeMapId, currentTime)
    end
    return false
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
    if AirdropTrajectorySamplingService and AirdropTrajectorySamplingService.HandleNoDetection then
        return AirdropTrajectorySamplingService:HandleNoDetection(self, targetMapData, currentTime)
    end
    return false
end

function AirdropTrajectoryService:HandleDetectedIcon(targetMapData, iconResult, currentTime)
    if AirdropTrajectorySamplingService and AirdropTrajectorySamplingService.HandleDetectedIcon then
        return AirdropTrajectorySamplingService:HandleDetectedIcon(self, targetMapData, iconResult, currentTime)
    end
    return false
end

function AirdropTrajectoryService:HandleDetectedCrate(targetMapData, iconResult, currentTime)
    if AirdropTrajectorySamplingService and AirdropTrajectorySamplingService.HandleDetectedCrate then
        return AirdropTrajectorySamplingService:HandleDetectedCrate(self, targetMapData, iconResult, currentTime)
    end
    return false
end

return AirdropTrajectoryService
