-- Timer.lua - 检测循环管理器

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

if not UnifiedDataManager then
    UnifiedDataManager = BuildEnv('UnifiedDataManager')
end

if not Area then
    Area = BuildEnv('Area')
end

TimerManager.detectionSources = {
    REFRESH_BUTTON = "refresh_button",
    API_INTERFACE = "api_interface",
    MAP_ICON = "map_icon",
    TEAM_MESSAGE = "team_message"
}

function TimerManager:Initialize()
    self.isInitialized = true;
    self.detectionState = self.detectionState or {};
    self.CONFIRM_TIME = 2;          -- 初筛防抖
    self.MIN_STABLE_TIME = 5;       -- 最短稳定存活时间（秒），达标后才广播/持久化
    
    -- 初始化UnifiedDataManager
    if UnifiedDataManager and UnifiedDataManager.Initialize then
        UnifiedDataManager:Initialize();
        -- 迁移现有数据
        UnifiedDataManager:MigrateExistingData();
    end
    
    Logger:DebugLimited("timer:init_complete", "Timer", "初始化", "计时器管理器已初始化");
end

local function SafeDebugLimited(messageKey, ...)
    Logger:DebugLimited(messageKey, "Timer", "调试", ...);
end

local function DT(key)
    return Logger:GetDebugText(key);
end

local function getCurrentTimestamp()
    return time();
end

local function HasRecentShout(mapDisplayName, currentTime)
    if Notification and Notification.IsRecentShout then
        return Notification:IsRecentShout(mapDisplayName, Notification.SHOUT_DEDUP_WINDOW, currentTime);
    end
    return false, nil;
end

function TimerManager:StartTimer(mapId, source, timestamp)
    Logger:Debug("Timer", "调试", string.format("StartTimer被调用：mapId=%s，source=%s", 
        tostring(mapId), tostring(source)))
    
    if not self.isInitialized then
        Logger:Error("Timer", "错误", "TimerManager未初始化");
        return false;
    end
    
    local mapData = Data:GetMap(mapId);
    if not mapData then
        Logger:Error("Timer", "错误", string.format("无效的地图ID：%s", tostring(mapId)));
        return false;
    end
    
    source = source or self.detectionSources.API_INTERFACE;
    timestamp = timestamp or getCurrentTimestamp();
    
    Logger:Debug("Timer", "更新", string.format("StartTimer: MapID=%d, Map=%s, Source=%s, Time=%d", 
        mapId, Data:GetMapDisplayName(mapData), source, timestamp));
    
    -- 直接使用UnifiedDataManager的统一接口
    local success = false;
    
    if UnifiedDataManager and UnifiedDataManager.SetTime then
        success = UnifiedDataManager:SetTime(mapId, timestamp, source);
        if success then
            Logger:Debug("Timer", "成功", string.format("设置时间成功：地图=%s，来源=%s", 
                Data:GetMapDisplayName(mapData), self:GetSourceDisplayName(source)));
        else
            Logger:Error("Timer", "错误", string.format("设置时间失败：地图=%s，来源=%s", 
                Data:GetMapDisplayName(mapData), source));
        end
    else
        Logger:Error("Timer", "错误", "UnifiedDataManager模块或SetTime函数不可用");
        return false;
    end
    
    if success then
        Logger:Debug("Timer", "成功", string.format("时间设置成功，准备更新UI：mapId=%d", mapId))
        -- 更新UI
        self:UpdateUI();
    else
        Logger:Error("Timer", "错误", string.format("设置时间失败：地图ID=%d，来源=%s", mapId, source));
    end
    
    return success;
end


