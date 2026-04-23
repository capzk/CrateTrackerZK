-- TeamCommListener.lua - 读取隐藏插件同步消息，更新空投时间状态

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TeamCommListener = BuildEnv('TeamCommListener');

local HiddenSyncAuditService = BuildEnv("HiddenSyncAuditService");
local HiddenSyncTransport = BuildEnv("HiddenSyncTransport");
local TeamCommMapCache = BuildEnv("TeamCommMapCache");
local TeamCommMessageService = BuildEnv("TeamCommMessageService");

TeamCommListener.isInitialized = false;
TeamCommListener.ADDON_PREFIX = "CTKZK_SYNC";
TeamCommListener.ADDON_MESSAGE_TYPE_AIRDROP = "AIRDROP";
TeamCommListener.ADDON_MESSAGE_TYPE_PHASE_CLAIM = "PHASE_CLAIM";
TeamCommListener.ADDON_MESSAGE_TYPE_PHASE_ACK = "PHASE_ACK";
TeamCommListener.ADDON_PROTOCOL_VERSION = 2;
TeamCommListener.addonPrefixRegistered = false;
TeamCommListener.addonPrefixRegistrationAttempted = false;
TeamCommListener.playerName = nil;
TeamCommListener.fullPlayerName = nil;
TeamCommListener.syncStateBuffer = TeamCommListener.syncStateBuffer or {};

local function ResetSyncStateBuffer(outState)
    if type(outState) ~= "table" then
        return nil
    end
    outState.messageType = nil
    outState.expansionID = nil
    outState.mapID = nil
    outState.phaseID = nil
    outState.timestamp = nil
    outState.objectGUID = nil
    return outState
end

function TeamCommListener:CanEnableHiddenSync()
    if not HiddenSyncTransport or HiddenSyncTransport.IsNonInstanceTeamContext == nil then
        return false
    end
    if HiddenSyncTransport:IsNonInstanceTeamContext() ~= true then
        return false
    end
    return Area and Area.IsActive and Area:IsActive() == true or false
end

function TeamCommListener:CanReceiveHiddenSync()
    if not HiddenSyncTransport or HiddenSyncTransport.IsNonInstanceTeamContext == nil then
        return false
    end
    if HiddenSyncTransport:IsNonInstanceTeamContext() ~= true then
        return false
    end
    if Area and Area.CanProcessTeamMessages then
        return Area:CanProcessTeamMessages() == true
    end
    return true
end

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

function TeamCommListener:RegisterAddonPrefix()
    if self.addonPrefixRegistered == true then
        return true;
    end
    if self.CanReceiveHiddenSync and self:CanReceiveHiddenSync() ~= true then
        return false;
    end
    if self.addonPrefixRegistrationAttempted == true then
        return false;
    end

    if HiddenSyncTransport and HiddenSyncTransport.EnsureAddonPrefix then
        return HiddenSyncTransport:EnsureAddonPrefix(self, self.ADDON_PREFIX) == true;
    end
    return false;
end

function TeamCommListener:BuildAirdropPayload(syncState)
    if type(syncState) ~= "table" then
        return nil
    end

    local mapID = tonumber(syncState.mapID)
    local timestamp = tonumber(syncState.timestamp)
    local objectGUID = syncState.objectGUID
    if not mapID
        or not timestamp then
        return nil
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return nil
    end

    return table.concat({
        self.ADDON_MESSAGE_TYPE_AIRDROP,
        tostring(self.ADDON_PROTOCOL_VERSION),
        tostring(math.floor(mapID)),
        tostring(math.floor(timestamp)),
        EncodePayloadField(objectGUID),
    }, "|")
end

function TeamCommListener:BuildPhaseAlertPayload(syncState, messageType)
    if type(syncState) ~= "table" then
        return nil
    end
    if messageType ~= self.ADDON_MESSAGE_TYPE_PHASE_CLAIM
        and messageType ~= self.ADDON_MESSAGE_TYPE_PHASE_ACK then
        return nil
    end

    local expansionID = syncState.expansionID
    local mapID = tonumber(syncState.mapID)
    local phaseID = syncState.phaseID
    local timestamp = tonumber(syncState.timestamp)
    if type(expansionID) ~= "string" or expansionID == "" then
        return nil
    end
    if not mapID or type(phaseID) ~= "string" or phaseID == "" or not timestamp then
        return nil
    end

    return table.concat({
        messageType,
        tostring(self.ADDON_PROTOCOL_VERSION),
        EncodePayloadField(expansionID),
        tostring(math.floor(mapID)),
        EncodePayloadField(phaseID),
        tostring(math.floor(timestamp)),
    }, "|")
