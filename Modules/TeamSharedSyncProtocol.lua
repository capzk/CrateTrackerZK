-- TeamSharedSyncProtocol.lua - 团队共享缓存同步协议

local TeamSharedSyncProtocol = BuildEnv("TeamSharedSyncProtocol")

TeamSharedSyncProtocol.ADDON_PREFIX = "CTKZK_PSYNC"
TeamSharedSyncProtocol.MESSAGE_TYPE = "PHASE_AIRDROP"
TeamSharedSyncProtocol.REQUEST_MESSAGE_TYPE = "SYNC_REQUEST"
TeamSharedSyncProtocol.TRAJECTORY_MESSAGE_TYPE = "TRAJECTORY_ROUTE"
TeamSharedSyncProtocol.TRAJECTORY_REQUEST_MESSAGE_TYPE = "TRAJECTORY_REQUEST"
TeamSharedSyncProtocol.TRAJECTORY_ALERT_CLAIM_MESSAGE_TYPE = "TRAJECTORY_ALERT_CLAIM"
TeamSharedSyncProtocol.TRAJECTORY_ALERT_ACK_MESSAGE_TYPE = "TRAJECTORY_ALERT_ACK"
TeamSharedSyncProtocol.PROTOCOL_VERSION = 1
TeamSharedSyncProtocol.COORDINATE_SCALE = 10000

local function EncodePayloadField(value)
    if value == nil then
        return "-"
    end

    local text = tostring(value)
    if text == "" then
        return "-"
    end

    local sanitized = text:gsub("|", "/")
    return sanitized
end

local function DecodePayloadField(value)
    if type(value) ~= "string" or value == "" or value == "-" then
        return nil
    end

    return value
end

function TeamSharedSyncProtocol:BuildPayload(syncState)
    if type(syncState) ~= "table" then
        return nil
    end

    local expansionID = DecodePayloadField(EncodePayloadField(syncState.expansionID))
    local mapID = tonumber(syncState.mapID)
    local phaseID = DecodePayloadField(EncodePayloadField(syncState.phaseID))
    local timestamp = tonumber(syncState.timestamp)
    local objectGUID = DecodePayloadField(EncodePayloadField(syncState.objectGUID))

    if type(expansionID) ~= "string" or expansionID == "" then
        return nil
    end
    if not mapID or mapID <= 0 then
        return nil
    end
    if type(phaseID) ~= "string" or phaseID == "" then
        return nil
    end
    if not timestamp or timestamp <= 0 then
        return nil
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return nil
    end

    return table.concat({
        self.MESSAGE_TYPE,
        tostring(self.PROTOCOL_VERSION),
        EncodePayloadField(expansionID),
        tostring(math.floor(mapID)),
        EncodePayloadField(phaseID),
        tostring(math.floor(timestamp)),
        EncodePayloadField(objectGUID),
    }, "|")
end

function TeamSharedSyncProtocol:BuildRequestPayload(requestState)
    if type(requestState) ~= "table" then
        return nil
    end

    local requestID = DecodePayloadField(EncodePayloadField(requestState.requestID))
    local timestamp = tonumber(requestState.timestamp)
    if type(requestID) ~= "string" or requestID == "" then
        return nil
    end
    if not timestamp or timestamp <= 0 then
        return nil
    end

    return table.concat({
        self.REQUEST_MESSAGE_TYPE,
        tostring(self.PROTOCOL_VERSION),
        EncodePayloadField(requestID),
        tostring(math.floor(timestamp)),
    }, "|")
end

function TeamSharedSyncProtocol:BuildTrajectoryPayload(routeState)
    if type(routeState) ~= "table" then
        return nil
    end

    local mapID = tonumber(routeState.mapID)
    local updatedAt = tonumber(routeState.updatedAt or routeState.timestamp)
    local sampleCount = tonumber(routeState.sampleCount) or 2
    local startConfirmed = routeState.startConfirmed == true and 1 or 0
    local endConfirmed = routeState.endConfirmed == true and 1 or 0
    local scale = tonumber(self.COORDINATE_SCALE) or 10000
    local startX = tonumber(routeState.startX)
    local startY = tonumber(routeState.startY)
    local endX = tonumber(routeState.endX)
    local endY = tonumber(routeState.endY)

    if not mapID or mapID <= 0 or not updatedAt or updatedAt <= 0 then
        return nil
    end
    if type(startX) ~= "number" or type(startY) ~= "number" or type(endX) ~= "number" or type(endY) ~= "number" then
        return nil
    end

    return table.concat({
        self.TRAJECTORY_MESSAGE_TYPE,
        tostring(self.PROTOCOL_VERSION),
        tostring(math.floor(mapID)),
        tostring(math.floor((startX * scale) + 0.5)),
        tostring(math.floor((startY * scale) + 0.5)),
        tostring(math.floor((endX * scale) + 0.5)),
        tostring(math.floor((endY * scale) + 0.5)),
        tostring(math.floor(updatedAt)),
        tostring(math.max(2, math.floor(sampleCount))),
        tostring(startConfirmed),
        tostring(endConfirmed),
    }, "|")
