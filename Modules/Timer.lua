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

TimerManager.detectionSources = {
    MANUAL_INPUT = "manual_input",
    REFRESH_BUTTON = "refresh_button",
    API_INTERFACE = "api_interface",
    MAP_ICON = "map_icon"
}

function TimerManager:Initialize()
    self.isInitialized = true;
    self.lastStatusReportTime = self.lastStatusReportTime or 0;
    self.STATUS_REPORT_INTERVAL = 10;
    self.detectionState = self.detectionState or {};
    self.CONFIRM_TIME = 2;
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

function TimerManager:StartTimer(mapId, source, timestamp)
    if not self.isInitialized then
        Logger:Error("Timer", "错误", L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    local mapData = Data:GetMap(mapId);
    if not mapData then
        Logger:Error("Timer", "错误", string.format(L["ErrorInvalidMapID"], tostring(mapId)));
        return false;
    end
    
    source = source or self.detectionSources.API_INTERFACE;
    timestamp = timestamp or getCurrentTimestamp();
    
    Logger:Debug("Timer", "更新", string.format("StartTimer: MapID=%d, Map=%s, Source=%s, Time=%d", 
        mapId, Data:GetMapDisplayName(mapData), source, timestamp));
    
    local isManualOperation = (source == self.detectionSources.REFRESH_BUTTON or source == self.detectionSources.MANUAL_INPUT);
    local success = false;
    
    if isManualOperation then
        local mapData = Data:GetMap(mapId);
        local needsUpdate = not mapData or mapData.lastRefresh ~= timestamp;
        
        if needsUpdate then
            success = Data:SetLastRefresh(mapId, timestamp);
            if success then
                local updatedMapData = Data:GetMap(mapId);
                if updatedMapData then
                    local sourceText = self:GetSourceDisplayName(source);
                    Logger:Debug("Timer", "更新", string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(updatedMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                end
                if source == self.detectionSources.MANUAL_INPUT then
                    self:UpdateUI();
                end
            else
                Logger:Error("Timer", "错误", string.format(L["ErrorTimerStartFailedMapID"], tostring(mapId)));
            end
        else
            if mapData then
                Data:SaveMapData(mapId);
                Logger:Debug("Timer", "更新", string.format("数据已更新，仅保存：地图=%s，时间=%s", 
                    Data:GetMapDisplayName(mapData), Data:FormatDateTime(timestamp)));
            end
            success = true;
        end
    else
        success = true;
    end
    
    return success;
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


function TimerManager:ReportCurrentStatus(currentMapID, targetMapData, currentTime)
    if not Logger or not Logger.debugEnabled then
        return;
    end
    
    if currentTime - self.lastStatusReportTime < self.STATUS_REPORT_INTERVAL then
        return;
    end
    
    self.lastStatusReportTime = currentTime;
    local mapDisplayName = "未知";
    if targetMapData then
        mapDisplayName = Data:GetMapDisplayName(targetMapData);
    end
    
    local statusParts = {};
    table.insert(statusParts, string.format("【当前地图】ID=%d，名称=%s，配置ID=%d", 
        currentMapID, mapDisplayName, targetMapData and targetMapData.id or 0));
    
    local areaStatus = "未知";
    if Area then
        if Area.detectionPaused then
            areaStatus = "已暂停（区域无效）";
        elseif Area.lastAreaValidState == true then
            areaStatus = "有效（检测运行中）";
        elseif Area.lastAreaValidState == false then
            areaStatus = "无效（检测已暂停）";
        else
            areaStatus = "未初始化";
        end
    end
    table.insert(statusParts, string.format("【区域状态】%s", areaStatus));
    
    if targetMapData then
        -- 显示存储的位面ID（从空投的 objectGUID 提取）
        local storedPhaseID = targetMapData.lastRefreshPhase or "无";
        table.insert(statusParts, string.format("【位面信息】存储位面（从objectGUID）=%s", storedPhaseID));
        -- 显示实时检测的位面ID（Phase 模块检测，用于UI显示）
        local currentPhaseID = targetMapData.currentPhaseID or "无";
        table.insert(statusParts, string.format("【位面信息】实时位面（Phase模块）=%s", currentPhaseID));
    end
    
    if targetMapData then
        local detectionState = self.detectionState[targetMapData.id];
        local stateText = "未检测";
        if detectionState then
            local timeSinceFirst = currentTime - (detectionState.firstDetectedTime or currentTime);
            if timeSinceFirst < self.CONFIRM_TIME then
                stateText = string.format("检测中（已等待%d秒）", timeSinceFirst);
            else
                local guidSuffix = detectionState.detectedObjectGUID and string.sub(detectionState.detectedObjectGUID, -12) or "无";
                stateText = string.format("已确认（等待处理，objectGUID=%s）", guidSuffix);
            end
        end
        
        local iconResult = { detected = false };
        if IconDetector and IconDetector.DetectIcon then
            iconResult = IconDetector:DetectIcon(currentMapID);
        end
        local guidSuffix = iconResult.objectGUID and string.sub(iconResult.objectGUID, -12) or "无";
        table.insert(statusParts, string.format("【空投检测】状态=%s，图标检测=%s，objectGUID=%s", 
            stateText, iconResult.detected and "是" or "否", guidSuffix));
    end
    
    local detectionRunning = self.mapIconDetectionTimer and true or false;
    table.insert(statusParts, string.format("【检测功能】地图图标检测=%s，位面检测=%s", 
        detectionRunning and "运行中" or "已停止",
        CrateTrackerZK.phaseTimerTicker and "运行中" or "已停止"));
    
    -- 合并为一条消息输出
    Logger:DebugLimited("timer:status_report", "Timer", "状态", table.concat(statusParts, " | "));
end

-- 检查是否应该发送通知（30秒限制）
local function ShouldSendNotification(mapData, currentTime)
    if not mapData.currentAirdropTimestamp then
        return true;
    end
    local timeSinceAirdrop = currentTime - mapData.currentAirdropTimestamp;
    return timeSinceAirdrop <= 30;
end

function TimerManager:DetectMapIcons()
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
    
    local currentTime = getCurrentTimestamp();
    self:ReportCurrentStatus(currentMapID, targetMapData, currentTime);
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
        targetMapData.airdropActiveTimestamp = currentTime;
        Logger:DebugLimited("detection:same_event_" .. targetMapData.id, "Timer", "检测", 
            string.format("检测到相同 objectGUID，更新活跃状态（同一事件持续中）：地图=%s（地图ID=%d，配置ID=%d），objectGUID=%s，空投开始时间=%s，活跃时间戳=%s", 
                Data:GetMapDisplayName(targetMapData), targetMapData.mapID, targetMapData.id, objectGUID,
                targetMapData.currentAirdropTimestamp and Data:FormatDateTime(targetMapData.currentAirdropTimestamp) or "无",
                Data:FormatDateTime(currentTime)));
        return true;
    elseif targetMapData.currentAirdropObjectGUID and targetMapData.currentAirdropObjectGUID ~= objectGUID then
        -- 新空投事件：清除通知记录
        local mapDisplayName = Data:GetMapDisplayName(targetMapData);
        if Notification then
            if Notification.firstNotificationTime and Notification.firstNotificationTime[mapDisplayName] then
                Notification.firstNotificationTime[mapDisplayName] = nil;
            end
            if Notification.playerSentNotification and Notification.playerSentNotification[mapDisplayName] then
                Notification.playerSentNotification[mapDisplayName] = nil;
            end
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
        if Notification then
            if Notification.firstNotificationTime and Notification.firstNotificationTime[mapDisplayName] then
                Notification.firstNotificationTime[mapDisplayName] = nil;
            end
            if Notification.playerSentNotification and Notification.playerSentNotification[mapDisplayName] then
                Notification.playerSentNotification[mapDisplayName] = nil;
            end
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
        
        Logger:Debug("Timer", "处理", string.format("确认空投事件：地图=%s，首次检测时间=%s，objectGUID=%s", 
            Data:GetMapDisplayName(targetMapData),
            Data:FormatDateTime(detectionState.firstDetectedTime),
            objectGUID));
        
        -- 检查是否已通过团队时间共享更新过时间
        local hasTeamSharedTime = false;
        local teamTimeShareEnabled = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.teamTimeShareEnabled;
        if teamTimeShareEnabled and targetMapData.currentAirdropTimestamp and targetMapData.lastRefresh then
            local timeDiff = math.abs(targetMapData.currentAirdropTimestamp - targetMapData.lastRefresh);
            if timeDiff <= 1 then
                local timeSinceLastRefresh = currentTime - targetMapData.lastRefresh;
                if timeSinceLastRefresh > 30 then
                    if targetMapData.currentAirdropObjectGUID and targetMapData.currentAirdropObjectGUID ~= objectGUID then
                        hasTeamSharedTime = false;
                        Logger:Debug("Timer", "判断", string.format("检测到新空投事件（objectGUID不同），正常处理：地图=%s，旧objectGUID=%s，新objectGUID=%s", 
                            Data:GetMapDisplayName(targetMapData), targetMapData.currentAirdropObjectGUID, objectGUID));
                    else
                        hasTeamSharedTime = true;
                        Logger:Debug("Timer", "判断", string.format("判断为已通过团队时间共享更新过时间：地图=%s，lastRefresh=%s，currentAirdropTimestamp=%s，时间差=%d秒", 
                            Data:GetMapDisplayName(targetMapData),
                            Data:FormatDateTime(targetMapData.lastRefresh),
                            Data:FormatDateTime(targetMapData.currentAirdropTimestamp),
                            timeSinceLastRefresh));
                    end
                end
            end
        end
        
        -- 已通过团队时间共享更新：只补齐空投信息，不更新时间
        if hasTeamSharedTime then
            local shouldSendNotification = ShouldSendNotification(targetMapData, currentTime);
            if shouldSendNotification and Notification and Notification.NotifyAirdropDetected then
                Notification:NotifyAirdropDetected(
                    Data:GetMapDisplayName(targetMapData), 
                    self.detectionSources.MAP_ICON
                );
            end
            
            targetMapData.currentAirdropObjectGUID = objectGUID;
            targetMapData.currentAirdropTimestamp = detectionState.firstDetectedTime;
            targetMapData.airdropActiveTimestamp = currentTime;
            
            -- 从空投的 objectGUID 提取位面ID并存储
            if IconDetector and IconDetector.ExtractPhaseID and objectGUID then
                local phaseID = IconDetector.ExtractPhaseID(objectGUID);
                if phaseID then
                    targetMapData.lastRefreshPhase = phaseID;
                    Logger:Debug("Timer", "保存", string.format("已保存位面ID（从objectGUID提取）：地图=%s，位面ID=%s", 
                        Data:GetMapDisplayName(targetMapData), phaseID));
                else
                    Logger:Debug("Timer", "保存", string.format("无法从objectGUID提取位面ID：地图=%s，objectGUID=%s", 
                        Data:GetMapDisplayName(targetMapData), objectGUID));
                end
            end
            
            Logger:Debug("Timer", "保存", string.format("准备保存空投信息：地图=%s（地图ID=%d，配置ID=%d），objectGUID=%s，timestamp=%s", 
                Data:GetMapDisplayName(targetMapData), targetMapData.mapID, targetMapData.id, objectGUID,
                Data:FormatDateTime(detectionState.firstDetectedTime)));
            Data:SaveMapData(targetMapData.id);
            
            -- 清除检测状态
            self.detectionState[targetMapData.id] = nil;
            
            Logger:Debug("Timer", "状态", string.format("空投信息已补齐：地图=%s（地图ID=%d，配置ID=%d），objectGUID=%s", 
                Data:GetMapDisplayName(targetMapData), targetMapData.mapID, targetMapData.id, objectGUID));
            
            self:UpdateUI();
        else
            -- 首次检测：无条件发送通知
            if Notification and Notification.NotifyAirdropDetected then
                Notification:NotifyAirdropDetected(
                    Data:GetMapDisplayName(targetMapData), 
                    self.detectionSources.MAP_ICON
                );
            end
            
            local success = Data:SetLastRefresh(targetMapData.id, detectionState.firstDetectedTime);
            if success then
                targetMapData.currentAirdropObjectGUID = objectGUID;
                targetMapData.currentAirdropTimestamp = detectionState.firstDetectedTime;
                -- 设置空投活跃状态时间戳（内存变量，用于通知按钮判断）
                targetMapData.airdropActiveTimestamp = currentTime;
                
                -- 从空投的 objectGUID 提取位面ID并存储
                if IconDetector and IconDetector.ExtractPhaseID and objectGUID then
                    local phaseID = IconDetector.ExtractPhaseID(objectGUID);
                    if phaseID then
                        targetMapData.lastRefreshPhase = phaseID;
                        Logger:Debug("Timer", "保存", string.format("已保存位面ID（从objectGUID提取）：地图=%s，位面ID=%s", 
                            Data:GetMapDisplayName(targetMapData), phaseID));
                    else
                        Logger:Debug("Timer", "保存", string.format("无法从objectGUID提取位面ID：地图=%s，objectGUID=%s", 
                            Data:GetMapDisplayName(targetMapData), objectGUID));
                    end
                end
                
                Logger:Debug("Timer", "保存", string.format("准备保存空投信息：地图=%s（地图ID=%d，配置ID=%d），objectGUID=%s", 
                    Data:GetMapDisplayName(targetMapData), targetMapData.mapID, targetMapData.id, objectGUID));
                Data:SaveMapData(targetMapData.id);
                
                -- 清除检测状态
                self.detectionState[targetMapData.id] = nil;
                
                local updatedMapData = Data:GetMap(targetMapData.id);
                local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
                if updatedMapData and updatedMapData.nextRefresh then
                    Logger:Debug("Timer", "更新", string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(targetMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                end
                
                Logger:Debug("Timer", "状态", string.format("空投事件已处理：地图=%s，objectGUID=%s", 
                    Data:GetMapDisplayName(targetMapData), objectGUID));
                
                self:UpdateUI();
            else
                Logger:Error("Timer", "错误", string.format(L["ErrorUpdateRefreshTimeFailed"], targetMapData.id));
            end
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
    if not self.isInitialized then
        Logger:Error("Timer", "错误", "Timer manager not initialized");
        return false;
    end
    
    self:StopMapIconDetection();
    
    interval = interval or 1;
    
    self.mapIconDetectionTimer = C_Timer.NewTicker(interval, function()
        if Area and not Area.detectionPaused and Area.lastAreaValidState == true then
            self:DetectMapIcons();
        end
    end);
    
    Logger:Debug("Timer", "初始化", string.format("地图图标检测已启动，间隔=%d秒", interval));
    return true;
end

function TimerManager:StopMapIconDetection()
    if self.mapIconDetectionTimer then
        self.mapIconDetectionTimer:Cancel();
        self.mapIconDetectionTimer = nil;
        Logger:Debug("Timer", "状态", "地图图标检测已停止");
    end
    return true;
end


return TimerManager;
