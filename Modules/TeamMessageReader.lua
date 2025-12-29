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
TeamMessageReader.messagePatterns = {};
TeamMessageReader.lastTeamMessageTime = {};
TeamMessageReader.MESSAGE_COOLDOWN = 30;

-- 初始化消息模式（匹配插件自动发送的团队消息，使用 AirdropDetected 格式）
local function InitializeMessagePatterns()
    TeamMessageReader.messagePatterns = {};
    
    local messageFormats = {};
    
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry();
        if localeRegistry then
            for locale, localeData in pairs(localeRegistry) do
                if localeData and localeData.AirdropDetected then
                    local found = false;
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
    
    if #messageFormats == 0 then
        local L = CrateTrackerZK and CrateTrackerZK.L;
        if L and L.AirdropDetected then
            table.insert(messageFormats, L.AirdropDetected);
            if Logger and Logger.Debug then
                Logger:Debug("TeamMessageReader", "初始化", string.format("使用当前语言消息格式（回退方案）：格式=%s", L.AirdropDetected));
            end
        end
    end
    
    for _, messageFormat in ipairs(messageFormats) do
        local msgPattern = messageFormat;
        
        msgPattern = msgPattern:gsub("%%", "%%%%");
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
local function IsAutoMessage(message)
    if not message or type(message) ~= "string" then
        return false;
    end
    
    for _, patternData in ipairs(TeamMessageReader.messagePatterns) do
        local mapName = message:match(patternData.pattern);
        if mapName and mapName ~= "" then
            if Logger and Logger.Debug then
                Logger:Debug("TeamMessageReader", "解析", string.format("检测到自动消息（匹配格式：%s）", patternData.original));
            end
            return true;
        end
    end
    
    return false;
end

local function ParseTeamMessage(message)
    if not message or type(message) ~= "string" then
        return nil;
    end
    
    if not IsAutoMessage(message) then
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "解析", "消息不匹配自动消息格式，跳过处理（可能是手动消息）");
        end
        return nil;
    end
    
    for _, patternData in ipairs(TeamMessageReader.messagePatterns) do
        local mapName = message:match(patternData.pattern);
        if mapName and mapName ~= "" then
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
    
    for _, mapData in ipairs(maps) do
        local displayName = Data:GetMapDisplayName(mapData);
        if displayName == mapName then
            return mapData.id;
        end
    end
    
    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry();
        if localeRegistry then
            for _, mapData in ipairs(maps) do
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

local function ShouldSendNotification(mapId, currentTime)
    if not mapId then
        return false;
    end
    
    local lastTime = TeamMessageReader.lastTeamMessageTime[mapId];
    if not lastTime then
        return true;
    end
    
    local timeSinceTeamMessage = currentTime - lastTime;
    return timeSinceTeamMessage < TeamMessageReader.MESSAGE_COOLDOWN;
end