end

function TeamCommListener:ParseAddonPayloadInto(prefix, payload, outState)
    if prefix ~= self.ADDON_PREFIX or type(payload) ~= "string" then
        return nil
    end
    if type(outState) ~= "table" then
        return nil
    end

    ResetSyncStateBuffer(outState)

    local messageType = payload:match("^([^|]+)|")
    if messageType == self.ADDON_MESSAGE_TYPE_AIRDROP then
        local parsedMessageType, protocolVersionText, mapIDText, timestampText, objectGUIDText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]*)$")
        local protocolVersion = tonumber(protocolVersionText)
        local mapID = tonumber(mapIDText)
        local timestamp = tonumber(timestampText)
        local objectGUID = DecodePayloadField(objectGUIDText)
        if parsedMessageType ~= self.ADDON_MESSAGE_TYPE_AIRDROP
            or protocolVersion ~= self.ADDON_PROTOCOL_VERSION
            or not mapID
            or not timestamp then
            return nil
        end
        if type(objectGUID) ~= "string" or objectGUID == "" then
            return nil
        end

        outState.messageType = parsedMessageType
        outState.mapID = mapID
        outState.timestamp = timestamp
        outState.objectGUID = objectGUID
        return outState
    end

    if messageType == self.ADDON_MESSAGE_TYPE_PHASE_CLAIM
        or messageType == self.ADDON_MESSAGE_TYPE_PHASE_ACK then
        local parsedMessageType, protocolVersionText, expansionIDText, mapIDText, phaseIDText, timestampText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        local protocolVersion = tonumber(protocolVersionText)
        local expansionID = DecodePayloadField(expansionIDText)
        local mapID = tonumber(mapIDText)
        local phaseID = DecodePayloadField(phaseIDText)
        local timestamp = tonumber(timestampText)
        if parsedMessageType ~= messageType
            or protocolVersion ~= self.ADDON_PROTOCOL_VERSION
            or type(expansionID) ~= "string"
            or expansionID == ""
            or not mapID
            or type(phaseID) ~= "string"
            or phaseID == ""
            or not timestamp then
            return nil
        end

        outState.messageType = parsedMessageType
        outState.expansionID = expansionID
        outState.mapID = mapID
        outState.phaseID = phaseID
        outState.timestamp = timestamp
        return outState
    end

    return nil
end

function TeamCommListener:Initialize()
    self.playerName = nil;
    self.fullPlayerName = nil;
    if TeamCommMapCache and TeamCommMapCache.EnsurePlayerIdentity then
        TeamCommMapCache:EnsurePlayerIdentity(self);
    end
    self:RegisterAddonPrefix();

    self.isInitialized = true;
end

function TeamCommListener:SendConfirmedSync(syncState, chatType)
    local canEnable = self:CanEnableHiddenSync() == true
    if canEnable ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = "CTKZK_SYNC",
                direction = "send",
                status = "blocked",
                note = "hidden_sync_disabled",
                messageType = syncState and self.ADDON_MESSAGE_TYPE_AIRDROP or nil,
                mapID = syncState and syncState.mapID or nil,
                objectGUID = syncState and syncState.objectGUID or nil,
            })
        end
        return false
    end
    local prefixReady = self:RegisterAddonPrefix() == true
    if prefixReady ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = "CTKZK_SYNC",
                direction = "send",
                status = "blocked",
                note = "prefix_not_ready",
                messageType = syncState and self.ADDON_MESSAGE_TYPE_AIRDROP or nil,
                mapID = syncState and syncState.mapID or nil,
                objectGUID = syncState and syncState.objectGUID or nil,
            })
        end
        return false
    end

    local distribution = HiddenSyncTransport and HiddenSyncTransport.ResolveDistribution and HiddenSyncTransport:ResolveDistribution(chatType) or nil
    local payload = self:BuildAirdropPayload(syncState)
    if not distribution or type(payload) ~= "string" or payload == "" then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = "CTKZK_SYNC",
                direction = "send",
                status = "failed",
                note = "payload_or_distribution_invalid",
                messageType = self.ADDON_MESSAGE_TYPE_AIRDROP,
                distribution = distribution,
                mapID = syncState and syncState.mapID or nil,
                objectGUID = syncState and syncState.objectGUID or nil,
                payload = payload,
            })
        end
        return false
    end

    local sent = HiddenSyncTransport
        and HiddenSyncTransport.SendAddonPayload
        and HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, payload, distribution)
        or false
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = "CTKZK_SYNC",
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.ADDON_PREFIX,
            messageType = self.ADDON_MESSAGE_TYPE_AIRDROP,
            distribution = distribution,
            mapID = syncState and syncState.mapID or nil,
            objectGUID = syncState and syncState.objectGUID or nil,
            payload = payload,
        })
    end
    return sent
