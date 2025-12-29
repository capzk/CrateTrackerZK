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

-- 初始化消息模式（匹配插件自动发送的团队消息，不带"通知："前缀）
local function InitializeMessagePatterns()
    TeamMessageReader.messagePatterns = {};
    
    -- 获取所有支持的语言的消息格式
    local messageFormats = {};
    
    -- 使用当前语言
    local L = CrateTrackerZK.L;
    if L and L.AirdropDetected then
        table.insert(messageFormats, L.AirdropDetected);
    end
    
    -- 尝试从Localization获取所有语言
    if Localization then
        local locales = {"zhCN", "zhTW", "enUS", "ruRU"};
        for _, locale in ipairs(locales) do
            local localeData = Localization:GetLocale(locale);
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
                end
            end
        end
    end
    
    -- 为每个消息格式创建匹配模式（不带"通知："前缀，即自动消息）
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
        
        Logger:Debug("TeamMessageReader", "初始化", string.format("已加载消息模式：格式=%s，模式=%s", messageFormat, msgPattern));
    end
    
    if #TeamMessageReader.messagePatterns == 0 then
        Logger:Warn("TeamMessageReader", "警告", "未找到任何消息模式，团队消息读取功能可能无法正常工作");
    end
end

-- 解析团队消息，提取地图名称
local function ParseTeamMessage(message)
    if not message or type(message) ~= "string" then
        return nil;
    end
    
    -- 排除以"通知："开头的消息（手动消息）
    if message:match("^通知：") then
        Logger:Debug("TeamMessageReader", "解析", "检测到手动消息（带'通知：'前缀），跳过处理");
        return nil;
    end
    
    -- 尝试匹配所有已加载的消息模式（只匹配自动消息，不带"通知："前缀）
    for _, patternData in ipairs(TeamMessageReader.messagePatterns) do
        local mapName = message:match(patternData.pattern);
        if mapName and mapName ~= "" then
            -- 去除首尾空格
            mapName = mapName:match("^%s*(.-)%s*$");
            if mapName and mapName ~= "" then
                Logger:Debug("TeamMessageReader", "解析", string.format("匹配到自动消息：格式=%s，地图名称=%s", 
                    patternData.original, mapName));
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
    
    Logger:Debug("TeamMessageReader", "处理", string.format("检测到团队空投消息：发送者=%s，地图=%s，聊天类型=%s", 
        sender or "未知", mapName, chatType));
    
    -- 根据地图名称获取地图ID
    local mapId = GetMapIdByName(mapName);
    if not mapId then
        Logger:Warn("TeamMessageReader", "警告", string.format("无法找到地图：%s", mapName));
        return false;
    end
    
    local currentTime = time();
    
    -- 记录收到团队消息的时间（用于防止之后进入地图时重复通知）
    TeamMessageReader.lastTeamMessageTime[mapId] = currentTime;
    
    -- 更新刷新时间（使用当前时间作为刷新时间）
    local success = Data:SetLastRefresh(mapId, currentTime);
    if not success then
        Logger:Error("TeamMessageReader", "错误", string.format("更新刷新时间失败：地图=%s", mapName));
        return false;
    end
    
    Logger:Info("TeamMessageReader", "更新", string.format("已根据团队消息更新刷新时间：地图=%s，时间=%s", 
        mapName, Data:FormatDateTime(currentTime)));
    
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
                Logger:Debug("TeamMessageReader", "通知", string.format("空投还在进行中，不发送重复通知：地图=%s", mapName));
            end
        end
        
        if shouldSend then
            -- 发送系统通知（不会再次发送团队消息，因为已经收到了）
            Logger:Info("Notification", "通知", string.format(L["AirdropDetected"], mapName));
        end
    else
        -- 不在当前地图上，不发送通知（但刷新时间已更新）
        -- 如果之后进入该地图，且空投还在进行中，不会再次发送通知（由Timer.lua中的检查处理）
        Logger:Debug("TeamMessageReader", "通知", string.format("不在当前地图上，不发送通知：地图=%s（如果之后进入该地图，且空投还在进行中，不会重复通知）", mapName));
    end
    
    return true;
end

function TeamMessageReader:Initialize()
    -- 清除所有内存状态（防止跨角色污染）
    TeamMessageReader.lastTeamMessageTime = {};
    
    if self.isInitialized then
        return;
    end
    
    self.isInitialized = true;
    
    -- 初始化消息模式
    InitializeMessagePatterns();
    
    -- 注册聊天消息监听
    if not self.chatFrame then
        self.chatFrame = CreateFrame("Frame");
        self.chatFrame:RegisterEvent("CHAT_MSG_RAID");
        self.chatFrame:RegisterEvent("CHAT_MSG_RAID_WARNING");
        self.chatFrame:RegisterEvent("CHAT_MSG_PARTY");
        self.chatFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT");
        
        self.chatFrame:SetScript("OnEvent", function(self, event, message, sender, ...)
            if TeamMessageReader and TeamMessageReader.ProcessTeamMessage then
                local chatType = event:gsub("CHAT_MSG_", "");
                TeamMessageReader:ProcessTeamMessage(message, chatType, sender);
            end
        end);
        
        Logger:Debug("TeamMessageReader", "初始化", "已注册聊天消息监听");
    end
    
    Logger:Debug("TeamMessageReader", "初始化", "团队消息读取器已初始化");
end

-- 清除通知记录（用于测试或重置）
function TeamMessageReader:ClearNotificationRecords()
    TeamMessageReader.lastTeamMessageTime = {};
    Logger:Debug("TeamMessageReader", "重置", "已清除所有团队消息记录");
end

return TeamMessageReader;

