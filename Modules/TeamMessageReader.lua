-- TeamMessageReader.lua
-- 读取团队通知消息，自动更新空投刷新时间

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TeamMessageReader = BuildEnv('TeamMessageReader');

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

TeamMessageReader.isInitialized = false;
TeamMessageReader.messagePatterns = {};  -- 存储各语言的消息模式
TeamMessageReader.lastTeamMessageTime = {};  -- 记录每个地图最后收到团队消息的时间（用于防止重复通知）
TeamMessageReader.MESSAGE_COOLDOWN = 30;  -- 30秒冷却期，超过30秒后不再发送通知（因为空投已经发生30秒了，再发没意义）

-- 初始化消息模式（匹配插件自动发送的团队消息，使用 AirdropDetected 格式）
local function InitializeMessagePatterns()
    TeamMessageReader.messagePatterns = {};
    
    -- 获取所有支持的语言的消息格式
    local messageFormats = {};
    
    -- 从LocaleManager获取所有已注册的语言（确保支持所有语言）
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry();
        if localeRegistry then
            -- 遍历所有已注册的语言
            for locale, localeData in pairs(localeRegistry) do
                if localeData and localeData.AirdropDetected then
                    local found = false;
                    -- 检查是否已经添加过相同的消息格式（避免重复）
                    for _, fmt in ipairs(messageFormats) do
                        if fmt == localeData.AirdropDetected then
                            found = true;
                            break;
                        end
                    end
                    if not found then
                        table.insert(messageFormats, localeData.AirdropDetected);
                        if Logger and Logger.Debug then
                            Logger:Debug("TeamMessageReader", "初始化", string.format("已添加语言消息格式：语言=%s，格式=%s", locale, localeData.AirdropDetected));
                        end
                    end
                end
            end
        end
    end
    
    -- 如果LocaleManager没有数据，尝试从当前语言获取（回退方案）
    if #messageFormats == 0 then
        local L = CrateTrackerZK and CrateTrackerZK.L;
        if L and L.AirdropDetected then
            table.insert(messageFormats, L.AirdropDetected);
            if Logger and Logger.Debug then
                Logger:Debug("TeamMessageReader", "初始化", string.format("使用当前语言消息格式（回退方案）：格式=%s", L.AirdropDetected));
            end
        end
    end
    
    -- 为每个消息格式创建匹配模式（匹配 AirdropDetected 格式，即自动消息）
    for _, messageFormat in ipairs(messageFormats) do
        -- 构建匹配模式：直接匹配消息格式（不带"通知："前缀）
        -- 例如：【%s】 发现 战争物资 正在空投！！！
        local msgPattern = messageFormat;
        
        -- 先转义所有特殊字符
        msgPattern = msgPattern:gsub("%%", "%%%%");  -- 先转义 % 本身
        msgPattern = msgPattern:gsub("%(", "%%(");
        msgPattern = msgPattern:gsub("%)", "%%)");
        msgPattern = msgPattern:gsub("%[", "%%[");
        msgPattern = msgPattern:gsub("%]", "%%]");
        msgPattern = msgPattern:gsub("%!", "%%!");
        msgPattern = msgPattern:gsub("%+", "%%+");
        msgPattern = msgPattern:gsub("%-", "%%-");
        msgPattern = msgPattern:gsub("%*", "%%*");
        msgPattern = msgPattern:gsub("%?", "%%?");
        msgPattern = msgPattern:gsub("%^", "%%^");
        msgPattern = msgPattern:gsub("%$", "%%$");
        msgPattern = msgPattern:gsub("%.", "%%.");
        
        -- 然后将 %%%%s 替换为 (.+) 来匹配地图名称
        msgPattern = msgPattern:gsub("%%%%s", "(.+)");
        
        table.insert(TeamMessageReader.messagePatterns, {
            pattern = msgPattern,
            original = messageFormat
        });
        
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "初始化", string.format("已加载消息模式：格式=%s，模式=%s", messageFormat, msgPattern));
        end
    end
    
    if #TeamMessageReader.messagePatterns == 0 then
        if Logger and Logger.Warn then
            Logger:Warn("TeamMessageReader", "警告", "未找到任何消息模式，团队消息读取功能可能无法正常工作");
        end
    end
end

