-- PublicSyncChannelService.lua - 备用缓存共享传输管理
-- 注意：该链路只承载隐藏式 AddonMessage 共享，不发送任何可见聊天消息。

local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")
local HiddenSyncTransport = BuildEnv("HiddenSyncTransport")

PublicSyncChannelService.FEATURE_ENABLED = true

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
    return HiddenSyncTransport
        and HiddenSyncTransport.IsNonInstanceTeamContext
        and HiddenSyncTransport:IsNonInstanceTeamContext() == true
        or false
end

function PublicSyncChannelService:GetResolvedChannelInfo()
    local distribution = HiddenSyncTransport and HiddenSyncTransport.ResolveDistribution and HiddenSyncTransport:ResolveDistribution() or nil
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
    if not HiddenSyncTransport
        or not HiddenSyncTransport.IsSupportedTeamChatType
        or HiddenSyncTransport:IsSupportedTeamChatType(chatType) ~= true then
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

    return HiddenSyncTransport
        and HiddenSyncTransport.SendAddonPayload
        and HiddenSyncTransport:SendAddonPayload(prefix, payload, distribution)
        or false
end

return PublicSyncChannelService
