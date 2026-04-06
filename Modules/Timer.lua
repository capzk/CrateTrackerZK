-- Timer.lua - 检测循环管理器

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TimerManager = BuildEnv('TimerManager')

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local AirdropEventService = BuildEnv("AirdropEventService");

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

local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")

TimerManager.detectionSources = {
    MAP_ICON = "map_icon",
    TEAM_MESSAGE = "team_message"
}

function TimerManager:Initialize()
    self.isInitialized = true;
    self.detectionState = self.detectionState or {};
    self.persistentStateBuffer = self.persistentStateBuffer or {};
    self.iconDetectionBuffer = self.iconDetectionBuffer or {};
    self.CONFIRM_TIME = 2;          -- 初筛防抖
    self.MIN_STABLE_TIME = 5;       -- 最短稳定存活时间（秒），达标后才广播/持久化
    self.MAP_SWITCH_GUARD_TIME = 2; -- 配置地图切换后短暂延迟检测，作为地图归属过滤的兜底
    self.mapSwitchGuardState = self.mapSwitchGuardState or {};
    
    -- 初始化UnifiedDataManager
    if UnifiedDataManager and UnifiedDataManager.Initialize then
        UnifiedDataManager:Initialize();
    end
end

local function AcquirePersistentStateBuffer(owner)
    owner.persistentStateBuffer = owner.persistentStateBuffer or {};
    return owner.persistentStateBuffer;
end

local function AcquireIconDetectionBuffer(owner)
    owner.iconDetectionBuffer = owner.iconDetectionBuffer or {};
    return owner.iconDetectionBuffer;
end

local function getCurrentTimestamp()
    return Utils:GetCurrentTimestamp();
end

local function HasRecentShout(mapNotificationKey, currentTime)
    if Notification and Notification.IsRecentShout then
        return Notification:IsRecentShout(mapNotificationKey, Notification.SHOUT_DEDUP_WINDOW, currentTime);
    end
    return false, nil;
end

local function ResetNotificationStateForNewEvent(mapNotificationKey, currentTime)
    local isRecentShout, lastShoutTime = HasRecentShout(mapNotificationKey, currentTime);
    local shouldReset = nil;
    if AirdropEventService and AirdropEventService.ShouldResetNotificationStateForNewEvent then
        shouldReset = AirdropEventService:ShouldResetNotificationStateForNewEvent(
            lastShoutTime,
            currentTime,
            Notification and Notification.SHOUT_DEDUP_WINDOW or 20
        );
    else
        shouldReset = not isRecentShout;
    end

    if shouldReset and Notification and Notification.ResetMapNotificationState then
        Notification:ResetMapNotificationState(mapNotificationKey);
    end
end

local function ActivateMapSwitchGuard(owner, targetMapData, currentTime)
    if not owner or not targetMapData or targetMapData.id == nil then
        return false
    end

    owner.mapSwitchGuardState = owner.mapSwitchGuardState or {}
    owner.mapSwitchGuardState.mapId = targetMapData.id
    owner.mapSwitchGuardState.untilTime = currentTime + (owner.MAP_SWITCH_GUARD_TIME or 2)
    owner.detectionState[targetMapData.id] = nil
    return true
end

local function IsMapSwitchGuardActive(owner, targetMapData, currentTime)
    if not owner or not targetMapData or targetMapData.id == nil then
        return false
    end

    local guardState = owner.mapSwitchGuardState
    if type(guardState) ~= "table" then
        return false
    end
    if guardState.mapId ~= targetMapData.id then
        return false
    end

    local untilTime = tonumber(guardState.untilTime)
    if not untilTime then
        owner.mapSwitchGuardState = nil
        return false
    end
    if currentTime < untilTime then
        return true
    end

    owner.mapSwitchGuardState = nil
    return false
end

function TimerManager:UpdateUI()
    if UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable();
    end
end


-- 检查同地图同一空投事件是否仍在自动通知窗口内
local function ShouldSendNotification(eventTimestamp, currentTime)
    if AirdropEventService and AirdropEventService.ShouldBroadcastByEventAge then
        return AirdropEventService:ShouldBroadcastByEventAge(
            eventTimestamp,
            currentTime,
            Notification and Notification.NOTIFICATION_WINDOW or 15
        );
    end
    if not eventTimestamp then
        return true;
    end
    local timeSinceAirdrop = currentTime - eventTimestamp;
    return timeSinceAirdrop <= (Notification and Notification.NOTIFICATION_WINDOW or 15);
