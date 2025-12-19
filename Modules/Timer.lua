-- 空投物资追踪器计时管理器模块
-- 提供统一的计时启动接口，支持多种检测手段

-- 确保BuildEnv函数存在
if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

-- 定义TimerManager命名空间
local TimerManager = BuildEnv('TimerManager')

-- 获取命名空间和本地化
local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

-- 确保Data命名空间存在
if not Data then
    Data = BuildEnv('Data')
end

-- 确保Utils命名空间存在
if not Utils then
    Utils = BuildEnv('Utils')
end

-- 安全的调试函数包装
local function SafeDebug(...)
    if Utils and Utils.Debug and type(Utils.Debug) == "function" then
        Utils.Debug(...);
    elseif Utils and Utils.debugEnabled then
        -- 如果Utils.Debug不存在但debugEnabled存在，使用简单的打印
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
    -- 如果Utils.Debug不存在且debugEnabled为false，则静默忽略
end

-- 记录已注册的检测源
TimerManager.detectionSources = {
    MANUAL_INPUT = "manual_input",
    REFRESH_BUTTON = "refresh_button",
    API_INTERFACE = "api_interface",
    MAP_ICON = "map_icon"
}

-- 调试信息输出限制：避免刷屏，相同信息每30秒最多输出一次
TimerManager.lastDebugMessage = TimerManager.lastDebugMessage or {};
TimerManager.DEBUG_MESSAGE_INTERVAL = 30; -- 30秒

-- 初始化TimerManager
function TimerManager:Initialize()
    -- 可以在这里添加初始化代码
    self.isInitialized = true;
    -- 记录每个地图的最后检测时间（用于位面变化时清除标记）
    self.lastDetectionTime = self.lastDetectionTime or {};
    -- 记录每个地图的通知发送次数，用于限制通知数量
    self.notificationCount = self.notificationCount or {};
    -- 记录每个地图是否检测到地图图标（用于判断空投事件是否进行中，不用于更新时间）
    self.mapIconDetected = self.mapIconDetected or {};
    -- 记录每个地图首次检测到图标的时间（用于连续检测验证，防止误报）
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {};
    -- 记录每个地图最近一次通过NPC喊话或地图图标更新时间的时刻（用于防止重复更新）
    self.lastUpdateTime = self.lastUpdateTime or {};
    -- 调试信息输出时间记录（用于限制输出频率）
    self.lastDebugMessage = self.lastDebugMessage or {};
    SafeDebug("【初始化】计时管理器已初始化");
end

-- 限制调试信息输出频率，避免刷屏
local function SafeDebugLimited(messageKey, ...)
    local currentTime = time();
    local lastTime = TimerManager.lastDebugMessage[messageKey] or 0;
    
    -- 如果距离上次输出超过间隔时间，才输出
    if (currentTime - lastTime) >= TimerManager.DEBUG_MESSAGE_INTERVAL then
        TimerManager.lastDebugMessage[messageKey] = currentTime;
        SafeDebug(...);
    end
end

-- 获取当前时间戳
local function getCurrentTimestamp()
    return time();
end

