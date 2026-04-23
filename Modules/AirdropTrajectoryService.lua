-- AirdropTrajectoryService.lua - 空投轨迹实时记录与落点预测

local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")
local AirdropTrajectoryMatchingService = BuildEnv("AirdropTrajectoryMatchingService")
local AirdropTrajectorySamplingService = BuildEnv("AirdropTrajectorySamplingService")
local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
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
AirdropTrajectoryService.MATCH_RECENT_MOTION_WINDOW = 1.25
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_START_TOLERANCE = 0.03
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_DIRECTION_DOT = 0.985
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_LINE_TOLERANCE = 0.02
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_EXTENSION_MARGIN = 0.02
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_SEPARATION_MIN = 0.012
AirdropTrajectoryService.MATCH_ROUTE_FAMILY_DISTANCE_MARGIN = 0.003
AirdropTrajectoryService.STATIONARY_TOLERANCE = 0.006
AirdropTrajectoryService.MOVE_CONFIRM_DISTANCE = 0.0045
AirdropTrajectoryService.END_PHASE_RADIUS = 0.015
AirdropTrajectoryService.END_PHASE_WINDOW_SAMPLES = 5
AirdropTrajectoryService.END_PHASE_MIN_SAMPLES = 4
AirdropTrajectoryService.MISSING_FINALIZE_DELAY = 2.2
AirdropTrajectoryService.PARTIAL_MIN_OBSERVATION_DISTANCE = 0.015
AirdropTrajectoryService.PREDICTION_VERIFICATION_TOLERANCE = 0.015
AirdropTrajectoryService.SHOUT_START_CONFIRM_WINDOW = 60
AirdropTrajectoryService.TRACE_DEBUG_SETTING_KEY = "trajectoryTraceDebugEnabled"
AirdropTrajectoryService.PREDICTION_TEST_SETTING_KEY = "trajectoryPredictionTestEnabled"

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

function AirdropTrajectoryService:IsPredictionTestEnabled()
    if AppSettingsStore and AppSettingsStore.GetBoolean then
        return AppSettingsStore:GetBoolean(self.PREDICTION_TEST_SETTING_KEY, false)
    end
    local uiDB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    return uiDB[self.PREDICTION_TEST_SETTING_KEY] == true
end

function AirdropTrajectoryService:SetPredictionTestEnabled(enabled)
    local normalized = enabled == true
    if AppSettingsStore and AppSettingsStore.SetBoolean then
        AppSettingsStore:SetBoolean(self.PREDICTION_TEST_SETTING_KEY, normalized)
        return normalized
    end
    CRATETRACKERZK_UI_DB = type(CRATETRACKERZK_UI_DB) == "table" and CRATETRACKERZK_UI_DB or {}
    CRATETRACKERZK_UI_DB[self.PREDICTION_TEST_SETTING_KEY] = normalized
    return normalized
end

function AirdropTrajectoryService:Reset()
    self.activeObservationByMap = {}
    self.pendingShoutStartByMap = {}
    self.isInitialized = false
    return true
end

function AirdropTrajectoryService:HandleAirdropShout(targetMapData, currentTime, iconResult)
    if type(targetMapData) ~= "table" or type(targetMapData.id) ~= "number" then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end

    local shoutState = {
        timestamp = tonumber(currentTime) or Utils:GetCurrentTimestamp()
    }
    if type(iconResult) == "table" and iconResult.detected == true then
        shoutState.objectGUID = type(iconResult.objectGUID) == "string" and iconResult.objectGUID or nil
        shoutState.positionX = tonumber(iconResult.positionX)
        shoutState.positionY = tonumber(iconResult.positionY)
    end

    self.pendingShoutStartByMap = self.pendingShoutStartByMap or {}
    self.pendingShoutStartByMap[targetMapData.id] = shoutState

    local activeState = self.activeObservationByMap and self.activeObservationByMap[targetMapData.id] or nil
    if type(activeState) == "table"
        and AirdropTrajectorySamplingService
        and AirdropTrajectorySamplingService.ApplyConfirmedStartFromShout then
        AirdropTrajectorySamplingService:ApplyConfirmedStartFromShout(activeState, shoutState)
    end
    return true
end

function AirdropTrajectoryService:NotifyPrediction(targetMapData, route)
    local predictionTestEnabled = self.IsPredictionTestEnabled and self:IsPredictionTestEnabled() == true
    if predictionTestEnabled ~= true then
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

return AirdropTrajectoryService
