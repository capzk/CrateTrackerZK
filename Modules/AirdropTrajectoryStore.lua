-- AirdropTrajectoryStore.lua - 空投规范轨迹持久化存储与迁移归并

local AirdropTrajectoryStore = BuildEnv("AirdropTrajectoryStore")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local AppContext = BuildEnv("AppContext")

AirdropTrajectoryStore.COORDINATE_SCALE = 1000
AirdropTrajectoryStore.IDENTITY_COORDINATE_SCALE = 100
AirdropTrajectoryStore.MIN_ROUTE_LENGTH = 0.02
AirdropTrajectoryStore.MAX_ROUTES_PER_MAP = 200
AirdropTrajectoryStore.DB_SCHEMA_VERSION = 3
AirdropTrajectoryStore.TRACK_ANGLE_THRESHOLD = 0.06
AirdropTrajectoryStore.TRACK_OFFSET_THRESHOLD = 0.012
AirdropTrajectoryStore.LANDING_PROJECTION_THRESHOLD = 0.03
AirdropTrajectoryStore.LANDING_ENDPOINT_DISTANCE_THRESHOLD = 0.03

local function DeepCopyTable(value, visited)
    if type(value) ~= "table" then
        return value
    end

    visited = visited or {}
    if visited[value] then
        return visited[value]
    end

    local copy = {}
    visited[value] = copy
    for key, nestedValue in pairs(value) do
        copy[DeepCopyTable(key, visited)] = DeepCopyTable(nestedValue, visited)
    end
    return copy
end

local function CreateEmptyPersistentState()
    return {
        schemaVersion = AirdropTrajectoryStore.DB_SCHEMA_VERSION,
        meta = {
            storageKind = "canonical",
            lastResetAt = Utils:GetCurrentTimestamp(),
            migratedAt = nil,
            migratedFromSchemaVersion = nil,
        },
        migrationBackup = nil,
        maps = {},
    }
end

local function ClearLegacyPersistentBucket()
    local db = AppContext and AppContext.EnsurePersistentState and AppContext:EnsurePersistentState() or nil
    if type(db) == "table" then
        db.trajectoryData = nil
    end
    return true
end

local function EnsurePersistentRootTable()
    if type(CRATETRACKERZK_TRAJECTORY_DB) ~= "table" then
        CRATETRACKERZK_TRAJECTORY_DB = CreateEmptyPersistentState()
    end
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

    local scale = tonumber(AirdropTrajectoryStore.COORDINATE_SCALE) or 1000
    return math.floor((numberValue * scale) + 0.5) / scale
end

local function QuantizeCoordinateForScale(value, scale)
    local normalized = NormalizeCoordinate(value)
    scale = tonumber(scale)
    if normalized == nil or type(scale) ~= "number" or scale <= 0 then
        return nil
    end
    return math.floor((normalized * scale) + 0.5)
end

local function QuantizeByStep(value, step)
    local numberValue = tonumber(value)
    local stepValue = tonumber(step)
    if type(numberValue) ~= "number" or type(stepValue) ~= "number" or stepValue <= 0 then
        return nil
    end

    local scaled = numberValue / stepValue
    if scaled >= 0 then
        return math.floor(scaled + 0.5)
    end
    return math.ceil(scaled - 0.5)
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

local function BuildTrackDescriptor(route)
    if type(route) ~= "table" then
        return nil
    end

    local dx, dy, length = ComputeRouteVector(route)
    if type(length) ~= "number" or length <= 0 then
        return nil
    end

    local ux = dx / length
    local uy = dy / length
    local nx = -uy
    local ny = ux
    return {
        angle = math.atan2(dy, dx),
        ux = ux,
        uy = uy,
        nx = nx,
        ny = ny,
        offset = ((tonumber(route.startX) or 0) * nx) + ((tonumber(route.startY) or 0) * ny),
        endProjection = ((tonumber(route.endX) or 0) * ux) + ((tonumber(route.endY) or 0) * uy),
    }
end

local function BuildRawObservationKey(route)
    local startX = QuantizeCoordinateForScale(route and route.startX, AirdropTrajectoryStore.COORDINATE_SCALE)
    local startY = QuantizeCoordinateForScale(route and route.startY, AirdropTrajectoryStore.COORDINATE_SCALE)
    local endX = QuantizeCoordinateForScale(route and route.endX, AirdropTrajectoryStore.COORDINATE_SCALE)
    local endY = QuantizeCoordinateForScale(route and route.endY, AirdropTrajectoryStore.COORDINATE_SCALE)
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

local function BuildRouteFamilyKey(route)
    local descriptor = BuildTrackDescriptor(route)
    if type(descriptor) ~= "table" then
        return nil
    end

    local angleBucket = QuantizeByStep(descriptor.angle, AirdropTrajectoryStore.TRACK_ANGLE_THRESHOLD)
    local offsetBucket = QuantizeByStep(descriptor.offset, AirdropTrajectoryStore.TRACK_OFFSET_THRESHOLD)
    if angleBucket == nil or offsetBucket == nil then
        return nil
    end
    return table.concat({
        tostring(angleBucket),
        tostring(offsetBucket),
    }, ":")
end

local function BuildLandingKey(route)
    local descriptor = BuildTrackDescriptor(route)
    if type(descriptor) ~= "table" then
        return nil
    end

    local projectionBucket = QuantizeByStep(descriptor.endProjection, AirdropTrajectoryStore.LANDING_PROJECTION_THRESHOLD)
    local endXBucket = QuantizeCoordinateForScale(route.endX, AirdropTrajectoryStore.IDENTITY_COORDINATE_SCALE)
    local endYBucket = QuantizeCoordinateForScale(route.endY, AirdropTrajectoryStore.IDENTITY_COORDINATE_SCALE)
    if projectionBucket == nil or endXBucket == nil or endYBucket == nil then
        return nil
    end

    return table.concat({
        tostring(projectionBucket),
        tostring(endXBucket),
        tostring(endYBucket),
    }, ":")
end

local function BuildCanonicalRouteKey(mapID, routeFamilyKey, landingKey)
    if type(routeFamilyKey) ~= "string" or routeFamilyKey == ""
        or type(landingKey) ~= "string" or landingKey == "" then
        return nil
    end
    return table.concat({
        "canon",
        tostring(tonumber(mapID) or 0),
        routeFamilyKey,
        landingKey,
    }, ":")
end

local function BuildAlertToken(mapID, routeFamilyKey, landingKey)
    if type(routeFamilyKey) ~= "string" or routeFamilyKey == ""
        or type(landingKey) ~= "string" or landingKey == "" then
        return nil
    end
    return table.concat({
        "traj",
        tostring(tonumber(mapID) or 0),
        routeFamilyKey,
        landingKey,
    }, ":")
end

local function IsReliableRoute(route)
    return type(route) == "table"
        and route.startConfirmed == true
        and route.endConfirmed == true
        and route.startSource == "npc_shout"
        and route.endSource == "crate_vignette"
end

local function FinalizeRouteReliability(route)
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
    if IsReliableRoute(route) == true then
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

