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
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")

TimerManager.detectionSources = {
    MAP_ICON = "map_icon",
    TEAM_MESSAGE = "team_message"
}

function TimerManager:Initialize()
    self.isInitialized = true;
    self.detectionState = self.detectionState or {};
    self.pendingAuthoritativeShoutByMap = self.pendingAuthoritativeShoutByMap or {};
    self.persistentStateBuffer = self.persistentStateBuffer or {};
    self.iconDetectionBuffer = self.iconDetectionBuffer or {};
    self.CONFIRM_TIME = 2;          -- 初筛防抖
    self.MIN_STABLE_TIME = 5;       -- 最短稳定存活时间（秒），达标后才广播/持久化
    self.MAP_SWITCH_GUARD_TIME = 2; -- 配置地图切换后短暂延迟检测，作为地图归属过滤的兜底
    self.AUTHORITATIVE_SHOUT_WINDOW = 120; -- shout 时间待确认窗口；超窗后不再作为当前事件权威时间
    self.mapSwitchGuardState = self.mapSwitchGuardState or {};
    
    -- 初始化UnifiedDataManager
    if UnifiedDataManager and UnifiedDataManager.Initialize then
        UnifiedDataManager:Initialize();
    end
    if AirdropTrajectoryService and AirdropTrajectoryService.Initialize then
        AirdropTrajectoryService:Initialize();
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

local function ClearDetectionState(owner, mapId)
    if not owner or type(mapId) ~= "number" then
        return false
    end
    owner.detectionState = owner.detectionState or {}
    owner.detectionState[mapId] = nil
    return true
end

local function GetAuthoritativeShoutWindow(owner)
    local configuredWindow = owner and tonumber(owner.AUTHORITATIVE_SHOUT_WINDOW) or nil
    if type(configuredWindow) == "number" and configuredWindow > 0 then
        return configuredWindow
    end
    return 120
end

function TimerManager:RegisterPendingAuthoritativeShout(targetMapData, timestamp, phaseId)
    if type(targetMapData) ~= "table" or type(targetMapData.id) ~= "number" then
        return false
    end

    local authoritativeTimestamp = tonumber(timestamp)
    if type(authoritativeTimestamp) ~= "number" then
        return false
    end

    self.pendingAuthoritativeShoutByMap = self.pendingAuthoritativeShoutByMap or {}
    self.pendingAuthoritativeShoutByMap[targetMapData.id] = {
        timestamp = authoritativeTimestamp,
        phaseId = type(phaseId) == "string" and phaseId ~= "" and phaseId or nil,
        registeredAt = Utils:GetCurrentTimestamp(),
    }
    return true
end

function TimerManager:GetValidPendingAuthoritativeShout(runtimeMapId, currentTime)
    if type(runtimeMapId) ~= "number" then
        return nil
    end

    local stateByMap = self.pendingAuthoritativeShoutByMap
    local state = type(stateByMap) == "table" and stateByMap[runtimeMapId] or nil
    if type(state) ~= "table" then
        return nil
    end

    local now = tonumber(currentTime) or getCurrentTimestamp()
    local timestamp = tonumber(state.timestamp)
    local windowSeconds = GetAuthoritativeShoutWindow(self)
    if type(timestamp) ~= "number"
        or now < timestamp
        or (now - timestamp) > windowSeconds then
        self:DiscardPendingAuthoritativeShout(runtimeMapId, true)
        return nil
    end
    return state
end

function TimerManager:ClearPendingAuthoritativeShout(runtimeMapId)
    if type(runtimeMapId) ~= "number" or type(self.pendingAuthoritativeShoutByMap) ~= "table" then
        return false
    end
    self.pendingAuthoritativeShoutByMap[runtimeMapId] = nil
    return true
end

function TimerManager:DiscardPendingAuthoritativeShout(runtimeMapId, clearTemporaryTime)
    if type(runtimeMapId) ~= "number" then
        return false
    end

    local removed = self:ClearPendingAuthoritativeShout(runtimeMapId) == true
    if clearTemporaryTime == true
        and UnifiedDataManager
        and UnifiedDataManager.ClearTemporaryTime then
        UnifiedDataManager:ClearTemporaryTime(runtimeMapId)
    end
    return removed or clearTemporaryTime == true
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

function TimerManager:HandleMapContextChanged(currentMapID, targetMapData, currentTime)
    self.detectionState = self.detectionState or {}

    local playerMapID = currentMapID;
    if not playerMapID and C_Map and C_Map.GetBestMapForUnit then
        playerMapID = C_Map.GetBestMapForUnit("player");
    end
    if not playerMapID or not MapTracker or not MapTracker.GetTargetMapData then
        return nil, targetMapData;
    end

    local now = currentTime or getCurrentTimestamp();
    local resolvedTargetMapData = targetMapData or MapTracker:GetTargetMapData(playerMapID);
    if not resolvedTargetMapData then
        local clearedState = MapTracker.ClearCurrentMapState and MapTracker:ClearCurrentMapState(playerMapID) or nil;
        local oldMapId = clearedState and clearedState.oldMapId or nil;
        if AirdropTrajectoryService and AirdropTrajectoryService.HandleMapSwitch and oldMapId then
            AirdropTrajectoryService:HandleMapSwitch(oldMapId, now);
        end
        ClearDetectionState(self, oldMapId);
        self:DiscardPendingAuthoritativeShout(oldMapId, true);
        self.mapSwitchGuardState = nil;
        return nil, nil;
    end

    local mapChangeState = MapTracker.OnMapChanged and MapTracker:OnMapChanged(playerMapID, resolvedTargetMapData, now) or nil;
    if mapChangeState and mapChangeState.configMapChanged then
        if AirdropTrajectoryService and AirdropTrajectoryService.HandleMapSwitch then
            AirdropTrajectoryService:HandleMapSwitch(mapChangeState.oldMapId, now);
        end
        ClearDetectionState(self, mapChangeState.oldMapId);
        self:DiscardPendingAuthoritativeShout(mapChangeState.oldMapId, true);
        ClearDetectionState(self, resolvedTargetMapData.id);
        self:DiscardPendingAuthoritativeShout(resolvedTargetMapData.id, true);
        ActivateMapSwitchGuard(self, resolvedTargetMapData, now);
    end

    return mapChangeState, resolvedTargetMapData;
