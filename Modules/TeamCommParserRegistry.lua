-- TeamCommParserRegistry.lua - 团队消息解析器

local TeamCommParserRegistry = BuildEnv("TeamCommParserRegistry")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")

local function BuildParser(messageFormat, locale)
    if type(messageFormat) ~= "string" or messageFormat == "" then
        return nil
    end
    local segments = {}
    local cursor = 1
    local placeholderCount = 0

    while true do
        local tokenStart = messageFormat:find("%s", cursor, true)
        if not tokenStart then
            table.insert(segments, messageFormat:sub(cursor))
            break
        end
        table.insert(segments, messageFormat:sub(cursor, tokenStart - 1))
        cursor = tokenStart + 2
        placeholderCount = placeholderCount + 1
    end

    if placeholderCount == 0 then
        return nil
    end

    return {
        original = messageFormat,
        locale = locale,
        segments = segments,
        placeholderCount = placeholderCount
    }
end

local function MatchWithParser(message, parser)
    if not parser then
        return nil
    end
    local textLen = #message
    local segments = parser.segments or {}
    if #segments == 0 then
        return nil
    end

    local cursor = 1
    local captures = {}
    for idx, seg in ipairs(segments) do
        local isLastSegment = idx == #segments
        if idx == 1 then
            if seg ~= "" then
                local segLen = #seg
                if textLen < segLen or message:sub(1, segLen) ~= seg then
                    return nil
                end
                cursor = segLen + 1
            end
        else
            if seg == "" then
                captures[idx - 1] = message:sub(cursor)
                cursor = textLen + 1
            else
                local pos = message:find(seg, cursor, true)
                if not pos then
                    return nil
                end
                captures[idx - 1] = message:sub(cursor, pos - 1)
                cursor = pos + #seg
            end
        end

        if isLastSegment and seg ~= "" and cursor <= textLen then
            return nil
        end
    end

    local mapName = type(captures[1]) == "string" and captures[1]:match("^%s*(.-)%s*$") or nil
    if not mapName or mapName == "" then
        return nil
    end
    return mapName
end

local function MatchWithParsers(message, parsers)
    if not parsers or #parsers == 0 then
        return nil, nil
    end
    for _, parser in ipairs(parsers) do
        local mapName = MatchWithParser(message, parser)
        if mapName then
            return mapName, parser
        end
    end
    return nil, nil
end

local function BuildParsersByLocaleKey(localeKey, skipEmpty)
    local preferred = {}
    local fallback = {}
    local seenFormats = {}
    local currentLocale = GetLocale and GetLocale() or nil

    local function AddFormat(locale, formatText, forcePreferred)
        if type(formatText) ~= "string" then
            return
        end
        if skipEmpty and formatText == "" then
            return
        end
        if seenFormats[formatText] then
            return
        end
        seenFormats[formatText] = true
        local parser = BuildParser(formatText, locale)
        if not parser then
            return
        end
        if forcePreferred or (currentLocale and locale == currentLocale) then
            table.insert(preferred, parser)
        else
            table.insert(fallback, parser)
        end
    end

    local LocaleManager = BuildEnv("LocaleManager")
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry()
        if localeRegistry then
            if currentLocale and localeRegistry[currentLocale] then
                AddFormat(currentLocale, localeRegistry[currentLocale][localeKey], true)
            end
            for locale, localeData in pairs(localeRegistry) do
                if localeData and locale ~= currentLocale then
                    AddFormat(locale, localeData[localeKey], false)
                end
            end
        end
    end

    local currentL = CrateTrackerZK and CrateTrackerZK.L
    if currentL then
        AddFormat(currentLocale or "current", currentL[localeKey], true)
    end

    return preferred, fallback
end

local function FlattenParsers(preferred, fallback)
    local result = {}
    for _, parser in ipairs(preferred or {}) do
        table.insert(result, parser)
    end
    for _, parser in ipairs(fallback or {}) do
        table.insert(result, parser)
    end
    return result
end

function TeamCommParserRegistry:Initialize(listener)
    listener.preferredMessageParsers, listener.fallbackMessageParsers = BuildParsersByLocaleKey("AirdropDetected", true)
    listener.messagePatterns = FlattenParsers(listener.preferredMessageParsers, listener.fallbackMessageParsers)
    listener.preferredAutoReportParsers, listener.fallbackAutoReportParsers = BuildParsersByLocaleKey("AutoTeamReportMessage", true)
    listener.autoReportPatterns = FlattenParsers(listener.preferredAutoReportParsers, listener.fallbackAutoReportParsers)
end

function TeamCommParserRegistry:ParseTeamMessage(listener, message)
    if not message or type(message) ~= "string" then
        return nil
    end

    local reportMapName = MatchWithParsers(message, listener.preferredAutoReportParsers)
    if not reportMapName then
        reportMapName = MatchWithParsers(message, listener.fallbackAutoReportParsers)
    end
    if reportMapName then
        if Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "解析", "消息为自动播报格式，跳过处理")
        end
        return nil
    end

    local mapName, parser = MatchWithParsers(message, listener.preferredMessageParsers)
    if not mapName then
        mapName, parser = MatchWithParsers(message, listener.fallbackMessageParsers)
    end
    if mapName and Logger and Logger.debugEnabled and Logger.Debug then
        Logger:Debug("TeamCommListener", "解析", string.format("匹配到自动消息：语言=%s，格式=%s，地图名称=%s",
            tostring(parser and parser.locale or "unknown"),
            tostring(parser and parser.original or "unknown"),
            mapName))
    end
    return mapName
end

return TeamCommParserRegistry