local function CompareRepresentativePriority(left, right)
    local leftVerifiedCount = math.max(0, math.floor(tonumber(left and left.verifiedPredictionCount) or 0))
    local rightVerifiedCount = math.max(0, math.floor(tonumber(right and right.verifiedPredictionCount) or 0))
    if leftVerifiedCount ~= rightVerifiedCount then
        return leftVerifiedCount > rightVerifiedCount
    end

    local leftObservationCount = math.max(0, math.floor(tonumber(left and left.observationCount) or 0))
    local rightObservationCount = math.max(0, math.floor(tonumber(right and right.observationCount) or 0))
    if leftObservationCount ~= rightObservationCount then
        return leftObservationCount > rightObservationCount
    end

    local leftSampleCount = math.max(0, math.floor(tonumber(left and left.sampleCount) or 0))
    local rightSampleCount = math.max(0, math.floor(tonumber(right and right.sampleCount) or 0))
    if leftSampleCount ~= rightSampleCount then
        return leftSampleCount > rightSampleCount
    end

    local leftUpdatedAt = math.max(0, math.floor(tonumber(left and left.updatedAt) or 0))
    local rightUpdatedAt = math.max(0, math.floor(tonumber(right and right.updatedAt) or 0))
    if leftUpdatedAt ~= rightUpdatedAt then
        return leftUpdatedAt > rightUpdatedAt
    end

    local leftKey = tostring(
        left
        and (
            left.representativeLegacyRouteKey
            or left.representativeRouteKey
            or left.routeKey
        )
        or ""
    )
    local rightKey = tostring(
        right
        and (
            right.representativeLegacyRouteKey
            or right.representativeRouteKey
            or right.routeKey
        )
        or ""
    )
    return leftKey < rightKey
end

local function SortRoutesForDerivation(routes)
    table.sort(routes, function(left, right)
        return CompareRepresentativePriority(left, right)
    end)
    return routes
end

local function NormalizeAngleDelta(leftAngle, rightAngle)
    local delta = math.abs((tonumber(leftAngle) or 0) - (tonumber(rightAngle) or 0))
    if delta > math.pi then
        delta = (math.pi * 2) - delta
    end
    return math.abs(delta)
end

local function BuildTrackMatchInfo(store, trackGroup, candidateRoute)
    if type(store) ~= "table" or type(trackGroup) ~= "table" or type(candidateRoute) ~= "table" then
        return nil
    end

    local trackAngle = tonumber(trackGroup.angle)
    local trackOffset = tonumber(trackGroup.offset)
    local candidateDescriptor = BuildTrackDescriptor(candidateRoute)
    if type(trackAngle) ~= "number"
        or type(trackOffset) ~= "number"
        or type(candidateDescriptor) ~= "table" then
        return nil
    end

    local angleDelta = NormalizeAngleDelta(trackAngle, candidateDescriptor.angle)
    if angleDelta > (tonumber(store.TRACK_ANGLE_THRESHOLD) or 0.06) then
        return nil
    end

    local offsetDistance = math.abs(trackOffset - candidateDescriptor.offset)
    if offsetDistance > (tonumber(store.TRACK_OFFSET_THRESHOLD) or 0.012) then
        return nil
    end

    return {
        angleDelta = angleDelta,
        offsetDistance = offsetDistance,
    }
end

local function CompareTrackMatchInfo(left, right)
    if type(left) ~= "table" then
        return false
    end
    if type(right) ~= "table" then
        return true
    end

    if left.offsetDistance ~= right.offsetDistance then
        return left.offsetDistance < right.offsetDistance
    end
    if left.angleDelta ~= right.angleDelta then
        return left.angleDelta < right.angleDelta
    end
    return false
end

local function ComputeTrackEndProjection(trackGroup, route)
    if type(trackGroup) ~= "table" or type(route) ~= "table" then
        return nil
    end

    local trackUx = tonumber(trackGroup.ux)
    local trackUy = tonumber(trackGroup.uy)
    if type(trackUx) ~= "number" or type(trackUy) ~= "number" then
        return nil
    end

    return ((tonumber(route.endX) or 0) * trackUx) + ((tonumber(route.endY) or 0) * trackUy)
end

local function BuildLandingClusterMatchInfo(store, trackGroup, landingCluster, candidateRoute)
    if type(store) ~= "table"
        or type(trackGroup) ~= "table"
        or type(landingCluster) ~= "table"
        or type(candidateRoute) ~= "table" then
        return nil
    end

    local trackUx = tonumber(trackGroup.ux)
    local trackUy = tonumber(trackGroup.uy)
    if type(trackUx) ~= "number" or type(trackUy) ~= "number" then
        return nil
    end

    local candidateProjection = ((tonumber(candidateRoute.endX) or 0) * trackUx) + ((tonumber(candidateRoute.endY) or 0) * trackUy)
    local projectionDistance = math.abs(candidateProjection - (tonumber(landingCluster.endProjection) or 0))
    if projectionDistance > (tonumber(store.LANDING_PROJECTION_THRESHOLD) or 0.03) then
        return nil
    end

    local endpointDistance = ComputeDistance(
        landingCluster.representativeRoute.endX,
        landingCluster.representativeRoute.endY,
        candidateRoute.endX,
        candidateRoute.endY
    )
    if endpointDistance > (tonumber(store.LANDING_ENDPOINT_DISTANCE_THRESHOLD) or 0.03) then
        return nil
    end

    return {
        projectionDistance = projectionDistance,
        endpointDistance = endpointDistance,
    }
end

local function CompareLandingClusterMatchInfo(left, right)
    if type(left) ~= "table" then
        return false
    end
    if type(right) ~= "table" then
        return true
    end

    if left.projectionDistance ~= right.projectionDistance then
        return left.projectionDistance < right.projectionDistance
    end
    if left.endpointDistance ~= right.endpointDistance then
        return left.endpointDistance < right.endpointDistance
    end
    return false
end

local function NormalizeBaseRouteRecord(routeState, source, currentTime)
    if type(routeState) ~= "table" then
        return nil
    end

    local mapID = tonumber(routeState.mapID)
    local startX = NormalizeCoordinate(routeState.startX)
    local startY = NormalizeCoordinate(routeState.startY)
    local endX = NormalizeCoordinate(routeState.endX)
    local endY = NormalizeCoordinate(routeState.endY)
    if not mapID or startX == nil or startY == nil or endX == nil or endY == nil then
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
        startConfirmed = routeState.startConfirmed == true,
        endConfirmed = routeState.endConfirmed == true,
        verificationCount = math.max(0, math.floor(tonumber(routeState.verificationCount) or 0)),
        verifiedPredictionCount = math.max(0, math.floor(tonumber(routeState.verifiedPredictionCount) or 0)),
        lastPredictionVerified = routeState.lastPredictionVerified == true,
        mergedRouteCount = math.max(1, math.floor(tonumber(routeState.mergedRouteCount) or 1)),
    }

    return normalized
end

local function NormalizeMigrationMemberRoute(routeState)
    local normalized = NormalizeBaseRouteRecord(routeState, routeState and routeState.source, routeState and routeState.updatedAt)
    if type(normalized) ~= "table" then
        return nil
    end

    normalized.routeKey = type(routeState.routeKey) == "string" and routeState.routeKey ~= ""
        and routeState.routeKey
        or BuildRawObservationKey(routeState)
    normalized.representativeLegacyRouteKey = normalized.routeKey
    return FinalizeRouteReliability(normalized)
end

