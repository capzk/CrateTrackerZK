-- AirdropTrajectoryStore.lua - 空投运行轨迹持久化存储与去重合并

local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AppContext = BuildEnv("AppContext")
local ClearLegacyPersistentBucket

AirdropTrajectoryStore.COORDINATE_SCALE = 1000
AirdropTrajectoryStore.MIN_ROUTE_LENGTH = 0.02
AirdropTrajectoryStore.MAX_ROUTES_PER_MAP = 200
AirdropTrajectoryStore.DB_SCHEMA_VERSION = 2

local function EnsureTrajectoryPersistentState()
    if type(CRATETRACKERZK_TRAJECTORY_DB) ~= "table"
        or tonumber(CRATETRACKERZK_TRAJECTORY_DB.schemaVersion) ~= AirdropTrajectoryStore.DB_SCHEMA_VERSION then
        CRATETRACKERZK_TRAJECTORY_DB = {
            schemaVersion = AirdropTrajectoryStore.DB_SCHEMA_VERSION,
            meta = {
                storageKind = "independent",
                lastResetAt = Utils:GetCurrentTimestamp(),
            },
            maps = {},
        }
    end
    if type(CRATETRACKERZK_TRAJECTORY_DB.meta) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB.meta = {
            storageKind = "independent",
        }
    end
    CRATETRACKERZK_TRAJECTORY_DB.schemaVersion = AirdropTrajectoryStore.DB_SCHEMA_VERSION
    CRATETRACKERZK_TRAJECTORY_DB.meta.storageKind = "independent"
    if type(CRATETRACKERZK_TRAJECTORY_DB.maps) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB.maps = {}
    end
    ClearLegacyPersistentBucket()
    return CRATETRACKERZK_TRAJECTORY_DB
end

local function EnsurePersistentBucket()
    return EnsureTrajectoryPersistentState().maps
end

ClearLegacyPersistentBucket = function()
    local db = AppContext and AppContext.EnsurePersistentState and AppContext:EnsurePersistentState() or nil
    if type(db) == "table" then
        db.trajectoryData = nil
    end
    return true
end

