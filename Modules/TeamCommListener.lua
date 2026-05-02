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
local AirdropEventService = BuildEnv("AirdropEventService");

TeamCommListener.isInitialized = false;
TeamCommListener.ADDON_PREFIX = "CTKZK_SYNC";
TeamCommListener.ADDON_MESSAGE_TYPE_AIRDROP = "AIRDROP";
TeamCommListener.ADDON_MESSAGE_TYPE_PHASE_CLAIM = "PHASE_CLAIM";
TeamCommListener.ADDON_MESSAGE_TYPE_PHASE_ACK = "PHASE_ACK";
TeamCommListener.ADDON_PROTOCOL_VERSION = 3;
TeamCommListener.LEGACY_AIRDROP_PROTOCOL_VERSION = 2;
TeamCommListener.PHASE_ALERT_PROTOCOL_VERSION = 2;
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
    outState.timeType = nil
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

local function ResolveAuditNoteForSend(sent, resultCode)
    if sent == true then
        return nil
    end
    return resultCode
end

function TeamCommListener:RegisterAddonPrefix()
    if self.CanReceiveHiddenSync and self:CanReceiveHiddenSync() ~= true then
        return false;
    end

    if HiddenSyncTransport and HiddenSyncTransport.EnsureAddonPrefix then
        return HiddenSyncTransport:EnsureAddonPrefix(self, self.ADDON_PREFIX) == true;
    end
    return false;
end

function TeamCommListener:BuildAirdropPayload(syncState, protocolVersion)
    if type(syncState) ~= "table" then
        return nil
    end

    local resolvedProtocolVersion = tonumber(protocolVersion) or self.ADDON_PROTOCOL_VERSION
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

    if resolvedProtocolVersion == self.LEGACY_AIRDROP_PROTOCOL_VERSION then
        return table.concat({
            self.ADDON_MESSAGE_TYPE_AIRDROP,
            tostring(self.LEGACY_AIRDROP_PROTOCOL_VERSION),
            tostring(math.floor(mapID)),
            tostring(math.floor(timestamp)),
            EncodePayloadField(objectGUID),
        }, "|")
    end

    local timeType = AirdropEventService
        and AirdropEventService.NormalizeTimeType
        and AirdropEventService:NormalizeTimeType(syncState.timeType, syncState.source)
        or syncState.timeType
    if type(timeType) ~= "string" or timeType == "" then
        return nil
    end

    return table.concat({
        self.ADDON_MESSAGE_TYPE_AIRDROP,
        tostring(resolvedProtocolVersion),
        tostring(math.floor(mapID)),
        tostring(math.floor(timestamp)),
        EncodePayloadField(objectGUID),
        EncodePayloadField(timeType),
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
        tostring(self.PHASE_ALERT_PROTOCOL_VERSION),
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
        local parsedMessageType, protocolVersionText, mapIDText, timestampText, objectGUIDText, timeTypeText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]*)|([^|]*)$")
        local protocolVersion = tonumber(protocolVersionText)
        local mapID = tonumber(mapIDText)
        local timestamp = tonumber(timestampText)
        local objectGUID = DecodePayloadField(objectGUIDText)
        if parsedMessageType == self.ADDON_MESSAGE_TYPE_AIRDROP
            and protocolVersion == self.ADDON_PROTOCOL_VERSION
            and mapID
            and timestamp
            and type(objectGUID) == "string"
            and objectGUID ~= "" then
            outState.messageType = parsedMessageType
            outState.mapID = mapID
            outState.timestamp = timestamp
            outState.objectGUID = objectGUID
            outState.timeType = AirdropEventService
                and AirdropEventService.NormalizeTimeType
                and AirdropEventService:NormalizeTimeType(DecodePayloadField(timeTypeText), nil)
                or DecodePayloadField(timeTypeText)
            return outState
        end

        parsedMessageType, protocolVersionText, mapIDText, timestampText, objectGUIDText =
            payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]*)$")
        protocolVersion = tonumber(protocolVersionText)
        mapID = tonumber(mapIDText)
        timestamp = tonumber(timestampText)
        objectGUID = DecodePayloadField(objectGUIDText)
        if parsedMessageType ~= self.ADDON_MESSAGE_TYPE_AIRDROP
            or protocolVersion ~= self.LEGACY_AIRDROP_PROTOCOL_VERSION
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
        -- 旧 payload 不携带 timeType，无法区分 shout 与 icon。
        -- 为避免把更老客户端发来的 icon 事件误抬升成 shout 权威，
        -- 接收端一律按更保守的 icon_detection 处理。
        outState.timeType = AirdropEventService
            and AirdropEventService.TimeType
            and AirdropEventService.TimeType.ICON_DETECTION
            or "icon_detection"
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
            or protocolVersion ~= self.PHASE_ALERT_PROTOCOL_VERSION
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
                timeType = syncState and syncState.timeType or nil,
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
                timeType = syncState and syncState.timeType or nil,
            })
        end
        return false
    end

    local distribution = HiddenSyncTransport and HiddenSyncTransport.ResolveDistribution and HiddenSyncTransport:ResolveDistribution(chatType) or nil
    local timeType = AirdropEventService
        and AirdropEventService.NormalizeTimeType
        and AirdropEventService:NormalizeTimeType(syncState and syncState.timeType, syncState and syncState.source)
        or (syncState and syncState.timeType)
        or "npc_shout"
    local legacyPayload = nil
    if AirdropEventService and AirdropEventService.IsShoutTimeType and AirdropEventService:IsShoutTimeType(timeType) == true then
        legacyPayload = self:BuildAirdropPayload(syncState, self.LEGACY_AIRDROP_PROTOCOL_VERSION)
    end
    local payload = self:BuildAirdropPayload(syncState, self.ADDON_PROTOCOL_VERSION)
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
                timeType = timeType,
                payload = payload,
            })
        end
        return false
    end

    local sentAny = false
    local function SendAndAuditAirdropPayload(singlePayload)
        local sent, resultCode = false, nil
        if HiddenSyncTransport and HiddenSyncTransport.SendAddonPayload then
            sent, resultCode = HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, singlePayload, distribution)
        end
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
                timeType = timeType,
                payload = singlePayload,
                resultCode = resultCode,
                note = ResolveAuditNoteForSend(sent, resultCode),
            })
        end
        if sent == true then
            sentAny = true
        end
    end

    if type(legacyPayload) == "string" and legacyPayload ~= "" then
        SendAndAuditAirdropPayload(legacyPayload)
    end
    SendAndAuditAirdropPayload(payload)
    return sentAny
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

    local sent, resultCode = false, nil
    if HiddenSyncTransport and HiddenSyncTransport.SendAddonPayload then
        sent, resultCode = HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, payload, distribution)
    end
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
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
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

    local sent, resultCode = false, nil
    if HiddenSyncTransport and HiddenSyncTransport.SendAddonPayload then
        sent, resultCode = HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, payload, distribution)
    end
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
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
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
            timeType = syncState.timeType,
            payload = payload,
        })
    end
    return processed == true;
end

return TeamCommListener;
