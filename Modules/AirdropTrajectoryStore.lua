-- AirdropTrajectoryStore.lua - 空投运行轨迹持久化存储与去重合并

local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AppContext = BuildEnv("AppContext")

AirdropTrajectoryStore.COORDINATE_SCALE = 100
AirdropTrajectoryStore.MIN_ROUTE_LENGTH = 0.02
AirdropTrajectoryStore.PARTIAL_MIN_ROUTE_LENGTH = 0.015
AirdropTrajectoryStore.ROUTE_LINE_TOLERANCE = 0.018
AirdropTrajectoryStore.MIN_DIRECTION_DOT = 0.94
AirdropTrajectoryStore.MAX_ROUTES_PER_MAP = 12
AirdropTrajectoryStore.MIN_SHARED_ROUTE_SAMPLE_COUNT = 8
AirdropTrajectoryStore.DB_SCHEMA_VERSION = 1

local function HasStoredRoutes(bucket)
    if type(bucket) ~= "table" then
        return false
    end
    for _, savedMapData in pairs(bucket) do
        if type(savedMapData) == "table"
            and type(savedMapData.routes) == "table"
            and next(savedMapData.routes) ~= nil then
            return true
        end
    end
    return false
end

local function EnsureTrajectoryPersistentState()
    if type(CRATETRACKERZK_TRAJECTORY_DB) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB = {}
    end
    if type(CRATETRACKERZK_TRAJECTORY_DB.meta) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB.meta = {}
    end
    CRATETRACKERZK_TRAJECTORY_DB.schemaVersion = AirdropTrajectoryStore.DB_SCHEMA_VERSION
    CRATETRACKERZK_TRAJECTORY_DB.meta.storageKind = "independent"
    if type(CRATETRACKERZK_TRAJECTORY_DB.maps) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB.maps = {}
    end

    local legacyRootMaps = {}
    for rawKey, value in pairs(CRATETRACKERZK_TRAJECTORY_DB) do
        local mapID = tonumber(rawKey)
        if mapID
            and type(value) == "table"
            and type(value.routes) == "table" then
            legacyRootMaps[#legacyRootMaps + 1] = {
                mapID = mapID,
                rawKey = rawKey,
                value = value,
            }
        end
    end

    for _, entry in ipairs(legacyRootMaps) do
        if type(CRATETRACKERZK_TRAJECTORY_DB.maps[entry.mapID]) ~= "table" then
            CRATETRACKERZK_TRAJECTORY_DB.maps[entry.mapID] = entry.value
        end
        CRATETRACKERZK_TRAJECTORY_DB[entry.rawKey] = nil
    end

    return CRATETRACKERZK_TRAJECTORY_DB
end

local function EnsurePersistentBucket()
    return EnsureTrajectoryPersistentState().maps
end

local function GetLegacyPersistentBucket()
    local db = AppContext and AppContext.EnsurePersistentState and AppContext:EnsurePersistentState() or {}
    if type(db.trajectoryData) ~= "table" then
        return nil
    end
    return db.trajectoryData
end

local function ClearLegacyPersistentBucket()
    local db = AppContext and AppContext.EnsurePersistentState and AppContext:EnsurePersistentState() or nil
    if type(db) ~= "table" then
        return false
    end
    db.trajectoryData = nil
    return true
end

local function ResetIndependentPersistentState()
    CRATETRACKERZK_TRAJECTORY_DB = {
        schemaVersion = AirdropTrajectoryStore.DB_SCHEMA_VERSION,
        meta = {
            storageKind = "independent",
            legacyImportCompleted = true,
            lastResetAt = Utils:GetCurrentTimestamp(),
        },
        maps = {},
    }
    return CRATETRACKERZK_TRAJECTORY_DB
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

local function ProjectPoint(context, x, y)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.ProjectPoint then
        return AirdropTrajectoryGeometryService:ProjectPoint(context, x, y)
    end
    return nil
end

