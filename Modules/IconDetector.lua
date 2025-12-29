-- IconDetector.lua
-- 检测地图上的空投图标，仅依赖名称匹配

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local IconDetector = BuildEnv('IconDetector');

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

if not Utils then
    Utils = BuildEnv('Utils')
end

local function GetCrateName()
    local crateName = "";
    if Localization then
        crateName = Localization:GetAirdropCrateName();
    else
        local L = CrateTrackerZK.L;
        local crateCode = "WarSupplyCrate";
        if L and L.AirdropCrateNames and L.AirdropCrateNames[crateCode] then
            crateName = L.AirdropCrateNames[crateCode];
        else
            local LocaleManager = BuildEnv("LocaleManager");
            if LocaleManager and LocaleManager.GetEnglishLocale then
                local enL = LocaleManager.GetEnglishLocale();
                if enL and enL.AirdropCrateNames and enL.AirdropCrateNames[crateCode] then
                    crateName = enL.AirdropCrateNames[crateCode];
                end
            end
        end
    end
    return crateName;
end

function IconDetector:DetectIcon(currentMapID)
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes or not C_VignetteInfo.GetVignetteInfo then
        Logger:DebugLimited("icon_detection:api_unavailable", "IconDetector", "检测", "C_VignetteInfo API 不可用");
        return false;
    end
    
    local crateName = GetCrateName();
    if not crateName or crateName == "" then
        Logger:DebugLimited("icon_detection:name_not_configured", "IconDetector", "检测", "空投箱名称未配置，跳过图标检测");
        return false;
    end
    
    local vignettes = C_VignetteInfo.GetVignettes();
    if not vignettes then
        return false;
    end
    
    for _, vignetteGUID in ipairs(vignettes) do
        local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID);
        if vignetteInfo then
            local vignetteName = vignetteInfo.name or "";
            if vignetteName ~= "" then
                local trimmedName = vignetteName:match("^%s*(.-)%s*$");
                if crateName and crateName ~= "" and trimmedName == crateName then
                    Logger:DebugLimited("icon_detection:detected_" .. tostring(currentMapID), "IconDetector", "检测", 
                        string.format("检测到空投图标：地图ID=%d，图标名称=%s", currentMapID, trimmedName));
                    return true;
                end
            end
        end
    end
    
    return false;
end

return IconDetector;

