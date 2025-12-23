-- CrateTrackerZK - 本地化
local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);

-- 定义 Localization 命名空间
local Localization = BuildEnv('Localization');

local function GetL()
    return CrateTrackerZK.L;
end

-- 初始化状态
Localization.isInitialized = false;
Localization.currentLocale = GetLocale();

-- 缺失翻译日志
Localization.missingTranslations = {};
Localization.missingLogEnabled = false;

function Localization:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.currentLocale = GetLocale();
    self.isInitialized = true;
    
    if Debug and Debug.IsEnabled and Debug:IsEnabled() then
        self.missingLogEnabled = Debug:IsEnabled();
    end
    
    C_Timer.After(0.1, function()
        self:ValidateCompleteness();
        self:ReportInitializationStatus();
    end);
end

function Localization:ValidateCompleteness()
    local missing = {
        mapNames = {},
        airdropCrateNames = {}
    };
    
    if Data and Data.DEFAULT_MAPS then
        local L = GetL();
        local enL = self:GetEnglishLocale();
        
        for _, mapData in ipairs(Data.DEFAULT_MAPS) do
            local mapCode = mapData.code;
            if mapCode then
                local hasTranslation = false;
                
                -- 检查当前语言
                if L and L.MapNames and L.MapNames[mapCode] then
                    hasTranslation = true;
                -- 检查英文回退
                elseif enL and enL.MapNames and enL.MapNames[mapCode] then
                    hasTranslation = true;
                end
                
                if not hasTranslation then
                    table.insert(missing.mapNames, mapCode);
                    self:LogMissingTranslation(mapCode, "MapNames", true);
                end
            end
        end
    end
    
    if Data and Data.MAP_CONFIG and Data.MAP_CONFIG.airdrop_crates then
        local L = GetL();
        local enL = self:GetEnglishLocale();
        
        for _, crateConfig in ipairs(Data.MAP_CONFIG.airdrop_crates) do
            local crateCode = crateConfig.code;
            if crateCode then
                local hasTranslation = false;
                
                -- 检查当前语言
                if L and L.AirdropCrateNames and L.AirdropCrateNames[crateCode] then
                    hasTranslation = true;
                -- 检查英文回退
                elseif enL and enL.AirdropCrateNames and enL.AirdropCrateNames[crateCode] then
                    hasTranslation = true;
                end
                
                if not hasTranslation then
                    table.insert(missing.airdropCrateNames, crateCode);
                    self:LogMissingTranslation(crateCode, "AirdropCrateNames", true);
                end
            end
        end
    end
    
    return missing;
end

function Localization:LogMissingTranslation(key, category, critical)
    if not key or not category then return end;
    
    local entry = {
        key = key,
        category = category,
        locale = GetLocale(),
        critical = critical or false,
        timestamp = time()
    };
    
    table.insert(self.missingTranslations, entry);
    
    if self.missingLogEnabled then
        local L = GetL();
        local levelKey = critical and "LocalizationCritical" or "LocalizationWarning";
        local level = (L and L[levelKey]) or (critical and "Critical" or "Warning");
        local prefix = "|cff00ff88[CrateTrackerZK]|r ";
        local formatStr = (L and L["LocalizationMissingTranslation"]) or "[Localization %s] Missing translation: %s.%s";
        print(prefix .. string.format(formatStr, level, category, key));
    end
end

function Localization:EnableMissingLog(enabled)
    self.missingLogEnabled = enabled or false;
end

function Localization:GetMissingTranslations()
    return self.missingTranslations;
end

function Localization:ClearMissingLog()
    self.missingTranslations = {};
end

