-- Utils.lua
-- 工具函数：时间解析和格式化

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Utils = BuildEnv('Utils')

local function ParseTimeFormatColon(input)
    if not string.match(input, '^%d%d:%d%d:%d%d$') then
        return nil;
    end
    return string.match(input, '^(%d%d):(%d%d):(%d%d)$');
end

local function ParseTimeFormatCompact(input)
    if not string.match(input, '^%d%d%d%d%d%d$') then
        return nil;
    end
    local hh = string.sub(input, 1, 2);
    local mm = string.sub(input, 3, 4);
    local ss = string.sub(input, 5, 6);
    return hh, mm, ss;
end

local function ValidateTimeRange(hh, mm, ss)
    if not (hh and mm and ss) then
        return false;
    end
    hh, mm, ss = tonumber(hh), tonumber(mm), tonumber(ss);
    return hh and mm and ss and
           hh >= 0 and hh <= 23 and
           mm >= 0 and mm <= 59 and
           ss >= 0 and ss <= 59;
end

function Utils.ParseTimeInput(input)
    if not input or input == '' then 
        return nil;
    end
    
    local hh, mm, ss;
    
    hh, mm, ss = ParseTimeFormatColon(input);
    if not hh then
        hh, mm, ss = ParseTimeFormatCompact(input);
        if not hh then
            return nil;
        end
    end
    
    if not ValidateTimeRange(hh, mm, ss) then
        return nil;
    end
    
    hh, mm, ss = tonumber(hh), tonumber(mm), tonumber(ss);
    
    return hh, mm, ss;
end

function Utils.GetTimestampFromTime(hh, mm, ss)
    if not hh or not mm or not ss then return nil end;
    
    local currentTime = time();
    local currentDate = date('*t', currentTime);
    
    local dateTable = {
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day,
        hour = hh,
        min = mm,
        sec = ss
    };
    
    return time(dateTable);
end

function Utils.PrintError(message)
    Logger:Error("Utils", "错误", message);
end

function Utils.Print(message)
    Logger:Info("Utils", nil, message);
end

function Utils.SetDebugEnabled(enabled)
    Logger:SetDebugEnabled(enabled);
end

function Utils.Debug(...)
    Logger:Debug("Utils", "调试", ...);
end

return Utils;