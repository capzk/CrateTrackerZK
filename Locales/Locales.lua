-- CrateTrackerZK 本地化管理
local ADDON_NAME = "CrateTrackerZK";

-- 确保 BuildEnv 函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local L = setmetatable({}, {
    __index = function(t, k)
        return k
    end
});

-- 导出到命名空间
local Namespace = BuildEnv(ADDON_NAME);
Namespace.L = L;

-- 获取当前语言
local locale = GetLocale();

-- 默认中文处理
if locale == "zhCN" or locale == "zhTW" then
    -- zhCN 会在单独的文件中定义
else
    -- enUS 或其他语言
end

