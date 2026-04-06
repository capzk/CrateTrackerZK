-- PublicSyncChannelService.lua - 公共同步自定义频道管理
-- 注意：WoW 只允许 AddonMessage 发送到自定义频道；
-- 因此这里改为自动加入一个专用临时频道，并尽量把频道存在感降到最低。
-- 该频道只承载隐藏式 AddonMessage 共享，不发送任何可见聊天消息。

local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")

PublicSyncChannelService.FEATURE_ENABLED = false
PublicSyncChannelService.CHANNEL_RESOLVE_CACHE_TTL = 2
PublicSyncChannelService.CUSTOM_CHANNEL_CATEGORY = "CHANNEL_CATEGORY_CUSTOM"
PublicSyncChannelService.SYNC_CHANNEL_NAME = "CTKV1"
PublicSyncChannelService.CHANNEL_FILTER_EVENTS = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_CHANNEL_JOIN",
    "CHAT_MSG_CHANNEL_LEAVE",
    "CHAT_MSG_CHANNEL_NOTICE",
    "CHAT_MSG_CHANNEL_NOTICE_USER",
}

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
end

local function IsASCIIOnly(text)
    return type(text) == "string" and not text:find("[\128-\255]")
end

local function Trim(text)
    if type(text) ~= "string" then
        return nil
    end
    return text:match("^%s*(.-)%s*$")
end

local function NormalizeChannelName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local normalized = name:gsub("%s+", " ")
    if IsASCIIOnly(normalized) then
        return normalized:lower()
    end
    return normalized
end

local function ParseChannelName(name)
    local normalized = NormalizeChannelName(Trim(name))
    if not normalized then
        return nil
    end

    local withoutIndex = normalized:gsub("^%d+%s*[%./、%-]*%s*", "")
    local baseName = withoutIndex:gsub("%s*%-%s*.*$", "")
    baseName = baseName:gsub("%s+", " ")
    return Trim(baseName)
end

local function GetManagedChannelBaseName()
    return NormalizeChannelName(PublicSyncChannelService.SYNC_CHANNEL_NAME)
end

local function IsManagedChannelName(name)
    local baseName = ParseChannelName(name)
    if type(baseName) ~= "string" or baseName == "" then
        return false
    end
    return baseName == GetManagedChannelBaseName()
end

local function GetChannelResolveTime()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

local function IsChannelCacheFresh(service, currentTime)
    local checkedAt = tonumber(service.channelResolveCheckedAt)
    if type(checkedAt) ~= "number" then
        return false
    end
    return (currentTime - checkedAt) < (service.CHANNEL_RESOLVE_CACHE_TTL or 2)
end

local function FillResolvedInfoBuffer(service, channelID, channelName, channelCategory)
    if type(channelID) ~= "number" or channelID <= 0 then
        return nil
    end

    local buffer = service.resolvedChannelInfoBuffer or {}
    service.resolvedChannelInfoBuffer = buffer
    buffer.channelID = channelID
    buffer.channelName = channelName
    buffer.channelCategory = channelCategory
    return buffer
end

local function StoreResolvedChannelState(service, channelID, channelName, channelCategory, checkedAt)
    service.cachedChannelID = channelID
    service.cachedChannelName = channelName
    service.cachedChannelCategory = channelCategory
    service.channelResolveCheckedAt = checkedAt
end

local function GetChannelDisplayMetadata(channelID)
    if type(channelID) ~= "number"
        or channelID <= 0
        or type(GetNumDisplayChannels) ~= "function"
        or type(GetChannelDisplayInfo) ~= "function" then
        return nil
    end

    local displayCount = tonumber(GetNumDisplayChannels()) or 0
    for index = 1, displayCount do
        local name, header, _, displayChannelID, _, active, category = GetChannelDisplayInfo(index)
        if header ~= true and tonumber(displayChannelID) == channelID then
            return {
                channelName = name,
                active = active == true,
                category = category,
            }
        end
    end

    return nil
end

local function GetChatFrame(frameIndex)
    if type(frameIndex) ~= "number" or frameIndex <= 0 then
        return nil
    end
    return _G["ChatFrame" .. tostring(frameIndex)]
end

local function HideChannelFromChatFrames(channelName)
    if type(channelName) ~= "string"
        or channelName == ""
        or type(ChatFrame_RemoveChannel) ~= "function" then
        return
    end

    local frameCount = tonumber(NUM_CHAT_WINDOWS) or 0
    for frameIndex = 1, frameCount do
        local frame = GetChatFrame(frameIndex)
        if frame then
            pcall(ChatFrame_RemoveChannel, frame, channelName)
        end
    end
end

local function ShouldFilterManagedChannelMessage(service, ...)
    local channelName = select(4, ...)
    local channelIndex = tonumber((select(8, ...)))
    local channelBaseName = select(9, ...)

    if type(channelIndex) == "number"
        and type(service.cachedChannelID) == "number"
        and channelIndex == service.cachedChannelID then
        return true
    end
    if IsManagedChannelName(channelBaseName) then
        return true
    end
    return IsManagedChannelName(channelName)
end

function PublicSyncChannelService:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function PublicSyncChannelService:RegisterChatFilters()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self.chatFiltersRegistered == true or type(ChatFrame_AddMessageEventFilter) ~= "function" then
        return false
    end

    self.channelMessageFilter = self.channelMessageFilter or function(_, _, ...)
        return ShouldFilterManagedChannelMessage(PublicSyncChannelService, ...)
    end

    for _, eventName in ipairs(self.CHANNEL_FILTER_EVENTS or {}) do
        ChatFrame_AddMessageEventFilter(eventName, self.channelMessageFilter)
    end

    self.chatFiltersRegistered = true
    return true