local function DistancePointToLine(context, x, y)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.DistancePointToLine then
        return AirdropTrajectoryGeometryService:DistancePointToLine(context, x, y)
    end
    return math.huge, nil
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
    outRoute.lastEventObjectGUID = route.lastEventObjectGUID
    outRoute.lastEventStartedAt = route.lastEventStartedAt
    outRoute.startConfirmed = route.startConfirmed == true
    outRoute.endConfirmed = route.endConfirmed == true
    return outRoute
end

local function CreateRouteRecord(route)
    local outRoute = {}
    return CopyRouteInto(outRoute, route)
end

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
    }
    normalized.routeKey = BuildRouteKey(normalized)
    if type(normalized.routeKey) ~= "string" or normalized.routeKey == "" then
        return nil
    end
    return normalized
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

    local minimumLength = AirdropTrajectoryStore.MIN_ROUTE_LENGTH or 0.02
    if route.startConfirmed == true or route.endConfirmed == true then
        minimumLength = math.min(minimumLength, AirdropTrajectoryStore.PARTIAL_MIN_ROUTE_LENGTH or 0.015)
    end
    return length >= minimumLength
end

local function SelectReferenceRoute(existing, candidate)
    local _, _, existingLength = ComputeRouteVector(existing)
    local _, _, candidateLength = ComputeRouteVector(candidate)
    if candidateLength > existingLength then
        return candidate, existing
    end
    return existing, candidate
end

local function IsProjectionRangeOverlapping(rangeStartA, rangeEndA, rangeStartB, rangeEndB, margin)
    local left = math.max(math.min(rangeStartA, rangeEndA), math.min(rangeStartB, rangeEndB))
    local right = math.min(math.max(rangeStartA, rangeEndA), math.max(rangeStartB, rangeEndB))
    return right >= (left - (margin or 0))
end

local function IsSimilarRoute(existing, candidate)
    if IsRouteRecordValid(existing) ~= true or IsRouteRecordValid(candidate) ~= true then
        return false
    end

    local reference, other = SelectReferenceRoute(existing, candidate)
    local referenceContext = BuildProjectionContext(reference)
    local otherDx, otherDy, otherLength = ComputeRouteVector(other)
    if not referenceContext or otherLength <= 0 then
        return false
    end

    local directionDot = (referenceContext.unitX * (otherDx / otherLength))
        + (referenceContext.unitY * (otherDy / otherLength))
    if directionDot < (AirdropTrajectoryStore.MIN_DIRECTION_DOT or 0.94) then
        return false
    end

    local startDistance, startProjection = DistancePointToLine(referenceContext, other.startX, other.startY)
    local endDistance, endProjection = DistancePointToLine(referenceContext, other.endX, other.endY)
    local tolerance = AirdropTrajectoryStore.ROUTE_LINE_TOLERANCE or 0.018
    if startDistance > tolerance or endDistance > tolerance then
        return false
    end
    if type(startProjection) ~= "number" or type(endProjection) ~= "number" or endProjection <= startProjection then
        return false
    end

    return IsProjectionRangeOverlapping(
        0,
        referenceContext.length,
        startProjection,
        endProjection,
        tolerance * 2
    )
end

