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

-- 使用 Logger 模块统一输出
local function SafeDebug(...)
    Logger:Debug("Timer", "调试", ...);
end

TimerManager.detectionSources = {
    MANUAL_INPUT = "manual_input",
    REFRESH_BUTTON = "refresh_button",
    API_INTERFACE = "api_interface",
    MAP_ICON = "map_icon"
}

-- 注意：调试消息限流已迁移到 Logger 模块

function TimerManager:Initialize()
    self.isInitialized = true;
    self.lastStatusReportTime = self.lastStatusReportTime or 0; -- 上次状态报告时间
    self.STATUS_REPORT_INTERVAL = 30; -- 状态报告间隔（秒，30秒一次，避免频繁输出）
    -- 调试模式下显示初始化信息
    Logger:DebugLimited("timer:init_complete", "Timer", "初始化", "计时器管理器已初始化");
end

-- 使用 Logger 模块统一输出（限流）
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
        Logger:Error("Timer", "错误", L["ErrorInvalidMapID"] .. " " .. tostring(mapId));
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
            local updatedMapData = Data:GetMap(mapId);
            if updatedMapData then
                local sourceText = self:GetSourceDisplayName(source);
                SafeDebug(string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(updatedMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                
                SafeDebug("[Timer] Manual update", "Map=" .. Data:GetMapDisplayName(updatedMapData), "Source=" .. source, "Last=" .. Data:FormatDateTime(updatedMapData.lastRefresh), "Next=" .. Data:FormatDateTime(updatedMapData.nextRefresh));
            end
            
            self:UpdateUI();
        else
            SafeDebug("[Timer] Timer start failed, MapID=" .. mapId .. ", reason=Data:SetLastRefresh returned false");
            Logger:Error("Timer", "错误", L["ErrorTimerStartFailedMapID"] .. tostring(mapId));
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


function TimerManager:CheckAndClearLeftMaps(currentTime)
    -- 委托给 MapTracker 模块处理（包括清除处理状态）
    if MapTracker and MapTracker.CheckAndClearLeftMaps then
        MapTracker:CheckAndClearLeftMaps(currentTime);
    end
end

-- 输出当前状态汇总（定期输出，限流）
function TimerManager:ReportCurrentStatus(currentMapID, targetMapData, currentTime)
    if not Logger or not Logger.debugEnabled then
        return; -- 调试模式未启用，不输出
    end
    
    -- 检查是否需要输出状态报告
    if currentTime - self.lastStatusReportTime < self.STATUS_REPORT_INTERVAL then
        return;
    end
    
    self.lastStatusReportTime = currentTime;
    
    -- 1. 当前地图信息
    local mapName = "未知";
    local mapDisplayName = "未知";
    if targetMapData then
        mapDisplayName = Data:GetMapDisplayName(targetMapData);
        mapName = Localization and Localization:GetMapName(currentMapID) or (targetMapData.name or tostring(currentMapID));
    end
    
    Logger:Debug("Timer", "状态", string.format("【当前地图】ID=%d，名称=%s，配置ID=%d", 
        currentMapID, mapDisplayName, targetMapData and targetMapData.id or 0));
    
    -- 2. 当前区域状态
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
    Logger:Debug("Timer", "状态", string.format("【区域状态】%s", areaStatus));
    
    -- 3. 当前位面信息
    if targetMapData then
        local instanceID = targetMapData.instance or "未获取";
        local lastInstance = targetMapData.lastInstance or "无";
        Logger:Debug("Timer", "状态", string.format("【位面信息】当前位面=%s，上次位面=%s", instanceID, lastInstance));
    end
    
    -- 4. 当前空投检测状态
    if targetMapData and DetectionState then
        local state = DetectionState:GetState(targetMapData.id);
        local stateText = "IDLE（未检测）";
        if state.status == DetectionState.STATES.DETECTING then
            stateText = string.format("DETECTING（检测中，已等待%d秒）", currentTime - (state.firstDetectedTime or currentTime));
        elseif state.status == DetectionState.STATES.CONFIRMED then
            stateText = "CONFIRMED（已确认，等待通知/更新）";
        elseif state.status == DetectionState.STATES.PROCESSED then
            local timeSinceProcessed = currentTime - (state.processedTime or currentTime);
            local remainingTime = DetectionState.PROCESSED_TIMEOUT - timeSinceProcessed;
            stateText = string.format("PROCESSED（已处理，暂停检测，剩余%d秒）", remainingTime > 0 and remainingTime or 0);
        end
        local iconDetected = false;
        if IconDetector and IconDetector.DetectIcon then
            iconDetected = IconDetector:DetectIcon(currentMapID);
        end
        Logger:Debug("Timer", "状态", string.format("【空投检测】状态=%s，图标检测=%s", 
            stateText, iconDetected and "是" or "否"));
    end
    
    -- 5. 检测功能状态
    local detectionRunning = self.mapIconDetectionTimer and true or false;
    Logger:Debug("Timer", "状态", string.format("【检测功能】地图图标检测=%s，位面检测=%s", 
        detectionRunning and "运行中" or "已停止",
        CrateTrackerZK.phaseTimerTicker and "运行中" or "已停止"));
end

-- ========== 简化后的 DetectMapIcons 函数 ==========
function TimerManager:DetectMapIcons()
    -- 1. 获取当前地图ID
    if not C_Map or not C_Map.GetBestMapForUnit then
        SafeDebugLimited("detection_loop:api_unavailable", DT("DebugCMapAPINotAvailable"));
        return false;
    end
    
    local currentMapID = C_Map.GetBestMapForUnit("player");
    if not currentMapID then
        SafeDebugLimited("detection_loop:no_map_id", DT("DebugCannotGetMapID"));
        return false;
    end
    
    -- 检测循环开始（限流显示，避免刷屏）
    SafeDebugLimited("detection_loop:start", "开始检测循环", "当前地图ID=" .. currentMapID);
    
    -- 2. 获取目标地图数据（支持父地图匹配）
    -- 注意：地图匹配信息已在 MapTracker:GetTargetMapData() 中输出（只有地图变化时才输出）
    if not MapTracker or not MapTracker.GetTargetMapData then
        Logger:Error("Timer", "错误", "MapTracker 模块未加载");
        return false;
    end
    
    local targetMapData = MapTracker:GetTargetMapData(currentMapID);
    if not targetMapData then
        -- 即使不在列表中，也要检查离开地图的状态清除
        if MapTracker and MapTracker.CheckAndClearLeftMaps then
            MapTracker:CheckAndClearLeftMaps(getCurrentTimestamp());
        end
        SafeDebugLimited("detection_loop:map_not_in_list", "当前地图不在列表中，跳过检测", "地图ID=" .. currentMapID);
        return false;
    end
    
    -- 3. 处理地图变化
    local currentTime = getCurrentTimestamp();
    
    -- 定期输出状态汇总（限流，每30秒一次）
    self:ReportCurrentStatus(currentMapID, targetMapData, currentTime);
    
    local changeInfo = MapTracker:OnMapChanged(currentMapID, targetMapData, currentTime);
    
    -- 配置地图变化时，清除状态已在 MapTracker:OnMapChanged() 中处理
    
    -- 4. 检查并清除超时的离开地图状态（300秒）
    self:CheckAndClearLeftMaps(currentTime);
    
    -- 5. 检查是否已处理
    if DetectionState and DetectionState:IsProcessed(targetMapData.id) then
        -- 检查是否超时（5分钟）
        if DetectionState:IsProcessedTimeout(targetMapData.id, currentTime) then
            -- 超时，清除状态，重新开始检测
            Logger:Debug("Timer", "状态", string.format(DT("DebugProcessedTimeout"), 
                Data:GetMapDisplayName(targetMapData)));
            DetectionState:ClearProcessed(targetMapData.id);
        else
            -- 未超时，跳过检测（限流输出，避免刷屏）
            local state = DetectionState:GetState(targetMapData.id);
            local timeSinceProcessed = currentTime - (state.processedTime or currentTime);
            local remainingTime = DetectionState.PROCESSED_TIMEOUT - timeSinceProcessed;
            Logger:DebugLimited("state_processed:skipped_" .. targetMapData.id, "Timer", "状态", 
                string.format(DT("DebugProcessedSkipped"), remainingTime > 0 and remainingTime or 0));
            return false;
        end
    end
    
    -- 6. 检测图标（仅依赖名称匹配）
    if not IconDetector or not IconDetector.DetectIcon then
        Logger:Error("Timer", "错误", "IconDetector 模块未加载");
        return false;
    end
    
    local iconDetected = IconDetector:DetectIcon(currentMapID);
    
    -- 7. 更新状态（状态机转换）
    if not DetectionState or not DetectionState.UpdateState then
        Logger:Error("Timer", "错误", "DetectionState 模块未加载");
        return iconDetected;
    end
    
    local oldState = DetectionState:GetState(targetMapData.id);
    local state = DetectionState:UpdateState(targetMapData.id, iconDetected, currentTime);
    
    -- 输出状态变化
    if oldState and oldState.status ~= state.status then
        Logger:Debug("Timer", "检测", string.format("图标检测：地图=%s，检测到图标=%s，状态=%s -> %s", 
            Data:GetMapDisplayName(targetMapData), 
            iconDetected and "是" or "否",
            oldState.status,
            state.status));
    end
    
    -- 8. CONFIRMED 状态处理：通知 + 更新时间 + 标记为已处理
    if state.status == DetectionState.STATES.CONFIRMED then
        Logger:Debug("Timer", "处理", string.format("开始处理 CONFIRMED 状态：地图=%s，首次检测时间=%s", 
            Data:GetMapDisplayName(targetMapData),
            state.firstDetectedTime and Data:FormatDateTime(state.firstDetectedTime) or "无"));
        
        -- 发送通知
        if Notification and Notification.NotifyAirdropDetected then
            Logger:Debug("Timer", "通知", string.format("发送空投检测通知：地图=%s", 
                Data:GetMapDisplayName(targetMapData)));
            Notification:NotifyAirdropDetected(
                Data:GetMapDisplayName(targetMapData), 
                self.detectionSources.MAP_ICON
            );
        end
        if NotificationCooldown and NotificationCooldown.RecordNotification then
            NotificationCooldown:RecordNotification(targetMapData.id, currentTime);
        end
        
        -- 更新时间（自动检测优先级最高，无条件更新）
        local success = Data:SetLastRefresh(targetMapData.id, state.firstDetectedTime);
        if success then
            DetectionState:SetLastUpdateTime(targetMapData.id, state.firstDetectedTime);
            
            -- 标记为已处理，记录处理时间
            DetectionState:MarkAsProcessed(targetMapData.id, currentTime);
            
            local updatedMapData = Data:GetMap(targetMapData.id);
            local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
            if updatedMapData and updatedMapData.nextRefresh then
                SafeDebug(string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(targetMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
                SafeDebug(string.format(DT("DebugUpdatedRefreshTime"), Data:GetMapDisplayName(targetMapData), Data:FormatDateTime(updatedMapData.nextRefresh)));
            end
            
            Logger:Debug("Timer", "状态", string.format(DT("DebugAirdropProcessed"), 
                Data:GetMapDisplayName(targetMapData)));
            
            self:UpdateUI();
        else
            Logger:Error("Timer", "错误", string.format(DT("DebugUpdateRefreshTimeFailed"), targetMapData.id));
            SafeDebug(string.format(DT("DebugUpdateRefreshTimeFailed"), targetMapData.id));
        end
    end
    
    return iconDetected;
end

function TimerManager:StartMapIconDetection(interval)
    if not self.isInitialized then
        Logger:Error("Timer", "错误", L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    self:StopMapIconDetection();
    
    interval = interval or 1;
    
    self.mapIconDetectionTimer = C_Timer.NewTicker(interval, function()
        if Area and not Area.detectionPaused and Area.lastAreaValidState == true then
            self:DetectMapIcons();
        end
    end);
    
    -- 调试模式下显示检测启动信息
    Logger:DebugLimited("timer:detection_started", "Timer", "初始化", "地图图标检测已启动，间隔=" .. interval .. "秒");
    return true;
end

function TimerManager:StopMapIconDetection()
    if self.mapIconDetectionTimer then
        self.mapIconDetectionTimer:Cancel();
        self.mapIconDetectionTimer = nil;
        -- 调试模式下显示检测停止信息
        Logger:Debug("Timer", "状态", "地图图标检测已停止");
    end
    return true;
end


return TimerManager;
