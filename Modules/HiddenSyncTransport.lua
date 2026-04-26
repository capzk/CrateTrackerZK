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

local function ResolveSendResultName(result)
    if type(result) == "number" and type(Enum) == "table" and type(Enum.SendAddonMessageResult) == "table" then
        for key, value in pairs(Enum.SendAddonMessageResult) do
            if value == result then
                return key
            end
        end
    end
    if result == true or result == 0 then
        return "Success"
    end
    if result == false then
        return "GeneralError"
    end
    if result == nil then
        return nil
    end
    return tostring(result)
end

local function IsInstanceLikeContent()
    local inInstance = IsInInstance and IsInInstance() or false
    if inInstance == true then
        return true
    end
    if GetInstanceInfo then
        local _, instanceType = GetInstanceInfo()
        if instanceType == "scenario" then
            return true
        end
    end
    return false
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
    if IsInstanceLikeContent() == true then
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
    listener.registeredAddonPrefixes = type(listener.registeredAddonPrefixes) == "table" and listener.registeredAddonPrefixes or {}
    if listener.registeredAddonPrefixes[prefix] == true then
        return true
    end

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

    listener.registeredAddonPrefixes[prefix] = registered == true
    if listener.ADDON_PREFIX == prefix then
        listener.addonPrefixRegistered = registered == true
        listener.addonPrefixRegistrationAttempted = registered == true
    end
    return listener.registeredAddonPrefixes[prefix] == true
end

function HiddenSyncTransport:SendAddonPayload(prefix, payload, distribution)
    if type(prefix) ~= "string" or prefix == "" then
        return false, "InvalidPrefix", nil
    end
    if type(payload) ~= "string" or payload == "" then
        return false, "InvalidPayload", nil
    end
    if type(distribution) ~= "string" or distribution == "" then
        return false, "InvalidDistribution", nil
    end

    local sendAddonMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(sendAddonMessage) ~= "function" then
        return false, "MissingSendFunction", nil
    end

    local ok, primaryResult, secondaryResult = pcall(function()
        return sendAddonMessage(prefix, payload, distribution)
    end)
    if ok ~= true then
        return false, "LuaError", nil
    end

    local normalizedResult = NormalizeAddonCallResult(primaryResult, secondaryResult)
    local resultName = ResolveSendResultName(normalizedResult)
    local successValue = type(Enum) == "table"
        and type(Enum.SendAddonMessageResult) == "table"
        and Enum.SendAddonMessageResult.Success
        or 0
    local isSuccess = normalizedResult == true
        or normalizedResult == 0
        or normalizedResult == successValue
    return isSuccess == true, resultName, normalizedResult
end

return HiddenSyncTransport