local function MergeRoutes(existing, candidate)
    local reference = SelectReferenceRoute(existing, candidate)
    local referenceContext = BuildProjectionContext(reference)
    if not referenceContext then
        return CreateRouteRecord(existing)
    end

    local startPoints = {
        {
            x = existing.startX,
            y = existing.startY,
            projection = ProjectPoint(referenceContext, existing.startX, existing.startY) or 0,
            confirmed = existing.startConfirmed == true,
        },
        {
            x = candidate.startX,
            y = candidate.startY,
            projection = ProjectPoint(referenceContext, candidate.startX, candidate.startY) or 0,
            confirmed = candidate.startConfirmed == true,
        },
    }
    local endPoints = {
        {
            x = existing.endX,
            y = existing.endY,
            projection = ProjectPoint(referenceContext, existing.endX, existing.endY) or referenceContext.length,
            confirmed = existing.endConfirmed == true,
        },
        {
            x = candidate.endX,
            y = candidate.endY,
            projection = ProjectPoint(referenceContext, candidate.endX, candidate.endY) or referenceContext.length,
            confirmed = candidate.endConfirmed == true,
        },
    }

    table.sort(startPoints, function(left, right)
        if left.confirmed ~= right.confirmed then
            return left.confirmed == true
        end
        if left.projection == right.projection then
            if left.x == right.x then
                return left.y < right.y
            end
            return left.x < right.x
        end
        return left.projection < right.projection
    end)
    table.sort(endPoints, function(left, right)
        if left.confirmed ~= right.confirmed then
            return left.confirmed == true
        end
        if left.projection == right.projection then
            if left.x == right.x then
                return left.y < right.y
            end
            return left.x < right.x
        end
        return left.projection > right.projection
    end)

    local merged = {}
    merged.mapID = existing.mapID
    merged.startConfirmed = existing.startConfirmed == true or candidate.startConfirmed == true
    merged.endConfirmed = existing.endConfirmed == true or candidate.endConfirmed == true
    merged.startX = NormalizeCoordinate(startPoints[1].x)
    merged.startY = NormalizeCoordinate(startPoints[1].y)
    merged.endX = NormalizeCoordinate(endPoints[1].x)
    merged.endY = NormalizeCoordinate(endPoints[1].y)
    merged.observationCount = math.max(1, tonumber(existing.observationCount) or 1)
        + math.max(1, tonumber(candidate.observationCount) or 1)
    merged.sampleCount = math.max(tonumber(existing.sampleCount) or 0, tonumber(candidate.sampleCount) or 0)
    merged.createdAt = math.min(
        tonumber(existing.createdAt) or tonumber(existing.updatedAt) or Utils:GetCurrentTimestamp(),
        tonumber(candidate.createdAt) or tonumber(candidate.updatedAt) or Utils:GetCurrentTimestamp()
    )
    merged.updatedAt = math.max(
        tonumber(existing.updatedAt) or 0,
        tonumber(candidate.updatedAt) or 0
    )
    merged.source = ((existing.source == "local") or (candidate.source == "local")) and "local" or "shared"
    merged.lastEventObjectGUID = candidate.lastEventObjectGUID or existing.lastEventObjectGUID
    merged.lastEventStartedAt = math.max(
        tonumber(existing.lastEventStartedAt) or tonumber(existing.createdAt) or 0,
        tonumber(candidate.lastEventStartedAt) or tonumber(candidate.createdAt) or 0
    )
    merged.routeKey = BuildRouteKey(merged)
    if type(merged.routeKey) ~= "string" or merged.routeKey == "" or IsRouteRecordValid(merged) ~= true then
        return CreateRouteRecord(existing)
    end
    return merged
end

local function MergeSameEventRoute(existing, candidate)
    local merged = MergeRoutes(existing, candidate)
    merged.observationCount = math.max(
        tonumber(existing.observationCount) or 1,
        tonumber(candidate.observationCount) or 1
    )
    merged.lastEventObjectGUID = candidate.lastEventObjectGUID or existing.lastEventObjectGUID
    merged.lastEventStartedAt = math.max(
        tonumber(existing.lastEventStartedAt) or tonumber(existing.createdAt) or 0,
        tonumber(candidate.lastEventStartedAt) or tonumber(candidate.createdAt) or 0
    )
    return merged
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
        or (existing.startConfirmed == true) ~= (candidate.startConfirmed == true)
        or (existing.endConfirmed == true) ~= (candidate.endConfirmed == true)
        or existing.observationCount ~= candidate.observationCount
        or existing.sampleCount ~= candidate.sampleCount
        or existing.updatedAt ~= candidate.updatedAt
        or existing.source ~= candidate.source
        or existing.lastEventObjectGUID ~= candidate.lastEventObjectGUID
        or existing.lastEventStartedAt ~= candidate.lastEventStartedAt
end

