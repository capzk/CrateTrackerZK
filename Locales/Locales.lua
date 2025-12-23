-- CrateTrackerZK 本地化管理
local ADDON_NAME = "CrateTrackerZK";

-- 确保 BuildEnv 函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 初始化 L 表
local L = setmetatable({}, {
    __index = function(t, k)
        return k
    end
});

-- 导出到命名空间
local Namespace = BuildEnv(ADDON_NAME);
Namespace.L = L;

-- ============================================================================
-- 语言文件注册表（用于存储所有语言文件的翻译数据）
-- ============================================================================
local LocaleRegistry = {};
local currentLocale = GetLocale();

-- 加载状态跟踪
local LocaleLoadStatus = {
    loadedLocales = {},      -- 已成功加载的语言
    failedLocales = {},      -- 加载失败的语言
    activeLocale = nil,      -- 当前激活的语言
    fallbackUsed = false,    -- 是否使用了回退
};

-- 加载语言数据到 L 表（必须在 RegisterLocale 之前定义）
local function LoadLocaleData(localeData)
    if not localeData then return end;
    
    -- 复制所有翻译数据到 L 表
    for k, v in pairs(localeData) do
        if k ~= "MapNames" and k ~= "AirdropCrateNames" then
            L[k] = v;
        end
    end
    -- 特殊处理 MapNames 和 AirdropCrateNames（表类型）
    if localeData.MapNames then
        L.MapNames = localeData.MapNames;
    end
    if localeData.AirdropCrateNames then
        L.AirdropCrateNames = localeData.AirdropCrateNames;
    end
end

-- 注册语言文件并立即检查是否需要加载
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
    
    -- 如果是当前语言，立即加载
    if locale == currentLocale then
        LoadLocaleData(data);
        LocaleLoadStatus.activeLocale = locale;
    end
end

-- 导出注册函数供语言文件使用
local LocaleManager = BuildEnv("LocaleManager");
LocaleManager.RegisterLocale = RegisterLocale;
LocaleManager.GetL = function() return L; end;
-- 导出获取英文数据的方法（用于 Localization 模块的回退机制）
LocaleManager.GetEnglishLocale = function()
    return LocaleRegistry["enUS"];
end;
-- 导出获取加载状态的方法
LocaleManager.GetLoadStatus = function()
    return LocaleLoadStatus;
end;
-- 导出获取注册表的方法（用于验证）
LocaleManager.GetLocaleRegistry = function()
    return LocaleRegistry;
end;
-- 初始化失败语言列表
LocaleManager.failedLocales = LocaleManager.failedLocales or {};

-- ============================================================================
-- 语言选择逻辑（统一管理）- 在所有文件加载后执行
-- ============================================================================
local function SelectLocale()
    -- 检查 L.MapNames 是否已加载（需要检查是否为表，因为 __index 可能返回字符串）
    local mapNamesLoaded = L.MapNames and type(L.MapNames) == "table" and next(L.MapNames) ~= nil;
    
    -- 1. 优先使用客户端语言对应的本地化文件
    if LocaleRegistry[currentLocale] then
        if not mapNamesLoaded then
            LoadLocaleData(LocaleRegistry[currentLocale]);
            LocaleLoadStatus.activeLocale = currentLocale;
            LocaleLoadStatus.fallbackUsed = false;
        end
    else
        -- 2. 回退到英文（默认语言）
        if LocaleRegistry["enUS"] then
            if not mapNamesLoaded then
                LoadLocaleData(LocaleRegistry["enUS"]);
                LocaleLoadStatus.activeLocale = "enUS";
                LocaleLoadStatus.fallbackUsed = true;
            end
        else
            -- 3. 如果英文也没有，记录错误
            table.insert(LocaleLoadStatus.failedLocales, {
                locale = "enUS",
                reason = "English locale file not found"
            });
        end
    end
end

-- 延迟执行，确保所有语言文件都已注册
C_Timer.After(0, SelectLocale);

-- 延迟报告加载失败的语言文件（在所有文件加载后）
C_Timer.After(0.2, function()
    -- 合并 LocaleManager.failedLocales 到 LocaleLoadStatus.failedLocales
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.failedLocales then
        for _, failed in ipairs(LocaleManager.failedLocales) do
            table.insert(LocaleLoadStatus.failedLocales, failed);
        end
    end
    
    -- 如果有加载失败的语言文件，在调试模式下报告
    if #LocaleLoadStatus.failedLocales > 0 and Debug and Debug.IsEnabled and Debug:IsEnabled() then
        local prefix = "|cff00ff88[CrateTrackerZK]|r ";
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
            "警告：%d 个语言文件加载失败",
            #LocaleLoadStatus.failedLocales
        ));
        for _, failed in ipairs(LocaleLoadStatus.failedLocales) do
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
                "  - %s: %s",
                failed.locale or "unknown",
                failed.reason or "unknown reason"
            ));
        end
    end
end);