end

function TeamSharedSyncProtocol:BuildTrajectoryRequestPayload(requestState)
    if type(requestState) ~= "table" then
        return nil
    end

    local requestID = DecodePayloadField(EncodePayloadField(requestState.requestID))
    local timestamp = tonumber(requestState.timestamp)
    if type(requestID) ~= "string" or requestID == "" then
        return nil
    end
    if not timestamp or timestamp <= 0 then
        return nil
    end

    return table.concat({
        self.TRAJECTORY_REQUEST_MESSAGE_TYPE,
        tostring(self.PROTOCOL_VERSION),
        EncodePayloadField(requestID),
        tostring(math.floor(timestamp)),
    }, "|")
end

function TeamSharedSyncProtocol:BuildTrajectoryAlertPayload(syncState, messageType)
    if type(syncState) ~= "table" then
        return nil
    end
    if messageType ~= self.TRAJECTORY_ALERT_CLAIM_MESSAGE_TYPE
        and messageType ~= self.TRAJECTORY_ALERT_ACK_MESSAGE_TYPE then
        return nil
    end

    local mapID = tonumber(syncState.mapID)
    local routeKey = DecodePayloadField(EncodePayloadField(syncState.routeKey))
    local objectGUID = DecodePayloadField(EncodePayloadField(syncState.objectGUID))
    local timestamp = tonumber(syncState.timestamp)
    if not mapID or mapID <= 0 or not timestamp or timestamp <= 0 then
        return nil
    end
    if type(routeKey) ~= "string" or routeKey == "" or type(objectGUID) ~= "string" or objectGUID == "" then
        return nil
    end

    return table.concat({
        messageType,
        tostring(self.PROTOCOL_VERSION),
        tostring(math.floor(mapID)),
        EncodePayloadField(routeKey),
        EncodePayloadField(objectGUID),
        tostring(math.floor(timestamp)),
    }, "|")
end