local function IsDuplicateRouteArtifact(existing, candidate)
    if type(existing) ~= "table" or type(candidate) ~= "table" then
        return false
    end

    if existing.routeKey ~= candidate.routeKey then
        return false
    end

    local existingUpdatedAt = tonumber(existing.updatedAt)
    local candidateUpdatedAt = tonumber(candidate.updatedAt)
    if type(existingUpdatedAt) ~= "number" or type(candidateUpdatedAt) ~= "number" then
        return false
    end

    return existingUpdatedAt == candidateUpdatedAt
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
    if merged.source ~= "local" and candidate.source == "local" then
        merged.source = "local"
    end
    if type(candidate.lastEventObjectGUID) == "string" and candidate.lastEventObjectGUID ~= "" then
        merged.lastEventObjectGUID = candidate.lastEventObjectGUID
    end
    merged.lastEventStartedAt = math.max(
        tonumber(existing.lastEventStartedAt) or tonumber(existing.createdAt) or 0,
        tonumber(candidate.lastEventStartedAt) or tonumber(candidate.createdAt) or 0
    )
    return merged
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
                lastEventObjectGUID = route.lastEventObjectGUID,
                lastEventStartedAt = route.lastEventStartedAt,
                startConfirmed = route.startConfirmed == true,
                endConfirmed = route.endConfirmed == true,
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
                if IsRouteRecordValid(normalized) == true then
                    runtimeBucket[normalized.routeKey] = normalized
                    loadedCount = loadedCount + 1
                end
            end
            PruneMapBucket(self, mapID)
        end
    end
    return loadedCount
end

