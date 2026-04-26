-- TeamSharedSyncChannelService.lua - 团队共享缓存传输管理
-- 注意：该链路只承载隐藏式 AddonMessage 共享，不发送任何可见聊天消息。

local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local HiddenSyncTransport = BuildEnv("HiddenSyncTransport")

TeamSharedSyncChannelService.FEATURE_ENABLED = true

function TeamSharedSyncChannelService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function TeamSharedSyncChannelService:Initialize()
    self.isInitialized = self:IsFeatureEnabled() == true
    return self.isInitialized == true
end

function TeamSharedSyncChannelService:Reset()
    self.isInitialized = false
end

function TeamSharedSyncChannelService:CanUseTeamChannel()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    return HiddenSyncTransport
        and HiddenSyncTransport.IsNonInstanceTeamContext
        and HiddenSyncTransport:IsNonInstanceTeamContext() == true
        or false
end

function TeamSharedSyncChannelService:GetResolvedChannelInfo()
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

function TeamSharedSyncChannelService:EnsureTeamChannelReady(force)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end
    return self:CanUseTeamChannel() == true and self:GetResolvedChannelInfo() ~= nil
end

function TeamSharedSyncChannelService:MatchesTeamChannelContext(chatType, target, zoneChannelID, localChannelID, channelName)
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

function TeamSharedSyncChannelService:SendPayload(prefix, payload)
    if self:IsFeatureEnabled() ~= true then
        return false, "FeatureDisabled", nil
    end
    if type(prefix) ~= "string" or prefix == "" or type(payload) ~= "string" or payload == "" then
        return false, "InvalidArguments", nil
    end

    if self:EnsureTeamChannelReady() ~= true then
        return false, "ChannelNotReady", nil
    end

    local resolved = self:GetResolvedChannelInfo()
    local distribution = resolved and resolved.distribution or nil
    if type(distribution) ~= "string" or distribution == "" then
        return false, "MissingDistribution", nil
    end

    if HiddenSyncTransport and HiddenSyncTransport.SendAddonPayload then
        return HiddenSyncTransport:SendAddonPayload(prefix, payload, distribution)
    end
    return false, "TransportUnavailable", nil
end

return TeamSharedSyncChannelService