end

function TimerManager:IsMapSwitchGuardActiveFor(targetMapData, currentTime)
    return IsMapSwitchGuardActive(self, targetMapData, currentTime or getCurrentTimestamp()) == true;
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
    self.detectionState = self.detectionState or {}
    self.pendingAuthoritativeShoutByMap = self.pendingAuthoritativeShoutByMap or {}

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
    
    local currentTime = getCurrentTimestamp();
    
    local mapChangeState = nil;
    local targetMapData = nil;
    mapChangeState, targetMapData = self:HandleMapContextChanged(playerMapID, nil, currentTime);
    if not targetMapData then
        return false;
    end

    -- 如果地图被隐藏，暂停该地图的空投检测
    if Data and Data.IsMapHidden and Data:IsMapHidden(targetMapData.expansionID, targetMapData.mapID) then
        -- 清除该地图的检测状态，避免残留
        self.detectionState[targetMapData.id] = nil;
        self:DiscardPendingAuthoritativeShout(targetMapData.id, true);
        return false;
    end

    local mapDisplayName = Data:GetMapDisplayName(targetMapData);
    local mapNotificationKey = targetMapData.id;
    if self:IsMapSwitchGuardActiveFor(targetMapData, currentTime) then
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

    if AirdropTrajectoryService and AirdropTrajectoryService.ArmMidFlightSampling then
        AirdropTrajectoryService:ArmMidFlightSampling(targetMapData, iconResult, currentTime);
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
        
        -- 提醒消息按“本地实际发现时间”门控，避免权威时间较早时压掉中途进图玩家的提醒。
        local notificationTimestamp = detectionState.firstDetectedTime;
        local shouldSendNotification = ShouldSendNotification(notificationTimestamp, currentTime);

        -- 只有权威时间（本地 shout 待确认 / 已共享权威时间）才允许进入持久化与隐藏同步。
        local eventTimestamp = nil;
        local hasAuthoritativeTime = false;
        local authoritativeSource = nil;
        local pendingAuthoritativeShout = self.GetValidPendingAuthoritativeShout
            and self:GetValidPendingAuthoritativeShout(targetMapData.id, currentTime)
            or nil;
        if type(pendingAuthoritativeShout) == "table"
            and type(pendingAuthoritativeShout.timestamp) == "number" then
            eventTimestamp = pendingAuthoritativeShout.timestamp;
            hasAuthoritativeTime = true;
            authoritativeSource = UnifiedDataManager.TimeSource.NPC_SHOUT;
        else
            eventTimestamp, hasAuthoritativeTime, authoritativeSource = UnifiedDataManager:SelectEventTimestamp(
                targetMapData.id,
                detectionState.firstDetectedTime,
                iconResult and iconResult.phaseID or nil,
                objectGUID
            );
        end

        if detectionState.confirmedWithoutAuthority == true and hasAuthoritativeTime ~= true then
            return true;
        end
        
        -- 首次检测：根据本地发现时间决定是否发送事件提醒。
        if shouldSendNotification and Notification and Notification.NotifyAirdropDetected then
            Notification:NotifyAirdropDetected(
                mapDisplayName,
                self.detectionSources.MAP_ICON,
                {
                    mapKey = mapNotificationKey,
                    eventTimestamp = notificationTimestamp,
                    objectGUID = objectGUID,
                }
            );
        end

        if hasAuthoritativeTime ~= true then
            detectionState.confirmedWithoutAuthority = true;
            detectionState.confirmedAt = currentTime;
            detectionState.detectedObjectGUID = objectGUID;
            return true;
        end
        
        local phaseId = iconResult and iconResult.phaseID or nil;
        local persistSource = authoritativeSource
            or (UnifiedDataManager.TimeSource and UnifiedDataManager.TimeSource.NPC_SHOUT)
            or self.detectionSources.TEAM_MESSAGE;

        local success = UnifiedDataManager and UnifiedDataManager.PersistConfirmedAirdropState
            and UnifiedDataManager:PersistConfirmedAirdropState(targetMapData.id, {
                lastRefresh = eventTimestamp,
                currentAirdropObjectGUID = objectGUID,
                currentAirdropTimestamp = eventTimestamp,
                lastRefreshPhase = phaseId,
                source = persistSource,
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
            
            -- 清除临时时间，避免影响后续事件
            UnifiedDataManager:ClearTemporaryTime(targetMapData.id);
            self:ClearPendingAuthoritativeShout(targetMapData.id);
            
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
