-- TeamCommListener.lua - 读取隐藏插件同步消息，更新空投时间状态

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TeamCommListener = BuildEnv('TeamCommListener');

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

local TEAM_CHAT_TYPES = {
    RAID = true,
    RAID_WARNING = true,
    PARTY = true,
    INSTANCE_CHAT = true
};

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
end

local function HasTeamChatContext()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return true
    end
    if IsInRaid and IsInRaid() then
        return true
    end
    if IsInGroup and IsInGroup() then
        return true
    end
    return false
end

function TeamCommListener:CanEnableHiddenSync()
    if not HasTeamChatContext() then
        return false
    end
    if Area and Area.IsActive then
        return Area:IsActive() == true
    end
    return false
end

function TeamCommListener:CanReceiveHiddenSync()
    if not HasTeamChatContext() then
        return false
    end
    if Area and Area.CanProcessTeamMessages then
        return Area:CanProcessTeamMessages() == true
    end
    if IsInInstance and IsInInstance() then
        return false
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

local function RegisterAddonPrefixInternal(prefix)
    if type(prefix) ~= "string" or prefix == "" then
        return false, nil;
    end

    if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
        local ok, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix);
        if ok and isRegistered == true then
            return true, 0;
        end
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok, result = pcall(function()
            return NormalizeAddonCallResult(C_ChatInfo.RegisterAddonMessagePrefix(prefix));
        end);
        if not ok then
            return false, nil;
        end
        if result == true or result == 0 then
            return true, result;
        end
        if C_ChatInfo.IsAddonMessagePrefixRegistered then
            local verifyOk, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix);
            if verifyOk and isRegistered == true then
                return true, result;
            end
        end
        return false, result;
    end
    if RegisterAddonMessagePrefix then
        local ok, result = pcall(function()
            return NormalizeAddonCallResult(RegisterAddonMessagePrefix(prefix));
        end);
        if not ok then
            return false, nil;
        end
        return result == true or result == 0, result;
    end
    return false, nil;
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

    self.addonPrefixRegistrationAttempted = true;
    local registered = RegisterAddonPrefixInternal(self.ADDON_PREFIX);
    self.addonPrefixRegistered = registered == true;
    self.addonPrefixRegistrationAttempted = self.addonPrefixRegistered == true;
    if not self.addonPrefixRegistered and Logger and Logger.Warn then
        Logger:Warn("TeamCommListener", tostring(self.ADDON_PREFIX), "注册失败");
    end
    return self.addonPrefixRegistered == true;
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

function TeamCommListener:HandleAddonEvent(event, prefix, payload, chatType, sender)
    if self.CanReceiveHiddenSync and self:CanReceiveHiddenSync() ~= true then
        return false;
    end
    if not self.isInitialized then
        self:Initialize();
    end
    if type(chatType) ~= "string" or not TEAM_CHAT_TYPES[chatType] then
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
