-- PublicSyncChannelService.lua - 公共频道传输管理
-- 注意：这里只尝试复用玩家当前已加入的“综合”频道做一次性 best-effort 广播。

local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")

PublicSyncChannelService.GENERAL_CHANNEL_BASE_NAMES = {
    enUS = { "general" },
    zhCN = { "综合" },
    zhTW = { "綜合" },
    koKR = { "일반" },
    ruRU = { "Общий", "общий" },
}

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
    return PublicSyncChannelService.GENERAL_CHANNEL_BASE_NAMES.zhCN
end

local function ExtractChannelBaseName(name)
    local normalized = NormalizeChannelName(Trim(name))
    if not normalized then
        return nil
    end

    normalized = normalized:gsub("^%d+%s*[%./、%-]*%s*", "")
    normalized = normalized:gsub("%s*%-%s*.*$", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = Trim(normalized)
    return normalized
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

local function IsGeneralChannelName(name)
    local baseName = ExtractChannelBaseName(name)
    if not baseName then
        return false
    end

    local expected = GetExpectedGeneralChannelBaseNames()
    if MatchesChannelAlias(baseName, expected) then
        return true
    end

    for _, candidate in pairs(PublicSyncChannelService.GENERAL_CHANNEL_BASE_NAMES) do
        if MatchesChannelAlias(baseName, candidate) then
            return true
        end
    end

    return false
end

function PublicSyncChannelService:Initialize()
    self.cachedChannelID = self.cachedChannelID or nil
    self.cachedChannelName = self.cachedChannelName or nil
end

function PublicSyncChannelService:Reset()
    self.cachedChannelID = nil
    self.cachedChannelName = nil
end

function PublicSyncChannelService:CanUsePublicChannel()
    if IsInInstance and IsInInstance() then
        return false
    end
    return true
end

function PublicSyncChannelService:GetResolvedChannelInfo()
    if type(GetChannelList) ~= "function" then
        return nil
    end

    local channelList = { GetChannelList() }
    for index = 1, #channelList, 3 do
        local channelID = tonumber(channelList[index])
        local channelName = channelList[index + 1]
        local disabled = channelList[index + 2]

        local isDisabled = disabled == true or disabled == 1 or disabled == "disabled"
        if channelID and channelID > 0 and not isDisabled and IsGeneralChannelName(channelName) then
            self.cachedChannelID = channelID
            self.cachedChannelName = channelName
            return {
                channelID = channelID,
                channelName = channelName,
            }
        end
    end

    self.cachedChannelID = nil
    self.cachedChannelName = nil
    return nil
end

function PublicSyncChannelService:EnsureChannelJoined(force)
    self:Initialize()

    if not self:CanUsePublicChannel() then
        return false
    end

    return self:GetResolvedChannelInfo() ~= nil
end

function PublicSyncChannelService:MatchesChannelContext(chatType, target, zoneChannelID, localChannelID, channelName)
    if chatType ~= "CHANNEL" then
        return false
    end

    local resolved = self:GetResolvedChannelInfo()
    local expectedChannelID = resolved and tonumber(resolved.channelID) or nil

    local candidateIDs = {
        tonumber(target),
        tonumber(zoneChannelID),
        tonumber(localChannelID),
    }

    if expectedChannelID then
        for _, candidate in ipairs(candidateIDs) do
            if candidate and candidate == expectedChannelID then
                return true
            end
        end
    end

    local candidateNames = {
        channelName,
        target,
    }

    for _, candidateName in ipairs(candidateNames) do
        if IsGeneralChannelName(candidateName) then
            return true
        end
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