local function NormalizeCanonicalRouteRecord(routeState, source, currentTime)
    local normalized = NormalizeBaseRouteRecord(routeState, source, currentTime)
    if type(normalized) ~= "table" then
        return nil
    end

    local routeFamilyKey = type(routeState.routeFamilyKey) == "string"
        and routeState.routeFamilyKey ~= ""
        and routeState.routeFamilyKey
        or BuildRouteFamilyKey(normalized)
    local landingKey = type(routeState.landingKey) == "string"
        and routeState.landingKey ~= ""
        and routeState.landingKey
        or BuildLandingKey(normalized)
    local routeKey = type(routeState.routeKey) == "string"
        and routeState.routeKey ~= ""
        and routeState.routeKey
        or BuildCanonicalRouteKey(normalized.mapID, routeFamilyKey, landingKey)
    local alertToken = type(routeState.alertToken) == "string"
        and routeState.alertToken ~= ""
        and routeState.alertToken
        or BuildAlertToken(normalized.mapID, routeFamilyKey, landingKey)
    if type(routeFamilyKey) ~= "string" or routeFamilyKey == ""
        or type(landingKey) ~= "string" or landingKey == ""
        or type(routeKey) ~= "string" or routeKey == ""
        or type(alertToken) ~= "string" or alertToken == "" then
        return nil
    end

    normalized.routeFamilyKey = routeFamilyKey
    normalized.landingKey = landingKey
    normalized.routeKey = routeKey
    normalized.alertToken = alertToken
    normalized.representativeLegacyRouteKey = type(routeState.representativeLegacyRouteKey) == "string"
        and routeState.representativeLegacyRouteKey ~= ""
        and routeState.representativeLegacyRouteKey
        or (type(routeState.representativeRouteKey) == "string" and routeState.representativeRouteKey ~= "" and routeState.representativeRouteKey or nil)
        or BuildRawObservationKey(routeState)
        or routeKey
    return FinalizeRouteReliability(normalized)
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
    outRoute.routeFamilyKey = route.routeFamilyKey
    outRoute.landingKey = route.landingKey
    outRoute.alertToken = route.alertToken
    outRoute.observationCount = route.observationCount
    outRoute.sampleCount = route.sampleCount
    outRoute.verificationCount = route.verificationCount
    outRoute.verifiedPredictionCount = route.verifiedPredictionCount
    outRoute.createdAt = route.createdAt
    outRoute.updatedAt = route.updatedAt
    outRoute.source = route.source
    outRoute.continuityConfirmed = route.continuityConfirmed == true
    outRoute.startSource = route.startSource
    outRoute.endSource = route.endSource
    outRoute.startConfirmed = route.startConfirmed == true
    outRoute.endConfirmed = route.endConfirmed == true
    outRoute.lastPredictionVerified = route.lastPredictionVerified == true
    outRoute.mergedRouteCount = route.mergedRouteCount
    outRoute.representativeLegacyRouteKey = route.representativeLegacyRouteKey
    outRoute.confidenceScore = route.confidenceScore
    return outRoute
end

local function CreateRouteRecord(route)
    return CopyRouteInto({}, route)
end

