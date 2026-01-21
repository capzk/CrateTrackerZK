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
Localization.mapNameCache = {};
Localization.suppressWarnings = false;

function Localization:Initialize()
    if self.isInitialized then
        return;
    end
    
    self.currentLocale = GetLocale();
    self.mapNameCache = {};
    self.missingLogEnabled = false;
    self.isInitialized = true;
    
    if Logger and Logger:IsDebugEnabled() then
        self.missingLogEnabled = Logger:IsDebugEnabled();
    end
    
    C_Timer.After(0.1, function()
        self:ValidateCompleteness();
        self:ReportInitializationStatus();
    end);
end

function Localization:ValidateCompleteness()
    if self.suppressWarnings then
        return {
            mapNames = {}
        };
    end
    local missing = {
        mapNames = {}
    };
    
    return missing;
end

function Localization:LogMissingTranslation(key, category, critical)
    if not key or not category then return end;
    if self.suppressWarnings then return end;
    
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
        if not L then
            return;
        end
        local levelKey = critical and "LocalizationCritical" or "LocalizationWarning";
        local level = L[levelKey];
        local formatStr = L["LocalizationMissingTranslation"];
        if not level or not formatStr then
            return;
        end
        if critical then
            Logger:Error("Localization", "本地化", string.format(formatStr, level, category, key));
        else
            Logger:Warn("Localization", "本地化", string.format(formatStr, level, category, key));
        end
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
    if self.suppressWarnings then
        return;
    end
    if not (Logger and Logger:IsDebugEnabled()) then
        return;
    end
    local LocaleManager = BuildEnv("LocaleManager");
    if not LocaleManager or not LocaleManager.GetLoadStatus then
        return;
    end
    
    local status = LocaleManager.GetLoadStatus();
    local L = GetL();
    
    if status.activeLocale then
        if status.activeLocale == GetLocale() then
        elseif status.fallbackUsed then
            if L and L["LocalizationFallbackWarning"] then
                Logger:Warn("Localization", "本地化", string.format(
                    L["LocalizationFallbackWarning"],
                    GetLocale(),
                    status.activeLocale
                ));
            end
        end
    else
        if L and L["LocalizationNoLocaleError"] then
            Logger:Error("Localization", "本地化", L["LocalizationNoLocaleError"]);
        end
    end
    
    local missing = self:ValidateCompleteness();
    local missingCount = #missing.mapNames;
    
    if missingCount > 0 then
        if not (L and L["MapNamesCount"] and L["LocalizationMissingTranslationsWarning"] and L["LocalizationMissingMapNames"]) then
            return;
        end
        local missingList = {};
        if #missing.mapNames > 0 then
            table.insert(missingList, string.format(L["MapNamesCount"], #missing.mapNames));
        end
        
        Logger:Warn("Localization", "本地化", string.format(
            L["LocalizationMissingTranslationsWarning"],
            missingCount,
            table.concat(missingList, ", ")
        ));
        
        if #missing.mapNames > 0 then
            Logger:Debug("Localization", "本地化", string.format(L["LocalizationMissingMapNames"], table.concat(missing.mapNames, ", ")));
        end
    end
end

function Localization:GetMapName(mapID)
    if not mapID or type(mapID) ~= "number" then return "" end;

    if self.mapNameCache and self.mapNameCache[mapID] then
        return self.mapNameCache[mapID];
    end
    
    if C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(mapID);
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            if self.mapNameCache then
                self.mapNameCache[mapID] = mapInfo.name;
            end
            return mapInfo.name;
        end
    end
    
    local fallback = "Map " .. tostring(mapID);
    if self.mapNameCache then
        self.mapNameCache[mapID] = fallback;
    end
    return fallback;
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

function Localization:GetAirdropShouts()
    local L = GetL();
    if L and L.AirdropShouts and type(L.AirdropShouts) == "table" and #L.AirdropShouts > 0 then
        return L.AirdropShouts;
    end
    local enL = self:GetEnglishLocale();
    if enL and enL.AirdropShouts and type(enL.AirdropShouts) == "table" and #enL.AirdropShouts > 0 then
        return enL.AirdropShouts;
    end
    return nil;
end

function Localization:FormatMapID(mapID)
    if not mapID or type(mapID) ~= "number" then return "" end;
    return "Map " .. tostring(mapID);
end

Localization:Initialize();

return Localization;

