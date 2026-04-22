-- SharedSyncSchedulerHelpers.lua - 共享同步调度通用 helper

local SharedSyncSchedulerHelpers = BuildEnv("SharedSyncSchedulerHelpers")

local function NormalizeDelay(delaySeconds)
    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then
        delay = 0
    end
    return delay
end

function SharedSyncSchedulerHelpers:ClearArray(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for index = #buffer, 1, -1 do
        buffer[index] = nil
    end
    return buffer
end

function SharedSyncSchedulerHelpers:ClearMap(buffer)
    if type(buffer) ~= "table" then
        return {}
    end
    for key in pairs(buffer) do
        buffer[key] = nil
    end
    return buffer
end

function SharedSyncSchedulerHelpers:BuildRequestKey(sender, requestID)
    return tostring(sender or "unknown") .. ":" .. tostring(requestID or "unknown")
end

function SharedSyncSchedulerHelpers:NormalizeJitterDelay(minDelay, maxDelay)
    local resolvedMin = tonumber(minDelay) or 0
    local resolvedMax = tonumber(maxDelay) or resolvedMin
    if resolvedMax < resolvedMin then
        resolvedMax = resolvedMin
    end
    if resolvedMin < 0 then
        resolvedMin = 0
    end
    if resolvedMax <= resolvedMin then
        return resolvedMin
    end
    return resolvedMin + (math.random() * (resolvedMax - resolvedMin))
end

function SharedSyncSchedulerHelpers:GetTeamContextKey(channelService)
    local resolved = channelService
        and channelService.GetResolvedChannelInfo
        and channelService:GetResolvedChannelInfo()
        or nil
    local distribution = resolved and resolved.distribution or nil
    if type(distribution) ~= "string" or distribution == "" then
        return nil
    end
    return distribution
end

function SharedSyncSchedulerHelpers:CancelOwnedTimer(owner, fieldName)
    if type(owner) ~= "table" or type(fieldName) ~= "string" or fieldName == "" then
        return false
    end
    local timer = owner[fieldName]
    if type(timer) == "table" and timer.Cancel then
        timer:Cancel()
    end
    owner[fieldName] = nil
    return true
end

function SharedSyncSchedulerHelpers:ScheduleOwnedTimer(owner, fieldName, delaySeconds, callback)
    if type(owner) ~= "table" or type(fieldName) ~= "string" or fieldName == "" or type(callback) ~= "function" then
        return false
    end

    self:CancelOwnedTimer(owner, fieldName)
    local delay = NormalizeDelay(delaySeconds)
    if C_Timer and C_Timer.NewTimer then
        owner[fieldName] = C_Timer.NewTimer(delay, function()
            owner[fieldName] = nil
            callback()
        end)
        return true
    end

    if C_Timer and C_Timer.After then
        local token = {}
        owner[fieldName] = token
        C_Timer.After(delay, function()
            if owner[fieldName] ~= token then
                return
            end
            owner[fieldName] = nil
            callback()
        end)
        return true
    end

    callback()
    return true
end

return SharedSyncSchedulerHelpers
