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
        print('|cff00ff00[空投物资追踪器]|r' .. message);
    end
    -- 如果Utils.Debug不存在且debugEnabled为false，则静默忽略
end

-- 记录已注册的检测源
TimerManager.detectionSources = {
    NPC_SPEECH = "npc_speech",
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
    -- 记录每个地图是否已经通过NPC喊话检测到（用于地图图标检测判断）
    self.npcSpeechDetected = self.npcSpeechDetected or {};
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
        Utils.PrintError("计时管理器尚未初始化");
        return false;
    end
    
    local mapData = Data:GetMap(mapId);
    if not mapData then
        Utils.PrintError("无效的地图ID: " .. tostring(mapId));
        return false;
    end
    
    -- 设置默认值
    source = source or self.detectionSources.API_INTERFACE;
    timestamp = timestamp or getCurrentTimestamp();
    
    SafeDebug("接口调用: TimerManager:StartTimer", "地图ID=" .. mapId, "地图名称=" .. mapData.mapName, "检测源=" .. source, "时间戳=" .. timestamp);
    
    -- 检测源分类：
    -- 1. NPC喊话检测：更新刷新时间，设置空投进行中标记，发送通知
    -- 2. 手动刷新按钮/手动输入：更新刷新时间，不设置空投进行中标记，不发送通知
    -- 3. 地图图标检测：首次检测到图标时更新刷新时间，设置空投进行中标记，发送通知（在DetectMapIcons函数中处理）
    local isNPCSpeech = (source == self.detectionSources.NPC_SPEECH);
    local isManualOperation = (source == self.detectionSources.REFRESH_BUTTON or source == self.detectionSources.MANUAL_INPUT);
    local success = false;
    
    if isNPCSpeech then
        -- NPC喊话检测：每次检测到都更新刷新时间，设置空投进行中
        -- 更新刷新时间
        success = Data:SetLastRefresh(mapId, timestamp);
        
        if success then
            -- 设置npcSpeechDetected标记（用于地图图标检测判断）
            self.npcSpeechDetected = self.npcSpeechDetected or {};
            self.npcSpeechDetected[mapId] = true;
            
            -- 设置mapIconDetected标记（空投进行中）
            self.mapIconDetected = self.mapIconDetected or {};
            self.mapIconDetected[mapId] = true;
            
            -- 记录更新时间（用于防止地图图标检测重复更新）
            self.lastUpdateTime = self.lastUpdateTime or {};
            self.lastUpdateTime[mapId] = timestamp;
            
            -- 记录日志（只在调试模式下输出）
            local sourceText = self:GetSourceDisplayName(source);
            SafeDebug("地图[" .. mapData.mapName .. "]计时已通过" .. sourceText .. "启动，下次刷新: " .. Data:FormatDateTime(mapData.nextRefresh));
            
            SafeDebug("【NPC喊话】已更新刷新时间并设置空投进行中: " .. mapData.mapName .. " 下次刷新=" .. Data:FormatDateTime(mapData.nextRefresh));
            
            -- 发送空投事件通知
            if Notification then
                Notification:NotifyAirdropDetected(mapData.mapName, self.detectionSources.NPC_SPEECH);
            end
            
            -- 更新界面显示
            self:UpdateUI();
        else
            -- 更新刷新时间失败
            SafeDebug("计时启动失败", "地图ID=" .. mapId, "原因=Data:SetLastRefresh返回false");
            Utils.PrintError("启动计时失败: 地图ID=" .. tostring(mapId));
        end
    elseif isManualOperation then
        -- 手动刷新按钮/手动输入：更新刷新时间，不设置空投进行中标记，不发送通知
        -- 更新刷新时间
        success = Data:SetLastRefresh(mapId, timestamp);
        
        if success then
            -- 记录日志（只在调试模式下输出）
            local sourceText = self:GetSourceDisplayName(source);
            SafeDebug("地图[" .. mapData.mapName .. "]计时已通过" .. sourceText .. "启动，下次刷新: " .. Data:FormatDateTime(mapData.nextRefresh));
            
            SafeDebug("手动操作: 已更新刷新时间", "地图名称=" .. mapData.mapName, "检测源=" .. source, "上次刷新=" .. Data:FormatDateTime(mapData.lastRefresh), "下次刷新=" .. Data:FormatDateTime(mapData.nextRefresh));
            
            -- 更新界面显示
            self:UpdateUI();
        else
            -- 更新刷新时间失败
            SafeDebug("计时启动失败", "地图ID=" .. mapId, "原因=Data:SetLastRefresh返回false");
            Utils.PrintError("启动计时失败: 地图ID=" .. tostring(mapId));
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
        Utils.PrintError("计时管理器尚未初始化");
        return false;
    end
    
    if not mapIds or type(mapIds) ~= "table" then
        Utils.PrintError("无效的地图ID列表");
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
        Utils.PrintError("计时管理器尚未初始化");
        return false;
    end
    
    local maps = Data:GetAllMaps();
    local targetMapId = nil;
    
    -- 查找匹配的地图
    for _, mapData in ipairs(maps) do
        if mapData.mapName == mapName then
            targetMapId = mapData.id;
            break;
        end
    end
    
    if targetMapId then
        return self:StartTimer(targetMapId, source, timestamp);
    else
        Utils.PrintError("未找到地图: " .. mapName);
        return false;
    end
end

-- 启动当前地图的计时
-- @param source 检测源
-- @param timestamp 时间戳（可选，默认为当前时间）
-- @return boolean 操作是否成功
function TimerManager:StartCurrentMapTimer(source, timestamp)
    if not self.isInitialized then
        Utils.PrintError("计时管理器尚未初始化");
        return false;
    end
    
    SafeDebug("接口调用: TimerManager:StartCurrentMapTimer", "检测源=" .. (source or "nil"));
    
    -- 获取当前地图信息
    local currentMapID = C_Map.GetBestMapForUnit("player");
    local currentMapName = "";
    
    local mapInfo = C_Map.GetMapInfo(currentMapID);
    if mapInfo and mapInfo.name then
        currentMapName = mapInfo.name;
        SafeDebug("获取当前地图信息成功", "地图ID=" .. currentMapID, "地图名称=" .. currentMapName);
    else
        -- 备选方案：使用GetInstanceInfo
        currentMapName = select(1, GetInstanceInfo());
        SafeDebug("使用GetInstanceInfo获取地图名称", "地图名称=" .. (currentMapName or "nil"));
    end
    
    if currentMapName then
        return self:StartTimerByName(currentMapName, source, timestamp);
    else
        SafeDebug("无法获取当前地图名称", "地图ID=" .. (currentMapID or "nil"));
        Utils.PrintError("无法获取当前地图名称");
        return false;
    end
end

-- 获取检测源的显示名称
-- @param source 检测源标识符
-- @return string 显示名称
function TimerManager:GetSourceDisplayName(source)
    local displayNames = {
        [self.detectionSources.NPC_SPEECH] = "NPC喊话",
        [self.detectionSources.MANUAL_INPUT] = "手动输入",
        [self.detectionSources.REFRESH_BUTTON] = "刷新按钮",
        [self.detectionSources.API_INTERFACE] = "API接口",
        [self.detectionSources.MAP_ICON] = "地图图标检测"
    };
    
    return displayNames[source] or "未知来源";
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
        Utils.PrintError("无效的检测源参数");
        return false;
    end
    
    self.detectionSources[sourceId:upper()] = sourceId;
    
    -- 可以在这里添加更多处理
    return true;
end

-- 检测地图上的战争物资箱图标
-- @return boolean 是否检测到图标
function TimerManager:DetectMapIcons()
    -- 检查是否在有效的检测区域（使用总开关CheckAndUpdateAreaValid）
    -- 这个函数检查：副本/战场/室内/主城/有效地图列表
    if not CheckAndUpdateAreaValid then
        SafeDebug("CheckAndUpdateAreaValid函数不可用，跳过地图图标检测")
        return false;
    end
    
    if not CheckAndUpdateAreaValid() then
        -- 使用限制输出，避免刷屏（每30秒最多输出一次）
        SafeDebugLimited("map_icon_invalid_area", "【空投检测】当前区域无效，跳过地图图标检测")
        return false;
    end
    
    -- 获取当前地图ID
    if not C_Map or not C_Map.GetBestMapForUnit then
        SafeDebug("C_Map API不可用")
        return false;
    end
    
    local currentMapID = C_Map.GetBestMapForUnit("player")
    if not currentMapID then
        SafeDebug("无法获取当前地图ID")
        return false;
    end
    
    -- 获取当前地图名称
    if not C_Map.GetMapInfo then
        SafeDebug("C_Map.GetMapInfo API不可用")
        return false;
    end
    
    local mapInfo = C_Map.GetMapInfo(currentMapID)
    if not mapInfo or not mapInfo.name then
        SafeDebug("无法获取当前地图名称")
        return false;
    end
    
    -- 查找对应的地图数据（使用与Main.lua相同的模糊匹配逻辑，支持父地图匹配）
    local targetMapData = nil
    local validMaps = Data:GetAllMaps()
    local parentMapName = "";
    
    if not validMaps or #validMaps == 0 then
        SafeDebug("地图列表为空，跳过地图图标检测")
        return false;
    end
    
    -- 获取父地图信息（用于子区域匹配）
    if mapInfo.parentMapID then
        local parentMapInfo = C_Map.GetMapInfo(mapInfo.parentMapID);
        if parentMapInfo and parentMapInfo.name then
            parentMapName = parentMapInfo.name;
        end
    end
    
    -- 1. 首先尝试匹配当前地图名称
    for _, mapData in ipairs(validMaps) do
        local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
        local cleanCurrentMapName = string.lower(string.gsub(mapInfo.name, "[%p ]", ""));
        
        if cleanMapDataName == cleanCurrentMapName then
            targetMapData = mapData;
            SafeDebugLimited("icon_map_match_" .. tostring(currentMapID), "【空投检测】地图匹配成功: " .. mapInfo.name);
            break;
        end
    end
    
    -- 2. 如果当前地图不匹配，尝试匹配父地图（子区域情况）
    if not targetMapData and parentMapName ~= "" then
        for _, mapData in ipairs(validMaps) do
            local cleanMapDataName = string.lower(string.gsub(mapData.mapName, "[%p ]", ""));
            local cleanParentMapName = string.lower(string.gsub(parentMapName, "[%p ]", ""));
            
            if cleanMapDataName == cleanParentMapName then
                targetMapData = mapData;
                SafeDebugLimited("icon_parent_match_" .. tostring(currentMapID), "【空投检测】父地图匹配成功（子区域）: " .. mapInfo.name .. " (父地图=" .. parentMapName .. ")");
                break;
            end
        end
    end
    
    if not targetMapData then
        SafeDebugLimited("map_not_in_list_" .. tostring(currentMapID), "【空投检测】当前地图不在有效列表中，跳过检测: " .. mapInfo.name .. " (父地图=" .. (parentMapName or "无") .. " 地图ID=" .. currentMapID .. ")")
        return false;
    end
    
    -- 注意：即使已经通过NPC喊话检测到空投，我们仍然需要检测地图图标
    -- 因为判断空投是否进行中的唯一标准是地图图标标记（mapIconDetected）
    -- 所以这里不再跳过地图图标检测，而是始终执行检测以更新mapIconDetected标记
    
    -- 记录本次检测是否发现地图图标
    local foundMapIcon = false;
    
    -- 方法1: 检查地图上的所有地标信息
    if C_WorldMap and C_WorldMap.GetNumMapLandmarks and C_WorldMap.GetMapLandmarkInfo then
        local numLandmarks = C_WorldMap.GetNumMapLandmarks()
        for i = 1, numLandmarks do
            local landmarkInfo = C_WorldMap.GetMapLandmarkInfo(i)
            if landmarkInfo and landmarkInfo.name then
                -- 精确匹配"战争物资箱"，避免误报（去除首尾空白后精确匹配）
                local trimmedName = landmarkInfo.name:match("^%s*(.-)%s*$");
                if trimmedName == "战争物资箱" then
                    foundMapIcon = true;
                    SafeDebugLimited("icon_landmark_" .. targetMapData.id, "【空投检测】检测到战争物资箱图标(地标): " .. targetMapData.mapName)
                    -- 注意：检测到箱子不更新时间，只设置标记用于判断空投事件状态
                    break
                end
            end
        end
    end
    
    -- 方法2: 检查地图上的Vignettes (特殊标记)
    if C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignetteInfo and C_VignetteInfo.GetVignettePosition then
        local vignettes = C_VignetteInfo.GetVignettes()
        if vignettes then
            for _, vignetteGUID in ipairs(vignettes) do
                local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
                if vignetteInfo then
                    -- 获取Vignette在地图上的位置
                    local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, currentMapID)
                    if position then
                        -- 获取Vignette的名称或类型信息
                        local vignetteName = vignetteInfo.name or ""
                        
                        -- 精确匹配"战争物资箱"，避免误报（去除首尾空白后精确匹配）
                        if vignetteName ~= "" then
                            local trimmedName = vignetteName:match("^%s*(.-)%s*$");
                            if trimmedName == "战争物资箱" then
                                foundMapIcon = true;
                                SafeDebugLimited("icon_vignette_" .. targetMapData.id, "【空投检测】检测到战争物资箱图标(Vignette): " .. targetMapData.mapName)
                                -- 注意：检测到箱子不更新时间，只设置标记用于判断空投事件状态
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 方法3: 检查地图上的区域POI（使用安全的API调用）
    if GetAreaPOIsForPlayerByMapIDCached and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPoiInfo then
        local areaPOIs = GetAreaPOIsForPlayerByMapIDCached(currentMapID);
        if areaPOIs then
            for _, areaPOI in ipairs(areaPOIs) do
                -- 使用新的API：C_AreaPoiInfo.GetAreaPoiInfo
                local areaPOIInfo = C_AreaPoiInfo.GetAreaPoiInfo(currentMapID, areaPOI);
                if areaPOIInfo and areaPOIInfo.name then
                    local areaPOIName = areaPOIInfo.name;
                    -- 精确匹配"战争物资箱"，避免误报（去除首尾空白后精确匹配）
                    local trimmedName = areaPOIName:match("^%s*(.-)%s*$");
                    if trimmedName == "战争物资箱" then
                        foundMapIcon = true;
                        SafeDebugLimited("icon_poi1_" .. targetMapData.id, "【空投检测】检测到战争物资箱图标(区域POI): " .. targetMapData.mapName)
                        -- 注意：检测到箱子不更新时间，只设置标记用于判断空投事件状态
                        break
                    end
                end
            end
        end
    elseif GetAreaPOIsForPlayerByMapIDCached and GetAreaPOIInfo then
        -- 兼容旧版API（如果存在）
        local areaPOIs = GetAreaPOIsForPlayerByMapIDCached(currentMapID);
        if areaPOIs then
            for _, areaPOI in ipairs(areaPOIs) do
                local areaPOIName = GetAreaPOIInfo(currentMapID, areaPOI);
                if areaPOIName then
                    -- 精确匹配"战争物资箱"，避免误报（去除首尾空白后精确匹配）
                    local trimmedName = areaPOIName:match("^%s*(.-)%s*$");
                    if trimmedName == "战争物资箱" then
                        foundMapIcon = true;
                        SafeDebugLimited("icon_poi2_" .. targetMapData.id, "【空投检测】检测到战争物资箱图标(区域POI): " .. targetMapData.mapName)
                        -- 注意：检测到箱子不更新时间，只设置标记用于判断空投事件状态
                        break
                    end
                end
            end
        end
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
    
    -- 检查是否最近（5秒内）已经通过NPC喊话更新过时间，如果是则跳过地图图标检测的更新
    local recentlyUpdatedByNPC = false;
    if lastUpdateTime and (currentTime - lastUpdateTime) <= 5 then
        -- 检查是否是通过NPC喊话更新的（通过npcSpeechDetected标记判断）
        if self.npcSpeechDetected and self.npcSpeechDetected[targetMapData.id] == true then
            recentlyUpdatedByNPC = true;
            SafeDebug("【空投检测】最近已通过NPC喊话更新过时间，跳过地图图标检测的更新: " .. targetMapData.mapName .. " (间隔=" .. (currentTime - lastUpdateTime) .. "秒)");
        end
    end
    
    if foundMapIcon then
        -- 检测到地图图标
        if not firstDetectedTime then
            -- 首次检测到图标，记录时间，但不立即更新和通知（等待连续检测确认）
            self.mapIconFirstDetectedTime[targetMapData.id] = currentTime;
                SafeDebug("【空投检测】首次检测到图标，等待连续检测确认: " .. targetMapData.mapName);
        else
            -- 之前已经检测到过，检查是否满足连续检测条件
            local timeSinceFirstDetection = currentTime - firstDetectedTime;
            
            -- 连续检测条件：距离首次检测时间 >= 2秒，或者这是第二次检测（检测间隔3秒，第二次检测时已经超过2秒）
            -- 这样可以确保是连续检测，而不是单次误报
            if timeSinceFirstDetection >= 2 then
                -- 满足连续检测条件，认为是有效的检测
                -- 但是，如果最近已经通过NPC喊话更新过时间，则跳过更新和通知
                if not wasDetectedBefore and not recentlyUpdatedByNPC then
                    -- 这是首次确认有效，且最近没有通过NPC喊话更新过，更新刷新时间并发送通知
                    SafeDebug("【空投检测】连续检测确认有效，更新刷新时间并发送通知: " .. targetMapData.mapName .. " (间隔=" .. timeSinceFirstDetection .. "秒)");
                    
                    -- 设置标记（空投进行中）
                    self.mapIconDetected[targetMapData.id] = true;
                    
                    -- 更新刷新时间（使用首次检测到的时间，更准确）
                    local success = Data:SetLastRefresh(targetMapData.id, firstDetectedTime);
                    
                    if success then
                        -- 记录更新时间
                        self.lastUpdateTime[targetMapData.id] = firstDetectedTime;
                        
                        -- 记录日志（只在调试模式下输出）
                        local sourceText = self:GetSourceDisplayName(self.detectionSources.MAP_ICON);
                        SafeDebug("地图[" .. targetMapData.mapName .. "]计时已通过" .. sourceText .. "启动，下次刷新: " .. Data:FormatDateTime(targetMapData.nextRefresh));
                        
                        SafeDebug("【空投检测】已更新刷新时间: " .. targetMapData.mapName .. " 下次刷新=" .. Data:FormatDateTime(targetMapData.nextRefresh));
                        
                        -- 更新界面显示
                        self:UpdateUI();
                    else
                        SafeDebug("【空投检测】更新刷新时间失败: 地图ID=" .. targetMapData.id);
                    end
                    
                    -- 发送空投事件通知
                    if Notification then
                        Notification:NotifyAirdropDetected(targetMapData.mapName, self.detectionSources.MAP_ICON);
                    end
                elseif recentlyUpdatedByNPC then
                    -- 最近已通过NPC喊话更新过，只设置标记，不更新时间和发送通知
                    self.mapIconDetected[targetMapData.id] = true;
                    SafeDebug("【空投检测】检测到箱子，但最近已通过NPC喊话更新过时间，只设置标记: " .. targetMapData.mapName);
                else
                    -- 已经确认过，只保持标记
                    SafeDebugLimited("icon_detected_" .. targetMapData.id, "【空投检测】检测到箱子，空投事件进行中: " .. targetMapData.mapName);
                end
            else
                -- 距离首次检测时间 < 2秒，继续等待连续检测确认
                SafeDebug("【空投检测】等待连续检测确认: " .. targetMapData.mapName .. " (间隔=" .. timeSinceFirstDetection .. "秒)");
            end
        end
    else
        -- 未检测到地图图标
        -- 清除首次检测时间记录（如果存在）
        if self.mapIconFirstDetectedTime[targetMapData.id] then
            self.mapIconFirstDetectedTime[targetMapData.id] = nil;
            SafeDebug("【空投检测】清除首次检测时间记录（未检测到图标）: " .. targetMapData.mapName);
        end
        
        -- 清除标记（空投已结束）
        -- 注意：不管是否有NPC喊话检测，只要地图图标消失，就说明空投已结束
        if self.mapIconDetected[targetMapData.id] then
            self.mapIconDetected[targetMapData.id] = nil;
            SafeDebugLimited("icon_cleared_" .. targetMapData.id, "【空投检测】未检测到箱子，空投事件已结束: " .. targetMapData.mapName);
        end
    end
    
    return false
end

-- 开始地图图标检测（定期检查）
-- @param interval 检测间隔（秒，默认10秒）
function TimerManager:StartMapIconDetection(interval)
    if not self.isInitialized then
        Utils.PrintError("计时管理器尚未初始化");
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
        if CheckAndUpdateAreaValid and CheckAndUpdateAreaValid() then
            self:DetectMapIcons();
        end
        -- 如果区域无效，静默跳过，不输出任何信息（避免刷屏）
    end);
    
    SafeDebug("地图图标检测已启动", "检测间隔=" .. interval .. "秒");
    return true;
end

-- 停止地图图标检测
function TimerManager:StopMapIconDetection()
    if self.mapIconDetectionTimer then
        self.mapIconDetectionTimer:Cancel();
        self.mapIconDetectionTimer = nil;
        Utils.Print("地图图标检测已停止");
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
