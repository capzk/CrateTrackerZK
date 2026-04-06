-- PublicSyncChannelService.lua - 公共频道传输管理
-- 注意：这里只尝试复用玩家当前已加入的“综合”频道做一次性 best-effort 广播。

local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")

PublicSyncChannelService.GENERAL_CHANNEL_BASE_NAMES = {
    enUS = { "general" },
    esMX = { "general" },
    zhCN = { "综合" },
    zhTW = { "綜合" },
    koKR = { "일반" },
    ruRU = { "Общий", "общий" },
}
PublicSyncChannelService.CHANNEL_RESOLVE_CACHE_TTL = 2

local function IsASCIIOnly(text)
    return type(text) == "string" and not text:find("[\128-\255]")
end

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
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

local function Trim(text)
    if type(text) ~= "string" then
        return nil
    end
    return text:match("^%s*(.-)%s*$")
end

local function GetExpectedGeneralChannelBaseNames()
    local locale = GetLocale and GetLocale() or nil
    local exact = locale and PublicSyncChannelService.GENERAL_CHANNEL_BASE_NAMES[locale] or nil
    if exact then
        return exact
    end
    return PublicSyncChannelService.GENERAL_CHANNEL_BASE_NAMES.enUS
end

local function ParseChannelName(name)
    local normalized = NormalizeChannelName(Trim(name))
    if not normalized then
        return nil, false
    end

    local withoutIndex = normalized:gsub("^%d+%s*[%./、%-]*%s*", "")
    local baseName = withoutIndex:gsub("%s*%-%s*.*$", "")
    baseName = baseName:gsub("%s+", " ")
    baseName = Trim(baseName)

    if not baseName then
        return nil, false
    end

    return baseName, withoutIndex:match("%s*%-%s*.+$") ~= nil
end

local function MatchesChannelAlias(baseName, aliases)
    if type(baseName) ~= "string" or baseName == "" then
        return false
    end

    if type(aliases) == "string" then
        local normalizedAlias = NormalizeChannelName(Trim(aliases))
        return normalizedAlias == baseName
    end

    if type(aliases) ~= "table" then
        return false
    end

    for _, alias in ipairs(aliases) do
        local normalizedAlias = NormalizeChannelName(Trim(alias))
        if normalizedAlias == baseName then
            return true
        end
    end

    return false
end

local function IsExpectedGeneralChannelName(name)
    local baseName = ParseChannelName(name)
    if type(baseName) ~= "string" or baseName == "" then
        return false
    end

    local expected = GetExpectedGeneralChannelBaseNames()
    return MatchesChannelAlias(baseName, expected)
end

local function GetChannelResolveTime()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

local function IsChannelCacheFresh(service, currentLocale, currentTime)
    local checkedAt = tonumber(service.channelResolveCheckedAt)
    if type(checkedAt) ~= "number" then
        return false
    end
    if service.channelResolveLocale ~= currentLocale then
        return false
    end
    return (currentTime - checkedAt) < (service.CHANNEL_RESOLVE_CACHE_TTL or 2)
end

local function FillResolvedInfoBuffer(service, channelID, channelName)
    if not channelID then
        return nil
    end

    local buffer = service.resolvedChannelInfoBuffer or {}
    service.resolvedChannelInfoBuffer = buffer
    buffer.channelID = channelID
    buffer.channelName = channelName
    return buffer
end

local function StoreResolvedChannelState(service, channelID, channelName, currentLocale, checkedAt)
    service.cachedChannelID = channelID
    service.cachedChannelName = channelName
    service.channelResolveLocale = currentLocale
    service.channelResolveCheckedAt = checkedAt
end

function PublicSyncChannelService:Initialize()
    self.cachedChannelID = self.cachedChannelID or nil
    self.cachedChannelName = self.cachedChannelName or nil
    self.channelResolveLocale = self.channelResolveLocale or nil
    self.channelResolveCheckedAt = self.channelResolveCheckedAt or nil
    self.resolvedChannelInfoBuffer = self.resolvedChannelInfoBuffer or {}
end

function PublicSyncChannelService:Reset()
    self.cachedChannelID = nil
    self.cachedChannelName = nil
    self.channelResolveLocale = nil
    self.channelResolveCheckedAt = nil
end

function PublicSyncChannelService:CanUsePublicChannel()
    if IsInInstance and IsInInstance() then
        return false
    end
    return true
end

function PublicSyncChannelService:GetResolvedChannelInfo(force)
    if type(GetChannelList) ~= "function" then
        return nil
    end

    self:Initialize()

    local currentLocale = GetLocale and GetLocale() or nil
    local checkedAt = GetChannelResolveTime()
    if force ~= true and IsChannelCacheFresh(self, currentLocale, checkedAt) then
        return FillResolvedInfoBuffer(self, self.cachedChannelID, self.cachedChannelName)
    end

    local channelList = { GetChannelList() }
    local expectedAliases = GetExpectedGeneralChannelBaseNames()
    local bestChannelID, bestChannelName = nil, nil
    for index = 1, #channelList, 3 do
        local channelID = tonumber(channelList[index])
        local channelName = channelList[index + 1]
        local disabled = channelList[index + 2]

        local isDisabled = disabled == true or disabled == 1 or disabled == "disabled"
        local baseName, hasContextSuffix = ParseChannelName(channelName)
        if channelID
            and channelID > 0
            and not isDisabled
            and type(baseName) == "string"
            and MatchesChannelAlias(baseName, expectedAliases) then
            if hasContextSuffix == true then
                bestChannelID = channelID
                bestChannelName = channelName
                break
            end
            if not bestChannelID then
                bestChannelID = channelID
                bestChannelName = channelName
            end
        end
    end

    StoreResolvedChannelState(self, bestChannelID, bestChannelName, currentLocale, checkedAt)
    return FillResolvedInfoBuffer(self, bestChannelID, bestChannelName)
end

function PublicSyncChannelService:EnsureChannelJoined(force)
    self:Initialize()

    if not self:CanUsePublicChannel() then
        return false
    end

    return self:GetResolvedChannelInfo(force == true) ~= nil
end

function PublicSyncChannelService:MatchesChannelContext(chatType, target, zoneChannelID, localChannelID, channelName)
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
        return false
    end

    if IsExpectedGeneralChannelName(channelName) then
        return true
    end
    if IsExpectedGeneralChannelName(target) then
        return true
    end

    return false
end

function PublicSyncChannelService:SendPayload(prefix, payload)
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
