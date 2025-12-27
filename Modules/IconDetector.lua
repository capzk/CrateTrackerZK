-- IconDetector.lua
-- 职责：只负责检测图标是否存在（符合设计文档）
-- 仅依赖名称匹配，不依赖位置信息

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

-- 使用 Logger 模块统一输出
local function SafeDebug(...)
    Logger:Debug("IconDetector", "调试", ...);
end

-- 获取空投箱子名称
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

-- 检测图标是否存在
-- 输入：currentMapID - 当前地图ID（可选，用于调试）
-- 输出：boolean - 是否检测到空投图标
function IconDetector:DetectIcon(currentMapID)
    -- 检查 API 是否可用
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes or not C_VignetteInfo.GetVignetteInfo then
        Logger:DebugLimited("icon_detection:api_unavailable", "IconDetector", "检测", "C_VignetteInfo API 不可用");
        return false;
    end
    
    -- 获取空投箱子名称
    local crateName = GetCrateName();
    if not crateName or crateName == "" then
        Logger:DebugLimited("icon_detection:name_not_configured", "IconDetector", "检测", "空投箱名称未配置，跳过图标检测");
        return false;
    end
    
    -- 获取所有 Vignette 图标
    local vignettes = C_VignetteInfo.GetVignettes();
    if not vignettes then
        return false;
    end
    
    -- 遍历查找匹配的图标（仅依赖名称匹配）
    for _, vignetteGUID in ipairs(vignettes) do
        local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID);
        if vignetteInfo then
            local vignetteName = vignetteInfo.name or "";
            
            if vignetteName ~= "" then
                -- 去除首尾空格
                local trimmedName = vignetteName:match("^%s*(.-)%s*$");
                
                -- 名称匹配（符合设计文档：仅依赖名称匹配）
                if crateName and crateName ~= "" and trimmedName == crateName then
                    return true;
                end
            end
        end
    end
    
    return false;
end

return IconDetector;