function TimerManager:GetSourceDisplayName(source)
    local displayNames = {
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


-- 检查是否应该发送通知（30秒限制）
local function ShouldSendNotification(eventTimestamp, currentTime)
    if not eventTimestamp then
        return true;
    end
    local timeSinceAirdrop = currentTime - eventTimestamp;
    return timeSinceAirdrop <= 30;
end

function TimerManager:DetectMapIcons()
    if Area and Area.IsActive and not Area:IsActive() then
        return false;
    end
    if not C_Map or not C_Map.GetBestMapForUnit then
        SafeDebugLimited("detection_loop:api_unavailable", DT("DebugCMapAPINotAvailable"));
        return false;
    end
    
    local currentMapID = C_Map.GetBestMapForUnit("player");
    if not currentMapID then
        SafeDebugLimited("detection_loop:no_map_id", DT("DebugCannotGetMapID"));
        return false;
    end
    
    SafeDebugLimited("detection_loop:start", "开始检测循环", "当前地图ID=" .. currentMapID);
    if not MapTracker or not MapTracker.GetTargetMapData then
        Logger:Error("Timer", "错误", "MapTracker module not loaded");
        return false;
    end
    
    local targetMapData = MapTracker:GetTargetMapData(currentMapID);
    if not targetMapData then
        SafeDebugLimited("detection_loop:map_not_in_list", "当前地图不在列表中，跳过检测", "地图ID=" .. currentMapID);
        return false;
    end

    -- 如果地图被隐藏，暂停该地图的空投检测
    if CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.hiddenMaps and CRATETRACKERZK_UI_DB.hiddenMaps[targetMapData.mapID] then
        SafeDebugLimited("detection_loop:hidden_map_" .. tostring(targetMapData.mapID), "地图被隐藏，跳过空投检测", Data:GetMapDisplayName(targetMapData));
        -- 清除该地图的检测状态，避免残留
        self.detectionState[targetMapData.id] = nil;
        return false;
    end
    
    local currentTime = getCurrentTimestamp();
    MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime);
    
    if not IconDetector or not IconDetector.DetectIcon then
        Logger:Error("Timer", "错误", "IconDetector module not loaded");
        return false;
    end
    
    -- 检测图标
    local iconResult = IconDetector:DetectIcon(currentMapID);
    if not iconResult or not iconResult.detected then
        -- 图标消失，清除检测状态
        if self.detectionState[targetMapData.id] then
            local detectionState = self.detectionState[targetMapData.id];
            local timeSinceFirst = currentTime - (detectionState.firstDetectedTime or currentTime);
            if timeSinceFirst < self.CONFIRM_TIME then
                -- 2秒确认期内消失
                Logger:Debug("Timer", "状态", string.format("图标在2秒确认期内消失，清除检测状态：地图=%s", 
                    Data:GetMapDisplayName(targetMapData)));
                -- 发送无效空投通知
                if Notification and Notification.NotifyInvalidAirdrop then
                    Notification:NotifyInvalidAirdrop(Data:GetMapDisplayName(targetMapData));
                end
                self.detectionState[targetMapData.id] = nil;
            else
                -- 已通过2秒确认
                Logger:Debug("Timer", "状态", string.format("图标消失（已通过2秒确认），清除检测状态：地图=%s", 
                    Data:GetMapDisplayName(targetMapData)));
                self.detectionState[targetMapData.id] = nil;
            end
        end
        return false;
    end
    
    local objectGUID = iconResult.objectGUID;
    
    -- 验证 objectGUID 格式
    if not objectGUID or type(objectGUID) ~= "string" then
        Logger:Error("Timer", "错误", string.format("检测到无效的 objectGUID：地图=%s，objectGUID=%s", 
            Data:GetMapDisplayName(targetMapData), tostring(objectGUID)));
        return false;
    end
    
    local guidParts = {strsplit("-", objectGUID)};
    if #guidParts < 7 then
        Logger:Error("Timer", "错误", string.format("检测到格式不正确的 objectGUID：地图=%s，objectGUID=%s（只有%d部分，需要至少7部分）", 
            Data:GetMapDisplayName(targetMapData), objectGUID, #guidParts));
        return false;
    end
    
    -- objectGUID 比对：相同则跳过（同一事件）
    if targetMapData.currentAirdropObjectGUID and targetMapData.currentAirdropObjectGUID == objectGUID then
        Logger:DebugLimited("detection:same_event_" .. targetMapData.id, "Timer", "检测", 
            string.format("检测到相同 objectGUID（同一事件持续中）：地图=%s（地图ID=%d，配置ID=%d），objectGUID=%s，空投开始时间=%s", 
                Data:GetMapDisplayName(targetMapData), targetMapData.mapID, targetMapData.id, objectGUID,
                targetMapData.currentAirdropTimestamp and UnifiedDataManager:FormatDateTime(targetMapData.currentAirdropTimestamp) or "无"));
        return true;
    elseif targetMapData.currentAirdropObjectGUID and targetMapData.currentAirdropObjectGUID ~= objectGUID then
        -- 新空投事件：清除通知记录（但若刚被喊话触发，则保留去重状态）
        local mapDisplayName = Data:GetMapDisplayName(targetMapData);
        local isRecentShout, lastShoutTime = HasRecentShout(mapDisplayName, currentTime);
        if Notification and not isRecentShout then
            if Notification.firstNotificationTime and Notification.firstNotificationTime[mapDisplayName] then
                Notification.firstNotificationTime[mapDisplayName] = nil;
            end
            if Notification.playerSentNotification and Notification.playerSentNotification[mapDisplayName] then
                Notification.playerSentNotification[mapDisplayName] = nil;
            end
        elseif isRecentShout then
            Logger:Debug("Timer", "去重", string.format("检测到新objectGUID但最近喊话触发，保留通知状态：地图=%s，间隔=%ds",
                mapDisplayName, currentTime - (lastShoutTime or currentTime)));
        end
    end
    
    local detectionState = self.detectionState[targetMapData.id];
    if not detectionState then
        -- 首次检测
        self.detectionState[targetMapData.id] = {
            firstDetectedTime = currentTime,
            detectedObjectGUID = objectGUID
        };
        Logger:Debug("Timer", "检测", string.format("首次检测到空投：地图=%s，objectGUID=%s", 
            Data:GetMapDisplayName(targetMapData), objectGUID));
        return true;
    end
    
    if detectionState.detectedObjectGUID ~= objectGUID then
        -- 新事件：清除通知记录
        local mapDisplayName = Data:GetMapDisplayName(targetMapData);
        local isRecentShout, lastShoutTime = HasRecentShout(mapDisplayName, currentTime);
        if Notification and not isRecentShout then
            if Notification.firstNotificationTime and Notification.firstNotificationTime[mapDisplayName] then
                Notification.firstNotificationTime[mapDisplayName] = nil;
            end
            if Notification.playerSentNotification and Notification.playerSentNotification[mapDisplayName] then
                Notification.playerSentNotification[mapDisplayName] = nil;
            end
        elseif isRecentShout then
            Logger:Debug("Timer", "去重", string.format("检测到新objectGUID但最近喊话触发，保留通知状态：地图=%s，间隔=%ds",
                mapDisplayName, currentTime - (lastShoutTime or currentTime)));
        end
        
        Logger:Debug("Timer", "检测", string.format("检测到新事件（objectGUID不同）：地图=%s，旧objectGUID=%s，新objectGUID=%s", 
            Data:GetMapDisplayName(targetMapData), detectionState.detectedObjectGUID, objectGUID));
        self.detectionState[targetMapData.id] = {
            firstDetectedTime = currentTime,
            detectedObjectGUID = objectGUID
        };
        return true;
    end
    local timeSinceFirstDetection = currentTime - detectionState.firstDetectedTime;
    if timeSinceFirstDetection >= self.CONFIRM_TIME then
        -- 2秒确认后重新检测
        local currentIconResult = IconDetector:DetectIcon(currentMapID);
        if not currentIconResult or not currentIconResult.detected or currentIconResult.objectGUID ~= objectGUID then
            Logger:Debug("Timer", "状态", string.format("2秒确认后重新检测，图标已消失或objectGUID不同，跳过处理：地图=%s", 
                Data:GetMapDisplayName(targetMapData)));
            -- 发送无效空投通知
            if Notification and Notification.NotifyInvalidAirdrop then
                Notification:NotifyInvalidAirdrop(Data:GetMapDisplayName(targetMapData));
            end
            self.detectionState[targetMapData.id] = nil;
            return false;
        end

        -- 等待达到最短稳定时间后再广播/持久化，减少误报
        if timeSinceFirstDetection < self.MIN_STABLE_TIME then
            Logger:DebugLimited("detection:stabilizing_" .. targetMapData.id, "Timer", "检测", 
                string.format("空投检测等待稳定：地图=%s，已持续%d秒，目标GUID=%s", 
                    Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection, objectGUID));
            return true;
        end
        
        Logger:Debug("Timer", "处理", string.format("确认空投事件：地图=%s，首次检测时间=%s，objectGUID=%s", 
            Data:GetMapDisplayName(targetMapData),
            UnifiedDataManager:FormatDateTime(detectionState.firstDetectedTime),
            objectGUID));
        
        -- 选择事件时间：若存在未过期的团队消息临时时间且与检测时间接近，则优先采用该时间
        local eventTimestamp, usedTemporary = UnifiedDataManager:SelectEventTimestamp(targetMapData.id, detectionState.firstDetectedTime);
        local shouldSendNotification = ShouldSendNotification(eventTimestamp, currentTime);
        
        -- 首次检测：根据事件时间决定是否发送团队消息
        if shouldSendNotification and Notification and Notification.NotifyAirdropDetected then
            Notification:NotifyAirdropDetected(
                Data:GetMapDisplayName(targetMapData), 
                self.detectionSources.MAP_ICON
            );
        else
            Logger:Debug("Timer", "通知", string.format("超过团队消息窗口或未配置通知：地图=%s，事件时间=%s，当前时间=%s", 
                Data:GetMapDisplayName(targetMapData),
                UnifiedDataManager:FormatDateTime(eventTimestamp),
                UnifiedDataManager:FormatDateTime(currentTime)));
        end
        
        -- 使用UnifiedDataManager设置持久化时间和位面数据
        local phaseId = nil;
        if IconDetector and IconDetector.ExtractPhaseID and objectGUID then
            phaseId = IconDetector.ExtractPhaseID(objectGUID);
        end
        
        local success = UnifiedDataManager:SetTime(targetMapData.id, eventTimestamp, UnifiedDataManager.TimeSource.ICON_DETECTION);
        
        -- 如果有位面ID，同时设置持久化位面数据
        if success and phaseId and UnifiedDataManager.SetPhase then
            UnifiedDataManager:SetPhase(targetMapData.id, phaseId, UnifiedDataManager.PhaseSource.ICON_DETECTION, true);
        end
        
        if success then
            targetMapData.currentAirdropObjectGUID = objectGUID;
            targetMapData.currentAirdropTimestamp = eventTimestamp;
            
            -- 从空投的 objectGUID 提取位面ID并存储（保持向后兼容）
            if phaseId then
                targetMapData.lastRefreshPhase = phaseId;
                Logger:Debug("Timer", "保存", string.format("已保存位面ID（从objectGUID提取）：地图=%s，位面ID=%s", 
                    Data:GetMapDisplayName(targetMapData), phaseId));
            else
                Logger:Debug("Timer", "保存", string.format("无法从objectGUID提取位面ID：地图=%s，objectGUID=%s", 
                    Data:GetMapDisplayName(targetMapData), objectGUID));
            end
            
            Logger:Debug("Timer", "保存", string.format("准备保存空投信息：地图=%s（地图ID=%d，配置ID=%d），objectGUID=%s，timestamp=%s（%s）", 
                Data:GetMapDisplayName(targetMapData), targetMapData.mapID, targetMapData.id, objectGUID,
                UnifiedDataManager:FormatDateTime(eventTimestamp),
                usedTemporary and "来自团队消息" or "本地检测"));
            Data:SaveMapData(targetMapData.id);
            
            -- 清除临时时间，避免影响后续事件
            UnifiedDataManager:ClearTemporaryTime(targetMapData.id);
            
            -- 清除检测状态
            self.detectionState[targetMapData.id] = nil;
            
            local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
            Logger:Debug("Timer", "更新", string.format("空投事件已处理：地图=%s，来源=%s", 
                Data:GetMapDisplayName(targetMapData), sourceText));
            
            Logger:Debug("Timer", "状态", string.format("空投事件已处理：地图=%s，objectGUID=%s", 
                Data:GetMapDisplayName(targetMapData), objectGUID));
            
            self:UpdateUI();
        else
            Logger:Error("Timer", "错误", string.format("设置持久化时间失败：地图ID=%d", targetMapData.id));
        end
    else
        -- 2秒确认期内
        Logger:DebugLimited("detection:confirming_" .. targetMapData.id, "Timer", "检测", 
            string.format("等待确认中：地图=%s，已等待%d秒，objectGUID=%s", 
                Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection, objectGUID));
    end
    
    return true;
end

function TimerManager:StartMapIconDetection(interval)
    if CrateTrackerZK and CrateTrackerZK.StartMapIconDetection then
        return CrateTrackerZK:StartMapIconDetection(interval);
    end
    Logger:Error("Timer", "错误", "Core map detection controller not available");
    return false;
end

function TimerManager:StopMapIconDetection()
    if CrateTrackerZK and CrateTrackerZK.StopMapIconDetection then
        return CrateTrackerZK:StopMapIconDetection();
    end
    return true;
end


return TimerManager;