function TeamSharedSyncProtocol:ParsePayloadInto(prefix, payload, outState)
    if prefix ~= self.ADDON_PREFIX or type(payload) ~= "string" or type(outState) ~= "table" then
        return nil
    end

    outState.messageType = nil
    outState.requestID = nil
    outState.expansionID = nil
    outState.mapID = nil
    outState.phaseID = nil
    outState.timestamp = nil
    outState.objectGUID = nil
    outState.startX = nil
    outState.startY = nil
    outState.endX = nil
    outState.endY = nil
    outState.sampleCount = nil
    outState.startConfirmed = nil
    outState.endConfirmed = nil
    outState.routeKey = nil

    local messageType = payload:match("^([^|]+)|")
    if type(messageType) ~= "string" or messageType == "" then
        return nil
    end

    if messageType == self.REQUEST_MESSAGE_TYPE then
        local requestMessageType, requestVersionText, requestIDText, requestTimestampText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        local requestProtocolVersion = tonumber(requestVersionText)
        local requestID = DecodePayloadField(requestIDText)
        local requestTimestamp = tonumber(requestTimestampText)

        if requestMessageType ~= self.REQUEST_MESSAGE_TYPE or requestProtocolVersion ~= self.PROTOCOL_VERSION then
            return nil
        end
        if type(requestID) ~= "string" or requestID == "" then
            return nil
        end
        if not requestTimestamp or requestTimestamp <= 0 then
            return nil
        end

        outState.messageType = requestMessageType
        outState.requestID = requestID
        outState.timestamp = requestTimestamp
        return outState
    end

    if messageType == self.TRAJECTORY_REQUEST_MESSAGE_TYPE then
        local requestMessageType, requestVersionText, requestIDText, requestTimestampText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        local requestProtocolVersion = tonumber(requestVersionText)
        local requestID = DecodePayloadField(requestIDText)
        local requestTimestamp = tonumber(requestTimestampText)

        if requestMessageType ~= self.TRAJECTORY_REQUEST_MESSAGE_TYPE or requestProtocolVersion ~= self.PROTOCOL_VERSION then
            return nil
        end
        if type(requestID) ~= "string" or requestID == "" then
            return nil
        end
        if not requestTimestamp or requestTimestamp <= 0 then
            return nil
        end

        outState.messageType = requestMessageType
        outState.requestID = requestID
        outState.timestamp = requestTimestamp
        return outState
    end

    if messageType == self.TRAJECTORY_MESSAGE_TYPE then
        local parsedMessageType, versionText, mapIDText, startXText, startYText, endXText, endYText, timestampText, sampleCountText, startConfirmedText, endConfirmedText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        local protocolVersion = tonumber(versionText)
        local mapID = tonumber(mapIDText)
        local scale = tonumber(self.COORDINATE_SCALE) or 10000
        local startX = tonumber(startXText)
        local startY = tonumber(startYText)
        local endX = tonumber(endXText)
        local endY = tonumber(endYText)
        local timestamp = tonumber(timestampText)
        local sampleCount = tonumber(sampleCountText)
        local startConfirmed = tonumber(startConfirmedText)
        local endConfirmed = tonumber(endConfirmedText)

        if parsedMessageType ~= self.TRAJECTORY_MESSAGE_TYPE or protocolVersion ~= self.PROTOCOL_VERSION then
            return nil
        end
        if not mapID or mapID <= 0 or not timestamp or timestamp <= 0 then
            return nil
        end
        if not startX or not startY or not endX or not endY then
            return nil
        end

        outState.messageType = parsedMessageType
        outState.mapID = mapID
        outState.startX = startX / scale
        outState.startY = startY / scale
        outState.endX = endX / scale
        outState.endY = endY / scale
        outState.timestamp = timestamp
        outState.sampleCount = math.max(2, math.floor(sampleCount or 2))
        outState.startConfirmed = startConfirmed == 1
        outState.endConfirmed = endConfirmed == 1
        return outState
    end

    if messageType == self.TRAJECTORY_ALERT_CLAIM_MESSAGE_TYPE
        or messageType == self.TRAJECTORY_ALERT_ACK_MESSAGE_TYPE then
        local parsedMessageType, versionText, mapIDText, routeKeyText, objectGUIDText, timestampText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        local protocolVersion = tonumber(versionText)
        local mapID = tonumber(mapIDText)
        local routeKey = DecodePayloadField(routeKeyText)
        local objectGUID = DecodePayloadField(objectGUIDText)
        local timestamp = tonumber(timestampText)

        if parsedMessageType ~= messageType or protocolVersion ~= self.PROTOCOL_VERSION then
            return nil
        end
        if not mapID or mapID <= 0 or not timestamp or timestamp <= 0 then
            return nil
        end
        if type(routeKey) ~= "string" or routeKey == "" or type(objectGUID) ~= "string" or objectGUID == "" then
            return nil
        end

        outState.messageType = parsedMessageType
        outState.mapID = mapID
        outState.routeKey = routeKey
        outState.objectGUID = objectGUID
        outState.timestamp = timestamp
        return outState
    end

    local messageType, versionText, expansionIDText, mapIDText, phaseIDText, timestampText, objectGUIDText =
        payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]*)$")

    local protocolVersion = tonumber(versionText)
    local expansionID = DecodePayloadField(expansionIDText)
    local mapID = tonumber(mapIDText)
    local phaseID = DecodePayloadField(phaseIDText)
    local timestamp = tonumber(timestampText)
    local objectGUID = DecodePayloadField(objectGUIDText)

    if messageType ~= self.MESSAGE_TYPE or protocolVersion ~= self.PROTOCOL_VERSION then
        return nil
    end
    if type(expansionID) ~= "string" or expansionID == "" then
        return nil
    end
    if not mapID or mapID <= 0 then
        return nil
    end
    if type(phaseID) ~= "string" or phaseID == "" then
        return nil
    end
    if not timestamp or timestamp <= 0 then
        return nil
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return nil
    end

    outState.expansionID = expansionID
    outState.mapID = mapID
    outState.phaseID = phaseID
    outState.timestamp = timestamp
    outState.objectGUID = objectGUID
    outState.messageType = messageType
    return outState
end

return TeamSharedSyncProtocol