function Localization:ReportInitializationStatus()
    local LocaleManager = BuildEnv("LocaleManager");
    if not LocaleManager or not LocaleManager.GetLoadStatus then
        return;
    end
    
    local status = LocaleManager.GetLoadStatus();
    local L = GetL();
    local prefix = "|cff00ff88[CrateTrackerZK]|r ";
    
    if status.activeLocale then
        if status.activeLocale == GetLocale() then
        elseif status.fallbackUsed then
            local formatStr = (L and L["LocalizationFallbackWarning"]) or "Warning: Locale file for %s not found, fallback to %s";
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
                formatStr,
                GetLocale(),
                status.activeLocale
            ));
        end
    else
        local errorMsg = (L and L["LocalizationNoLocaleError"]) or "Error: No available locale file found";
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. errorMsg);
    end
    
    local missing = self:ValidateCompleteness();
    local missingCount = #missing.mapNames + #missing.airdropCrateNames;
    
    if missingCount > 0 then
        local missingList = {};
        local mapNamesFormat = (L and L["MapNamesCount"]) or "Map names: %d";
        local crateNamesFormat = (L and L["AirdropCratesCount"]) or "Airdrop crates: %d";
        if #missing.mapNames > 0 then
            table.insert(missingList, string.format(mapNamesFormat, #missing.mapNames));
        end
        if #missing.airdropCrateNames > 0 then
            table.insert(missingList, string.format(crateNamesFormat, #missing.airdropCrateNames));
        end
        
        local warningFormat = (L and L["LocalizationMissingTranslationsWarning"]) or "Warning: Found %d missing critical translations (%s)";
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
            warningFormat,
            missingCount,
            table.concat(missingList, ", ")
        ));
        
        if Debug and Debug:IsEnabled() then
            local mapNamesMsg = (L and L["LocalizationMissingMapNames"]) or "Missing map names: %s";
            local crateNamesMsg = (L and L["LocalizationMissingCrateNames"]) or "Missing airdrop crate names: %s";
            if #missing.mapNames > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(mapNamesMsg, table.concat(missing.mapNames, ", ")));
            end
            if #missing.airdropCrateNames > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(crateNamesMsg, table.concat(missing.airdropCrateNames, ", ")));
            end
        end
    end
end

function Localization:GetMapName(mapCode)
    if not mapCode then return "" end;
    
    local L = GetL();
    if not L then
        -- 如果L还没有初始化，回退到格式化代号
        self:LogMissingTranslation(mapCode, "MapNames", false);
        return self:FormatMapCode(mapCode);
    end
    
    if L.MapNames and L.MapNames[mapCode] then
        return L.MapNames[mapCode];
    end
    
    local enL = self:GetEnglishLocale();
    if enL and enL.MapNames and enL.MapNames[mapCode] then
        if GetLocale() ~= "enUS" then
            self:LogMissingTranslation(mapCode, "MapNames", false);
        end
        return enL.MapNames[mapCode];
    end
    
    self:LogMissingTranslation(mapCode, "MapNames", true);
    return self:FormatMapCode(mapCode);
end

function Localization:FormatMapCode(mapCode)
    if not mapCode then return "" end;
    return mapCode:gsub("_", " "):gsub("(%a+)(%d+)", function(prefix, number)
        return prefix:sub(1,1):upper() .. prefix:sub(2):lower() .. " " .. number;
    end);
end

function Localization:GetEnglishLocale()
    local L = GetL();
    if not L then
        return nil;
    end
    
    local currentLocale = GetLocale();
    if currentLocale:sub(1, 2) == "en" then
        return L;
    end
    
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetEnglishLocale then
        return LocaleManager.GetEnglishLocale();
    end
    
    return nil;
end

function Localization:GetAllMapNames()
    local result = {};
    
    if Data and Data.DEFAULT_MAPS then
        for _, mapData in ipairs(Data.DEFAULT_MAPS) do
            local mapCode = mapData.code;
            result[mapCode] = self:GetMapName(mapCode);
        end
    end
    
    return result;
end

-- ============================================================================
-- 空投箱子名称本地化
-- ============================================================================

-- 获取空投箱子名称
-- @return string 当前语言的空投箱子名称
function Localization:GetAirdropCrateName()
    local crateCode = "AIRDROP_CRATE_001";
    local L = GetL();
    
    if not L then
        -- 如果L还没有初始化，尝试获取英文本地化
        self:LogMissingTranslation(crateCode, "AirdropCrateNames", false);
        local enL = self:GetEnglishLocale();
        if enL and enL.AirdropCrateNames and enL.AirdropCrateNames[crateCode] then
            return enL.AirdropCrateNames[crateCode];
        end
        -- 如果英文也没有，返回格式化代号（不应该到达这里）
        return self:FormatMapCode(crateCode);
    end
    
    -- 使用代号系统
    if L.AirdropCrateNames and L.AirdropCrateNames[crateCode] then
        return L.AirdropCrateNames[crateCode];
    end
    
    -- 回退到英文
    local enL = self:GetEnglishLocale();
    if enL and enL.AirdropCrateNames and enL.AirdropCrateNames[crateCode] then
        -- 使用英文回退，记录但不标记为严重（因为英文是默认语言）
        if GetLocale() ~= "enUS" then
            self:LogMissingTranslation(crateCode, "AirdropCrateNames", false);
        end
        return enL.AirdropCrateNames[crateCode];
    end
    
    -- 最后回退到格式化代号（不应该到达这里，因为英文本地化文件应该总是存在）
    self:LogMissingTranslation(crateCode, "AirdropCrateNames", true);
    return self:FormatMapCode(crateCode);
end

-- ============================================================================
-- 地图名称匹配（支持多语言）
-- ============================================================================

-- 检查地图名称是否匹配（支持多语言）
-- @param mapData 地图数据对象（包含code字段）
-- @param mapName 要匹配的地图名称
-- @return boolean 是否匹配
function Localization:IsMapNameMatch(mapData, mapName)
    if not mapData or not mapName then return false end;
    
    -- 通过代号获取当前语言的本地化名称
    local mapCode = mapData.code;
    if not mapCode then return false end;
    
    local localizedName = self:GetMapName(mapCode);
    
    -- 清理名称进行比较（移除标点符号和空格）
    local function cleanName(name)
        return string.lower(string.gsub(name or "", "[%p ]", ""));
    end
    
    local cleanMapName = cleanName(localizedName);
    local cleanInputName = cleanName(mapName);
    
    return cleanMapName == cleanInputName;
end

-- ============================================================================
-- 初始化检查
-- ============================================================================

-- 自动初始化
Localization:Initialize();

return Localization;

