-- TeamMessageReader.lua - 读取团队通知消息，自动更新空投刷新时间

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

-- 初始化消息模式
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

-- 检查是否是自动消息
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

-- 根据地图名称获取地图ID
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

function TeamMessageReader:ProcessTeamMessage(message, chatType, sender)
    if not message or type(message) ~= "string" then
        return false;
    end
    
    -- 团队消息检测始终运行，开关只控制时间更新
    
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
    
    -- 跳过自己发送的消息
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
    
    -- 检查是否在空投地图
    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player");
    local mapData = Data:GetMap(mapId);
    local isOnMap = mapData and currentMapID == mapData.mapID;
    
    -- 如果不在空投地图，处理团队消息
    
    if Logger and Logger.Debug then
        Logger:Debug("TeamMessageReader", "处理", string.format("检测到团队空投消息：发送者=%s，地图=%s，聊天类型=%s", 
            sender or "未知", mapName, chatType));
    end
    
    local currentTime = time();
    
    if not Data or not Data.SetLastRefresh then
        return false;
    end
    
    local teamTimeShareEnabled = CRATETRACKERZK_UI_DB and CRATETRACKERZK_UI_DB.teamTimeShareEnabled;
    
    -- 更新首次通知时间（用于30秒限制）
    if Notification and Notification.UpdateFirstNotificationTime then
        Notification:UpdateFirstNotificationTime(mapName, currentTime);
    end
    
    -- 如果不在空投地图，处理团队消息
    if not isOnMap then
        -- 检查30秒时间窗口
        local mapData = Data:GetMap(mapId);
        if mapData and mapData.currentAirdropTimestamp then
            local timeSinceLastUpdate = currentTime - mapData.currentAirdropTimestamp;
            -- 如果新时间在30秒内，且新时间更晚，说明是同一空投的多次消息，跳过更新
            if timeSinceLastUpdate <= 30 and currentTime > mapData.currentAirdropTimestamp then
                if Logger and Logger.Debug then
                    Logger:Debug("TeamMessageReader", "处理", string.format("跳过重复的团队消息（30秒内，新时间更晚）：地图=%s，上次更新时间=%s，新消息时间=%s，时间差=%d秒", 
                        mapName, 
                        Data:FormatDateTime(mapData.currentAirdropTimestamp),
                        Data:FormatDateTime(currentTime),
                        timeSinceLastUpdate));
                end
                return true;
            end
        end
        
        if not teamTimeShareEnabled then
            if Logger and Logger.Debug then
                Logger:Debug("TeamMessageReader", "处理", string.format("团队时间共享功能已关闭，检测到消息但不更新时间：地图=%s", mapName));
            end
            return true;
        end
        local success = Data:SetLastRefresh(mapId, currentTime);
        if not success then
            if Logger and Logger.Error then
                Logger:Error("TeamMessageReader", "错误", string.format("更新刷新时间失败：地图=%s", mapName));
            end
            return false;
        end
        
        -- 更新空投事件时间戳
        if mapData then
            mapData.currentAirdropTimestamp = currentTime;
            mapData.currentAirdropObjectGUID = nil;
            Data:SaveMapData(mapId);
        end
        
        
        if TimerManager and TimerManager.UpdateUI then
            TimerManager:UpdateUI();
        end
    else
        -- 在空投地图，不更新时间
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "处理", string.format("在空投地图，跳过团队消息更新（由自己的检测处理）：地图=%s", mapName));
        end
    end
    
    return true;
end

function TeamMessageReader:CheckHistoricalObjectGUID(mapId, objectGUID)
    if not mapId or not objectGUID then
        return false;
    end
    
    local mapData = Data:GetMap(mapId);
    if mapData and mapData.currentAirdropObjectGUID == objectGUID then
        if Logger and Logger.Debug then
            Logger:Debug("TeamMessageReader", "比对", string.format("重载后比对：相同 objectGUID，是同一事件，忽略：地图ID=%d，objectGUID=%s", 
                mapId, objectGUID));
        end
        return true;
    end
    
    return false;
end

function TeamMessageReader:Initialize()
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

return TeamMessageReader;