local function CanonicalizeMapBucket(self, mapID)
    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" then
        return 0
    end

    local routes = {}
    for _, route in pairs(runtimeBucket) do
        if type(route) == "table" then
            routes[#routes + 1] = CreateRouteRecord(route)
        end
    end
    if #routes <= 1 then
        return 0
    end

    table.sort(routes, function(left, right)
        local leftUpdatedAt = tonumber(left and left.updatedAt) or 0
        local rightUpdatedAt = tonumber(right and right.updatedAt) or 0
        if leftUpdatedAt == rightUpdatedAt then
            local leftSamples = tonumber(left and left.sampleCount) or 0
            local rightSamples = tonumber(right and right.sampleCount) or 0
            if leftSamples == rightSamples then
                return (left.routeKey or "") < (right.routeKey or "")
            end
            return leftSamples > rightSamples
        end
        return leftUpdatedAt > rightUpdatedAt
    end)

    local canonicalBucket = {}
    local mergedCount = 0
    for _, route in ipairs(routes) do
        local matchedKey = nil
        local matchedRoute = nil
        for routeKey, existingRoute in pairs(canonicalBucket) do
            if IsSimilarRoute(existingRoute, route) == true then
                matchedKey = routeKey
                matchedRoute = existingRoute
                break
            end
        end

        if not matchedRoute then
            canonicalBucket[route.routeKey] = route
        else
            local merged = IsDuplicateRouteArtifact(matchedRoute, route) == true
                and MergeDuplicateArtifact(matchedRoute, route)
                or MergeRoutes(matchedRoute, route)
            canonicalBucket[matchedKey] = nil
            canonicalBucket[merged.routeKey] = merged
            mergedCount = mergedCount + 1
        end
    end

    self.routesByMap[mapID] = canonicalBucket
    PruneMapBucket(self, mapID)
    SaveMapBucket(self, mapID)
    return mergedCount
end

local function ImportLegacyBucketIntoIndependentStore(self, legacyBucket, currentTime)
    if type(legacyBucket) ~= "table" then
        return 0
    end

    local importedCount = 0
    for rawMapID, savedMapData in pairs(legacyBucket) do
        local mapID = tonumber(rawMapID)
        local savedRoutes = type(savedMapData) == "table" and savedMapData.routes or nil
        if mapID and type(savedRoutes) == "table" then
            for _, savedRoute in pairs(savedRoutes) do
                local routeState = savedRoute
                if type(savedRoute) == "table" and type(savedRoute.mapID) ~= "number" then
                    routeState = {}
                    for key, value in pairs(savedRoute) do
                        routeState[key] = value
                    end
                    routeState.mapID = mapID
                end
                local changed = self:UpsertRoute(mapID, routeState, savedRoute and savedRoute.source, currentTime)
                if changed == true then
                    importedCount = importedCount + 1
                end
            end
        end
    end
    return importedCount
end

function AirdropTrajectoryStore:Initialize()
    self.routesByMap = {}

    local trajectoryState = EnsureTrajectoryPersistentState()
    local persistentBucket = trajectoryState.maps or {}
    LoadPersistentRoutesIntoRuntime(self, persistentBucket)
    for rawMapID in pairs(persistentBucket) do
        local mapID = tonumber(rawMapID)
        if mapID then
            CanonicalizeMapBucket(self, mapID)
        end
    end

    local meta = trajectoryState.meta or {}
    if meta.legacyImportCompleted ~= true then
        local legacyBucket = GetLegacyPersistentBucket()
        local importedCount = 0
        if HasStoredRoutes(persistentBucket) ~= true and type(legacyBucket) == "table" then
            importedCount = ImportLegacyBucketIntoIndependentStore(self, legacyBucket, Utils:GetCurrentTimestamp())
        end
        meta.legacyImportCompleted = true
        meta.legacyImportedAt = Utils:GetCurrentTimestamp()
        meta.legacyImportedRouteCount = importedCount
        trajectoryState.meta = meta
        if importedCount > 0 or HasStoredRoutes(persistentBucket) == true then
            ClearLegacyPersistentBucket()
        end
    end

    return true
end

function AirdropTrajectoryStore:IsPredictionReady(route)
    return type(route) == "table" and route.endConfirmed == true
end

function AirdropTrajectoryStore:GetRouteQualityLabel(route)
    if type(route) ~= "table" then
        return "unknown"
    end
    if route.startConfirmed == true and route.endConfirmed == true then
        return "complete"
    end
    if route.endConfirmed == true then
        return "prediction_ready"
    end
    return "partial"
end

function AirdropTrajectoryStore:IsShareEligible(route)
    if IsRouteRecordValid(route) ~= true then
        return false
    end
    if type(route) ~= "table" or route.endConfirmed ~= true then
        return false
    end
    return (tonumber(route.sampleCount) or 0) >= (self.MIN_SHARED_ROUTE_SAMPLE_COUNT or 8)
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
    ResetIndependentPersistentState()
    ClearLegacyPersistentBucket()
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
    if IsRouteRecordValid(normalized) ~= true then
        return false, nil
    end

    local resolvedMapID = tonumber(normalized.mapID)
    local runtimeBucket = EnsureMapBucket(self, resolvedMapID)
    local matchedKey = nil
    local matchedRoute = nil
    local sameEventMatched = false

    for routeKey, route in pairs(runtimeBucket) do
        if IsSimilarRoute(route, normalized) == true then
            local isSameEvent = type(normalized.lastEventObjectGUID) == "string"
                and normalized.lastEventObjectGUID ~= ""
                and type(route.lastEventObjectGUID) == "string"
                and route.lastEventObjectGUID == normalized.lastEventObjectGUID
            if isSameEvent then
                matchedKey = routeKey
                matchedRoute = route
                sameEventMatched = true
                break
            end
            if not matchedRoute then
                matchedKey = routeKey
                matchedRoute = route
            end
        end
    end

    if matchedRoute then
        local merged = sameEventMatched == true
            and MergeSameEventRoute(matchedRoute, normalized)
            or MergeRoutes(matchedRoute, normalized)
        if HasRouteChanged(matchedRoute, merged) ~= true then
            return false, matchedRoute
        end

        runtimeBucket[matchedKey] = nil
        runtimeBucket[merged.routeKey] = merged
        PruneMapBucket(self, resolvedMapID)
        SaveMapBucket(self, resolvedMapID)
        return true, runtimeBucket[merged.routeKey]
    end

    runtimeBucket[normalized.routeKey] = normalized
    PruneMapBucket(self, resolvedMapID)
    SaveMapBucket(self, resolvedMapID)
    return true, runtimeBucket[normalized.routeKey]
end

return AirdropTrajectoryStore