-- 检查是否是自动消息（通过匹配 AirdropDetected 格式）
-- 自动消息：【%s】 检测到战争物资正在空投！！！（匹配 AirdropDetected 格式）
-- 手动消息：【%s】 战争物资正在空投！！！（匹配 AirdropDetectedManual 格式，不处理）
local function IsAutoMessage(message)
    if not message or type(message) ~= "string" then
        return false;
    end
    
    -- 尝试用所有语言的 AirdropDetected 格式匹配消息
    -- 如果匹配成功，说明是自动消息
    for _, patternData in ipairs(TeamMessageReader.messagePatterns) do
        local mapName = message:match(patternData.pattern);
        if mapName and mapName ~= "" then
            -- 匹配成功，是自动消息
            if Logger and Logger.Debug then
                Logger:Debug("TeamMessageReader", "解析", string.format("检测到自动消息（匹配格式：%s）", patternData.original));
            end
            return true;
        end
    end
    
    return false;
end

-- 解析团队消息，提取地图名称
local function ParseTeamMessage(message)
    if not message or type(message) ~= "string" then
        return nil;
    end
    
    -- 只处理自动消息（匹配 AirdropDetected 格式的消息）
    if not IsAutoMessage(message) then
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "解析", "消息不匹配自动消息格式，跳过处理（可能是手动消息）");
        end
        return nil;
    end
    
    -- 尝试匹配所有已加载的消息模式（只匹配自动消息，即 AirdropDetected 格式）
    for _, patternData in ipairs(TeamMessageReader.messagePatterns) do
        local mapName = message:match(patternData.pattern);
        if mapName and mapName ~= "" then
            -- 去除首尾空格
            mapName = mapName:match("^%s*(.-)%s*$");
            if mapName and mapName ~= "" then
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "解析", string.format("匹配到自动消息：格式=%s，地图名称=%s", 
                        patternData.original, mapName));
                end
                return mapName;
            end
        end
    end
    
    return nil;
end

-- 根据地图名称获取地图ID（支持多语言地图名称匹配）
local function GetMapIdByName(mapName)
    if not mapName or not Data then
        return nil;
    end
    
    local maps = Data:GetAllMaps();
    if not maps then
        return nil;
    end
    
    -- 首先尝试使用当前语言的地图名称匹配
    for _, mapData in ipairs(maps) do
        local displayName = Data:GetMapDisplayName(mapData);
        if displayName == mapName then
            return mapData.id;
        end
    end
    
    -- 如果当前语言匹配失败，尝试使用所有语言的地图名称匹配
    -- 这允许用户使用任何语言的地图名称
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry();
        if localeRegistry then
            for _, mapData in ipairs(maps) do
                -- 检查所有语言的地图名称
                for locale, localeData in pairs(localeRegistry) do
                    if localeData and localeData.MapNames and localeData.MapNames[mapData.mapID] then
                        if localeData.MapNames[mapData.mapID] == mapName then
                            if Logger and Logger.Debug then
                                Logger:Debug("TeamMessageReader", "匹配", string.format("使用语言=%s的地图名称匹配：地图ID=%d，地图名称=%s", locale, mapData.mapID, mapName));
                            end
                            return mapData.id;
                        end
                    end
                end
            end
        end
    end
    
    return nil;
end

-- 检查是否应该发送通知（防止重复通知）
-- 如果距离团队消息超过30秒，不再发送通知（因为空投已经发生30秒了，再发没意义）
local function ShouldSendNotification(mapId, currentTime)
    if not mapId then
        return false;
    end
    
    local lastTime = TeamMessageReader.lastTeamMessageTime[mapId];
    if not lastTime then
        return true;  -- 没有记录，可以发送
    end
    
    local timeSinceTeamMessage = currentTime - lastTime;
    -- 如果超过30秒，不再发送通知
    return timeSinceTeamMessage < TeamMessageReader.MESSAGE_COOLDOWN;
end