function TeamMessageReader:ProcessTeamMessage(message, chatType, sender)
    if not message or type(message) ~= "string" then
        return false;
    end
    
    if not self.isInitialized then
        self:Initialize();
    end
    
    if not chatType or (chatType ~= "RAID" and chatType ~= "RAID_WARNING" and chatType ~= "PARTY" and chatType ~= "INSTANCE_CHAT") then
        return false;
    end
    
    local mapName = ParseTeamMessage(message);
    if not mapName then
        return false;
    end
    
    local mapId = GetMapIdByName(mapName);
    if not mapId then
        if Logger and Logger.Warn then
            Logger:Warn("TeamMessageReader", "警告", string.format("无法找到地图：%s", mapName));
        end
        return false;
    end
    
    -- 防重复更新机制 #1: 跳过自己发送的消息
    local playerName = UnitName("player");
    local realmName = GetRealmName();
    local fullPlayerName = playerName;
    if realmName then
        fullPlayerName = playerName .. "-" .. realmName;
    end
    
    if sender and (sender == playerName or sender == fullPlayerName) then
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "处理", string.format("跳过自己发送的消息：发送者=%s，地图=%s", sender, mapName));
        end
        return false;
    end
    
    -- 防重复更新机制 #2: 如果当前地图是 PROCESSED 状态，跳过处理
    if DetectionState then
        local state = DetectionState:GetState(mapId);
        if state and state.status == DetectionState.STATES.PROCESSED then
            local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player");
            local mapData = Data:GetMap(mapId);
            local isOnMap = mapData and currentMapID == mapData.mapID;
            if isOnMap then
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "处理", string.format("跳过当前地图的PROCESSED状态消息（可能是自己发送的）：地图=%s，发送者=%s", mapName, sender or "未知"));
                end
                return false;
            end
        end
    end
    
    if Logger and Logger.Debug then
        Logger:Debug("TeamMessageReader", "处理", string.format("检测到团队空投消息：发送者=%s，地图=%s，聊天类型=%s", 
            sender or "未知", mapName, chatType));
    end
    
    local currentTime = time();
    TeamMessageReader.lastTeamMessageTime[mapId] = currentTime;
    
    if not Data or not Data.SetLastRefresh then
        return false;
    end
    
    -- 防重复更新机制 #3: 时间窗口检查（如果时间差异≤30秒，使用更早的时间）
    local mapData = Data:GetMap(mapId);
    local oldTime = mapData and mapData.lastRefresh;
    local refreshTime = currentTime;
    local shouldUpdate = true;
    
    if oldTime then
        local timeDiff = math.abs(currentTime - oldTime);
        
        if timeDiff <= TeamMessageReader.MESSAGE_COOLDOWN then
            if currentTime < oldTime then
                refreshTime = currentTime;
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "更新", string.format("使用更早的时间：地图=%s，旧时间=%s，新时间=%s，使用时间=%s", 
                        mapName,
                        Data:FormatDateTime(oldTime),
                        Data:FormatDateTime(currentTime),
                        Data:FormatDateTime(refreshTime)));
                end
            else
                shouldUpdate = false;
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "更新", string.format("跳过重复更新：地图=%s，旧时间=%s，新时间=%s（时间差异在冷却期内，且新时间不更早）", 
                        mapName, 
                        Data:FormatDateTime(oldTime),
                        Data:FormatDateTime(currentTime)));
                end
            end
        end
    end
    
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
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "更新", string.format("消息已处理但跳过更新：地图=%s（已使用更早的时间）", mapName));
        end
        return true;
    end
    
    if TimerManager and TimerManager.UpdateUI then
        TimerManager:UpdateUI();
    end
    
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player");
    local mapData = Data:GetMap(mapId);
    local isOnMap = mapData and currentMapID == mapData.mapID;
    
    if isOnMap then
        local shouldSend = true;
        if DetectionState then
            local state = DetectionState:GetState(mapId);
            if state and state.status == DetectionState.STATES.PROCESSED then
                shouldSend = false;
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "通知", string.format("空投还在进行中，不发送重复通知：地图=%s", mapName));
                end
            end
        end
        
        if shouldSend then
            if Logger and Logger.Info then
                local currentL = CrateTrackerZK and CrateTrackerZK.L;
                if currentL and currentL.AirdropDetected then
                    Logger:Info("Notification", "通知", string.format(currentL.AirdropDetected, mapName));
                else
                    Logger:Info("Notification", "通知", string.format("【%s】 发现战争物资正在空投！！！", mapName));
                end
            end
        end
    end
    
    return true;
end

function TeamMessageReader:Initialize()
    TeamMessageReader.lastTeamMessageTime = {};
    InitializeMessagePatterns();
    
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

function TeamMessageReader:ClearNotificationRecords()
    TeamMessageReader.lastTeamMessageTime = {};
    if Logger and Logger.Debug then
        Logger:Debug("TeamMessageReader", "重置", "已清除所有团队消息记录");
    end
end

return TeamMessageReader;