-- 更新指定地图的计时
-- @param mapId 地图ID
-- @param source 检测源（可选，用于记录是哪种方式触发的计时）
-- @param timestamp 时间戳（可选，默认为当前时间）
-- @return boolean 操作是否成功
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
    
    -- 设置默认值
    source = source or self.detectionSources.API_INTERFACE;
    timestamp = timestamp or getCurrentTimestamp();
    
    SafeDebug(L["DebugAPICall"] .. ": TimerManager:StartTimer", L["DebugMapID"] .. "=" .. mapId, L["DebugMapName"] .. "=" .. Data:GetMapDisplayName(mapData), L["DebugSource"] .. "=" .. source, L["DebugTimestamp"] .. "=" .. timestamp);
    
    -- 检测源分类：
    -- 1. 手动刷新按钮/手动输入：更新刷新时间，不设置空投进行中标记，不发送通知
    -- 2. 地图图标检测：首次检测到图标时更新刷新时间，设置空投进行中标记，发送通知（在DetectMapIcons函数中处理）
    local isManualOperation = (source == self.detectionSources.REFRESH_BUTTON or source == self.detectionSources.MANUAL_INPUT);
    local success = false;
    
    if isManualOperation then
        -- 手动刷新按钮/手动输入：更新刷新时间，不设置空投进行中标记，不发送通知
        -- 更新刷新时间
        success = Data:SetLastRefresh(mapId, timestamp);
        
        if success then
            -- 对于手动输入，设置时间锁定标志以防止自动更新修改这个时间
            if source == self.detectionSources.MANUAL_INPUT and Data.manualInputLock then
                Data.manualInputLock[mapId] = timestamp;
            end
            
            -- 记录日志（只在调试模式下输出）
            local sourceText = self:GetSourceDisplayName(source);
            SafeDebug(string.format(L["DebugTimerStarted"], Data:GetMapDisplayName(mapData), sourceText, Data:FormatDateTime(mapData.nextRefresh)));
            
            SafeDebug(L["DebugManualUpdate"], L["DebugMapName"] .. "=" .. Data:GetMapDisplayName(mapData), L["DebugSource"] .. "=" .. source, L["DebugLastRefresh"] .. "=" .. Data:FormatDateTime(mapData.lastRefresh), L["DebugNextRefresh"] .. "=" .. Data:FormatDateTime(mapData.nextRefresh));
            
            -- 更新界面显示
            self:UpdateUI();
        else
            -- 更新刷新时间失败
            SafeDebug("计时启动失败", "地图ID=" .. mapId, "原因=Data:SetLastRefresh返回false");
            Utils.PrintError(L["ErrorTimerStartFailedMapID"] .. tostring(mapId));
        end
    else
        -- 其他检测源（如地图图标检测、API接口等）：不更新刷新时间
        -- 注意：地图图标检测在DetectMapIcons函数中处理，这里不需要处理
        success = true;
    end
    
    return success;
end

-- 批量更新多个地图的计时
-- @param mapIds 地图ID列表
-- @param source 检测源
-- @param timestamp 时间戳（可选，默认为当前时间）
-- @return boolean 操作是否成功
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

-- 启动当前地图的计时
-- @param source 检测源
-- @param timestamp 时间戳（可选，默认为当前时间）
-- @return boolean 操作是否成功
function TimerManager:StartCurrentMapTimer(source, timestamp)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    SafeDebug(L["DebugAPICall"] .. ": TimerManager:StartCurrentMapTimer", L["DebugSource"] .. "=" .. (source or "nil"));
    
    -- 获取当前地图信息
    local currentMapID = C_Map.GetBestMapForUnit("player");
    local currentMapName = "";
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if mapInfo and mapInfo.name then
        currentMapName = mapInfo.name;
        SafeDebug(L["DebugGetMapInfoSuccess"], L["DebugMapID"] .. "=" .. currentMapID, L["DebugMapName"] .. "=" .. currentMapName);
    else
        -- 备选方案：使用GetInstanceInfo
        currentMapName = select(1, GetInstanceInfo());
        SafeDebug(L["DebugUsingGetInstanceInfo"], L["DebugMapName"] .. "=" .. (currentMapName or "nil"));
    end
    
    if currentMapName then
        return self:StartTimerByName(currentMapName, source, timestamp);
    else
        SafeDebug(L["DebugCannotGetMapName"], L["DebugMapID"] .. "=" .. (currentMapID or "nil"));
        Utils.PrintError(L["DebugCannotGetMapName2"]);
        return false;
    end
end

-- 获取检测源的显示名称
-- @param source 检测源标识符
-- @return string 显示名称
function TimerManager:GetSourceDisplayName(source)
    local displayNames = {
        [self.detectionSources.MANUAL_INPUT] = L["DebugDetectionSourceManual"],
        [self.detectionSources.REFRESH_BUTTON] = L["DebugDetectionSourceRefresh"],
        [self.detectionSources.API_INTERFACE] = L["DebugDetectionSourceAPI"],
        [self.detectionSources.MAP_ICON] = L["DebugDetectionSourceMapIcon"]
    };
    
    return displayNames[source] or L["DebugUnknownSource"];