-- 处理团队消息
function TeamMessageReader:ProcessTeamMessage(message, chatType, sender)
    -- 参数验证
    if not message or type(message) ~= "string" then
        return false;
    end
    
    if not self.isInitialized then
        self:Initialize();
    end
    
    -- 只处理团队/小队消息，忽略系统消息
    if not chatType or (chatType ~= "RAID" and chatType ~= "RAID_WARNING" and chatType ~= "PARTY" and chatType ~= "INSTANCE_CHAT") then
        return false;
    end
    
    -- 解析消息，提取地图名称
    local mapName = ParseTeamMessage(message);
    if not mapName then
        return false;  -- 不是插件发送的空投消息
    end
    
    -- 根据地图名称获取地图ID
    local mapId = GetMapIdByName(mapName);
    if not mapId then
        if Logger and Logger.Warn then
            Logger:Warn("TeamMessageReader", "警告", string.format("无法找到地图：%s", mapName));
        end
        return false;
    end
    
    -- 检查是否是当前玩家发送的消息（避免重复更新）
    local playerName = UnitName("player");
    local realmName = GetRealmName();
    local fullPlayerName = playerName;
    if realmName then
        fullPlayerName = playerName .. "-" .. realmName;
    end
    
    -- 检查发送者是否是当前玩家（支持带服务器名和不带服务器名的格式）
    if sender and (sender == playerName or sender == fullPlayerName) then
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "处理", string.format("跳过自己发送的消息：发送者=%s，地图=%s", sender, mapName));
        end
        return false;  -- 是自己发送的消息，不处理
    end
    
    -- 检查当前地图是否已经是 PROCESSED 状态（说明已经处理过了，避免重复更新）
    if DetectionState then
        local state = DetectionState:GetState(mapId);
        if state and state.status == DetectionState.STATES.PROCESSED then
            -- 检查是否是当前地图（如果是当前地图且是 PROCESSED 状态，说明是自己检测到的，跳过）
            local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player");
            local mapData = Data:GetMap(mapId);
            local isOnMap = mapData and currentMapID == mapData.mapID;
            if isOnMap then
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "处理", string.format("跳过当前地图的PROCESSED状态消息（可能是自己发送的）：地图=%s，发送者=%s", mapName, sender or "未知"));
                end
                return false;  -- 当前地图且是 PROCESSED 状态，可能是自己发送的，跳过
            end
        end
    end
    
    if Logger and Logger.Debug then
        Logger:Debug("TeamMessageReader", "处理", string.format("检测到团队空投消息：发送者=%s，地图=%s，聊天类型=%s", 
            sender or "未知", mapName, chatType));
    end
    
    local currentTime = time();
    
    -- 记录收到团队消息的时间（用于防止之后进入地图时重复通知）
    TeamMessageReader.lastTeamMessageTime[mapId] = currentTime;
    
    -- 检查是否应该更新刷新时间（防止短时间内多次更新）
    if not Data or not Data.SetLastRefresh then
        return false;
    end
    
    -- 获取当前地图数据，检查是否已有刷新时间记录
    local mapData = Data:GetMap(mapId);
    local oldTime = mapData and mapData.lastRefresh;
    local refreshTime = currentTime;
    local shouldUpdate = true;
    
    if oldTime then
        -- 已有旧记录，检查时间差异
        local timeDiff = math.abs(currentTime - oldTime);
        
        -- 如果时间差异在30秒内，说明是同一个空投的多次报告
        if timeDiff <= TeamMessageReader.MESSAGE_COOLDOWN then
            -- 使用更早的时间（空投实际开始的时间）
            if currentTime < oldTime then
                -- 新时间更早，使用新时间
                refreshTime = currentTime;
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "更新", string.format("使用更早的时间：地图=%s，旧时间=%s，新时间=%s，使用时间=%s", 
                        mapName,
                        Data:FormatDateTime(oldTime),
                        Data:FormatDateTime(currentTime),
                        Data:FormatDateTime(refreshTime)));
                end
            else
                -- 新时间不更早，保持旧时间（不更新）
                shouldUpdate = false;
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "更新", string.format("跳过重复更新：地图=%s，旧时间=%s，新时间=%s（时间差异在冷却期内，且新时间不更早）", 
                        mapName, 
                        Data:FormatDateTime(oldTime),
                        Data:FormatDateTime(currentTime)));
                end
            end
        else
            -- 时间差异超过30秒，说明是新的空投，允许更新
            if Logger and Logger.Debug then
                Logger:Debug("TeamMessageReader", "更新", string.format("时间差异超过冷却期，视为新空投：地图=%s，旧时间=%s，新时间=%s，差异=%d秒", 
                    mapName,
                    Data:FormatDateTime(oldTime),
                    Data:FormatDateTime(currentTime),
                    timeDiff));
            end
        end
    else
        -- 没有旧记录，允许更新（首次检测）
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "更新", string.format("首次更新刷新时间：地图=%s，时间=%s", 
                mapName, Data:FormatDateTime(currentTime)));
        end
    end
    
    -- 如果需要更新，执行更新
    if shouldUpdate then
        local success = Data:SetLastRefresh(mapId, refreshTime);
        if not success then
            if Logger and Logger.Error then
                Logger:Error("TeamMessageReader", "错误", string.format("更新刷新时间失败：地图=%s", mapName));
            end
            return false;
        end
        
        if Logger and Logger.Info then
            local currentL = CrateTrackerZK and CrateTrackerZK.L;
            if currentL and currentL.TeamMessageUpdated then
                Logger:Info("TeamMessageReader", "更新", string.format(currentL.TeamMessageUpdated, 
                    mapName, Data:FormatDateTime(refreshTime)));
            else
                Logger:Info("TeamMessageReader", "更新", string.format("已成功通过团队用户获取到【%s】最新空投时间：%s", 
                    mapName, Data:FormatDateTime(refreshTime)));
            end
        end
    else
        -- 不需要更新，但返回true表示消息已处理
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "更新", string.format("消息已处理但跳过更新：地图=%s（已使用更早的时间）", mapName));
        end
        return true;  -- 跳过更新，但返回true表示消息已处理
    end
    
    -- 更新UI
    if TimerManager and TimerManager.UpdateUI then
        TimerManager:UpdateUI();
    end
    
    -- 检查当前是否在该地图上
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player");
    local mapData = Data:GetMap(mapId);
    local isOnMap = mapData and currentMapID == mapData.mapID;
    
    if isOnMap then
        -- 在当前地图上，检查是否应该发送通知
        -- 如果空投还在进行中（PROCESSED状态），不发送通知
        local shouldSend = true;
        if DetectionState then
            local state = DetectionState:GetState(mapId);
            if state and state.status == DetectionState.STATES.PROCESSED then
                -- 空投还在进行中，不发送通知（因为已经收到团队消息了）
                shouldSend = false;
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "通知", string.format("空投还在进行中，不发送重复通知：地图=%s", mapName));
                end
            end
        end
        
        if shouldSend then
            -- 发送系统通知（不会再次发送团队消息，因为已经收到了）
            if Logger and Logger.Info then
                local currentL = CrateTrackerZK and CrateTrackerZK.L;
                if currentL and currentL.AirdropDetected then
                    Logger:Info("Notification", "通知", string.format(currentL.AirdropDetected, mapName));
                else
                    Logger:Info("Notification", "通知", string.format("【%s】 发现战争物资正在空投！！！", mapName));
                end
            end
        end
    else
        -- 不在当前地图上，不发送通知（但刷新时间已更新）
        -- 如果之后进入该地图，且空投还在进行中，不会再次发送通知（由Timer.lua中的检查处理）
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "通知", string.format("不在当前地图上，不发送通知：地图=%s（如果之后进入该地图，且空投还在进行中，不会重复通知）", mapName));
        end
    end
    
    return true;
