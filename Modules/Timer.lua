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
TimerManager.DEBUG_MESSAGE_INTERVAL = 30;

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

local function DT(key)
    if Debug and Debug.GetText then
        return Debug:GetText(key);
    end
    return key;
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
                SafeDebug(string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(updatedMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                
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

function TimerManager:StartCurrentMapTimer(source, timestamp)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    SafeDebug("[Timer] StartCurrentMapTimer", "Source=" .. (source or "nil"));
    
    local currentMapID = C_Map.GetBestMapForUnit("player");
    if not currentMapID then
        SafeDebug("[Timer] Cannot get map ID");
        Utils.PrintError(DT("DebugCannotGetMapID"));
        return false;
    end
    
    local targetMapData = Data:GetMapByMapID(currentMapID);
    
    if not targetMapData then
        local mapInfo = C_Map.GetMapInfo(currentMapID);
        if mapInfo and mapInfo.parentMapID then
            targetMapData = Data:GetMapByMapID(mapInfo.parentMapID);
            if targetMapData then
                SafeDebug("[Timer] Matched parent map", "CurrentMapID=" .. currentMapID, "ParentMapID=" .. mapInfo.parentMapID);
            end
        end
    end
    
    if targetMapData then
        SafeDebug("[Timer] Found map data", "MapID=" .. currentMapID, "Map=" .. Data:GetMapDisplayName(targetMapData));
        return self:StartTimer(targetMapData.id, source, timestamp);
    else
        SafeDebug("[Timer] Map not in list", "MapID=" .. currentMapID);
        Utils.PrintError(L["ErrorMapNotFound"] .. " (MapID: " .. tostring(currentMapID) .. ")");
        return false;
    end
end

function TimerManager:GetSourceDisplayName(source)
    local displayNames = {
        [self.detectionSources.MANUAL_INPUT] = DT("DebugDetectionSourceManual"),
        [self.detectionSources.REFRESH_BUTTON] = DT("DebugDetectionSourceRefresh"),
        [self.detectionSources.API_INTERFACE] = DT("DebugDetectionSourceAPI"),
        [self.detectionSources.MAP_ICON] = DT("DebugDetectionSourceMapIcon")
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
        SafeDebug(DT("DebugCMapAPINotAvailable"))
        return false;
    end
    
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if not currentMapID then
        SafeDebug(DT("DebugCannotGetMapID"))
        return false;
    end
    
    if not C_Map.GetMapInfo then
        SafeDebug(DT("DebugCMapGetMapInfoNotAvailable"))
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID)
    if not mapInfo then
        SafeDebug(DT("DebugCannotGetMapName2"))
        return false;
    end
    
    local targetMapData = nil
    local validMaps = Data:GetAllMaps()
    
    if not validMaps or #validMaps == 0 then
        SafeDebug(DT("DebugMapListEmpty"))
        return false;
    end
    
    for _, mapData in ipairs(validMaps) do
        if mapData.mapID == currentMapID then
            targetMapData = mapData;
            if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                SafeDebugLimited("icon_map_match_" .. tostring(currentMapID), string.format(DT("DebugMapMatchSuccess"), mapDisplayName));
                self.lastMatchedMapID = currentMapID;
            end
            break;
        end
    end
    
    if not targetMapData and mapInfo.parentMapID then
        for _, mapData in ipairs(validMaps) do
            if mapData.mapID == mapInfo.parentMapID then
                targetMapData = mapData;
                if not self.lastMatchedMapID or self.lastMatchedMapID ~= currentMapID then
                    local currentMapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
                    local parentMapDisplayName = Localization and Localization:GetMapName(mapInfo.parentMapID) or tostring(mapInfo.parentMapID);
                    SafeDebugLimited("icon_parent_match_" .. tostring(currentMapID), string.format(DT("DebugParentMapMatchSuccess"), currentMapDisplayName, parentMapDisplayName));
                    self.lastMatchedMapID = currentMapID;
                end
                break;
            end
        end
    end
    
    if not targetMapData then
        if not self.lastUnmatchedMapID or self.lastUnmatchedMapID ~= currentMapID then
            local mapDisplayName = Localization and Localization:GetMapName(currentMapID) or (mapInfo.name or tostring(currentMapID));
            local parentMapDisplayName = (mapInfo.parentMapID and Localization and Localization:GetMapName(mapInfo.parentMapID)) or (mapInfo.parentMapID and tostring(mapInfo.parentMapID)) or DT("DebugNoRecord");
            SafeDebugLimited("map_not_in_list_" .. tostring(currentMapID), string.format(DT("DebugMapNotInList"), mapDisplayName, parentMapDisplayName, currentMapID))
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
    
    if not crateName or crateName == "" then
        local L = CrateTrackerZK.L;
        SafeDebug(DT("DebugMapIconNameNotConfigured"));
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
                                SafeDebugLimited("icon_detection_start", string.format(DT("DebugIconDetectionStart"), Data:GetMapDisplayName(targetMapData), crateName));
                                SafeDebugLimited("icon_vignette_" .. targetMapData.id, string.format(DT("DebugDetectedMapIconVignette"), Data:GetMapDisplayName(targetMapData), crateName))
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
                SafeDebug(string.format(DT("DebugFirstDetectionWait"), Data:GetMapDisplayName(targetMapData)));
        else
            local timeSinceFirstDetection = currentTime - firstDetectedTime;
            
            if timeSinceFirstDetection >= 2 then
                if not wasDetectedBefore then
                    SafeDebug(string.format(DT("DebugContinuousDetectionConfirmed"), Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection));
                    
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
                            SafeDebug(string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(targetMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                            SafeDebug(string.format(DT("DebugUpdatedRefreshTime"), Data:GetMapDisplayName(targetMapData), Data:FormatDateTime(updatedMapData.nextRefresh)));
                        else
                            SafeDebug(string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(targetMapData), sourceText, DT("DebugNoRecord")));
                        end
                        
                        self:UpdateUI();
                    else
                        SafeDebug(string.format(DT("DebugUpdateRefreshTimeFailed"), targetMapData.id));
                    end
                    
                    if Notification then
                        Notification:NotifyAirdropDetected(Data:GetMapDisplayName(targetMapData), self.detectionSources.MAP_ICON);
                    end
                else
                    SafeDebugLimited("icon_detected_" .. targetMapData.id, string.format(DT("DebugAirdropActive"), Data:GetMapDisplayName(targetMapData)));
                end
            else
                SafeDebug(string.format(DT("DebugWaitingForConfirmation"), Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection));
            end
        end
    else
        if self.mapIconFirstDetectedTime[targetMapData.id] then
            self.mapIconFirstDetectedTime[targetMapData.id] = nil;
            SafeDebug(string.format(DT("DebugClearedFirstDetectionTime"), Data:GetMapDisplayName(targetMapData)));
        end
        
        if self.mapIconDetected[targetMapData.id] then
            self.mapIconDetected[targetMapData.id] = nil;
            SafeDebugLimited("icon_cleared_" .. targetMapData.id, string.format(DT("DebugAirdropEnded"), Data:GetMapDisplayName(targetMapData)));
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
