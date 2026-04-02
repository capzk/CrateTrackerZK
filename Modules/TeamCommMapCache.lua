-- TeamCommMapCache.lua - 团队隐藏同步身份缓存

local TeamCommMapCache = BuildEnv("TeamCommMapCache")

local function NormalizeIdentityText(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local normalized = value
        :gsub("’", "'")
        :gsub("‘", "'")
        :gsub("＇", "'")
        :lower()
        :gsub("[%s%-%_'`]", "")
    if normalized == "" then
        return nil
    end
    return normalized
end

local function ParsePlayerSender(sender)
    if type(sender) ~= "string" or sender == "" then
        return nil, nil
    end
    local name, realm = sender:match("^([^%-]+)%-(.+)$")
    if name then
        return name, realm
    end
    return sender, nil
end

local function BuildRealmIdentityKeys(realmDisplayName, realmNormalizedName)
    local keys = {}
    local displayKey = NormalizeIdentityText(realmDisplayName)
    if displayKey then
        keys[displayKey] = true
    end
    local normalizedKey = NormalizeIdentityText(realmNormalizedName)
    if normalizedKey then
        keys[normalizedKey] = true
    end
    return keys
end

function TeamCommMapCache:EnsurePlayerIdentity(listener)
    if listener.playerName and listener.fullPlayerName then
        return
    end
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local normalizedRealmName = GetNormalizedRealmName and GetNormalizedRealmName() or nil
    listener.playerName = playerName
    listener.playerNameNormalized = NormalizeIdentityText(playerName)
    listener.realmName = realmName
    listener.normalizedRealmName = normalizedRealmName
    listener.realmIdentityKeys = BuildRealmIdentityKeys(realmName, normalizedRealmName)
    if playerName and realmName and realmName ~= "" then
        listener.fullPlayerName = playerName .. "-" .. realmName
    else
        listener.fullPlayerName = playerName
    end
end

function TeamCommMapCache:IsSelfSender(listener, sender)
    self:EnsurePlayerIdentity(listener)
    if type(sender) ~= "string" or sender == "" then
        return false
    end

    local senderName, senderRealm = ParsePlayerSender(sender)
    local senderNameKey = NormalizeIdentityText(senderName)
    if not senderNameKey or not listener.playerNameNormalized or senderNameKey ~= listener.playerNameNormalized then
        return false
    end

    if not senderRealm or senderRealm == "" then
        return true
    end

    local senderRealmKey = NormalizeIdentityText(senderRealm)
    if not senderRealmKey then
        return false
    end

    local realmKeys = listener.realmIdentityKeys or {}
    return realmKeys[senderRealmKey] == true
end

return TeamCommMapCache