local function BuildCanonicalRouteFromMembers(mapID, memberRoutes)
    if type(memberRoutes) ~= "table" or #memberRoutes == 0 then
        return nil
    end

    local sortedMembers = {}
    for _, memberRoute in ipairs(memberRoutes) do
        sortedMembers[#sortedMembers + 1] = memberRoute
    end
    SortRoutesForDerivation(sortedMembers)
    local representativeRoute = sortedMembers[1]
    if type(representativeRoute) ~= "table" then
        return nil
    end

    local routeFamilyKey = BuildRouteFamilyKey(representativeRoute)
    local landingKey = BuildLandingKey(representativeRoute)
    local routeKey = BuildCanonicalRouteKey(mapID, routeFamilyKey, landingKey)
    local alertToken = BuildAlertToken(mapID, routeFamilyKey, landingKey)
    if type(routeFamilyKey) ~= "string" or routeFamilyKey == ""
        or type(landingKey) ~= "string" or landingKey == ""
        or type(routeKey) ~= "string" or routeKey == ""
        or type(alertToken) ~= "string" or alertToken == "" then
        return nil
    end

    local canonicalRoute = {
        routeKey = routeKey,
        mapID = mapID,
        startX = representativeRoute.startX,
        startY = representativeRoute.startY,
        endX = representativeRoute.endX,
        endY = representativeRoute.endY,
        routeFamilyKey = routeFamilyKey,
        landingKey = landingKey,
        alertToken = alertToken,
        observationCount = 0,
        sampleCount = 0,
        verificationCount = 0,
        verifiedPredictionCount = 0,
        createdAt = math.huge,
        updatedAt = 0,
        source = "shared",
        continuityConfirmed = false,
        startSource = representativeRoute.startSource,
        endSource = representativeRoute.endSource,
        startConfirmed = representativeRoute.startConfirmed == true,
        endConfirmed = representativeRoute.endConfirmed == true,
        lastPredictionVerified = false,
        mergedRouteCount = #sortedMembers,
        representativeLegacyRouteKey = representativeRoute.representativeLegacyRouteKey or representativeRoute.routeKey or routeKey,
    }

    for _, memberRoute in ipairs(sortedMembers) do
        canonicalRoute.observationCount = canonicalRoute.observationCount + math.max(1, math.floor(tonumber(memberRoute.observationCount) or 1))
        canonicalRoute.sampleCount = math.max(canonicalRoute.sampleCount, math.max(2, math.floor(tonumber(memberRoute.sampleCount) or 2)))
        canonicalRoute.verificationCount = math.max(
            canonicalRoute.verificationCount,
            math.max(0, math.floor(tonumber(memberRoute.verificationCount) or 0))
        )
        canonicalRoute.verifiedPredictionCount = math.max(
            canonicalRoute.verifiedPredictionCount,
            math.max(0, math.floor(tonumber(memberRoute.verifiedPredictionCount) or 0))
        )
        canonicalRoute.createdAt = math.min(
            canonicalRoute.createdAt,
            math.max(0, math.floor(tonumber(memberRoute.createdAt) or tonumber(memberRoute.updatedAt) or 0))
        )
        canonicalRoute.updatedAt = math.max(
            canonicalRoute.updatedAt,
            math.max(0, math.floor(tonumber(memberRoute.updatedAt) or 0))
        )
        canonicalRoute.continuityConfirmed = canonicalRoute.continuityConfirmed or memberRoute.continuityConfirmed == true
        canonicalRoute.lastPredictionVerified = canonicalRoute.lastPredictionVerified or memberRoute.lastPredictionVerified == true
        if canonicalRoute.source ~= "local" and memberRoute.source == "local" then
            canonicalRoute.source = "local"
        end
    end

    if canonicalRoute.createdAt == math.huge then
        canonicalRoute.createdAt = math.max(0, math.floor(tonumber(representativeRoute.createdAt) or tonumber(representativeRoute.updatedAt) or 0))
    end
    return FinalizeRouteReliability(canonicalRoute)
end

local function CreateTrackGroupRecord(trackGroup)
    local outRoute = CreateRouteRecord(trackGroup)
    if type(outRoute) ~= "table" or type(trackGroup) ~= "table" then
        return outRoute
    end

    outRoute.trackKey = type(trackGroup.trackKey) == "string" and trackGroup.trackKey or nil
    outRoute.representativeRouteKey = type(trackGroup.representativeRouteKey) == "string"
        and trackGroup.representativeRouteKey
        or outRoute.routeKey
    outRoute.rawRouteCount = math.max(1, math.floor(tonumber(trackGroup.rawRouteCount) or 1))
    outRoute.landingClusterCount = math.max(1, math.floor(tonumber(trackGroup.landingClusterCount) or 1))
    outRoute.angle = tonumber(trackGroup.angle)
    outRoute.offset = tonumber(trackGroup.offset)
    outRoute.ux = tonumber(trackGroup.ux)
    outRoute.uy = tonumber(trackGroup.uy)
    outRoute.nx = tonumber(trackGroup.nx)
    outRoute.ny = tonumber(trackGroup.ny)
    outRoute.representativeRoute = type(trackGroup.representativeRoute) == "table"
        and CreateRouteRecord(trackGroup.representativeRoute)
        or CreateRouteRecord(trackGroup)
    outRoute.landingClusters = {}
    for _, landingCluster in ipairs(trackGroup.landingClusters or {}) do
        outRoute.landingClusters[#outRoute.landingClusters + 1] = {
            routeKey = landingCluster.routeKey,
            mapID = landingCluster.mapID,
            startX = landingCluster.startX,
            startY = landingCluster.startY,
            endX = landingCluster.endX,
            endY = landingCluster.endY,
            routeFamilyKey = landingCluster.routeFamilyKey,
            landingKey = landingCluster.landingKey,
            alertToken = landingCluster.alertToken,
            observationCount = landingCluster.observationCount,
            sampleCount = landingCluster.sampleCount,
            verificationCount = landingCluster.verificationCount,
            verifiedPredictionCount = landingCluster.verifiedPredictionCount,
            createdAt = landingCluster.createdAt,
            updatedAt = landingCluster.updatedAt,
            source = landingCluster.source,
            continuityConfirmed = landingCluster.continuityConfirmed == true,
            startSource = landingCluster.startSource,
            endSource = landingCluster.endSource,
            startConfirmed = landingCluster.startConfirmed == true,
            endConfirmed = landingCluster.endConfirmed == true,
            lastPredictionVerified = landingCluster.lastPredictionVerified == true,
            mergedRouteCount = landingCluster.mergedRouteCount,
            representativeLegacyRouteKey = landingCluster.representativeLegacyRouteKey,
            confidenceScore = landingCluster.confidenceScore,
            clusterRouteCount = math.max(1, math.floor(tonumber(landingCluster.clusterRouteCount) or 1)),
            representativeRouteKey = type(landingCluster.representativeRouteKey) == "string"
                and landingCluster.representativeRouteKey
                or landingCluster.routeKey,
            endProjection = tonumber(landingCluster.endProjection),
            trackKey = type(trackGroup.trackKey) == "string" and trackGroup.trackKey or nil,
            clusterIndex = tonumber(landingCluster.clusterIndex),
            representativeRoute = type(landingCluster.representativeRoute) == "table"
                and CreateRouteRecord(landingCluster.representativeRoute)
                or CreateRouteRecord(landingCluster),
        }
    end
    return outRoute
end

local function BuildAggregatedRepresentativeRoute(representativeRoute, memberRoutes)
    if type(representativeRoute) ~= "table" or type(memberRoutes) ~= "table" then
        return nil
    end

    local aggregated = CreateRouteRecord(representativeRoute)
    if type(aggregated) ~= "table" then
        return nil
    end

    aggregated.observationCount = 0
    aggregated.sampleCount = 0
    aggregated.createdAt = math.huge
    aggregated.updatedAt = 0
    aggregated.source = representativeRoute.source
    aggregated.continuityConfirmed = false
    aggregated.verificationCount = 0
    aggregated.verifiedPredictionCount = 0
    aggregated.lastPredictionVerified = false
    aggregated.mergedRouteCount = 0

    for _, memberRoute in ipairs(memberRoutes) do
        aggregated.observationCount = aggregated.observationCount + math.max(1, math.floor(tonumber(memberRoute.observationCount) or 1))
        aggregated.sampleCount = math.max(aggregated.sampleCount, math.max(2, math.floor(tonumber(memberRoute.sampleCount) or 2)))
        aggregated.updatedAt = math.max(aggregated.updatedAt, math.max(0, math.floor(tonumber(memberRoute.updatedAt) or 0)))
        aggregated.createdAt = math.min(
            aggregated.createdAt,
            math.max(0, math.floor(tonumber(memberRoute.createdAt) or tonumber(memberRoute.updatedAt) or 0))
        )
        if aggregated.source ~= "local" and memberRoute.source == "local" then
            aggregated.source = "local"
        end
        aggregated.continuityConfirmed = aggregated.continuityConfirmed or memberRoute.continuityConfirmed == true
        aggregated.verificationCount = aggregated.verificationCount + math.max(0, math.floor(tonumber(memberRoute.verificationCount) or 0))
        aggregated.verifiedPredictionCount = aggregated.verifiedPredictionCount + math.max(0, math.floor(tonumber(memberRoute.verifiedPredictionCount) or 0))
        aggregated.lastPredictionVerified = aggregated.lastPredictionVerified or memberRoute.lastPredictionVerified == true
        aggregated.mergedRouteCount = aggregated.mergedRouteCount + math.max(1, math.floor(tonumber(memberRoute.mergedRouteCount) or 1))
    end

    if aggregated.createdAt == math.huge then
        aggregated.createdAt = math.max(0, math.floor(tonumber(representativeRoute.createdAt) or tonumber(representativeRoute.updatedAt) or 0))
    end

    return FinalizeRouteReliability(aggregated)
end

local function BuildLandingClusterAggregate(trackGroup, landingCluster, clusterIndex)
    if type(trackGroup) ~= "table" or type(landingCluster) ~= "table" or type(landingCluster.representativeRoute) ~= "table" then
        return nil
    end

    local aggregated = BuildAggregatedRepresentativeRoute(landingCluster.representativeRoute, landingCluster.memberRoutes or {})
    if type(aggregated) ~= "table" then
        return nil
    end

    aggregated.routeKey = landingCluster.representativeRoute.routeKey
    aggregated.representativeRouteKey = landingCluster.representativeRoute.routeKey
    aggregated.representativeRoute = CreateRouteRecord(landingCluster.representativeRoute)
    aggregated.clusterRouteCount = math.max(1, math.floor(tonumber(landingCluster.clusterRouteCount) or #(landingCluster.memberRoutes or {})))
    aggregated.endProjection = tonumber(landingCluster.endProjection)
    aggregated.trackKey = type(trackGroup.trackKey) == "string" and trackGroup.trackKey or nil
    aggregated.clusterIndex = clusterIndex
    return aggregated
end

local function BuildTrackGroupAggregate(trackGroup)
    if type(trackGroup) ~= "table" or type(trackGroup.representativeRoute) ~= "table" then
        return nil
    end

    local aggregated = BuildAggregatedRepresentativeRoute(trackGroup.representativeRoute, trackGroup.memberRoutes or {})
    if type(aggregated) ~= "table" then
        return nil
    end

    aggregated.routeKey = trackGroup.representativeRoute.routeKey
    aggregated.trackKey = tostring(trackGroup.mapID or aggregated.mapID or "0") .. ":" .. tostring(trackGroup.representativeRoute.routeKey or "unknown")
    aggregated.representativeRouteKey = trackGroup.representativeRoute.routeKey
    aggregated.representativeRoute = CreateRouteRecord(trackGroup.representativeRoute)
    aggregated.rawRouteCount = math.max(1, math.floor(tonumber(trackGroup.rawRouteCount) or #(trackGroup.memberRoutes or {})))
    aggregated.angle = tonumber(trackGroup.angle)
    aggregated.offset = tonumber(trackGroup.offset)
    aggregated.ux = tonumber(trackGroup.ux)
    aggregated.uy = tonumber(trackGroup.uy)
    aggregated.nx = tonumber(trackGroup.nx)
    aggregated.ny = tonumber(trackGroup.ny)
    aggregated.landingClusters = {}
    table.sort(trackGroup.landingClusters or {}, function(left, right)
        local leftProjection = tonumber(left and left.endProjection) or math.huge
        local rightProjection = tonumber(right and right.endProjection) or math.huge
        if leftProjection ~= rightProjection then
            return leftProjection < rightProjection
        end
        return CompareRepresentativePriority(left and left.representativeRoute, right and right.representativeRoute)
    end)
    for index, landingCluster in ipairs(trackGroup.landingClusters or {}) do
        local clusterRecord = BuildLandingClusterAggregate(aggregated, landingCluster, index)
        if type(clusterRecord) == "table" then
            aggregated.landingClusters[#aggregated.landingClusters + 1] = clusterRecord
        end
    end
    aggregated.landingClusterCount = #aggregated.landingClusters
    return aggregated
end

local function BuildTrackGroupsFromRoutes(store, routes)
    local trackGroups = {}
    local sortedRoutes = {}
    for _, route in ipairs(routes or {}) do
        if IsReliableRoute(route) == true then
            sortedRoutes[#sortedRoutes + 1] = route
        end
    end
    SortRoutesForDerivation(sortedRoutes)

    for _, route in ipairs(sortedRoutes) do
        local bestTrackGroup = nil
        local bestMatch = nil
        for _, trackGroup in ipairs(trackGroups) do
            local trackMatchInfo = BuildTrackMatchInfo(store, trackGroup, route)
            if type(trackMatchInfo) == "table" then
                if CompareTrackMatchInfo(trackMatchInfo, bestMatch) then
                    bestTrackGroup = trackGroup
                    bestMatch = trackMatchInfo
                elseif type(bestMatch) == "table"
                    and trackMatchInfo.offsetDistance == bestMatch.offsetDistance
                    and trackMatchInfo.angleDelta == bestMatch.angleDelta
                    and CompareRepresentativePriority(trackGroup.representativeRoute, bestTrackGroup and bestTrackGroup.representativeRoute) then
                    bestTrackGroup = trackGroup
                    bestMatch = trackMatchInfo
                end
            end
        end

        if type(bestTrackGroup) ~= "table" then
            local descriptor = BuildTrackDescriptor(route)
            trackGroups[#trackGroups + 1] = {
                mapID = route.mapID,
                representativeRoute = route,
                memberRoutes = { route },
                angle = descriptor and descriptor.angle or nil,
                ux = descriptor and descriptor.ux or nil,
                uy = descriptor and descriptor.uy or nil,
                nx = descriptor and descriptor.nx or nil,
                ny = descriptor and descriptor.ny or nil,
                offset = descriptor and descriptor.offset or nil,
                landingClusters = {},
            }
        else
            bestTrackGroup.memberRoutes[#bestTrackGroup.memberRoutes + 1] = route
            if CompareRepresentativePriority(route, bestTrackGroup.representativeRoute) then
                bestTrackGroup.representativeRoute = route
                local descriptor = BuildTrackDescriptor(route)
                bestTrackGroup.angle = descriptor and descriptor.angle or nil
                bestTrackGroup.ux = descriptor and descriptor.ux or nil
                bestTrackGroup.uy = descriptor and descriptor.uy or nil
                bestTrackGroup.nx = descriptor and descriptor.nx or nil
                bestTrackGroup.ny = descriptor and descriptor.ny or nil
                bestTrackGroup.offset = descriptor and descriptor.offset or nil
            end
        end
    end

    for _, trackGroup in ipairs(trackGroups) do
        local landingClusters = {}
        local sortedMembers = {}
        for _, memberRoute in ipairs(trackGroup.memberRoutes or {}) do
            sortedMembers[#sortedMembers + 1] = memberRoute
        end
        SortRoutesForDerivation(sortedMembers)

        for _, memberRoute in ipairs(sortedMembers) do
            local bestLandingCluster = nil
            local bestLandingMatch = nil
            for _, landingCluster in ipairs(landingClusters) do
                local landingMatchInfo = BuildLandingClusterMatchInfo(store, trackGroup, landingCluster, memberRoute)
                if CompareLandingClusterMatchInfo(landingMatchInfo, bestLandingMatch) then
                    bestLandingCluster = landingCluster
                    bestLandingMatch = landingMatchInfo
                end
            end

            if type(bestLandingCluster) ~= "table" then
                landingClusters[#landingClusters + 1] = {
                    representativeRoute = memberRoute,
                    memberRoutes = { memberRoute },
                    endProjection = ComputeTrackEndProjection(trackGroup, memberRoute),
                    clusterRouteCount = 1,
                }
            else
                bestLandingCluster.memberRoutes[#bestLandingCluster.memberRoutes + 1] = memberRoute
                bestLandingCluster.clusterRouteCount = #(bestLandingCluster.memberRoutes)
                if CompareRepresentativePriority(memberRoute, bestLandingCluster.representativeRoute) then
                    bestLandingCluster.representativeRoute = memberRoute
                    bestLandingCluster.endProjection = ComputeTrackEndProjection(trackGroup, memberRoute)
                end
            end
        end

        trackGroup.rawRouteCount = #(trackGroup.memberRoutes or {})
        trackGroup.landingClusters = landingClusters
    end

    return trackGroups
end

local function BuildCanonicalRoutesFromLegacyRoutes(store, mapID, legacyRoutes)
    local canonicalRoutes = {}
    local trackGroups = BuildTrackGroupsFromRoutes(store, legacyRoutes)
    for _, trackGroup in ipairs(trackGroups) do
        for _, landingCluster in ipairs(trackGroup.landingClusters or {}) do
            local canonicalRoute = BuildCanonicalRouteFromMembers(mapID, landingCluster.memberRoutes or {})
            if type(canonicalRoute) == "table" then
                canonicalRoutes[#canonicalRoutes + 1] = canonicalRoute
            end
        end
    end
    return canonicalRoutes
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
        or existing.routeFamilyKey ~= candidate.routeFamilyKey
        or existing.landingKey ~= candidate.landingKey
        or existing.alertToken ~= candidate.alertToken
        or existing.observationCount ~= candidate.observationCount
        or existing.sampleCount ~= candidate.sampleCount
        or existing.verificationCount ~= candidate.verificationCount
        or existing.verifiedPredictionCount ~= candidate.verifiedPredictionCount
        or existing.createdAt ~= candidate.createdAt
        or existing.updatedAt ~= candidate.updatedAt
        or existing.source ~= candidate.source
        or (existing.continuityConfirmed == true) ~= (candidate.continuityConfirmed == true)
        or existing.startSource ~= candidate.startSource
        or existing.endSource ~= candidate.endSource
        or (existing.startConfirmed == true) ~= (candidate.startConfirmed == true)
        or (existing.endConfirmed == true) ~= (candidate.endConfirmed == true)
        or (existing.lastPredictionVerified == true) ~= (candidate.lastPredictionVerified == true)
        or existing.mergedRouteCount ~= candidate.mergedRouteCount
        or existing.representativeLegacyRouteKey ~= candidate.representativeLegacyRouteKey
end

local function BuildMergedCanonicalRoute(existing, candidate)
    local preferCandidate = CompareRepresentativePriority(candidate, existing)
    local merged = CreateRouteRecord(preferCandidate == true and candidate or existing)
    if type(merged) ~= "table" then
        return CreateRouteRecord(existing)
    end

    local existingObservationCount = math.max(1, math.floor(tonumber(existing.observationCount) or 1))
    local candidateObservationCount = math.max(1, math.floor(tonumber(candidate.observationCount) or 1))
    local existingMergedRouteCount = math.max(1, math.floor(tonumber(existing.mergedRouteCount) or 1))
    local candidateMergedRouteCount = math.max(1, math.floor(tonumber(candidate.mergedRouteCount) or 1))

    if candidate.source == "local" then
        merged.observationCount = existingObservationCount + candidateObservationCount
        merged.mergedRouteCount = existingMergedRouteCount + candidateMergedRouteCount
    else
        merged.observationCount = math.max(existingObservationCount, candidateObservationCount)
        merged.mergedRouteCount = math.max(existingMergedRouteCount, candidateMergedRouteCount)
    end
    merged.sampleCount = math.max(
        math.max(2, math.floor(tonumber(existing.sampleCount) or 2)),
        math.max(2, math.floor(tonumber(candidate.sampleCount) or 2))
    )
    merged.verificationCount = math.max(
        math.max(0, math.floor(tonumber(existing.verificationCount) or 0)),
        math.max(0, math.floor(tonumber(candidate.verificationCount) or 0))
    )
    merged.verifiedPredictionCount = math.max(
        math.max(0, math.floor(tonumber(existing.verifiedPredictionCount) or 0)),
        math.max(0, math.floor(tonumber(candidate.verifiedPredictionCount) or 0))
    )
    merged.createdAt = math.min(
        math.max(0, math.floor(tonumber(existing.createdAt) or 0)),
        math.max(0, math.floor(tonumber(candidate.createdAt) or 0))
    )
    merged.updatedAt = math.max(
        math.max(0, math.floor(tonumber(existing.updatedAt) or 0)),
        math.max(0, math.floor(tonumber(candidate.updatedAt) or 0))
    )
    merged.continuityConfirmed = existing.continuityConfirmed == true or candidate.continuityConfirmed == true
    merged.lastPredictionVerified = existing.lastPredictionVerified == true or candidate.lastPredictionVerified == true
    if merged.source ~= "local" and (existing.source == "local" or candidate.source == "local") then
        merged.source = "local"
    end

    -- 规范路线身份一旦建立后保持不变，避免共享与验证链路抖动。
    merged.routeKey = existing.routeKey
    merged.routeFamilyKey = existing.routeFamilyKey
    merged.landingKey = existing.landingKey
    merged.alertToken = existing.alertToken

    if preferCandidate ~= true then
        merged.representativeLegacyRouteKey = existing.representativeLegacyRouteKey or candidate.representativeLegacyRouteKey
    end

    return FinalizeRouteReliability(merged)
end

local function DoesCanonicalRouteMatch(store, existingRoute, candidateRoute)
    if type(store) ~= "table" or type(existingRoute) ~= "table" or type(candidateRoute) ~= "table" then
        return false
    end
    if tonumber(existingRoute.mapID) ~= tonumber(candidateRoute.mapID) then
        return false
    end

    local existingDescriptor = BuildTrackDescriptor(existingRoute)
    local candidateDescriptor = BuildTrackDescriptor(candidateRoute)
    if type(existingDescriptor) ~= "table" or type(candidateDescriptor) ~= "table" then
        return false
    end

    local angleDelta = NormalizeAngleDelta(existingDescriptor.angle, candidateDescriptor.angle)
    if angleDelta > (tonumber(store.TRACK_ANGLE_THRESHOLD) or 0.06) then
        return false
    end

    local offsetDistance = math.abs(existingDescriptor.offset - candidateDescriptor.offset)
    if offsetDistance > (tonumber(store.TRACK_OFFSET_THRESHOLD) or 0.012) then
        return false
    end

    local candidateProjection = ((tonumber(candidateRoute.endX) or 0) * existingDescriptor.ux) + ((tonumber(candidateRoute.endY) or 0) * existingDescriptor.uy)
    local projectionDistance = math.abs(candidateProjection - (tonumber(existingDescriptor.endProjection) or 0))
    if projectionDistance > (tonumber(store.LANDING_PROJECTION_THRESHOLD) or 0.03) then
        return false
    end

    return ComputeDistance(existingRoute.endX, existingRoute.endY, candidateRoute.endX, candidateRoute.endY)
        <= (tonumber(store.LANDING_ENDPOINT_DISTANCE_THRESHOLD) or 0.03)
end

local function EnsureMapBucket(self, mapID)
    self.routesByMap = self.routesByMap or {}
    self.routesByMap[mapID] = self.routesByMap[mapID] or {}
    return self.routesByMap[mapID]
end

local function PruneMapBucket(self, mapID)
    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" then
        return
    end

    local maxRoutes = tonumber(self.MAX_ROUTES_PER_MAP) or 200
    local routes = {}
    for routeKey, route in pairs(runtimeBucket) do
        routes[#routes + 1] = {
            routeKey = routeKey,
            updatedAt = type(route) == "table" and tonumber(route.updatedAt) or 0,
            observationCount = type(route) == "table" and tonumber(route.observationCount) or 0,
            mergedRouteCount = type(route) == "table" and tonumber(route.mergedRouteCount) or 0,
        }
    end

    if #routes <= maxRoutes then
        return
    end

    table.sort(routes, function(left, right)
        if left.updatedAt ~= right.updatedAt then
            return left.updatedAt > right.updatedAt
        end
        if left.observationCount ~= right.observationCount then
            return left.observationCount > right.observationCount
        end
        if left.mergedRouteCount ~= right.mergedRouteCount then
            return left.mergedRouteCount > right.mergedRouteCount
        end
        return left.routeKey < right.routeKey
    end)

    for index = maxRoutes + 1, #routes do
        runtimeBucket[routes[index].routeKey] = nil
    end
end

local function SaveMapBucket(self, mapID)
    if type(mapID) ~= "number" then
        return false
    end

    local db = EnsurePersistentRootTable()
    db.maps = type(db.maps) == "table" and db.maps or {}
    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" or next(runtimeBucket) == nil then
        db.maps[mapID] = nil
        return true
    end

    db.maps[mapID] = db.maps[mapID] or {}
    db.maps[mapID].routes = {}
    for routeKey, route in pairs(runtimeBucket) do
        if type(routeKey) == "string" and type(route) == "table" then
            db.maps[mapID].routes[routeKey] = {
                routeKey = route.routeKey,
                mapID = route.mapID,
                startX = route.startX,
                startY = route.startY,
                endX = route.endX,
                endY = route.endY,
                routeFamilyKey = route.routeFamilyKey,
                landingKey = route.landingKey,
                alertToken = route.alertToken,
                observationCount = route.observationCount,
                sampleCount = route.sampleCount,
                verificationCount = route.verificationCount,
                verifiedPredictionCount = route.verifiedPredictionCount,
                createdAt = route.createdAt,
                updatedAt = route.updatedAt,
                source = route.source,
                continuityConfirmed = route.continuityConfirmed == true,
                startSource = route.startSource,
                endSource = route.endSource,
                startConfirmed = route.startConfirmed == true,
                endConfirmed = route.endConfirmed == true,
                lastPredictionVerified = route.lastPredictionVerified == true,
                mergedRouteCount = route.mergedRouteCount,
                representativeLegacyRouteKey = route.representativeLegacyRouteKey,
            }
        end
    end
    return true
end

local function InvalidateTrackGroups(self, mapID)
    self.trackGroupsByMap = self.trackGroupsByMap or {}
    if type(mapID) == "number" then
        self.trackGroupsByMap[mapID] = nil
        return true
    end
    self.trackGroupsByMap = {}
    return true
end

local function FindMatchingRoute(runtimeBucket, store, candidateRoute)
    if type(runtimeBucket) ~= "table" or type(candidateRoute) ~= "table" then
        return nil
    end

    local exactRoute = runtimeBucket[candidateRoute.routeKey]
    if type(exactRoute) == "table" then
        return exactRoute, candidateRoute.routeKey, "route_key"
    end

    for routeKey, route in pairs(runtimeBucket) do
        if type(route) == "table"
            and route.routeFamilyKey == candidateRoute.routeFamilyKey
            and route.landingKey == candidateRoute.landingKey then
            return route, routeKey, "canonical_identity"
        end
    end

    local bestRoute = nil
    local bestKey = nil
    for routeKey, route in pairs(runtimeBucket) do
        if type(route) == "table" and DoesCanonicalRouteMatch(store, route, candidateRoute) == true then
            if not bestRoute or CompareRepresentativePriority(route, bestRoute) then
                bestRoute = route
                bestKey = routeKey
            end
        end
    end
    if type(bestRoute) == "table" then
        return bestRoute, bestKey, "geometry"
    end

    return nil
end

local function UpsertCanonicalRouteIntoBucket(store, runtimeBucket, candidateRoute)
    local matchedRoute, matchedKey, matchMode = FindMatchingRoute(runtimeBucket, store, candidateRoute)
    if type(matchedRoute) == "table" and type(matchedKey) == "string" then
        local mergedRoute = BuildMergedCanonicalRoute(matchedRoute, candidateRoute)
        local inputRouteKey = candidateRoute.representativeLegacyRouteKey or candidateRoute.routeKey
        if HasRouteChanged(matchedRoute, mergedRoute) ~= true then
            return false, matchedRoute, {
                status = "unchanged",
                matchMode = matchMode,
                inputRouteKey = inputRouteKey,
                storedRouteKey = matchedRoute.routeKey,
                routeFamilyKey = matchedRoute.routeFamilyKey,
                landingKey = matchedRoute.landingKey,
                alertToken = matchedRoute.alertToken,
            }
        end

        runtimeBucket[matchedKey] = nil
        mergedRoute.routeKey = matchedKey
        runtimeBucket[matchedKey] = mergedRoute
        return true, runtimeBucket[matchedKey], {
            status = "updated_canonical_route",
            matchMode = matchMode,
            inputRouteKey = inputRouteKey,
            storedRouteKey = matchedKey,
            routeFamilyKey = mergedRoute.routeFamilyKey,
            landingKey = mergedRoute.landingKey,
            alertToken = mergedRoute.alertToken,
        }
    end

    runtimeBucket[candidateRoute.routeKey] = candidateRoute
    return true, runtimeBucket[candidateRoute.routeKey], {
        status = "created_canonical_route",
        matchMode = "new",
        inputRouteKey = candidateRoute.representativeLegacyRouteKey or candidateRoute.routeKey,
        storedRouteKey = candidateRoute.routeKey,
        routeFamilyKey = candidateRoute.routeFamilyKey,
        landingKey = candidateRoute.landingKey,
        alertToken = candidateRoute.alertToken,
    }
end

local function ValidatePersistentState(db)
    if type(db) ~= "table" or tonumber(db.schemaVersion) ~= AirdropTrajectoryStore.DB_SCHEMA_VERSION then
        return false
    end
    if type(db.meta) ~= "table" or type(db.maps) ~= "table" then
        return false
    end

    for _, savedMapData in pairs(db.maps) do
        if type(savedMapData) ~= "table" or type(savedMapData.routes) ~= "table" then
            return false
        end
        for routeKey, savedRoute in pairs(savedMapData.routes) do
            if type(routeKey) ~= "string" or type(savedRoute) ~= "table" then
                return false
            end
            local normalized = NormalizeCanonicalRouteRecord(savedRoute, savedRoute.source, savedRoute.updatedAt)
            if IsRouteRecordValid(normalized) ~= true or IsReliableRoute(normalized) ~= true then
                return false
            end
        end
    end
    return true
end

local function BuildMigratedPersistentState(store, legacyState)
    local migratedState = CreateEmptyPersistentState()
    local now = Utils:GetCurrentTimestamp()
    migratedState.meta.lastResetAt = now
    migratedState.meta.migratedAt = now
    migratedState.meta.migratedFromSchemaVersion = tonumber(legacyState and legacyState.schemaVersion) or 0
    migratedState.migrationBackup = DeepCopyTable(legacyState)

    local legacyMaps = type(legacyState) == "table" and legacyState.maps or nil
    if type(legacyMaps) ~= "table" then
        return migratedState
    end

    for rawMapID, savedMapData in pairs(legacyMaps) do
        local mapID = tonumber(rawMapID)
        local savedRoutes = type(savedMapData) == "table" and savedMapData.routes or nil
        if mapID and type(savedRoutes) == "table" then
            local legacyRoutes = {}
            for savedRouteKey, savedRoute in pairs(savedRoutes) do
                local rawRoute = nil
                if type(savedRoute) == "table" then
                    rawRoute = DeepCopyTable(savedRoute)
                    rawRoute.mapID = tonumber(rawRoute.mapID) or mapID
                    rawRoute.routeKey = type(rawRoute.routeKey) == "string" and rawRoute.routeKey ~= ""
                        and rawRoute.routeKey
                        or (type(savedRouteKey) == "string" and savedRouteKey ~= "" and savedRouteKey or nil)
                    rawRoute.representativeLegacyRouteKey = rawRoute.routeKey
                end
                local normalizedLegacyRoute = NormalizeMigrationMemberRoute(rawRoute)
                if IsRouteRecordValid(normalizedLegacyRoute) == true
                    and IsReliableRoute(normalizedLegacyRoute) == true then
                    legacyRoutes[#legacyRoutes + 1] = normalizedLegacyRoute
                end
            end

            if #legacyRoutes > 0 then
                local runtimeBucket = {}
                local canonicalRoutes = BuildCanonicalRoutesFromLegacyRoutes(store, mapID, legacyRoutes)
                for _, canonicalRoute in ipairs(canonicalRoutes) do
                    local normalizedCanonicalRoute = NormalizeCanonicalRouteRecord(canonicalRoute, canonicalRoute.source, canonicalRoute.updatedAt)
                    if IsRouteRecordValid(normalizedCanonicalRoute) == true
                        and IsReliableRoute(normalizedCanonicalRoute) == true then
                        UpsertCanonicalRouteIntoBucket(store, runtimeBucket, normalizedCanonicalRoute)
                    end
                end

                migratedState.maps[mapID] = { routes = {} }
                for routeKey, route in pairs(runtimeBucket) do
                    migratedState.maps[mapID].routes[routeKey] = {
                        routeKey = route.routeKey,
                        mapID = route.mapID,
                        startX = route.startX,
                        startY = route.startY,
                        endX = route.endX,
                        endY = route.endY,
                        routeFamilyKey = route.routeFamilyKey,
                        landingKey = route.landingKey,
                        alertToken = route.alertToken,
                        observationCount = route.observationCount,
                        sampleCount = route.sampleCount,
                        verificationCount = route.verificationCount,
                        verifiedPredictionCount = route.verifiedPredictionCount,
                        createdAt = route.createdAt,
                        updatedAt = route.updatedAt,
                        source = route.source,
                        continuityConfirmed = route.continuityConfirmed == true,
                        startSource = route.startSource,
                        endSource = route.endSource,
                        startConfirmed = route.startConfirmed == true,
                        endConfirmed = route.endConfirmed == true,
                        lastPredictionVerified = route.lastPredictionVerified == true,
                        mergedRouteCount = route.mergedRouteCount,
                        representativeLegacyRouteKey = route.representativeLegacyRouteKey,
                    }
                end
            end
        end
    end

    return migratedState
end

local function EnsureTrajectoryPersistentState(store)
    local db = EnsurePersistentRootTable()
    ClearLegacyPersistentBucket()

    if ValidatePersistentState(db) == true then
        db.schemaVersion = AirdropTrajectoryStore.DB_SCHEMA_VERSION
        db.meta.storageKind = "canonical"
        if type(db.maps) ~= "table" then
            db.maps = {}
        end
        return db
    end

    local rebuildSource = nil
    if tonumber(db.schemaVersion) == AirdropTrajectoryStore.DB_SCHEMA_VERSION
        and type(db.migrationBackup) == "table" then
        rebuildSource = db.migrationBackup
    else
        rebuildSource = DeepCopyTable(db)
    end

    local migratedState = BuildMigratedPersistentState(store, rebuildSource)
    CRATETRACKERZK_TRAJECTORY_DB = migratedState
    return CRATETRACKERZK_TRAJECTORY_DB
end

local function SortTrackGroups(routes)
    table.sort(routes, function(left, right)
        local leftUpdatedAt = math.max(0, math.floor(tonumber(left and left.updatedAt) or 0))
        local rightUpdatedAt = math.max(0, math.floor(tonumber(right and right.updatedAt) or 0))
        if leftUpdatedAt ~= rightUpdatedAt then
            return leftUpdatedAt > rightUpdatedAt
        end
        return tostring(left and left.routeKey or "") < tostring(right and right.routeKey or "")
    end)
    return routes
end

local function BuildTrackGroupCacheForMap(self, mapID)
    if type(mapID) ~= "number" then
        return {
            trackGroups = {},
            predictionTracks = {},
        }
    end

    self.trackGroupsByMap = self.trackGroupsByMap or {}
    if type(self.trackGroupsByMap[mapID]) == "table" then
        return self.trackGroupsByMap[mapID]
    end

    local runtimeBucket = self.routesByMap and self.routesByMap[mapID] or nil
    if type(runtimeBucket) ~= "table" then
        local emptyCache = {
            trackGroups = {},
            predictionTracks = {},
        }
        self.trackGroupsByMap[mapID] = emptyCache
        return emptyCache
    end

    local canonicalRoutes = {}
    for _, route in pairs(runtimeBucket) do
        if IsReliableRoute(route) == true then
            canonicalRoutes[#canonicalRoutes + 1] = route
        end
    end

    local rawTrackGroups = BuildTrackGroupsFromRoutes(self, canonicalRoutes)
    local aggregatedTrackGroups = {}
    for _, trackGroup in ipairs(rawTrackGroups) do
        local aggregatedTrackGroup = BuildTrackGroupAggregate(trackGroup)
        if type(aggregatedTrackGroup) == "table" then
            aggregatedTrackGroups[#aggregatedTrackGroups + 1] = aggregatedTrackGroup
        end
    end
    SortTrackGroups(aggregatedTrackGroups)

    local cache = {
        trackGroups = aggregatedTrackGroups,
        predictionTracks = aggregatedTrackGroups,
    }
    self.trackGroupsByMap[mapID] = cache
    return cache
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
            for routeKey, savedRoute in pairs(savedRoutes) do
                local routeState = nil
                if type(savedRoute) == "table" then
                    routeState = DeepCopyTable(savedRoute)
                    routeState.mapID = tonumber(routeState.mapID) or mapID
                    routeState.routeKey = type(routeState.routeKey) == "string" and routeState.routeKey ~= ""
                        and routeState.routeKey
                        or (type(routeKey) == "string" and routeKey ~= "" and routeKey or nil)
                end
                local normalized = NormalizeCanonicalRouteRecord(routeState, routeState and routeState.source, routeState and routeState.updatedAt)
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
    self.trackGroupsByMap = {}

    local trajectoryState = EnsureTrajectoryPersistentState(self)
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
    InvalidateTrackGroups(self, mapID)
    return true, route
end

function AirdropTrajectoryStore:Reset()
    self.routesByMap = {}
    self.trackGroupsByMap = {}
    return true
end

function AirdropTrajectoryStore:IsUsingIndependentPersistentStore()
    local trajectoryState = EnsureTrajectoryPersistentState(self)
    return type(trajectoryState) == "table"
        and type(trajectoryState.maps) == "table"
        and type(trajectoryState.meta) == "table"
        and trajectoryState.meta.storageKind == "canonical"
end

function AirdropTrajectoryStore:ClearPersistentData()
    CRATETRACKERZK_TRAJECTORY_DB = CreateEmptyPersistentState()
    self.routesByMap = {}
    self.trackGroupsByMap = {}
    ClearLegacyPersistentBucket()
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

function AirdropTrajectoryStore:GetPredictionTracks(mapID)
    if type(mapID) ~= "number" then
        return {}
    end

    local cache = BuildTrackGroupCacheForMap(self, mapID)
    local routes = {}
    for _, route in ipairs(cache.predictionTracks or {}) do
        routes[#routes + 1] = CreateTrackGroupRecord(route)
    end
    return routes
end

function AirdropTrajectoryStore:GetPredictionTrackReferences(mapID)
    if type(mapID) ~= "number" then
        return {}
    end

    local cache = BuildTrackGroupCacheForMap(self, mapID)
    return cache.predictionTracks or {}
end

function AirdropTrajectoryStore:GetTrackGroups(mapID)
    if type(mapID) ~= "number" then
        return {}
    end

    local cache = BuildTrackGroupCacheForMap(self, mapID)
    local trackGroups = {}
    for _, route in ipairs(cache.trackGroups or {}) do
        trackGroups[#trackGroups + 1] = CreateTrackGroupRecord(route)
    end
    return trackGroups
end

function AirdropTrajectoryStore:AppendRoutesTo(outRoutes)
    outRoutes = type(outRoutes) == "table" and outRoutes or {}

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
    outRoutes = type(outRoutes) == "table" and outRoutes or {}

    for _, route in ipairs(self:AppendRoutesTo({})) do
        if self:IsShareEligible(route) == true then
            outRoutes[#outRoutes + 1] = route
        end
    end
    return outRoutes
end

function AirdropTrajectoryStore:UpsertRoute(mapID, routeState, source, currentTime)
    local normalized = NormalizeCanonicalRouteRecord(routeState, source, currentTime)
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
    local changed, routeRecord, storeMeta = UpsertCanonicalRouteIntoBucket(self, runtimeBucket, normalized)
    if changed == true then
        PruneMapBucket(self, resolvedMapID)
        SaveMapBucket(self, resolvedMapID)
        InvalidateTrackGroups(self, resolvedMapID)
        routeRecord = runtimeBucket[storeMeta and storeMeta.storedRouteKey or normalized.routeKey] or routeRecord
    end
    return changed == true, routeRecord, storeMeta
end

function AirdropTrajectoryStore:GetPredictionRoutes(mapID)
    return self:GetPredictionTracks(mapID)
end

function AirdropTrajectoryStore:GetRouteFamilies(mapID)
    return self:GetTrackGroups(mapID)
end

return AirdropTrajectoryStore
