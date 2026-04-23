-- AirdropTrajectoryGeometryService.lua - 轨迹几何计算服务

local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")

function AirdropTrajectoryGeometryService:ComputeDistance(x1, y1, x2, y2)
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

function AirdropTrajectoryGeometryService:FormatCoordinatePercent(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" then
        return "0.0"
    end
    return string.format("%.1f", numberValue * 100)
end

function AirdropTrajectoryGeometryService:FormatQuantizedCoordinatePercent(value, scale)
    local numberValue = tonumber(value)
    local resolvedScale = tonumber(scale) or 1000
    if type(numberValue) ~= "number" or resolvedScale <= 0 then
        return "0.0"
    end
    return string.format("%.1f", (numberValue * 100) / resolvedScale)
end

function AirdropTrajectoryGeometryService:ComputeRouteVector(route)
    if type(route) ~= "table" then
        return 0, 0, 0
    end
    local dx = (route.endX or 0) - (route.startX or 0)
    local dy = (route.endY or 0) - (route.startY or 0)
    local length = math.sqrt((dx * dx) + (dy * dy))
    return dx, dy, length
end

function AirdropTrajectoryGeometryService:BuildProjectionContext(route)
    local dx, dy, length = self:ComputeRouteVector(route)
    if type(length) ~= "number" or length <= 0 then
        return nil
    end
    return {
        startX = route.startX,
        startY = route.startY,
        unitX = dx / length,
        unitY = dy / length,
        length = length,
    }
end

function AirdropTrajectoryGeometryService:ProjectPoint(context, x, y)
    if type(context) ~= "table" then
        return nil
    end
    return ((x - context.startX) * context.unitX) + ((y - context.startY) * context.unitY)
end

function AirdropTrajectoryGeometryService:DistancePointToLine(context, x, y)
    if type(context) ~= "table" then
        return math.huge, nil
    end
    local projection = self:ProjectPoint(context, x, y)
    if type(projection) ~= "number" then
        return math.huge, nil
    end
    local closestX = context.startX + (projection * context.unitX)
    local closestY = context.startY + (projection * context.unitY)
    local dx = x - closestX
    local dy = y - closestY
    return math.sqrt((dx * dx) + (dy * dy)), projection
end

function AirdropTrajectoryGeometryService:EvaluateRouteMatch(route, positionX, positionY, directionDX, directionDY, options)
    options = type(options) == "table" and options or {}

    local dx, dy, length = self:ComputeRouteVector(route)
    if type(length) ~= "number" or length <= 0 then
        return nil
    end

    local unitX = dx / length
    local unitY = dy / length
    local relX = positionX - route.startX
    local relY = positionY - route.startY
    local projection = (relX * unitX) + (relY * unitY)
    local projectionMargin = length * (tonumber(options.projectionMargin) or 0.08)
    if projection < -projectionMargin or projection > (length + projectionMargin) then
        return nil
    end

    local closestX = route.startX + (projection * unitX)
    local closestY = route.startY + (projection * unitY)
    local distance = self:ComputeDistance(positionX, positionY, closestX, closestY)
    if distance > (tonumber(options.distanceTolerance) or 0.015) then
        return nil
    end

    local directionLength = self:ComputeDistance(0, 0, directionDX or 0, directionDY or 0)
    if directionLength < (tonumber(options.minDirectionDistance) or 0.0035) then
        return nil
    end

    local directionDot = (((directionDX or 0) * unitX) + ((directionDY or 0) * unitY)) / directionLength
    if directionDot < (tonumber(options.minDirectionDot) or 0.92) then
        return nil
    end

    return {
        route = route,
        distance = distance,
        projection = projection,
        routeLength = length,
        progress = projection / length,
        directionDot = directionDot,
    }
end

function AirdropTrajectoryGeometryService:UpdateAnchorAverage(anchorX, anchorY, sampleCount, positionX, positionY)
    local count = math.max(1, tonumber(sampleCount) or 1)
    local nextCount = count + 1
    return ((anchorX * count) + positionX) / nextCount, ((anchorY * count) + positionY) / nextCount, nextCount
end

return AirdropTrajectoryGeometryService
