-- TimeFormatter.lua - 时间格式化工具

local TimeFormatter = BuildEnv("TimeFormatter")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")

local function GetLocaleTable(localeTable)
    if localeTable then
        return localeTable
    end
    return CrateTrackerZK and CrateTrackerZK.L or {}
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

    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"] or "%d:%02d"
        return string.format(formatStr, minutes + hours * 60, secs)
    end
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

function TimeFormatter:FormatDateTime(timestamp, localeTable)
    local L = GetLocaleTable(localeTable)
    if not timestamp then
        return L["NoRecord"] or "无"
    end
    return date("%H:%M:%S", timestamp)
end

function TimeFormatter:FormatTimeForDisplay(timestamp)
    if not timestamp then
        return "--:--"
    end
    local t = date("*t", timestamp)
    return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end

return TimeFormatter
