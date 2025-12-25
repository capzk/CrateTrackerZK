local ADDON_NAME = "CrateTrackerZK";
local CrateTrackerZK = BuildEnv(ADDON_NAME);
local Localization = BuildEnv('Localization');

local function GetL()
    return CrateTrackerZK.L;
end

Localization.isInitialized = false;
Localization.currentLocale = GetLocale();
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
    
    if Data and Data.MAP_CONFIG and Data.MAP_CONFIG.current_maps then
        local L = GetL();
        local enL = self:GetEnglishLocale();
        
        for _, mapData in ipairs(Data.MAP_CONFIG.current_maps) do
            local mapID = mapData.mapID;
            if mapID then
                local hasTranslation = false;
                
                -- 检查当前语言
                if L and L.MapNames and L.MapNames[mapID] then
                    hasTranslation = true;
                -- 检查英文回退
                elseif enL and enL.MapNames and enL.MapNames[mapID] then
                    hasTranslation = true;
                end
                
                if not hasTranslation then
                    table.insert(missing.mapNames, tostring(mapID));
                    self:LogMissingTranslation(tostring(mapID), "MapNames", true);
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

function Localization:GetMapName(mapID)
    if not mapID or type(mapID) ~= "number" then return "" end;
    
    local L = GetL();
    if not L then
        -- 如果L还没有初始化，回退到格式化ID
        self:LogMissingTranslation(tostring(mapID), "MapNames", false);
        return "Map " .. tostring(mapID);
    end
    
    if L.MapNames and L.MapNames[mapID] then
        return L.MapNames[mapID];
    end
    
    local enL = self:GetEnglishLocale();
    if enL and enL.MapNames and enL.MapNames[mapID] then
        if GetLocale() ~= "enUS" then
            self:LogMissingTranslation(tostring(mapID), "MapNames", false);
        end
        return enL.MapNames[mapID];
    end
    
    self:LogMissingTranslation(tostring(mapID), "MapNames", true);
    return "Map " .. tostring(mapID);
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
    
    if Data and Data.MAP_CONFIG and Data.MAP_CONFIG.current_maps then
        for _, mapData in ipairs(Data.MAP_CONFIG.current_maps) do
            local mapID = mapData.mapID;
            if mapID then
                result[mapID] = self:GetMapName(mapID);
            end
        end
    end
    
    return result;
end

function Localization:GetAirdropCrateName()
    local crateCode = "WarSupplyCrate";
    local L = GetL();
    
    if not L then
        self:LogMissingTranslation(crateCode, "AirdropCrateNames", false);
        local enL = self:GetEnglishLocale();
        if enL and enL.AirdropCrateNames and enL.AirdropCrateNames[crateCode] then
            return enL.AirdropCrateNames[crateCode];
        end
        return "War Supply Crate";
    end
    
    if L.AirdropCrateNames and L.AirdropCrateNames[crateCode] then
        return L.AirdropCrateNames[crateCode];
    end
    
    local enL = self:GetEnglishLocale();
    if enL and enL.AirdropCrateNames and enL.AirdropCrateNames[crateCode] then
        if GetLocale() ~= "enUS" then
            self:LogMissingTranslation(crateCode, "AirdropCrateNames", false);
        end
        return enL.AirdropCrateNames[crateCode];
    end
    
    self:LogMissingTranslation(crateCode, "AirdropCrateNames", true);
    return "War Supply Crate";
end

function Localization:FormatMapID(mapID)
    if not mapID or type(mapID) ~= "number" then return "" end;
    return "Map " .. tostring(mapID);
end

Localization:Initialize();

return Localization;