end

function TeamMessageReader:Initialize()
    -- 清除所有内存状态（防止跨角色污染）
    TeamMessageReader.lastTeamMessageTime = {};
    
    -- 初始化消息模式（即使已经初始化也要重新初始化，确保消息模式是最新的）
    InitializeMessagePatterns();
    
    -- 注册聊天消息监听（确保每次初始化都注册，防止事件丢失）
    if not self.chatFrame then
        self.chatFrame = CreateFrame("Frame");
        if not self.chatFrame then
            if Logger and Logger.Error then
                Logger:Error("TeamMessageReader", "错误", "无法创建聊天消息监听框架");
            end
            return;
        end
        
        self.chatFrame:RegisterEvent("CHAT_MSG_RAID");
        self.chatFrame:RegisterEvent("CHAT_MSG_RAID_WARNING");
        self.chatFrame:RegisterEvent("CHAT_MSG_PARTY");
        self.chatFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT");
        
        self.chatFrame:SetScript("OnEvent", function(self, event, ...)
            if TeamMessageReader and TeamMessageReader.ProcessTeamMessage then
                -- CHAT_MSG_* 事件的参数顺序：message, sender, languageName, channelName, target, flags, ...
                local message = select(1, ...);
                local sender = select(2, ...);
                if message and type(message) == "string" then
                    local chatType = event:gsub("CHAT_MSG_", "");
                    TeamMessageReader:ProcessTeamMessage(message, chatType, sender);
                end
            end
        end);
        
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "初始化", "已注册聊天消息监听");
        end
    end
    
    self.isInitialized = true;
    
    if Logger and Logger.Debug then
        Logger:Debug("TeamMessageReader", "初始化", "团队消息读取器已初始化");
    end
end

-- 清除通知记录（用于测试或重置）
function TeamMessageReader:ClearNotificationRecords()
    TeamMessageReader.lastTeamMessageTime = {};
    if Logger and Logger.Debug then
        Logger:Debug("TeamMessageReader", "重置", "已清除所有团队消息记录");
    end
end

return TeamMessageReader;

