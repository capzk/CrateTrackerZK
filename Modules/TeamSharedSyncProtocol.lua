-- TeamSharedSyncProtocol.lua - 团队共享缓存同步协议

local TeamSharedSyncProtocol = BuildEnv("TeamSharedSyncProtocol")

TeamSharedSyncProtocol.ADDON_PREFIX = "CTKZK_PSYNC"
TeamSharedSyncProtocol.MESSAGE_TYPE = "PHASE_AIRDROP"
TeamSharedSyncProtocol.PROTOCOL_VERSION = 1

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

function TeamSharedSyncProtocol:ParsePayloadInto(prefix, payload, outState)
    if prefix ~= self.ADDON_PREFIX or type(payload) ~= "string" or type(outState) ~= "table" then
        return nil
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
    return outState
end

return TeamSharedSyncProtocol
