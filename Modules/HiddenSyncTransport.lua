-- HiddenSyncTransport.lua - 隐藏同步公共传输基础设施

local HiddenSyncTransport = BuildEnv("HiddenSyncTransport")
HiddenSyncTransport.TEAM_CHAT_TYPES = {
    RAID = true,
    RAID_WARNING = true,
    PARTY = true,
    INSTANCE_CHAT = true,
}

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
end

function HiddenSyncTransport:HasTeamChatContext()
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

function HiddenSyncTransport:IsNonInstanceTeamContext()
    if self:HasTeamChatContext() ~= true then
        return false
    end
    if IsInInstance and IsInInstance() then
        return false
    end
    return true
end

function HiddenSyncTransport:IsSupportedTeamChatType(chatType)
    return type(chatType) == "string" and self.TEAM_CHAT_TYPES[chatType] == true
end

function HiddenSyncTransport:ResolveDistribution(chatType)
    if chatType == "RAID_WARNING" then
        return "RAID"
    end
    if chatType == "RAID" or chatType == "PARTY" or chatType == "INSTANCE_CHAT" then
        return chatType
    end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

function HiddenSyncTransport:EnsureAddonPrefix(listener, prefix)
    if type(listener) ~= "table" or type(prefix) ~= "string" or prefix == "" then
        return false
    end
    if listener.addonPrefixRegistered == true then
        return true
    end
    if listener.addonPrefixRegistrationAttempted == true then
        return false
    end

    listener.addonPrefixRegistrationAttempted = true

    local registered = false
    if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
        local ok, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix)
        if ok and isRegistered == true then
            registered = true
        end
    end

    if not registered then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            local ok, result = pcall(function()
                return NormalizeAddonCallResult(C_ChatInfo.RegisterAddonMessagePrefix(prefix))
            end)
            if ok and (result == true or result == 0) then
                registered = true
            elseif C_ChatInfo.IsAddonMessagePrefixRegistered then
                local verifyOk, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix)
                if verifyOk and isRegistered == true then
                    registered = true
                end
            end
        elseif RegisterAddonMessagePrefix then
            local ok, result = pcall(function()
                return NormalizeAddonCallResult(RegisterAddonMessagePrefix(prefix))
            end)
            if ok and (result == true or result == 0) then
                registered = true
            elseif C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
                local verifyOk, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix)
                if verifyOk and isRegistered == true then
                    registered = true
                end
            end
        end
    end

    listener.addonPrefixRegistered = registered == true
    listener.addonPrefixRegistrationAttempted = listener.addonPrefixRegistered == true
    return listener.addonPrefixRegistered == true
end

function HiddenSyncTransport:SendAddonPayload(prefix, payload, distribution)
    if type(prefix) ~= "string" or prefix == "" then
        return false
    end
    if type(payload) ~= "string" or payload == "" then
        return false
    end
    if type(distribution) ~= "string" or distribution == "" then
        return false
    end

    local sendAddonMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(sendAddonMessage) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return NormalizeAddonCallResult(sendAddonMessage(prefix, payload, distribution))
    end)
    return ok and (result == true or result == 0)
end

return HiddenSyncTransport
