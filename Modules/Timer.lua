-- 空投计时管理器

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TimerManager = BuildEnv('TimerManager')

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

local function SafeDebug(...)
    if Utils and Utils.Debug and type(Utils.Debug) == "function" then
        Utils.Debug(...);
    elseif Utils and Utils.debugEnabled then
        local message = "";
        for i = 1, select("#", ...) do
            local arg = select(i, ...);
            if type(arg) == "table" then
                message = message .. " {table}";
            else
                message = message .. " " .. tostring(arg);
            end
        end
        print('|cff00ff00[CrateTrackerZK]|r' .. message);
    end
end

TimerManager.detectionSources = {
    MANUAL_INPUT = "manual_input",
    REFRESH_BUTTON = "refresh_button",
    API_INTERFACE = "api_interface",
    MAP_ICON = "map_icon"
}

TimerManager.lastDebugMessage = TimerManager.lastDebugMessage or {};
TimerManager.DEBUG_MESSAGE_INTERVAL = 30; -- 30秒

function TimerManager:Initialize()
    self.isInitialized = true;
    self.lastDetectionTime = self.lastDetectionTime or {};
    self.notificationCount = self.notificationCount or {};
    self.mapIconDetected = self.mapIconDetected or {};
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {};
    self.lastUpdateTime = self.lastUpdateTime or {};
    self.lastDebugMessage = self.lastDebugMessage or {};
    self.lastMatchedMapID = self.lastMatchedMapID or nil;
    self.lastUnmatchedMapID = self.lastUnmatchedMapID or nil;
    SafeDebug("[Timer] Timer manager initialized");
end

local function SafeDebugLimited(messageKey, ...)
    local currentTime = time();
    local lastTime = TimerManager.lastDebugMessage[messageKey] or 0;
    
    if (currentTime - lastTime) >= TimerManager.DEBUG_MESSAGE_INTERVAL then
        TimerManager.lastDebugMessage[messageKey] = currentTime;
        SafeDebug(...);
    end
end

local function getCurrentTimestamp()
    return time();
end

