-- PublicSyncChannelService.lua - 公共同步团队频道传输管理
-- 注意：该链路仍然只承载隐藏式 AddonMessage 共享，不发送任何可见聊天消息。

local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")

PublicSyncChannelService.FEATURE_ENABLED = true

local TEAM_CHAT_TYPES = {
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

local function ResolveAddonDistribution()
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

function PublicSyncChannelService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function PublicSyncChannelService:Initialize()
    self.isInitialized = self:IsFeatureEnabled() == true
    return self.isInitialized == true
end

function PublicSyncChannelService:Reset()
    self.isInitialized = false
end

function PublicSyncChannelService:CanUsePublicChannel()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if IsInInstance and IsInInstance() then
        return false
    end
    return HasTeamChatContext()
end

function PublicSyncChannelService:GetResolvedChannelInfo()
    local distribution = ResolveAddonDistribution()
    if not distribution then
        return nil
    end

    local buffer = self.resolvedChannelInfoBuffer or {}
    self.resolvedChannelInfoBuffer = buffer
    buffer.distribution = distribution
    buffer.chatType = distribution
    return buffer
end

function PublicSyncChannelService:EnsureChannelJoined(force)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end
    return self:CanUsePublicChannel() == true and self:GetResolvedChannelInfo() ~= nil
end

function PublicSyncChannelService:MatchesChannelContext(chatType, target, zoneChannelID, localChannelID, channelName)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if type(chatType) ~= "string" or not TEAM_CHAT_TYPES[chatType] then
        return false
    end

    local resolved = self:GetResolvedChannelInfo()
    local distribution = resolved and resolved.distribution or nil
    if type(distribution) ~= "string" then
        return false
    end

    if distribution == "RAID" then
        return chatType == "RAID" or chatType == "RAID_WARNING"
    end

    return chatType == distribution
end

function PublicSyncChannelService:SendPayload(prefix, payload)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if type(prefix) ~= "string" or prefix == "" or type(payload) ~= "string" or payload == "" then
        return false
    end

    if self:EnsureChannelJoined() ~= true then
        return false
    end

    local resolved = self:GetResolvedChannelInfo()
    local distribution = resolved and resolved.distribution or nil
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

return PublicSyncChannelService
