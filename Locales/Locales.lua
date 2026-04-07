local ADDON_NAME = "CrateTrackerZK";

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

local Namespace = BuildEnv(ADDON_NAME);
Namespace.L = L;

-- ============================================================================
-- 语言文件注册表（用于存储所有语言文件的翻译数据）
-- ============================================================================
local LocaleRegistry = {};
local currentLocale = GetLocale();
local LocaleAliasMap = {
    enGB = "enUS",
};

local LocaleLoadStatus = {
    loadedLocales = {},      -- 已成功加载的语言
    failedLocales = {},      -- 加载失败的语言
    activeLocale = nil,      -- 当前激活的语言
    fallbackUsed = false,
    revision = 0,
    cacheToken = "pending|direct|0",
};

local function RefreshLocaleCacheToken()
    local activeLocale = LocaleLoadStatus.activeLocale or "pending";
    local fallbackMarker = LocaleLoadStatus.fallbackUsed == true and "fallback" or "direct";
    LocaleLoadStatus.cacheToken = table.concat({
        tostring(activeLocale),
        "|",
        fallbackMarker,
        "|",
        tostring(LocaleLoadStatus.revision or 0),
    });
    return LocaleLoadStatus.cacheToken;
end

local function LoadLocaleData(localeData)
    if not localeData then return end;
    
    for k, v in pairs(localeData) do
        L[k] = v;
    end
    LocaleLoadStatus.revision = (LocaleLoadStatus.revision or 0) + 1;
    RefreshLocaleCacheToken();
end

local function RegisterLocale(locale, data)
    if not locale or not data then
        table.insert(LocaleLoadStatus.failedLocales, {
            locale = locale or "unknown",
            reason = "Invalid locale data"
        });
        return;
    end
    
    LocaleRegistry[locale] = data;
    table.insert(LocaleLoadStatus.loadedLocales, locale);
    
    if locale == currentLocale then
        LocaleLoadStatus.activeLocale = locale;
        LocaleLoadStatus.fallbackUsed = false;
        LoadLocaleData(data);
    end
end

local LocaleManager = BuildEnv("LocaleManager");
LocaleManager.RegisterLocale = RegisterLocale;
LocaleManager.GetL = function() return L; end;
LocaleManager.GetEnglishLocale = function()
    return LocaleRegistry["enUS"];
end;
LocaleManager.GetLoadStatus = function()
    return LocaleLoadStatus;
end;
LocaleManager.GetCacheToken = function()
    return LocaleLoadStatus.cacheToken or RefreshLocaleCacheToken();
end;
LocaleManager.GetLocaleRegistry = function()
    return LocaleRegistry;
end;
LocaleManager.failedLocales = LocaleManager.failedLocales or {};

-- ============================================================================
-- 语言选择逻辑（统一管理）- 在所有文件加载后执行
-- ============================================================================
local function SelectLocale()
    local selectedLocale = currentLocale;
    if not LocaleRegistry[selectedLocale] then
        selectedLocale = LocaleAliasMap[currentLocale] or "enUS";
    end

    if LocaleRegistry[selectedLocale] then
        LocaleLoadStatus.activeLocale = selectedLocale;
        LocaleLoadStatus.fallbackUsed = selectedLocale ~= currentLocale;
        LoadLocaleData(LocaleRegistry[selectedLocale]);
    else
        table.insert(LocaleLoadStatus.failedLocales, {
            locale = "enUS",
            reason = "English locale file not found"
        });
    end
end

RefreshLocaleCacheToken();

C_Timer.After(0, SelectLocale);

C_Timer.After(0.2, function()
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.failedLocales then
        for _, failed in ipairs(LocaleManager.failedLocales) do
            table.insert(LocaleLoadStatus.failedLocales, failed);
        end
    end
end);
