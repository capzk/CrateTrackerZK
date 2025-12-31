-- IconDetector.lua - 图标检测模块

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

-- 提取 SpawnUID（GUID 第7部分）
local function ExtractSpawnUID(objectGUID)
    if not objectGUID or type(objectGUID) ~= "string" then 
        return nil;
    end
    
    local parts = {strsplit("-", objectGUID)};
    if #parts >= 7 then
        return parts[7];
    end
    
    return nil;
end

-- 提取位面ID（GUID 第3-4部分：分片ID-实例ID）
local function ExtractPhaseID(objectGUID)
    if not objectGUID or type(objectGUID) ~= "string" then 
        return nil;
    end
    
    local parts = {strsplit("-", objectGUID)};
    if #parts >= 4 then
        local shardID = parts[3];
        local instancePart = parts[4];
        if shardID and instancePart then
            return shardID .. "-" .. instancePart;
        end
    end
    
    return nil;
end

function IconDetector:DetectIcon(currentMapID)
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes or not C_VignetteInfo.GetVignetteInfo then
        Logger:DebugLimited("icon_detection:api_unavailable", "IconDetector", "检测", "C_VignetteInfo API 不可用");
        return { detected = false };
    end
    
    local crateName = GetCrateName();
    if not crateName or crateName == "" then
        Logger:DebugLimited("icon_detection:name_not_configured", "IconDetector", "检测", "空投箱名称未配置，跳过图标检测");
        return { detected = false };
    end
    
    local vignettes = C_VignetteInfo.GetVignettes();
    if not vignettes then
        return { detected = false };
    end
    
    -- 仅检测飞机图标（vignetteID = 3689）
    for _, vignetteGUID in ipairs(vignettes) do
        local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID);
        if vignetteInfo then
            if vignetteInfo.vignetteID == 3689 then
                local vignetteName = vignetteInfo.name or "";
                if vignetteName ~= "" then
                    local trimmedName = vignetteName:match("^%s*(.-)%s*$");
                    if crateName and crateName ~= "" and trimmedName == crateName then
                        local objectGUID = vignetteInfo.objectGUID;
                        local spawnUID = nil;
                        
                        if objectGUID then
                            spawnUID = ExtractSpawnUID(objectGUID);
                        end
                        
                        local phaseID = ExtractPhaseID(objectGUID);
                        
                        Logger:DebugLimited("icon_detection:detected_" .. tostring(currentMapID), "IconDetector", "检测", 
                            string.format("检测到空投飞机：地图ID=%d，objectGUID=%s", currentMapID, objectGUID or "无"));
                        
                        return {
                            detected = true,
                            objectGUID = objectGUID,
                            spawnUID = spawnUID,
                            phaseID = phaseID,
                            vignetteGUID = vignetteGUID,
                            vignetteID = vignetteInfo.vignetteID
                        };
                    end
                end
            end
        end
    end
    
    return { detected = false };
end

IconDetector.ExtractSpawnUID = ExtractSpawnUID;
IconDetector.ExtractPhaseID = ExtractPhaseID;

return IconDetector;

