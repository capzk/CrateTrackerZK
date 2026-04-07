-- TimeFormatter.lua - 时间格式化工具

local TimeFormatter = BuildEnv("TimeFormatter")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")

TimeFormatter.MAX_TIME_CACHE_SIZE = 4096
TimeFormatter.MAX_DATETIME_CACHE_SIZE = 2048
TimeFormatter.MAX_DISPLAY_CACHE_SIZE = 1024
TimeFormatter.runtimeCache = TimeFormatter.runtimeCache or {
    formatTime = {},
    formatDateTime = {},
    formatTimeForDisplay = {},
    formatTimeCount = 0,
    formatDateTimeCount = 0,
    formatTimeForDisplayCount = 0,
}

local function GetLocaleTable(localeTable)
    if localeTable then
        return localeTable
    end
    return CrateTrackerZK and CrateTrackerZK.L or {}
end

local function GetLocaleCacheToken(localeTable)
    local currentLocaleTable = CrateTrackerZK and CrateTrackerZK.L or nil
    if localeTable and localeTable ~= currentLocaleTable then
        return "custom|" .. tostring(localeTable)
    end

    local LocaleManager = BuildEnv("LocaleManager")
    if LocaleManager and LocaleManager.GetCacheToken then
        local cacheToken = LocaleManager.GetCacheToken()
        if type(cacheToken) == "string" and cacheToken ~= "" then
            return cacheToken
        end
    end

    return "table|" .. tostring(GetLocaleTable(localeTable))
end

local function ResetCacheBucket(cache, fieldName, countFieldName)
    cache[fieldName] = {}
    cache[countFieldName] = 0
    return cache[fieldName]
end

local function AcquireCacheBucket(fieldName, countFieldName, maxSize)
    local cache = TimeFormatter.runtimeCache
    local bucket = cache[fieldName]
    if type(bucket) ~= "table" then
        bucket = ResetCacheBucket(cache, fieldName, countFieldName)
    elseif (cache[countFieldName] or 0) >= maxSize then
        bucket = ResetCacheBucket(cache, fieldName, countFieldName)
    end
    return bucket, cache
end

local function GetLocaleMarker(localeTable)
    return GetLocaleCacheToken(localeTable)
end

local function GetCachedValue(fieldName, cacheKey)
    local bucket = TimeFormatter.runtimeCache and TimeFormatter.runtimeCache[fieldName]
    if type(bucket) ~= "table" then
        return nil
    end
    return bucket[cacheKey]
end

local function SetCachedValue(fieldName, countFieldName, maxSize, cacheKey, value)
    local bucket, cache = AcquireCacheBucket(fieldName, countFieldName, maxSize)
    if bucket[cacheKey] == nil then
        cache[countFieldName] = (cache[countFieldName] or 0) + 1
    end
    bucket[cacheKey] = value
    return value
end

function TimeFormatter:FormatTime(seconds, showOnlyMinutes, localeTable)
    local L = GetLocaleTable(localeTable)
    if not seconds or seconds < 0 then
        return L["NoRecord"] or "--:--"
    end
    if seconds == 0 then
        return "00:00"
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    local localeMarker = GetLocaleMarker(localeTable)
    local cacheKey = table.concat({
        localeMarker,
        "|",
        showOnlyMinutes == true and "m" or "f",
        "|",
        tostring(hours),
        ":",
        tostring(minutes),
        ":",
        tostring(secs),
    })
    local cached = GetCachedValue("formatTime", cacheKey)
    if cached ~= nil then
        return cached
    end

    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"] or "%d:%02d"
        return SetCachedValue(
            "formatTime",
            "formatTimeCount",
            self.MAX_TIME_CACHE_SIZE,
            cacheKey,
            string.format(formatStr, minutes + hours * 60, secs)
        )
    end
    if hours > 0 then
        return SetCachedValue(
            "formatTime",
            "formatTimeCount",
            self.MAX_TIME_CACHE_SIZE,
            cacheKey,
            string.format("%d:%02d:%02d", hours, minutes, secs)
        )
    end
    return SetCachedValue(
        "formatTime",
        "formatTimeCount",
        self.MAX_TIME_CACHE_SIZE,
        cacheKey,
        string.format("%02d:%02d", minutes, secs)
    )
end

function TimeFormatter:FormatDateTime(timestamp, localeTable)
    local L = GetLocaleTable(localeTable)
    if not timestamp then
        return L["NoRecord"] or "无"
    end
    local cacheKey = GetLocaleMarker(localeTable) .. "|" .. tostring(timestamp)
    local cached = GetCachedValue("formatDateTime", cacheKey)
    if cached ~= nil then
        return cached
    end
    return SetCachedValue(
        "formatDateTime",
        "formatDateTimeCount",
        self.MAX_DATETIME_CACHE_SIZE,
        cacheKey,
        date("%H:%M:%S", timestamp)
    )
end

function TimeFormatter:FormatTimeForDisplay(timestamp)
    if not timestamp then
        return "--:--"
    end
    local cacheKey = tostring(timestamp)
    local cached = GetCachedValue("formatTimeForDisplay", cacheKey)
    if cached ~= nil then
        return cached
    end
    local t = date("*t", timestamp)
    return SetCachedValue(
        "formatTimeForDisplay",
        "formatTimeForDisplayCount",
        self.MAX_DISPLAY_CACHE_SIZE,
        cacheKey,
        string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
    )
end

return TimeFormatter
