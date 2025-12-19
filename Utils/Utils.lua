-- CrateTrackerZK - 工具函数模块
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

-- 解析HHMMSS格式的时间字符串
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
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 输入为空");
        end
        return nil;
    end
    
    if Utils.debugEnabled then
        Utils.Debug("时间解析: 开始解析", "输入=" .. input);
    end
    
    local hh, mm, ss;
    
    hh, mm, ss = ParseTimeFormatColon(input);
    if hh then
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 匹配HH:MM:SS格式");
        end
    else
        hh, mm, ss = ParseTimeFormatCompact(input);
        if hh then
            if Utils.debugEnabled then
                Utils.Debug("时间解析: 匹配HHMMSS格式");
            end
        else
            if Utils.debugEnabled then
                Utils.Debug("时间解析: 格式不匹配", "输入=" .. input);
            end
            return nil;
        end
    end
    
    if not ValidateTimeRange(hh, mm, ss) then
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 时间范围无效", "时=" .. (hh or "nil"), "分=" .. (mm or "nil"), "秒=" .. (ss or "nil"));
        end
        return nil;
    end
    
    hh, mm, ss = tonumber(hh), tonumber(mm), tonumber(ss);
    
    if Utils.debugEnabled then
        Utils.Debug("时间解析: 解析成功", "时=" .. hh, "分=" .. mm, "秒=" .. ss);
    end
    
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
    print('|cffff0000[CrateTrackerZK] ' .. message .. '|r');
end

function Utils.Print(message)
    print('|cff4FC1FF[CrateTrackerZK] ' .. message .. '|r');
end

Utils.debugEnabled = false;

function Utils.SetDebugEnabled(enabled)
    Utils.debugEnabled = enabled;
end

function Utils.Debug(...)    
    if Utils.debugEnabled then
        local message = "";
        for i = 1, select("#", ...) do
            local arg = select(i, ...);
            if type(arg) == "table" then
                message = message .. " {table}";
            else
                message = message .. " " .. tostring(arg);
            end
        end
        print('|cff00ff00[CrateTrackerZK]|r' .. message);
    end
end

return Utils;