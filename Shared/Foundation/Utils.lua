-- Utils.lua - 占位模块（手动时间输入功能已移除，保留命名空间以兼容旧引用）

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local Utils = BuildEnv('Utils')

local function ResolveCurrentTimestamp()
    if type(GetServerTime) == "function" then
        local ok, timestamp = pcall(GetServerTime)
        if ok and type(timestamp) == "number" and timestamp > 0 then
            return timestamp
        end
    end

    return time()
end

function Utils:GetCurrentTimestamp()
    return ResolveCurrentTimestamp()
end

return Utils;
