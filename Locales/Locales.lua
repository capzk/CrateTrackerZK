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

local LocaleLoadStatus = {
    loadedLocales = {},      -- 已成功加载的语言
    failedLocales = {},      -- 加载失败的语言
    activeLocale = nil,      -- 当前激活的语言
    fallbackUsed = false,
};

local function LoadLocaleData(localeData)
    if not localeData then return end;
    
    for k, v in pairs(localeData) do
        if k ~= "MapNames" then
            L[k] = v;
        end
    end
    if localeData.MapNames then
        L.MapNames = localeData.MapNames;
    end
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
        LoadLocaleData(data);
        LocaleLoadStatus.activeLocale = locale;
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
LocaleManager.GetLocaleRegistry = function()
    return LocaleRegistry;
end;
LocaleManager.failedLocales = LocaleManager.failedLocales or {};

-- ============================================================================
-- 语言选择逻辑（统一管理）- 在所有文件加载后执行
-- ============================================================================
local function SelectLocale()
    local mapNamesLoaded = L.MapNames and type(L.MapNames) == "table" and next(L.MapNames) ~= nil;
    
    if LocaleRegistry[currentLocale] then
        if not mapNamesLoaded then
            LoadLocaleData(LocaleRegistry[currentLocale]);
            LocaleLoadStatus.activeLocale = currentLocale;
            LocaleLoadStatus.fallbackUsed = false;
        end
    else
        if LocaleRegistry["enUS"] then
            if not mapNamesLoaded then
                LoadLocaleData(LocaleRegistry["enUS"]);
                LocaleLoadStatus.activeLocale = "enUS";
                LocaleLoadStatus.fallbackUsed = true;
            end
        else
            table.insert(LocaleLoadStatus.failedLocales, {
                locale = "enUS",
                reason = "English locale file not found"
            });
        end
    end
end

C_Timer.After(0, SelectLocale);

C_Timer.After(0.2, function()
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.failedLocales then
        for _, failed in ipairs(LocaleManager.failedLocales) do
            table.insert(LocaleLoadStatus.failedLocales, failed);
        end
    end
    
    if #LocaleLoadStatus.failedLocales > 0 and Logger and Logger:IsDebugEnabled() then
        local L = LocaleManager.GetL and LocaleManager.GetL() or L;
        local warningFormat = (L and L["LocalizationFailedLocalesWarning"]) or "Warning: %d locale files failed to load";
        Logger:Warn("Localization", "本地化", string.format(
            warningFormat,
            #LocaleLoadStatus.failedLocales
        ));
        for _, failed in ipairs(LocaleLoadStatus.failedLocales) do
            Logger:Debug("Localization", "本地化", string.format(
                "  - %s: %s",
                failed.locale or "unknown",
                failed.reason or "unknown reason"
            ));
        end
    end
end);