end

-- 更新UI显示
function TimerManager:UpdateUI()
    -- 检查MainPanel是否存在且有UpdateTable方法
    if MainPanel and MainPanel.UpdateTable then
        MainPanel:UpdateTable();
    end
end

-- 注册新的检测源（用于扩展）
-- @param sourceId 检测源标识符
-- @param displayName 显示名称
function TimerManager:RegisterDetectionSource(sourceId, displayName)
    if not sourceId or not displayName then
        Utils.PrintError(L["ErrorInvalidSourceParam"]);
        return false;
    end
    
    self.detectionSources[sourceId:upper()] = sourceId;
    
    -- 可以在这里添加更多处理
    return true;
end

-- 检测地图上的空投图标
-- @return boolean 是否检测到图标
function TimerManager:DetectMapIcons()
    -- 注意：此函数只在区域有效时被调用（定时器已暂停时不会调用）
    -- 区域有效性检测只在区域变化时执行一次，如果区域无效，定时器已暂停
    
    -- 获取当前地图ID
    if not C_Map or not C_Map.GetBestMapForUnit then
        SafeDebug(L["DebugCMapAPINotAvailable"])
        return false;
    end
    
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if not currentMapID then
        SafeDebug(L["DebugCannotGetMapID"])
        return false;
    end
    
    -- 获取当前地图名称
    if not C_Map.GetMapInfo then
        SafeDebug(L["DebugCMapGetMapInfoNotAvailable"])
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID)
    if not mapInfo or not mapInfo.name then
        SafeDebug(L["DebugCannotGetMapName2"])
        return false;
    end
    
    -- 查找对应的地图数据（使用与Main.lua相同的模糊匹配逻辑，支持父地图匹配）
    local targetMapData = nil
    local validMaps = Data:GetAllMaps()
    local parentMapName = "";
    
    if not validMaps or #validMaps == 0 then
        SafeDebug(L["DebugMapListEmpty"])
        return false;
    end
    
    -- 获取父地图信息（用于子区域匹配）
    if mapInfo.parentMapID then
        local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
        if parentMapInfo and parentMapInfo.name then
            parentMapName = parentMapInfo.name;
        end
    end
    
    for _, mapData in ipairs(validMaps) do
        if Data:IsMapNameMatch(mapData, mapInfo.name) then
            targetMapData = mapData;
            SafeDebugLimited("icon_map_match_" .. tostring(currentMapID), string.format(L["DebugMapMatchSuccess"], mapInfo.name));
            break;
        end
    end
    
    if not targetMapData and parentMapName ~= "" then
        for _, mapData in ipairs(validMaps) do
            if Data:IsMapNameMatch(mapData, parentMapName) then
                targetMapData = mapData;
                SafeDebugLimited("icon_parent_match_" .. tostring(currentMapID), string.format(L["DebugParentMapMatchSuccess"], mapInfo.name, parentMapName));
                break;
            end
        end
    end
    
    if not targetMapData then
        SafeDebugLimited("map_not_in_list_" .. tostring(currentMapID), string.format(L["DebugMapNotInList"], mapInfo.name, parentMapName or L["DebugNoRecord"], currentMapID))
        return false;
    end
    
    -- 注意：即使已经通过NPC喊话检测到空投，我们仍然需要检测地图图标
    -- 因为判断空投是否进行中的唯一标准是地图图标标记（mapIconDetected）
    -- 所以这里不再跳过地图图标检测，而是始终执行检测以更新mapIconDetected标记
    
    -- 记录本次检测是否发现地图图标
    local foundMapIcon = false;
    
    local L = CrateTrackerZK.L;
    local iconName = L and L["AirdropMapIconName"];
    if not iconName or iconName == "" then
        SafeDebug(L["DebugMapIconNameNotConfigured"]);
        return false;
    end
    
    SafeDebugLimited("icon_detection_start", string.format("[地图图标检测] 开始检测，地图=%s，图标名称=%s", Data:GetMapDisplayName(targetMapData), iconName));
    
    -- 检查地图上的Vignettes (特殊标记) - 唯一有效的检测方式
    if C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignetteInfo and C_VignetteInfo.GetVignettePosition then
        local vignettes = C_VignetteInfo.GetVignettes()
        if vignettes then
            SafeDebugLimited("icon_vignette_count", string.format("[地图图标检测] Vignette数量: %d", #vignettes));
            for _, vignetteGUID in ipairs(vignettes) do
                local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
                if vignetteInfo then
                    -- 获取Vignette在地图上的位置
                    local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID)
                    if position then
                        -- 获取Vignette的名称或类型信息
                        local vignetteName = vignetteInfo.name or ""
                        
                        if vignetteName ~= "" then
                            local trimmedName = vignetteName:match("^%s*(.-)%s*$");
                            SafeDebugLimited("icon_vignette_name_" .. vignetteGUID, string.format("[地图图标检测] Vignette名称: %s", trimmedName));
                            
                            if Commands and Commands:IsCollectDataEnabled() then
                                DEFAULT_CHAT_FRAME:AddMessage(L["Prefix"] .. "|cffff0000" .. (L["CollectDataLabel"] or "[数据收集]") .. "|r " .. (L["CollectDataVignetteName"] or "Vignette名称") .. ": |cffffff00" .. (trimmedName or "nil") .. "|r");
                            end
                            
                            if iconName and iconName ~= "" and trimmedName == iconName then
                                foundMapIcon = true;
                                SafeDebugLimited("icon_vignette_" .. targetMapData.id, string.format(L["DebugDetectedMapIconVignette"], Data:GetMapDisplayName(targetMapData), iconName))
                                break
                            end
                        end
                    end
                end
            end
        else
            SafeDebugLimited("icon_vignette_empty", "[地图图标检测] Vignette列表为空");
        end
    else
        SafeDebugLimited("icon_vignette_api_unavailable", "[地图图标检测] C_VignetteInfo API不可用");
    end
    
    -- 设置地图图标检测标记（用于判断空投事件是否进行中）
    -- 地图图标检测：连续两次检测到图标（或连续2秒内检测到）才认为是有效的，防止误报
    -- 判断空投是否进行中的唯一标准是地图图标：检测到图标=进行中，未检测到图标=已结束
    self.mapIconDetected = self.mapIconDetected or {};
    self.mapIconFirstDetectedTime = self.mapIconFirstDetectedTime or {};
    self.lastUpdateTime = self.lastUpdateTime or {};
    local wasDetectedBefore = (self.mapIconDetected[targetMapData.id] == true);
    local currentTime = getCurrentTimestamp();
    local firstDetectedTime = self.mapIconFirstDetectedTime[targetMapData.id];
    local lastUpdateTime = self.lastUpdateTime[targetMapData.id];
    
    
    if foundMapIcon then
        -- 检测到地图图标
        if not firstDetectedTime then
            -- 首次检测到图标，记录时间，但不立即更新和通知（等待连续检测确认）
            self.mapIconFirstDetectedTime[targetMapData.id] = currentTime;
                SafeDebug(string.format(L["DebugFirstDetectionWait"], Data:GetMapDisplayName(targetMapData)));
        else
            -- 之前已经检测到过，检查是否满足连续检测条件
            local timeSinceFirstDetection = currentTime - firstDetectedTime;
            
            -- 连续检测条件：距离首次检测时间 >= 2秒
            -- 这样可以确保是连续检测，而不是单次误报
            if timeSinceFirstDetection >= 2 then
                -- 满足连续检测条件，认为是有效的检测
                if not wasDetectedBefore then
                    -- 这是首次确认有效，更新刷新时间并发送通知
                    SafeDebug(string.format(L["DebugContinuousDetectionConfirmed"], Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection));
                    
                    -- 设置标记（空投进行中）
                    self.mapIconDetected[targetMapData.id] = true;
                    
                    -- 系统检测的时间是权威时间，清除手动输入的时间锁定
                    if Data.manualInputLock then
                        Data.manualInputLock[targetMapData.id] = nil;
                    end
                    -- 更新刷新时间（使用首次检测到的时间，更准确）
                    local success = Data:SetLastRefresh(targetMapData.id, firstDetectedTime);
                    
                    if success then
                        -- 记录更新时间
                        self.lastUpdateTime[targetMapData.id] = firstDetectedTime;
                        
                        -- 记录日志（只在调试模式下输出）
                        local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
                        SafeDebug(string.format(L["DebugTimerStarted"], Data:GetMapDisplayName(targetMapData), sourceText, Data:FormatDateTime(targetMapData.nextRefresh)));
                        
                        SafeDebug(string.format(L["DebugUpdatedRefreshTime"], Data:GetMapDisplayName(targetMapData), Data:FormatDateTime(targetMapData.nextRefresh)));
                        
                        -- 更新界面显示
                        self:UpdateUI();
                    else
                        SafeDebug(string.format(L["DebugUpdateRefreshTimeFailed"], targetMapData.id));
                    end
                    
                    if Notification then
                        Notification:NotifyAirdropDetected(Data:GetMapDisplayName(targetMapData), self.detectionSources.MAP_ICON);
                    end
                else
                    -- 已经确认过，只保持标记
                    SafeDebugLimited("icon_detected_" .. targetMapData.id, string.format(L["DebugAirdropActive"], Data:GetMapDisplayName(targetMapData)));
                end
            else
                -- 距离首次检测时间 < 2秒，继续等待连续检测确认
                SafeDebug(string.format(L["DebugWaitingForConfirmation"], Data:GetMapDisplayName(targetMapData), timeSinceFirstDetection));
            end
        end
    else
        -- 未检测到地图图标
        -- 清除首次检测时间记录（如果存在）
        if self.mapIconFirstDetectedTime[targetMapData.id] then
            self.mapIconFirstDetectedTime[targetMapData.id] = nil;
            SafeDebug(string.format(L["DebugClearedFirstDetectionTime"], Data:GetMapDisplayName(targetMapData)));
        end
        
        -- 清除标记（空投已结束）
        -- 地图图标消失，说明空投已结束
        if self.mapIconDetected[targetMapData.id] then
            self.mapIconDetected[targetMapData.id] = nil;
            SafeDebugLimited("icon_cleared_" .. targetMapData.id, string.format(L["DebugAirdropEnded"], Data:GetMapDisplayName(targetMapData)));
        end
    end
    
    return false
end

-- 开始地图图标检测（定期检查）
-- @param interval 检测间隔（秒，默认10秒）
function TimerManager:StartMapIconDetection(interval)
    if not self.isInitialized then
        Utils.PrintError(L["ErrorTimerManagerNotInitialized"]);
        return false;
    end
    
    -- 停止现有的检测计时器（如果有）
    self:StopMapIconDetection();
    
    -- 设置默认检测间隔
    interval = interval or 10;
    
    -- 创建检测计时器
    -- 注意：在定时器回调中先检查有效区域，无效时不调用检测函数（避免不必要的函数调用和调试信息输出）
    self.mapIconDetectionTimer = C_Timer.NewTicker(interval, function()
        -- 先检查有效区域，无效时不调用检测函数（避免不必要的函数调用和调试信息输出）
        if Area and not Area.detectionPaused then
            self:DetectMapIcons();
        end
        -- 如果区域无效，静默跳过，不输出任何信息（避免刷屏）
    end);
    
    SafeDebug(L["DebugMapIconDetectionStarted"], L["DebugDetectionInterval"] .. "=" .. interval .. L["DebugSeconds"]);
    return true;
end

-- 停止地图图标检测
function TimerManager:StopMapIconDetection()
    if self.mapIconDetectionTimer then
        self.mapIconDetectionTimer:Cancel();
        self.mapIconDetectionTimer = nil;
        SafeDebug(L["DebugMapIconDetectionStopped"]);
    end
    return true;
end

-- 获取所有已注册的检测源
-- @return table 检测源列表
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