end

function PublicSyncChannelService:Initialize()
    if self:IsFeatureEnabled() ~= true then
        self.isInitialized = false
        return false
    end
    self.cachedChannelID = self.cachedChannelID or nil
    self.cachedChannelName = self.cachedChannelName or nil
    self.cachedChannelCategory = self.cachedChannelCategory or nil
    self.channelResolveCheckedAt = self.channelResolveCheckedAt or nil
    self.resolvedChannelInfoBuffer = self.resolvedChannelInfoBuffer or {}
    self:RegisterChatFilters()
    self.isInitialized = true
    return true
end

function PublicSyncChannelService:Reset()
    self.isInitialized = false
    self.cachedChannelID = nil
    self.cachedChannelName = nil
    self.cachedChannelCategory = nil
    self.channelResolveCheckedAt = nil
end

function PublicSyncChannelService:CanUsePublicChannel()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if IsInInstance and IsInInstance() then
        return false
    end
    return true
end

function PublicSyncChannelService:GetManagedChannelName()
    return self.SYNC_CHANNEL_NAME
end

function PublicSyncChannelService:HideManagedChannel(channelName)
    HideChannelFromChatFrames(channelName or self.cachedChannelName or self:GetManagedChannelName())
end

function PublicSyncChannelService:GetResolvedChannelInfo(force)
    if self:IsFeatureEnabled() ~= true then
        return nil
    end
    self:Initialize()

    local checkedAt = GetChannelResolveTime()
    if force ~= true and IsChannelCacheFresh(self, checkedAt) then
        return FillResolvedInfoBuffer(self, self.cachedChannelID, self.cachedChannelName, self.cachedChannelCategory)
    end

    local resolvedChannelID, resolvedChannelName, resolvedChannelCategory = nil, nil, nil
    local managedChannelName = self:GetManagedChannelName()

    if type(GetChannelName) == "function" then
        local channelID, channelName = GetChannelName(managedChannelName)
        channelID = tonumber(channelID)
        if channelID and channelID > 0 then
            local metadata = GetChannelDisplayMetadata(channelID)
            local effectiveName = metadata and metadata.channelName or channelName or managedChannelName
            local category = metadata and metadata.category or nil
            local isActive = metadata and metadata.active ~= false or true

            if isActive and category == self.CUSTOM_CHANNEL_CATEGORY and IsManagedChannelName(effectiveName) then
                resolvedChannelID = channelID
                resolvedChannelName = effectiveName
                resolvedChannelCategory = category
            end
        end
    end

    StoreResolvedChannelState(self, resolvedChannelID, resolvedChannelName, resolvedChannelCategory, checkedAt)
    if resolvedChannelID then
        self:HideManagedChannel(resolvedChannelName)
    end
    return FillResolvedInfoBuffer(self, resolvedChannelID, resolvedChannelName, resolvedChannelCategory)
end

function PublicSyncChannelService:JoinManagedChannel()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    local joinChannel = JoinTemporaryChannel or JoinChannelByName
    if type(joinChannel) ~= "function" then
        return false
    end

    local managedChannelName = self:GetManagedChannelName()
    local frameID = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.GetID and DEFAULT_CHAT_FRAME:GetID() or 1

    local ok = pcall(function()
        joinChannel(managedChannelName, nil, frameID, false)
    end)
    if not ok then
        return false
    end

    local resolved = self:GetResolvedChannelInfo(true)
    if resolved and resolved.channelID then
        self:HideManagedChannel(resolved.channelName)
        return true
    end

    return false
end

function PublicSyncChannelService:EnsureChannelJoined(force)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    self:Initialize()

    if not self:CanUsePublicChannel() then
        return false
    end

    local resolved = self:GetResolvedChannelInfo(force == true)
    if resolved and resolved.channelID then
        self:HideManagedChannel(resolved.channelName)
        return true
    end

    if self:JoinManagedChannel() ~= true then
        return false
    end

    resolved = self:GetResolvedChannelInfo(true)
    if resolved and resolved.channelID then
        self:HideManagedChannel(resolved.channelName)
        return true
    end

    return false
end

function PublicSyncChannelService:MatchesChannelContext(chatType, target, zoneChannelID, localChannelID, channelName)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if chatType ~= "CHANNEL" then
        return false
    end

    local resolved = self:GetResolvedChannelInfo()
    local expectedChannelID = resolved and tonumber(resolved.channelID) or nil
    if expectedChannelID then
        local targetID = tonumber(target)
        if targetID and targetID == expectedChannelID then
            return true
        end

        local zoneID = tonumber(zoneChannelID)
        if zoneID and zoneID == expectedChannelID then
            return true
        end

        local localID = tonumber(localChannelID)
        if localID and localID == expectedChannelID then
            return true
        end
    end

    if IsManagedChannelName(channelName) then
        return true
    end
    if IsManagedChannelName(target) then
        return true
    end

    return false
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
    if not resolved or not resolved.channelID then
        return false
    end

    local sendAddonMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(sendAddonMessage) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return NormalizeAddonCallResult(sendAddonMessage(prefix, payload, "CHANNEL", resolved.channelID))
    end)

    return ok and (result == true or result == 0)
end

return PublicSyncChannelService