end

function TeamCommListener:SendPhaseAlertClaim(syncState, chatType)
    if self:CanEnableHiddenSync() ~= true then
        return false
    end
    if self:RegisterAddonPrefix() ~= true then
        return false
    end

    local distribution = HiddenSyncTransport and HiddenSyncTransport.ResolveDistribution and HiddenSyncTransport:ResolveDistribution(chatType) or nil
    local payload = self:BuildPhaseAlertPayload(syncState, self.ADDON_MESSAGE_TYPE_PHASE_CLAIM)
    if not distribution or type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent = HiddenSyncTransport
        and HiddenSyncTransport.SendAddonPayload
        and HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, payload, distribution)
        or false
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = "CTKZK_SYNC",
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.ADDON_PREFIX,
            messageType = self.ADDON_MESSAGE_TYPE_PHASE_CLAIM,
            distribution = distribution,
            expansionID = syncState and syncState.expansionID or nil,
            mapID = syncState and syncState.mapID or nil,
            phaseID = syncState and syncState.phaseID or nil,
            payload = payload,
        })
    end
    return sent
end

function TeamCommListener:SendPhaseAlertAck(syncState, chatType)
    if self:CanEnableHiddenSync() ~= true then
        return false
    end
    if self:RegisterAddonPrefix() ~= true then
        return false
    end

    local distribution = HiddenSyncTransport and HiddenSyncTransport.ResolveDistribution and HiddenSyncTransport:ResolveDistribution(chatType) or nil
    local payload = self:BuildPhaseAlertPayload(syncState, self.ADDON_MESSAGE_TYPE_PHASE_ACK)
    if not distribution or type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent = HiddenSyncTransport
        and HiddenSyncTransport.SendAddonPayload
        and HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, payload, distribution)
        or false
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = "CTKZK_SYNC",
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.ADDON_PREFIX,
            messageType = self.ADDON_MESSAGE_TYPE_PHASE_ACK,
            distribution = distribution,
            expansionID = syncState and syncState.expansionID or nil,
            mapID = syncState and syncState.mapID or nil,
            phaseID = syncState and syncState.phaseID or nil,
            payload = payload,
        })
    end
    return sent
end

function TeamCommListener:HandleAddonEvent(event, prefix, payload, chatType, sender)
    if self.CanReceiveHiddenSync and self:CanReceiveHiddenSync() ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = "CTKZK_SYNC",
                direction = "recv",
                status = "blocked",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "receive_gate_closed",
            })
        end
        return false;
    end
    if not self.isInitialized then
        self:Initialize();
    end
    if not HiddenSyncTransport
        or not HiddenSyncTransport.IsSupportedTeamChatType
        or HiddenSyncTransport:IsSupportedTeamChatType(chatType) ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = "CTKZK_SYNC",
                direction = "recv",
                status = "ignored",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "unsupported_chat_type",
            })
        end
        return false;
    end

    self.syncStateBuffer = self.syncStateBuffer or {};
    local syncState = self:ParseAddonPayloadInto(prefix, payload, self.syncStateBuffer);
    if not syncState then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = "CTKZK_SYNC",
                direction = "recv",
                status = "ignored",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "parse_failed",
            })
        end
        return false;
    end

    local processed = false
    if TeamCommMessageService and TeamCommMessageService.ProcessSync then
        processed = TeamCommMessageService:ProcessSync(self, syncState, chatType, sender) == true;
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = "CTKZK_SYNC",
            direction = "recv",
            status = processed == true and "processed" or "ignored",
            prefix = prefix,
            messageType = syncState.messageType,
            chatType = chatType,
            sender = sender,
            expansionID = syncState.expansionID,
            mapID = syncState.mapID,
            phaseID = syncState.phaseID,
            objectGUID = syncState.objectGUID,
            payload = payload,
        })
    end
    return processed == true;
end

return TeamCommListener;