end

function TimerManager:DetectMapIcons(currentMapID)
    if Area and Area.IsActive and not Area:IsActive() then
        return false;
    end
    
    local playerMapID = currentMapID;
    if not playerMapID then
        if not C_Map or not C_Map.GetBestMapForUnit then
            return false;
        end
        playerMapID = C_Map.GetBestMapForUnit("player");
    end
    
    if not playerMapID then
        return false;
    end
    if not MapTracker or not MapTracker.GetTargetMapData then
        Logger:Error("Timer", "错误", "MapTracker module not loaded");
        return false;
    end
    
    local targetMapData = MapTracker:GetTargetMapData(playerMapID);
    if not targetMapData then
        return false;
    end

    -- 如果地图被隐藏，暂停该地图的空投检测
    if Data and Data.IsMapHidden and Data:IsMapHidden(targetMapData.expansionID, targetMapData.mapID) then
        -- 清除该地图的检测状态，避免残留
        self.detectionState[targetMapData.id] = nil;
        return false;
    end

    local mapDisplayName = Data:GetMapDisplayName(targetMapData);
    local mapNotificationKey = targetMapData.id;
    
    local currentTime = getCurrentTimestamp();
    local mapChangeState = nil;
    if MapTracker.OnMapChanged then
        mapChangeState = MapTracker:OnMapChanged(playerMapID, targetMapData, currentTime);
    elseif MapTracker.UpdateCurrentMapState then
        MapTracker:UpdateCurrentMapState(playerMapID, targetMapData, currentTime);
    else
        MapTracker:OnMapChanged(playerMapID, targetMapData, currentTime);
    end

    if mapChangeState and mapChangeState.configMapChanged then
        ActivateMapSwitchGuard(self, targetMapData, currentTime);
    end
    if IsMapSwitchGuardActive(self, targetMapData, currentTime) then
        return false;
    end
    
    if not IconDetector or not IconDetector.DetectIcon then
        Logger:Error("Timer", "错误", "IconDetector module not loaded");
        return false;
    end
    
    -- 检测图标
    local iconResult = IconDetector.DetectIconInto
        and IconDetector:DetectIconInto(playerMapID, targetMapData.mapID, AcquireIconDetectionBuffer(self))
        or IconDetector:DetectIcon(playerMapID, targetMapData.mapID);
    if not iconResult or not iconResult.detected then
        -- 图标消失，清除检测状态
        self.detectionState[targetMapData.id] = nil;
        return false;
    end
    
    local objectGUID = iconResult.objectGUID;
    
    -- 验证 objectGUID 格式
    if not objectGUID or type(objectGUID) ~= "string" then
        Logger:Error("Timer", "错误", string.format("检测到无效的 objectGUID：地图=%s，objectGUID=%s", 
            mapDisplayName, tostring(objectGUID)));
        return false;
    end
    
    local guidPartCount = select("#", strsplit("-", objectGUID));
    if guidPartCount < 7 then
        Logger:Error("Timer", "错误", string.format("检测到格式不正确的 objectGUID：地图=%s，objectGUID=%s（只有%d部分，需要至少7部分）", 
            mapDisplayName, objectGUID, guidPartCount));
        return false;
    end
    
    -- objectGUID 比对：相同则跳过（同一事件）
    local persistentState = UnifiedDataManager and UnifiedDataManager.GetPersistentAirdropStateInto
        and UnifiedDataManager:GetPersistentAirdropStateInto(targetMapData.id, AcquirePersistentStateBuffer(self))
        or nil;
    local persistentObjectGUID = persistentState and persistentState.currentAirdropObjectGUID or nil;
    local hasSameObjectGUID = AirdropEventService and AirdropEventService.HasSameObjectGUID
        and AirdropEventService:HasSameObjectGUID(persistentObjectGUID, objectGUID)
        or (persistentObjectGUID and persistentObjectGUID == objectGUID);
    local hasDifferentObjectGUID = AirdropEventService and AirdropEventService.HasDifferentObjectGUID
        and AirdropEventService:HasDifferentObjectGUID(persistentObjectGUID, objectGUID)
        or (persistentObjectGUID and persistentObjectGUID ~= objectGUID);

    if hasSameObjectGUID then
        return true;
    elseif hasDifferentObjectGUID then
        -- 新空投事件：清除通知记录（但若刚被喊话触发，则保留去重状态）
        ResetNotificationStateForNewEvent(mapNotificationKey, currentTime);
    end
    
    local detectionState = self.detectionState[targetMapData.id];
    if not detectionState then
        -- 首次检测
        self.detectionState[targetMapData.id] = AirdropEventService
            and AirdropEventService.CreateDetectionState
            and AirdropEventService:CreateDetectionState(currentTime, objectGUID)
            or {
                firstDetectedTime = currentTime,
                detectedObjectGUID = objectGUID
            };
        return true;
    end
    
    if (AirdropEventService and AirdropEventService.HasDifferentObjectGUID
        and AirdropEventService:HasDifferentObjectGUID(detectionState.detectedObjectGUID, objectGUID))
        or (detectionState.detectedObjectGUID ~= objectGUID) then
        -- 新事件：清除通知记录
        ResetNotificationStateForNewEvent(mapNotificationKey, currentTime);
        self.detectionState[targetMapData.id] = AirdropEventService
            and AirdropEventService.CreateDetectionState
            and AirdropEventService:CreateDetectionState(currentTime, objectGUID)
            or {
                firstDetectedTime = currentTime,
                detectedObjectGUID = objectGUID
            };
        return true;
    end
    local timeSinceFirstDetection = currentTime - detectionState.firstDetectedTime;
    if timeSinceFirstDetection >= self.CONFIRM_TIME then
        -- 等待达到最短稳定时间后再广播/持久化，减少误报
        if timeSinceFirstDetection < self.MIN_STABLE_TIME then
            return true;
        end
        
        -- 选择事件时间：若存在未过期的团队消息临时时间且与检测时间接近，则优先采用该时间
        local eventTimestamp = UnifiedDataManager:SelectEventTimestamp(
            targetMapData.id,
            detectionState.firstDetectedTime,
            iconResult and iconResult.phaseID or nil
        );
        local shouldSendNotification = ShouldSendNotification(eventTimestamp, currentTime);
        
        -- 首次检测：根据事件时间决定是否发送团队消息
        if shouldSendNotification and Notification and Notification.NotifyAirdropDetected then
            Notification:NotifyAirdropDetected(
                mapDisplayName,
                self.detectionSources.MAP_ICON,
                {
                    mapKey = mapNotificationKey,
                    eventTimestamp = eventTimestamp,
                    objectGUID = objectGUID,
                }
            );
        end
        
        local phaseId = iconResult and iconResult.phaseID or nil;

        local success = UnifiedDataManager and UnifiedDataManager.PersistConfirmedAirdropState
            and UnifiedDataManager:PersistConfirmedAirdropState(targetMapData.id, {
                lastRefresh = eventTimestamp,
                currentAirdropObjectGUID = objectGUID,
                currentAirdropTimestamp = eventTimestamp,
                lastRefreshPhase = phaseId,
                source = UnifiedDataManager.TimeSource.ICON_DETECTION,
                phaseSource = UnifiedDataManager.PhaseSource.ICON_DETECTION,
            });
        
        if success then
            if Notification and Notification.SendAirdropSync then
                Notification:SendAirdropSync({
                    mapID = targetMapData.mapID,
                    timestamp = eventTimestamp,
                    objectGUID = objectGUID,
                });
            end

            if PublicChannelSyncListener
                and PublicChannelSyncListener.SendConfirmedSync
                and PublicChannelSyncListener.IsFeatureEnabled
                and PublicChannelSyncListener:IsFeatureEnabled() == true
                and type(phaseId) == "string"
                and phaseId ~= "" then
                PublicChannelSyncListener:SendConfirmedSync({
                    expansionID = targetMapData.expansionID,
                    mapID = targetMapData.mapID,
                    phaseID = phaseId,
                    timestamp = eventTimestamp,
                    objectGUID = objectGUID,
                });
            end
            
            -- 清除临时时间，避免影响后续事件
            UnifiedDataManager:ClearTemporaryTime(targetMapData.id);
            
            -- 清除检测状态
            self.detectionState[targetMapData.id] = nil;

            self:UpdateUI();
        else
            Logger:Error("Timer", "错误", string.format("设置持久化时间失败：地图ID=%d", targetMapData.id));
        end
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
