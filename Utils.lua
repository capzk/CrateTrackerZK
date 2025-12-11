-- 空投物资追踪器通用工具函数文件

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义Utils命名空间
local Utils = BuildEnv('Utils')

-- 时间处理函数
function Utils.ParseTimeInput(input)
    if not input or input == '' then 
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 输入为空");
        end
        return nil 
    end;
    
    if Utils.debugEnabled then
        Utils.Debug("时间解析: 开始解析", "输入=" .. input);
    end
    
    local hh, mm, ss;
    
    -- 尝试匹配HH:MM:SS格式
    if string.match(input, '^%d%d:%d%d:%d%d$') then
        hh, mm, ss = string.match(input, '^(%d%d):(%d%d):(%d%d)$');
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 匹配HH:MM:SS格式");
        end
    -- 尝试匹配HHMMSS格式
    elseif string.match(input, '^%d%d%d%d%d%d$') then
        hh = string.sub(input, 1, 2);
        mm = string.sub(input, 3, 4);
        ss = string.sub(input, 5, 6);
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 匹配HHMMSS格式");
        end
    else
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 格式不匹配", "输入=" .. input);
        end
        return nil;
    end
    
    hh, mm, ss = tonumber(hh), tonumber(mm), tonumber(ss);
    
    -- 验证时间范围
    if not (hh and mm and ss) or 
       hh < 0 or hh > 23 or 
       mm < 0 or mm > 59 or 
       ss < 0 or ss > 59 then
        if Utils.debugEnabled then
            Utils.Debug("时间解析: 时间范围无效", "时=" .. (hh or "nil"), "分=" .. (mm or "nil"), "秒=" .. (ss or "nil"));
        end
        return nil;
    end
    
    if Utils.debugEnabled then
        Utils.Debug("时间解析: 解析成功", "时=" .. hh, "分=" .. mm, "秒=" .. ss);
    end
    
    return hh, mm, ss;
end

-- 将时间组件转换为时间戳
function Utils.GetTimestampFromTime(hh, mm, ss)
    if not hh or not mm or not ss then return nil end;
    
    local currentTime = time();
    local currentDate = date('*t', currentTime);
    
    -- 设置为当前日期的指定时间
    local dateTable = {
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day,
        hour = hh,
        min = mm,
        sec = ss
    };
    
    local timestamp = time(dateTable);
    
    -- 用户输入时间通常表示"刚才XX:XX刷新了"
    -- 如果输入的时间已经过了当前时间，说明是今天已经发生的时间，直接使用今天的时间戳
    -- 如果输入的时间还没到，也使用今天的时间戳（可能是用户提前记录）
    -- 这样确保时间戳是今天的时间，不会跳到明天导致计算错误
    
    return timestamp;
end

-- 打印错误消息
function Utils.PrintError(message)
    print('|cffff0000[空投物资追踪器] ' .. message .. '|r');
end

-- 打印普通消息
function Utils.Print(message)
    print('|cff4FC1FF[空投物资追踪器] ' .. message .. '|r');
end

-- 调试开关（默认关闭）
Utils.debugEnabled = false;

-- 设置调试开关状态
function Utils.SetDebugEnabled(enabled)
    Utils.debugEnabled = enabled;
end

-- 打印调试消息
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
        print('|cff00ff00[空投物资追踪器]|r' .. message);
    end
end

return Utils;