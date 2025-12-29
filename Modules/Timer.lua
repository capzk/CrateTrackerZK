-- Timer.lua
-- 核心检测循环管理器，协调地图图标检测、状态更新和通知

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
    self.STATUS_REPORT_INTERVAL = 10;  -- 状态报告间隔10秒（中级重要信息）
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
        Logger:Error("Timer", "错误", "Invalid map ID: " .. tostring(mapId));
        return false;
    end
    
    source = source or self.detectionSources.API_INTERFACE;
    timestamp = timestamp or getCurrentTimestamp();
    
    Logger:Debug("Timer", "更新", string.format("StartTimer: MapID=%d, Map=%s, Source=%s, Time=%d", 
        mapId, Data:GetMapDisplayName(mapData), source, timestamp));
    
    local isManualOperation = (source == self.detectionSources.REFRESH_BUTTON or source == self.detectionSources.MANUAL_INPUT);
    local success = false;
    
    if isManualOperation then
        -- 检查数据是否已经更新（避免重复更新，特别是刷新按钮已经更新过的情况）
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
                -- 刷新按钮已经在 RefreshMap 中更新了UI，这里不再重复更新
                -- 手动输入需要更新UI
                if source == self.detectionSources.MANUAL_INPUT then
                    self:UpdateUI();
                end
            else
                Logger:Error("Timer", "错误", "Timer start failed: Map ID=" .. tostring(mapId));
            end
        else
            -- 数据已经更新，只保存数据（刷新按钮已经更新了内存数据，这里只需要保存）
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
    -- 更新UI显示（如果主面板显示）
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
    
    -- 合并状态报告为一条消息，减少输出
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
        local instanceID = targetMapData.instance or "未获取";
        local lastInstance = targetMapData.lastInstance or "无";
        table.insert(statusParts, string.format("【位面信息】当前位面=%s，上次位面=%s", instanceID, lastInstance));
    end
    
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
        table.insert(statusParts, string.format("【空投检测】状态=%s，图标检测=%s", 
            stateText, iconDetected and "是" or "否"));
    end
    
    local detectionRunning = self.mapIconDetectionTimer and true or false;
    table.insert(statusParts, string.format("【检测功能】地图图标检测=%s，位面检测=%s", 
        detectionRunning and "运行中" or "已停止",
        CrateTrackerZK.phaseTimerTicker and "运行中" or "已停止"));
    
    -- 合并为一条消息输出
    Logger:DebugLimited("timer:status_report", "Timer", "状态", table.concat(statusParts, " | "));
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
    if DetectionState and DetectionState:IsProcessed(targetMapData.id) then
        if DetectionState:IsProcessedTimeout(targetMapData.id, currentTime) then
            Logger:Debug("Timer", "状态", string.format(DT("DebugProcessedTimeout"), 
                Data:GetMapDisplayName(targetMapData)));
            DetectionState:ClearProcessed(targetMapData.id);
        else
            local state = DetectionState:GetState(targetMapData.id);
            local timeSinceProcessed = currentTime - (state.processedTime or currentTime);
            local remainingTime = DetectionState.PROCESSED_TIMEOUT - timeSinceProcessed;
            Logger:DebugLimited("state_processed:skipped_" .. targetMapData.id, "Timer", "状态", 
                string.format(DT("DebugProcessedSkipped"), remainingTime > 0 and remainingTime or 0));
            return false;
        end
    end
    if not IconDetector or not IconDetector.DetectIcon then
        Logger:Error("Timer", "错误", "IconDetector module not loaded");
        return false;
    end
    
    local iconDetected = IconDetector:DetectIcon(currentMapID);
    
    if not DetectionState or not DetectionState.UpdateState then
        Logger:Error("Timer", "错误", "DetectionState module not loaded");
        return iconDetected;
    end
    
    local oldState = DetectionState:GetState(targetMapData.id);
    local state = DetectionState:UpdateState(targetMapData.id, iconDetected, currentTime);
    
    if oldState and oldState.status ~= state.status then
        Logger:Debug("Timer", "检测", string.format("图标检测：地图=%s，检测到图标=%s，状态=%s -> %s", 
            Data:GetMapDisplayName(targetMapData), 
            iconDetected and "是" or "否",
            oldState.status,
            state.status));
    end
    if state.status == DetectionState.STATES.CONFIRMED then
        -- 关键验证：再次检查图标是否仍然存在，确保只有真正的空投事件才进入PROCESSED
        local currentIconDetected = IconDetector:DetectIcon(currentMapID);
        if not currentIconDetected then
            Logger:Debug("Timer", "状态", string.format("CONFIRMED状态下图标已消失（重新检测确认），跳过处理：地图=%s", 
                Data:GetMapDisplayName(targetMapData)));
            return currentIconDetected;
        end
        
        Logger:Debug("Timer", "处理", string.format("开始处理 CONFIRMED 状态：地图=%s，首次检测时间=%s", 
            Data:GetMapDisplayName(targetMapData),
            state.firstDetectedTime and Data:FormatDateTime(state.firstDetectedTime) or "无"));
        
        -- 检查是否在30秒内收到过团队消息（防止重复通知）
        local shouldSendNotification = true;
        if TeamMessageReader and TeamMessageReader.lastTeamMessageTime then
            local lastTeamMessageTime = TeamMessageReader.lastTeamMessageTime[targetMapData.id];
            if lastTeamMessageTime then
                local timeSinceTeamMessage = currentTime - lastTeamMessageTime;
                if timeSinceTeamMessage < TeamMessageReader.MESSAGE_COOLDOWN then
                    shouldSendNotification = false;
                    Logger:Debug("Timer", "通知", string.format("30秒内收到过团队消息，不发送重复通知：地图=%s，距离团队消息=%d秒", 
                        Data:GetMapDisplayName(targetMapData), timeSinceTeamMessage));
                else
                    shouldSendNotification = false;
                    Logger:Debug("Timer", "通知", string.format("距离团队消息已超过30秒（%d秒），不再发送通知：地图=%s", 
                        timeSinceTeamMessage, Data:GetMapDisplayName(targetMapData)));
                end
            end
        end
        
        if shouldSendNotification and Notification and Notification.NotifyAirdropDetected then
            Notification:NotifyAirdropDetected(
                Data:GetMapDisplayName(targetMapData), 
                self.detectionSources.MAP_ICON
            );
        end
        
        local success = Data:SetLastRefresh(targetMapData.id, state.firstDetectedTime);
        if success then
            DetectionState:SetLastUpdateTime(targetMapData.id, state.firstDetectedTime);
            DetectionState:MarkAsProcessed(targetMapData.id, currentTime);
            
            local updatedMapData = Data:GetMap(targetMapData.id);
            local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
            if updatedMapData and updatedMapData.nextRefresh then
                Logger:Debug("Timer", "更新", string.format(DT("DebugTimerStarted"), Data:GetMapDisplayName(targetMapData), sourceText, Data:FormatDateTime(updatedMapData.nextRefresh)));
            end
            
            Logger:Debug("Timer", "状态", string.format(DT("DebugAirdropProcessed"), 
                Data:GetMapDisplayName(targetMapData)));
            
            self:UpdateUI();
        else
            Logger:Error("Timer", "错误", string.format("Failed to update refresh time: Map ID=%s", targetMapData.id));
        end
    end
    
    if oldState and oldState.status == DetectionState.STATES.CONFIRMED and state.status == DetectionState.STATES.IDLE then
        Logger:Debug("Timer", "状态", string.format("CONFIRMED状态已清除：地图=%s（已通过2秒确认，静默清除）", 
            Data:GetMapDisplayName(targetMapData)));
    end
    
    return iconDetected;
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
    
    -- 核心操作：启动检测循环
    Logger:Debug("Timer", "初始化", string.format("地图图标检测已启动，间隔=%d秒", interval));
    return true;
end

function TimerManager:StopMapIconDetection()
    if self.mapIconDetectionTimer then
        self.mapIconDetectionTimer:Cancel();
        self.mapIconDetectionTimer = nil;
        -- 核心操作：停止检测循环
        Logger:Debug("Timer", "状态", "地图图标检测已停止");
    end
    return true;
end


return TimerManager;