local function NormalizeCoordinate(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" then
        return nil
    end
    if numberValue < 0 then
        numberValue = 0
    elseif numberValue > 1 then
        numberValue = 1
    end
    local scale = AirdropTrajectoryStore.COORDINATE_SCALE or 10000
    return math.floor((numberValue * scale) + 0.5) / scale
end

local function QuantizeCoordinate(value)
    local normalized = NormalizeCoordinate(value)
    if normalized == nil then
        return nil
    end
    local scale = AirdropTrajectoryStore.COORDINATE_SCALE or 10000
    return math.floor((normalized * scale) + 0.5)
end

local function ComputeDistance(x1, y1, x2, y2)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeDistance then
        return AirdropTrajectoryGeometryService:ComputeDistance(x1, y1, x2, y2)
    end
    local dx = (tonumber(x2) or 0) - (tonumber(x1) or 0)
    local dy = (tonumber(y2) or 0) - (tonumber(y1) or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function ComputeRouteVector(route)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ComputeRouteVector then
        return AirdropTrajectoryGeometryService:ComputeRouteVector(route)
    end
    return 0, 0, 0
end

local function BuildRouteKey(route)
    local startX = QuantizeCoordinate(route and route.startX)
    local startY = QuantizeCoordinate(route and route.startY)
    local endX = QuantizeCoordinate(route and route.endX)
    local endY = QuantizeCoordinate(route and route.endY)
    if startX == nil or startY == nil or endX == nil or endY == nil then
        return nil
    end
    return table.concat({
        tostring(startX),
        tostring(startY),
        tostring(endX),
        tostring(endY),
    }, ":")
end

local function CopyRouteInto(outRoute, route)
    if type(outRoute) ~= "table" or type(route) ~= "table" then
        return nil
    end
    outRoute.routeKey = route.routeKey
    outRoute.mapID = route.mapID
    outRoute.startX = route.startX
    outRoute.startY = route.startY
    outRoute.endX = route.endX
    outRoute.endY = route.endY
    outRoute.observationCount = route.observationCount
    outRoute.sampleCount = route.sampleCount
    outRoute.createdAt = route.createdAt
    outRoute.updatedAt = route.updatedAt
    outRoute.source = route.source
    outRoute.continuityConfirmed = route.continuityConfirmed == true
    outRoute.startSource = route.startSource
    outRoute.endSource = route.endSource
    outRoute.lastEventObjectGUID = route.lastEventObjectGUID
    outRoute.lastEventStartedAt = route.lastEventStartedAt
    outRoute.startConfirmed = route.startConfirmed == true
    outRoute.endConfirmed = route.endConfirmed == true
    outRoute.verificationCount = route.verificationCount
    outRoute.verifiedPredictionCount = route.verifiedPredictionCount
    outRoute.lastPredictionVerified = route.lastPredictionVerified == true
    outRoute.confidenceScore = route.confidenceScore
    return outRoute
end

local function CreateRouteRecord(route)
    local outRoute = {}
    return CopyRouteInto(outRoute, route)
end

local IsReliableRoute
local FinalizeRouteReliability

local function NormalizeRouteRecord(routeState, source, currentTime)
    if type(routeState) ~= "table" then
        return nil
    end

    local mapID = tonumber(routeState.mapID)
    local startX = NormalizeCoordinate(routeState.startX)
    local startY = NormalizeCoordinate(routeState.startY)
    local endX = NormalizeCoordinate(routeState.endX)
    local endY = NormalizeCoordinate(routeState.endY)
    if not mapID or not startX or not startY or not endX or not endY then
        return nil
    end

    local now = math.floor(tonumber(currentTime) or Utils:GetCurrentTimestamp())
    local createdAt = math.floor(tonumber(routeState.createdAt) or tonumber(routeState.timestamp) or now)
    local updatedAt = math.floor(tonumber(routeState.updatedAt) or tonumber(routeState.timestamp) or now)
    if createdAt > updatedAt then
        createdAt = updatedAt
    end

    local normalized = {
        mapID = mapID,
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        observationCount = math.max(1, math.floor(tonumber(routeState.observationCount) or 1)),
        sampleCount = math.max(2, math.floor(tonumber(routeState.sampleCount) or 2)),
        createdAt = createdAt,
        updatedAt = updatedAt,
        source = source == "local" and "local" or "shared",
        continuityConfirmed = routeState.continuityConfirmed == true,
        startSource = type(routeState.startSource) == "string" and routeState.startSource or nil,
        endSource = type(routeState.endSource) == "string" and routeState.endSource or nil,
        lastEventObjectGUID = type(routeState.lastEventObjectGUID) == "string"
            and routeState.lastEventObjectGUID ~= ""
            and routeState.lastEventObjectGUID
            or (type(routeState.eventObjectGUID) == "string" and routeState.eventObjectGUID ~= "" and routeState.eventObjectGUID or nil),
        lastEventStartedAt = math.floor(
            tonumber(routeState.lastEventStartedAt)
                or tonumber(routeState.eventStartedAt)
                or createdAt
        ),
        startConfirmed = routeState.startConfirmed == true,
        endConfirmed = routeState.endConfirmed == true,
        verificationCount = math.max(0, math.floor(tonumber(routeState.verificationCount) or 0)),
        verifiedPredictionCount = math.max(0, math.floor(tonumber(routeState.verifiedPredictionCount) or 0)),
        lastPredictionVerified = routeState.lastPredictionVerified == true,
    }
    normalized.routeKey = BuildRouteKey(normalized)
    if type(normalized.routeKey) ~= "string" or normalized.routeKey == "" then
        return nil
    end
    if normalized.verifiedPredictionCount > normalized.verificationCount then
        normalized.verificationCount = normalized.verifiedPredictionCount
    end
    return FinalizeRouteReliability(normalized)
end

IsReliableRoute = function(route)
    return type(route) == "table"
        and route.startConfirmed == true
        and route.endConfirmed == true
        and route.startSource == "npc_shout"
        and route.endSource == "crate_vignette"
end

FinalizeRouteReliability = function(route)
    if type(route) ~= "table" then
        return nil
    end

    route.verificationCount = math.max(0, math.floor(tonumber(route.verificationCount) or 0))
    route.verifiedPredictionCount = math.max(0, math.floor(tonumber(route.verifiedPredictionCount) or 0))
    if route.verifiedPredictionCount > route.verificationCount then
        route.verificationCount = route.verifiedPredictionCount
    end
    route.lastPredictionVerified = route.lastPredictionVerified == true

    local confidence = 0
    if IsReliableRoute(route) then
        confidence = 60
        confidence = confidence + math.min(15, math.floor((tonumber(route.sampleCount) or 0) / 4))
        confidence = confidence + math.min(15, math.floor((tonumber(route.observationCount) or 0) * 3))
        if route.verificationCount > 0 then
            local hitRate = route.verifiedPredictionCount / route.verificationCount
            confidence = confidence + math.floor(hitRate * 10)
            local missCount = math.max(0, route.verificationCount - route.verifiedPredictionCount)
            confidence = confidence - math.min(10, missCount * 2)
        else
            confidence = confidence + 5
        end
        if route.lastPredictionVerified == true then
            confidence = confidence + 5
        end
    end

    if confidence < 0 then
        confidence = 0
    elseif confidence > 100 then
        confidence = 100
    end
    route.confidenceScore = confidence
    return route
end

local function IsRouteRecordValid(route)
    if type(route) ~= "table" then
        return false
    end
    if type(route.mapID) ~= "number" then
        return false
    end
    if type(route.startX) ~= "number"
        or type(route.startY) ~= "number"
        or type(route.endX) ~= "number"
        or type(route.endY) ~= "number" then
        return false
    end
    local _, _, length = ComputeRouteVector(route)
    if type(length) ~= "number" then
        return false
    end

    return length >= (AirdropTrajectoryStore.MIN_ROUTE_LENGTH or 0.02)
end

local function HasRouteChanged(existing, candidate)
    if type(existing) ~= "table" then
        return true
    end
    if type(candidate) ~= "table" then
        return false
    end
    return existing.routeKey ~= candidate.routeKey
        or existing.startX ~= candidate.startX
        or existing.startY ~= candidate.startY
        or existing.endX ~= candidate.endX
        or existing.endY ~= candidate.endY
        or existing.startSource ~= candidate.startSource
        or existing.endSource ~= candidate.endSource
        or (existing.startConfirmed == true) ~= (candidate.startConfirmed == true)
        or (existing.endConfirmed == true) ~= (candidate.endConfirmed == true)
        or existing.observationCount ~= candidate.observationCount
        or existing.sampleCount ~= candidate.sampleCount
        or existing.updatedAt ~= candidate.updatedAt
        or existing.source ~= candidate.source
        or existing.lastEventObjectGUID ~= candidate.lastEventObjectGUID
        or existing.lastEventStartedAt ~= candidate.lastEventStartedAt
        or (tonumber(existing.verificationCount) or 0) ~= (tonumber(candidate.verificationCount) or 0)
        or (tonumber(existing.verifiedPredictionCount) or 0) ~= (tonumber(candidate.verifiedPredictionCount) or 0)
        or (existing.lastPredictionVerified == true) ~= (candidate.lastPredictionVerified == true)
end

local function MergeDuplicateArtifact(existing, candidate)
    local merged = CreateRouteRecord(existing)
    if type(merged) ~= "table" then
        return CreateRouteRecord(candidate)
    end

    merged.startConfirmed = existing.startConfirmed == true or candidate.startConfirmed == true
    merged.endConfirmed = existing.endConfirmed == true or candidate.endConfirmed == true
    merged.sampleCount = math.max(tonumber(existing.sampleCount) or 0, tonumber(candidate.sampleCount) or 0)
    merged.observationCount = math.max(tonumber(existing.observationCount) or 1, tonumber(candidate.observationCount) or 1)
    merged.createdAt = math.min(
        tonumber(existing.createdAt) or tonumber(existing.updatedAt) or Utils:GetCurrentTimestamp(),
        tonumber(candidate.createdAt) or tonumber(candidate.updatedAt) or Utils:GetCurrentTimestamp()
    )
    merged.updatedAt = math.max(
        tonumber(existing.updatedAt) or 0,
        tonumber(candidate.updatedAt) or 0
    )
    merged.continuityConfirmed = existing.continuityConfirmed == true or candidate.continuityConfirmed == true
    if merged.source ~= "local" and candidate.source == "local" then
        merged.source = "local"
    end
    merged.startSource = candidate.startSource or existing.startSource
    merged.endSource = candidate.endSource or existing.endSource
    if type(candidate.lastEventObjectGUID) == "string" and candidate.lastEventObjectGUID ~= "" then
        merged.lastEventObjectGUID = candidate.lastEventObjectGUID
    end
    merged.lastEventStartedAt = math.max(
        tonumber(existing.lastEventStartedAt) or tonumber(existing.createdAt) or 0,
        tonumber(candidate.lastEventStartedAt) or tonumber(candidate.createdAt) or 0
    )
    merged.verificationCount = math.max(
        math.max(0, tonumber(existing.verificationCount) or 0),
        math.max(0, tonumber(candidate.verificationCount) or 0)
    )
    merged.verifiedPredictionCount = math.max(
        math.max(0, tonumber(existing.verifiedPredictionCount) or 0),
        math.max(0, tonumber(candidate.verifiedPredictionCount) or 0)
    )
    merged.lastPredictionVerified = candidate.lastPredictionVerified == true or existing.lastPredictionVerified == true
    return FinalizeRouteReliability(merged)
end

local function EnsureMapBucket(self, mapID)
    self.routesByMap = self.routesByMap or {}
    self.routesByMap[mapID] = self.routesByMap[mapID] or {}
    return self.routesByMap[mapID]
end

local function SaveMapBucket(self, mapID)
    if type(mapID) ~= "number" then
        return false
    end

    local persistentBucket = EnsurePersistentBucket()
    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" or next(runtimeBucket) == nil then
        persistentBucket[mapID] = nil
        return true
    end

    persistentBucket[mapID] = persistentBucket[mapID] or {}
    persistentBucket[mapID].routes = persistentBucket[mapID].routes or {}

    local savedRoutes = {}
    for routeKey, route in pairs(runtimeBucket) do
        if type(routeKey) == "string" and type(route) == "table" then
            savedRoutes[routeKey] = {
                mapID = mapID,
                startX = route.startX,
                startY = route.startY,
                endX = route.endX,
                endY = route.endY,
                observationCount = route.observationCount,
                sampleCount = route.sampleCount,
                createdAt = route.createdAt,
                updatedAt = route.updatedAt,
                source = route.source,
                continuityConfirmed = route.continuityConfirmed == true,
                startSource = route.startSource,
                endSource = route.endSource,
                lastEventObjectGUID = route.lastEventObjectGUID,
                lastEventStartedAt = route.lastEventStartedAt,
                startConfirmed = route.startConfirmed == true,
                endConfirmed = route.endConfirmed == true,
                verificationCount = route.verificationCount,
                verifiedPredictionCount = route.verifiedPredictionCount,
                lastPredictionVerified = route.lastPredictionVerified == true,
            }
        end
    end
    persistentBucket[mapID].routes = savedRoutes
    return true
end

local function PruneMapBucket(self, mapID)
    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" then
        return
    end

    local maxRoutes = tonumber(self.MAX_ROUTES_PER_MAP) or 12
    local routes = {}
    for routeKey, route in pairs(runtimeBucket) do
        routes[#routes + 1] = {
            routeKey = routeKey,
            updatedAt = type(route) == "table" and tonumber(route.updatedAt) or 0,
            observationCount = type(route) == "table" and tonumber(route.observationCount) or 0,
        }
    end

    if #routes <= maxRoutes then
        return
    end

    table.sort(routes, function(left, right)
        if left.updatedAt == right.updatedAt then
            if left.observationCount == right.observationCount then
                return left.routeKey < right.routeKey
            end
            return left.observationCount > right.observationCount
        end
        return left.updatedAt > right.updatedAt
    end)

    for index = maxRoutes + 1, #routes do
        runtimeBucket[routes[index].routeKey] = nil
    end
end

local function LoadPersistentRoutesIntoRuntime(self, sourceBucket)
    if type(sourceBucket) ~= "table" then
        return 0
    end

    local loadedCount = 0
    for rawMapID, savedMapData in pairs(sourceBucket) do
        local mapID = tonumber(rawMapID)
        local savedRoutes = type(savedMapData) == "table" and savedMapData.routes or nil
        if mapID and type(savedRoutes) == "table" then
            local runtimeBucket = EnsureMapBucket(self, mapID)
            for _, savedRoute in pairs(savedRoutes) do
                local routeState = savedRoute
                if type(savedRoute) == "table" and type(savedRoute.mapID) ~= "number" then
                    routeState = {}
                    for key, value in pairs(savedRoute) do
                        routeState[key] = value
                    end
                    routeState.mapID = mapID
                end
                local normalized = NormalizeRouteRecord(routeState, savedRoute and savedRoute.source, savedRoute and savedRoute.updatedAt)
                if IsRouteRecordValid(normalized) == true
                    and IsReliableRoute(normalized) == true then
                    runtimeBucket[normalized.routeKey] = normalized
                    loadedCount = loadedCount + 1
                end
            end
            PruneMapBucket(self, mapID)
        end
    end
    return loadedCount
end

function AirdropTrajectoryStore:Initialize()
    self.routesByMap = {}

    local trajectoryState = EnsureTrajectoryPersistentState()
    local persistentBucket = trajectoryState.maps or {}
    LoadPersistentRoutesIntoRuntime(self, persistentBucket)

    return true
end

function AirdropTrajectoryStore:IsPredictionReady(route)
    return IsReliableRoute(route) == true
end

function AirdropTrajectoryStore:GetRouteQualityLabel(route)
    if type(route) ~= "table" then
        return "unknown"
    end
    if IsReliableRoute(route) ~= true then
        return "invalid"
    end
    if (tonumber(route.verifiedPredictionCount) or 0) > 0 then
        return "verified"
    end
    if route.startConfirmed == true and route.endConfirmed == true then
        return "complete"
    end
    return "unknown"
end

function AirdropTrajectoryStore:IsShareEligible(route)
    if IsRouteRecordValid(route) ~= true then
        return false
    end
    if IsReliableRoute(route) ~= true then
        return false
    end
    if route.continuityConfirmed ~= true then
        return false
    end
    return true
end

function AirdropTrajectoryStore:GetPredictionConfidence(route)
    return type(route) == "table" and math.max(0, math.floor(tonumber(route.confidenceScore) or 0)) or 0
end

function AirdropTrajectoryStore:UpdatePredictionVerification(mapID, routeKey, isAccurate)
    if type(mapID) ~= "number" or type(routeKey) ~= "string" or routeKey == "" then
        return false, nil
    end

    local runtimeBucket = EnsureMapBucket(self, mapID)
    local route = runtimeBucket[routeKey]
    if type(route) ~= "table" then
        return false, nil
    end

    route.verificationCount = math.max(0, tonumber(route.verificationCount) or 0) + 1
    if isAccurate == true then
        route.verifiedPredictionCount = math.max(0, tonumber(route.verifiedPredictionCount) or 0) + 1
    end
    route.lastPredictionVerified = isAccurate == true
    FinalizeRouteReliability(route)
    SaveMapBucket(self, mapID)
    return true, route
end

function AirdropTrajectoryStore:Reset()
    self.routesByMap = {}
    return true
end

function AirdropTrajectoryStore:IsUsingIndependentPersistentStore()
    local trajectoryState = EnsureTrajectoryPersistentState()
    return type(trajectoryState) == "table"
        and type(trajectoryState.maps) == "table"
        and type(trajectoryState.meta) == "table"
        and trajectoryState.meta.storageKind == "independent"
end

function AirdropTrajectoryStore:ClearPersistentData()
    CRATETRACKERZK_TRAJECTORY_DB = nil
    EnsureTrajectoryPersistentState()
    self.routesByMap = {}
    return true
end

function AirdropTrajectoryStore:GetRoutes(mapID)
    if type(mapID) ~= "number" then
        return {}
    end

    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" then
        return {}
    end

    local routes = {}
    for _, route in pairs(runtimeBucket) do
        routes[#routes + 1] = route
    end
    table.sort(routes, function(left, right)
        local leftUpdatedAt = tonumber(left and left.updatedAt) or 0
        local rightUpdatedAt = tonumber(right and right.updatedAt) or 0
        if leftUpdatedAt == rightUpdatedAt then
            return (left.routeKey or "") < (right.routeKey or "")
        end
        return leftUpdatedAt > rightUpdatedAt
    end)
    return routes
end

function AirdropTrajectoryStore:AppendRoutesTo(outRoutes)
    if type(outRoutes) ~= "table" then
        outRoutes = {}
    end

    local mapIDs = {}
    for mapID in pairs(self.routesByMap or {}) do
        mapIDs[#mapIDs + 1] = mapID
    end
    table.sort(mapIDs)

    for _, mapID in ipairs(mapIDs) do
        for _, route in ipairs(self:GetRoutes(mapID)) do
            outRoutes[#outRoutes + 1] = CreateRouteRecord(route)
        end
    end
    return outRoutes
end

function AirdropTrajectoryStore:AppendShareableRoutesTo(outRoutes)
    if type(outRoutes) ~= "table" then
        outRoutes = {}
    end

    for _, route in ipairs(self:AppendRoutesTo({})) do
        if self:IsShareEligible(route) == true then
            outRoutes[#outRoutes + 1] = route
        end
    end
    return outRoutes
end

function AirdropTrajectoryStore:UpsertRoute(mapID, routeState, source, currentTime)
    local normalized = NormalizeRouteRecord(routeState, source, currentTime)
    if IsRouteRecordValid(normalized) ~= true
        or type(normalized) ~= "table"
        or IsReliableRoute(normalized) ~= true then
        return false, nil, {
            status = "rejected",
            reason = "invalid_route",
        }
    end

    local resolvedMapID = tonumber(normalized.mapID)
    local runtimeBucket = EnsureMapBucket(self, resolvedMapID)
    local matchedKey = normalized.routeKey
    local matchedRoute = runtimeBucket[matchedKey]

    if matchedRoute then
        local merged = MergeDuplicateArtifact(matchedRoute, normalized)
        if HasRouteChanged(matchedRoute, merged) ~= true then
            return false, matchedRoute, {
                status = "unchanged",
                reason = "matched_identical_route",
                inputRouteKey = normalized.routeKey,
                matchedRouteKey = matchedKey,
                storedRouteKey = matchedRoute.routeKey,
            }
        end

        runtimeBucket[matchedKey] = nil
        merged.routeKey = matchedKey
        runtimeBucket[matchedKey] = merged
        PruneMapBucket(self, resolvedMapID)
        SaveMapBucket(self, resolvedMapID)
        return true, runtimeBucket[matchedKey], {
            status = "updated_identical_route",
            inputRouteKey = normalized.routeKey,
            matchedRouteKey = matchedKey,
            storedRouteKey = matchedKey,
        }
    end

    runtimeBucket[normalized.routeKey] = normalized
    PruneMapBucket(self, resolvedMapID)
    SaveMapBucket(self, resolvedMapID)
    return true, runtimeBucket[normalized.routeKey], {
        status = "created_new_route",
        inputRouteKey = normalized.routeKey,
        storedRouteKey = normalized.routeKey,
    }
end

return AirdropTrajectoryStore