function TimerManager:StartTimer(mapId, source, timestamp)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    local mapData = Data:GetMap(mapId);
    if not mapData then
        Utils.PrintError(L["ErrorInvalidMapID"] .. " " .. tostring(mapId));
        return false;
    end
    
    source = source or self.detectionSources.API_INTERFACE;
    timestamp = timestamp or getCurrentTimestamp();
    
    SafeDebug("[Timer] StartTimer", "MapID=" .. mapId, "Map=" .. Data:GetMapDisplayName(mapData), "Source=" .. source, "Time=" .. timestamp);
    
    local isManualOperation = (source == self.detectionSources.REFRESH_BUTTON or source == self.detectionSources.MANUAL_INPUT);
    local success = false;
    
    if isManualOperation then
        success = Data:SetLastRefresh(mapId, timestamp);
        
        if success then
            if source == self.detectionSources.MANUAL_INPUT and Data.manualInputLock then
                Data.manualInputLock[mapId] = timestamp;
            end
            
            local updatedMapData = Data:GetMap(mapId);
            if updatedMapData then
                local sourceText = self:GetSourceDisplayName(source);
                SafeDebug(string.format(L["DebugTimerStarted"], Data:GetMapDisplayName(updatedMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                
                SafeDebug("[Timer] Manual update", "Map=" .. Data:GetMapDisplayName(updatedMapData), "Source=" .. source, "Last=" .. Data:FormatDateTime(updatedMapData.lastRefresh), "Next=" .. Data:FormatDateTime(updatedMapData.nextRefresh));
            end
            
            self:UpdateUI();
        else
            SafeDebug("[Timer] Timer start failed, MapID=" .. mapId .. ", reason=Data:SetLastRefresh returned false");
            Utils.PrintError(L["ErrorTimerStartFailedMapID"] .. tostring(mapId));
        end
    else
        success = true;
    end
    
    return success;
end

function TimerManager:StartTimers(mapIds, source, timestamp)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    if not mapIds or type(mapIds) ~= "table" then
        Utils.PrintError(L["ErrorInvalidMapIDList"]);
        return false;
    end
    
    local allSuccess = true;
    local timestamp = timestamp or getCurrentTimestamp();
    
    for _, mapId in ipairs(mapIds) do
        local success = self:StartTimer(mapId, source, timestamp);
        if not success then
            allSuccess = false;
        end
    end
    
    return allSuccess;
end

-- 更新指定地图的计时（通过地图名称）
-- @param mapName 地图名称
-- @param source 检测源
-- @param timestamp 时间戳（可选，默认为当前时间）
-- @return boolean 操作是否成功
function TimerManager:StartTimerByName(mapName, source, timestamp)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    local maps = Data:GetAllMaps();
    local targetMapId = nil;
    
    for _, mapData in ipairs(maps) do
        if Data:IsMapNameMatch(mapData, mapName) then
            targetMapId = mapData.id;
            break;
        end
    end
    
    if targetMapId then
        return self:StartTimer(targetMapId, source, timestamp);
    else
        Utils.PrintError(L["ErrorMapNotFound"] .. " " .. mapName);
        return false;
    end
end

function TimerManager:StartCurrentMapTimer(source, timestamp)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    SafeDebug("[Timer] StartCurrentMapTimer", "Source=" .. (source or "nil"));
    
    local currentMapID = C_Map.GetBestMapForUnit("player");
    local currentMapName = "";
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if mapInfo and mapInfo.name then
        currentMapName = mapInfo.name;
        SafeDebug("[Timer] Got map info", "MapID=" .. currentMapID, "Map=" .. currentMapName);
    else
        currentMapName = select(1, GetInstanceInfo());
        SafeDebug("[Timer] Using GetInstanceInfo", "Map=" .. (currentMapName or "nil"));
    end
    
    if currentMapName then
        return self:StartTimerByName(currentMapName, source, timestamp);
    else
        SafeDebug("[Timer] Cannot get map name", "MapID=" .. (currentMapID or "nil"));
        Utils.PrintError(L["DebugCannotGetMapName2"]);
        return false;
    end
end

function TimerManager:GetSourceDisplayName(source)
    local displayNames = {
        [self.detectionSources.MANUAL_INPUT] = L["DebugDetectionSourceManual"],
        [self.detectionSources.REFRESH_BUTTON] = L["DebugDetectionSourceRefresh"],
        [self.detectionSources.API_INTERFACE] = L["DebugDetectionSourceAPI"],
        [self.detectionSources.MAP_ICON] = L["DebugDetectionSourceMapIcon"]
    };
    
    return displayNames[source] or "Unknown";
end

function TimerManager:UpdateUI()
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable();
    end
end

function TimerManager:RegisterDetectionSource(sourceId, displayName)
    if not sourceId or not displayName then
        Utils.PrintError(L["ErrorInvalidSourceParam"]);
        return false;
    end
    
    self.detectionSources[sourceId:upper()] = sourceId;
    
    return true;
end

function TimerManager:DetectMapIcons()
    if not C_Map or not C_Map.GetBestMapForUnit then
        SafeDebug(L["DebugCMapAPINotAvailable"])
        return false;
    end
    
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if not currentMapID then
        SafeDebug(L["DebugCannotGetMapID"])
        return false;
    end
    
    if not C_Map.GetMapInfo then
        SafeDebug(L["DebugCMapGetMapInfoNotAvailable"])
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID)
    if not mapInfo or not mapInfo.name then
        SafeDebug(L["DebugCannotGetMapName2"])
        return false;
    end
    
    local targetMapData = nil
    local validMaps = Data:GetAllMaps()
    local parentMapName = "";
    
    if not validMaps or #validMaps == 0 then
        SafeDebug(L["DebugMapListEmpty"])
        return false;
    end
    
    if mapInfo.parentMapID then
        local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
        if parentMapInfo and parentMapInfo.name then
            parentMapName = parentMapInfo.name;
        end
    end
    
    for _, mapData in ipairs(validMaps) do
        if Data:IsMapNameMatch(mapData, mapInfo.name) then
            targetMapData = mapData;
            if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                SafeDebugLimited("icon_map_match_" .. tostring(currentMapID), string.format(L["DebugMapMatchSuccess"], mapInfo.name));
                self.lastMatchedMapID = currentMapID;
            end
            break;
        end
    end
    
    if not targetMapData and parentMapName ~= "" then
        for _, mapData in ipairs(validMaps) do
            if Data:IsMapNameMatch(mapData, parentMapName) then
                targetMapData = mapData;
                -- 只在首次匹配时输出（减少重复输出）
                if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                    SafeDebugLimited("icon_parent_match_" .. tostring(currentMapID), string.format(L["DebugParentMapMatchSuccess"], mapInfo.name, parentMapName));
                    self.lastMatchedMapID = currentMapID;
                end
                break;
            end
        end
    end
    
    if not targetMapData then
        if not self.lastUnmatchedMapID or self.lastUnmatchedMapID ~= currentMapID then
            SafeDebugLimited("map_not_in_list_" .. tostring(currentMapID), string.format(L["DebugMapNotInList"], mapInfo.name, parentMapName or L["DebugNoRecord"], currentMapID))
            self.lastUnmatchedMapID = currentMapID;
        end
        return false;
    end
    
    local foundMapIcon = false;
    
    local crateName = "";
    if Localization then
        crateName = Localization:GetAirdropCrateName();
    else
        local L = CrateTrackerZK.L;
        if L and L.AirdropCrateNames and L.AirdropCrateNames["AIRDROP_CRATE_001"] then
            crateName = L.AirdropCrateNames["AIRDROP_CRATE_001"];
        else
            local LocaleManager = BuildEnv("LocaleManager");
            if LocaleManager and LocaleManager.GetEnglishLocale then
                local enL = LocaleManager.GetEnglishLocale();
                if enL and enL.AirdropCrateNames and enL.AirdropCrateNames["AIRDROP_CRATE_001"] then
                    crateName = enL.AirdropCrateNames["AIRDROP_CRATE_001"];
                end
            end
        end
    end
    
    if not crateName or crateName == "" then
        local L = CrateTrackerZK.L;
        SafeDebug(L["DebugMapIconNameNotConfigured"]);
        return false;
    end
    
    if C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignetteInfo and C_VignetteInfo.GetVignettePosition then
        local vignettes = C_VignetteInfo.GetVignettes()
        if vignettes then
            for _, vignetteGUID in ipairs(vignettes) do
                local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
                if vignetteInfo then
                    local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID)
                    if position then
                        local vignetteName = vignetteInfo.name or ""
                        
                        if vignetteName ~= "" then
                            local trimmedName = vignetteName:match("^%s*(.-)%s*$");
                            
                            if crateName and crateName ~= "" and trimmedName == crateName then
                                foundMapIcon = true;
                                SafeDebugLimited("icon_detection_start", string.format(L["DebugIconDetectionStart"], Data:GetMapDisplayName(targetMapData), crateName));
                                SafeDebugLimited("icon_vignette_" .. targetMapData.id, string.format(L["DebugDetectedMapIconVignette"], Data:GetMapDisplayName(targetMapData), crateName))
                                break
                            end
                        end
                    end
                end
            end
        else
            SafeDebugLimited("icon_vignette_empty", "[Timer] Vignette list is empty");
        end
    else
        SafeDebugLimited("icon_vignette_api_unavailable", "[Timer] C_VignetteInfo API not available");
    end
    
    self.mapIconDetected = self.mapIconDetected or {};
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {};
    self.lastUpdateTime = self.lastUpdateTime or {};
    local wasDetectedBefore = (self.mapIconDetected[targetMapData.id] == true);
    local currentTime = getCurrentTimestamp();
    local firstDetectedTime = self.mapIconFirstDetectedTime[targetMapData.id];
    
    
    if foundMapIcon then
        if not firstDetectedTime then
            self.mapIconFirstDetectedTime[targetMapData.id] = currentTime;
                SafeDebug(string.format(L["DebugFirstDetectionWait"], Data:GetMapDisplayName(targetMapData)));
        else
            local timeSinceFirstDetection = currentTime - firstDetectedTime;
            
            if timeSinceFirstDetection >= 2 then
                if not wasDetectedBefore then
                    SafeDebug(string.format(L["DebugContinuousDetectionConfirmed"], Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection));
                    
                    self.mapIconDetected[targetMapData.id] = true;
                    
                    if Data.manualInputLock then
                        Data.manualInputLock[targetMapData.id] = nil;
                    end
                    local success = Data:SetLastRefresh(targetMapData.id, firstDetectedTime);
                    
                    if success then
                        self.lastUpdateTime[targetMapData.id] = firstDetectedTime;
                        
                        local updatedMapData = Data:GetMap(targetMapData.id);
                        
                        local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
                        if updatedMapData and updatedMapData.nextRefresh then
                            SafeDebug(string.format(L["DebugTimerStarted"], Data:GetMapDisplayName(targetMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                            SafeDebug(string.format(L["DebugUpdatedRefreshTime"], Data:GetMapDisplayName(targetMapData), Data:FormatDateTime(updatedMapData.nextRefresh)));
                        else
                            SafeDebug(string.format(L["DebugTimerStarted"], Data:GetMapDisplayName(targetMapData), sourceText, L["NoRecord"]));
                        end
                        
                        self:UpdateUI();
                    else
                        SafeDebug(string.format(L["DebugUpdateRefreshTimeFailed"], targetMapData.id));
                    end
                    
                    if Notification then
                        Notification:NotifyAirdropDetected(Data:GetMapDisplayName(targetMapData), self.detectionSources.MAP_ICON);
                    end
                else
                    SafeDebugLimited("icon_detected_" .. targetMapData.id, string.format(L["DebugAirdropActive"], Data:GetMapDisplayName(targetMapData)));
                end
            else
                SafeDebug(string.format(L["DebugWaitingForConfirmation"], Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection));
            end
        end
    else
        if self.mapIconFirstDetectedTime[targetMapData.id] then
            self.mapIconFirstDetectedTime[targetMapData.id] = nil;
            SafeDebug(string.format(L["DebugClearedFirstDetectionTime"], Data:GetMapDisplayName(targetMapData)));
        end
        
        if self.mapIconDetected[targetMapData.id] then
            self.mapIconDetected[targetMapData.id] = nil;
            SafeDebugLimited("icon_cleared_" .. targetMapData.id, string.format(L["DebugAirdropEnded"], Data:GetMapDisplayName(targetMapData)));
        end
    end
    
    return foundMapIcon;
end

function TimerManager:StartMapIconDetection(interval)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    self:StopMapIconDetection();
    
    interval = interval or 2;
    
    self.mapIconDetectionTimer = C_Timer.NewTicker(interval, function()
        if Area and not Area.detectionPaused then
            self:DetectMapIcons();
        end
    end);
    
    SafeDebug("[Timer] Map icon detection started", "Interval=" .. interval .. "s");
    return true;
end

function TimerManager:StopMapIconDetection()
    if self.mapIconDetectionTimer then
        self.mapIconDetectionTimer:Cancel();
        self.mapIconDetectionTimer = nil;
        SafeDebug("[Timer] Map icon detection stopped");
    end
    return true;
end

function TimerManager:GetAllDetectionSources()
    local sources = {};
    for name, id in pairs(self.detectionSources) do
        table.insert(sources, {
            id = id,
            name = name,
            displayName = self:GetSourceDisplayName(id)
        });
    end
    return sources;
end

return TimerManager;
