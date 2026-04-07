-- TeamCommListener.lua - 读取隐藏插件同步消息，更新空投时间状态

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TeamCommListener = BuildEnv('TeamCommListener');

local HiddenSyncTransport = BuildEnv("HiddenSyncTransport");
local TeamCommMapCache = BuildEnv("TeamCommMapCache");
local TeamCommMessageService = BuildEnv("TeamCommMessageService");

TeamCommListener.isInitialized = false;
TeamCommListener.ADDON_PREFIX = "CTKZK_SYNC";
TeamCommListener.ADDON_MESSAGE_TYPE_AIRDROP = "AIRDROP";
TeamCommListener.ADDON_PROTOCOL_VERSION = 2;
TeamCommListener.addonPrefixRegistered = false;
TeamCommListener.addonPrefixRegistrationAttempted = false;
TeamCommListener.playerName = nil;
TeamCommListener.fullPlayerName = nil;
TeamCommListener.syncStateBuffer = TeamCommListener.syncStateBuffer or {};

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

function TeamCommListener:ParseAddonPayloadInto(prefix, payload, outState)
    if prefix ~= self.ADDON_PREFIX or type(payload) ~= "string" then
        return nil
    end
    if type(outState) ~= "table" then
        return nil
    end

    local messageType, protocolVersionText, mapIDText, timestampText, objectGUIDText =
        payload:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]*)$")
    local protocolVersion = tonumber(protocolVersionText)
    local mapID = tonumber(mapIDText)
    local timestamp = tonumber(timestampText)
    local objectGUID = DecodePayloadField(objectGUIDText)
    if messageType ~= self.ADDON_MESSAGE_TYPE_AIRDROP
        or protocolVersion ~= self.ADDON_PROTOCOL_VERSION
        or not mapID
        or not timestamp then
        return nil
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return nil
    end

    outState.mapID = mapID
    outState.timestamp = timestamp
    outState.objectGUID = objectGUID
    return outState
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
    if self:CanEnableHiddenSync() ~= true then
        return false
    end
    if self:RegisterAddonPrefix() ~= true then
        return false
    end

    local distribution = HiddenSyncTransport and HiddenSyncTransport.ResolveDistribution and HiddenSyncTransport:ResolveDistribution(chatType) or nil
    local payload = self:BuildAirdropPayload(syncState)
    if not distribution or type(payload) ~= "string" or payload == "" then
        return false
    end

    return HiddenSyncTransport
        and HiddenSyncTransport.SendAddonPayload
        and HiddenSyncTransport:SendAddonPayload(self.ADDON_PREFIX, payload, distribution)
        or false
end

function TeamCommListener:HandleAddonEvent(event, prefix, payload, chatType, sender)
    if self.CanReceiveHiddenSync and self:CanReceiveHiddenSync() ~= true then
        return false;
    end
    if not self.isInitialized then
        self:Initialize();
    end
    if not HiddenSyncTransport
        or not HiddenSyncTransport.IsSupportedTeamChatType
        or HiddenSyncTransport:IsSupportedTeamChatType(chatType) ~= true then
        return false;
    end

    self.syncStateBuffer = self.syncStateBuffer or {};
    local syncState = self:ParseAddonPayloadInto(prefix, payload, self.syncStateBuffer);
    if not syncState then
        return false;
    end

    if TeamCommMessageService and TeamCommMessageService.ProcessSync then
        return TeamCommMessageService:ProcessSync(self, syncState, chatType, sender);
    end
    return false;
end

return TeamCommListener;
