-- TeamCommListener.lua - 读取团队通知消息，自动更新空投刷新时间

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local TeamCommListener = BuildEnv('TeamCommListener');

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

if not Data then
    Data = BuildEnv('Data')
end

if not Utils then
    Utils = BuildEnv('Utils')
end

if not AirdropEventService then
    AirdropEventService = BuildEnv('AirdropEventService')
end

if not UnifiedDataManager then
    UnifiedDataManager = BuildEnv('UnifiedDataManager')
end

if not TimerManager then
    TimerManager = BuildEnv('TimerManager')
end

if not Area then
    Area = BuildEnv('Area')
end

TeamCommListener.isInitialized = false;
TeamCommListener.messagePatterns = {};       -- 兼容保留
TeamCommListener.autoReportPatterns = {};    -- 兼容保留
TeamCommListener.preferredMessageParsers = {};
TeamCommListener.fallbackMessageParsers = {};
TeamCommListener.preferredAutoReportParsers = {};
TeamCommListener.fallbackAutoReportParsers = {};
TeamCommListener.mapNameToID = {};
TeamCommListener.mapNameCacheSignature = nil;
TeamCommListener.mapNameCacheMapsRef = nil;
TeamCommListener.mapNameCacheCount = nil;
TeamCommListener.mapNameCacheExpansionID = nil;
TeamCommListener.playerName = nil;
TeamCommListener.fullPlayerName = nil;

TeamCommListener.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW = 300;

local TEAM_CHAT_TYPES = {
    RAID = true,
    RAID_WARNING = true,
    PARTY = true,
    INSTANCE_CHAT = true
};

local CHAT_EVENT_TO_TYPE = {
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID_WARNING",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT"
};

local function TrimString(value)
    if type(value) ~= "string" then
        return nil;
    end
    return value:match("^%s*(.-)%s*$");
end

local function IsDebugEnabled()
    return Logger and Logger.debugEnabled == true;
end

local function HasRecentLocalConfirmedAirdrop(mapData, currentTime)
    if type(mapData) ~= "table" then
        return false;
    end
    if type(mapData.currentAirdropObjectGUID) ~= "string" or mapData.currentAirdropObjectGUID == "" then
        return false;
    end
    if type(mapData.currentAirdropTimestamp) ~= "number" then
        return false;
    end
    if type(currentTime) ~= "number" or currentTime < mapData.currentAirdropTimestamp then
        return false;
    end

    local suppressWindow = TeamCommListener.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW or 300;
    if AirdropEventService and AirdropEventService.HasRecentTimestamp then
        return AirdropEventService:HasRecentTimestamp(mapData.currentAirdropTimestamp, currentTime, suppressWindow);
    end
    return (currentTime - mapData.currentAirdropTimestamp) <= suppressWindow;
end

local function BuildParser(messageFormat, locale)
    if type(messageFormat) ~= "string" or messageFormat == "" then
        return nil;
    end
    local segments = {};
    local cursor = 1;
    local placeholderCount = 0;

    while true do
        local tokenStart = messageFormat:find("%s", cursor, true);
        if not tokenStart then
            table.insert(segments, messageFormat:sub(cursor));
            break;
        end
        table.insert(segments, messageFormat:sub(cursor, tokenStart - 1));
        cursor = tokenStart + 2;
        placeholderCount = placeholderCount + 1;
    end

    if placeholderCount == 0 then
        return nil;
    end

    return {
        original = messageFormat,
        locale = locale,
        segments = segments,
        placeholderCount = placeholderCount
    };
end

local function MatchWithParser(message, parser)
    if not parser then
        return nil;
    end
    local textLen = #message;
    local segments = parser.segments or {};
    if #segments == 0 then
        return nil;
    end

    local cursor = 1;
    local captures = {};

    for idx, seg in ipairs(segments) do
        local isLastSegment = idx == #segments;
        if idx == 1 then
            if seg ~= "" then
                local segLen = #seg;
                if textLen < segLen or message:sub(1, segLen) ~= seg then
                    return nil;
                end
                cursor = segLen + 1;
            end
        else
            if seg == "" then
                captures[idx - 1] = message:sub(cursor);
                cursor = textLen + 1;
            else
                local pos = message:find(seg, cursor, true);
                if not pos then
                    return nil;
                end
                captures[idx - 1] = message:sub(cursor, pos - 1);
                cursor = pos + #seg;
            end
        end

        if isLastSegment and seg ~= "" and cursor <= textLen then
            return nil;
        end
    end

    local mapName = TrimString(captures[1]);
    if not mapName or mapName == "" then
        return nil;
    end
    return mapName;
end

local function MatchWithParsers(message, parsers)
    if not parsers or #parsers == 0 then
        return nil, nil;
    end
    for _, parser in ipairs(parsers) do
        local mapName = MatchWithParser(message, parser);
        if mapName then
            return mapName, parser;
        end
    end
    return nil, nil;
end

local function BuildParsersByLocaleKey(localeKey, skipEmpty)
    local preferred = {};
    local fallback = {};
    local seenFormats = {};
    local currentLocale = GetLocale and GetLocale() or nil;

    local function AddFormat(locale, formatText, forcePreferred)
        if type(formatText) ~= "string" then
            return;
        end
        if skipEmpty and formatText == "" then
            return;
        end
        if seenFormats[formatText] then
            return;
        end
        seenFormats[formatText] = true;
        local parser = BuildParser(formatText, locale);
        if not parser then
            return;
        end
        if forcePreferred or (currentLocale and locale == currentLocale) then
            table.insert(preferred, parser);
        else
            table.insert(fallback, parser);
        end
    end

    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry();
        if localeRegistry then
            if currentLocale and localeRegistry[currentLocale] then
                AddFormat(currentLocale, localeRegistry[currentLocale][localeKey], true);
            end
            for locale, localeData in pairs(localeRegistry) do
                if localeData and locale ~= currentLocale then
                    AddFormat(locale, localeData[localeKey], false);
                end
            end
        end
    end

    local currentL = CrateTrackerZK and CrateTrackerZK.L;
    if currentL then
        AddFormat(currentLocale or "current", currentL[localeKey], true);
    end

    return preferred, fallback;
end

local function FlattenParsers(preferred, fallback)
    local result = {};
    for _, parser in ipairs(preferred or {}) do
        table.insert(result, parser);
    end
    for _, parser in ipairs(fallback or {}) do
        table.insert(result, parser);
    end
    return result;
end

local function InitializeMessagePatterns()
    TeamCommListener.preferredMessageParsers, TeamCommListener.fallbackMessageParsers = BuildParsersByLocaleKey("AirdropDetected", true);
    TeamCommListener.messagePatterns = FlattenParsers(TeamCommListener.preferredMessageParsers, TeamCommListener.fallbackMessageParsers);

    if #TeamCommListener.messagePatterns == 0 then
        if Logger and Logger.Warn then
            Logger:Warn("TeamCommListener", "警告", "未找到任何消息模式，团队消息读取功能可能无法正常工作");
        end
    elseif Logger and Logger.Debug then
        local preferredCount = #TeamCommListener.preferredMessageParsers;
        local fallbackCount = #TeamCommListener.fallbackMessageParsers;
        Logger:Debug("TeamCommListener", "初始化", string.format("团队消息解析器已加载：首选=%d，回退=%d", preferredCount, fallbackCount));
    end
end

local function InitializeAutoReportPatterns()
    TeamCommListener.preferredAutoReportParsers, TeamCommListener.fallbackAutoReportParsers = BuildParsersByLocaleKey("AutoTeamReportMessage", true);
    TeamCommListener.autoReportPatterns = FlattenParsers(TeamCommListener.preferredAutoReportParsers, TeamCommListener.fallbackAutoReportParsers);

    if Logger and Logger.Debug then
        local preferredCount = #TeamCommListener.preferredAutoReportParsers;
        local fallbackCount = #TeamCommListener.fallbackAutoReportParsers;
        Logger:Debug("TeamCommListener", "初始化", string.format("自动播报解析器已加载：首选=%d，回退=%d", preferredCount, fallbackCount));
    end
end

local function ParseTeamMessage(message)
    if not message or type(message) ~= "string" then
        return nil;
    end

    local reportMapName = MatchWithParsers(message, TeamCommListener.preferredAutoReportParsers);
    if not reportMapName then
        reportMapName = MatchWithParsers(message, TeamCommListener.fallbackAutoReportParsers);
    end
    if reportMapName then
        if Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "解析", "消息为自动播报格式，跳过处理");
        end
        return nil;
    end

    local mapName, parser = MatchWithParsers(message, TeamCommListener.preferredMessageParsers);
    if not mapName then
        mapName, parser = MatchWithParsers(message, TeamCommListener.fallbackMessageParsers);
    end
    if mapName then
        if IsDebugEnabled() and Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "解析", string.format("匹配到自动消息：语言=%s，格式=%s，地图名称=%s",
                tostring(parser and parser.locale or "unknown"),
                tostring(parser and parser.original or "unknown"),
                mapName));
        end
        return mapName;
    end

    if IsDebugEnabled() and Logger and Logger.Debug then
        Logger:Debug("TeamCommListener", "解析", "消息不匹配自动消息格式，跳过处理（可能是手动消息）");
    end
    return nil;
end

local function BuildMapNameCache()
    TeamCommListener.mapNameToID = {};
    TeamCommListener.mapNameCacheSignature = nil;
    TeamCommListener.mapNameCacheMapsRef = nil;
    TeamCommListener.mapNameCacheCount = nil;
    TeamCommListener.mapNameCacheExpansionID = nil;

    if not Data or not Data.GetAllMaps then
        return;
    end
    local maps = Data:GetAllMaps();
    if not maps or #maps == 0 then
        return;
    end

    local expansionID = (Data.GetCurrentExpansionID and Data:GetCurrentExpansionID()) or "default";
    local signatureParts = { tostring(expansionID), tostring(#maps) };
    for _, mapData in ipairs(maps) do
        if mapData then
            table.insert(signatureParts, tostring(mapData.id) .. ":" .. tostring(mapData.mapID));
        end
    end
    TeamCommListener.mapNameCacheSignature = table.concat(signatureParts, "|");
    TeamCommListener.mapNameCacheMapsRef = maps;
    TeamCommListener.mapNameCacheCount = #maps;
    TeamCommListener.mapNameCacheExpansionID = expansionID;

    for _, mapData in ipairs(maps) do
        if mapData then
            local displayName = Data:GetMapDisplayName(mapData);
            if type(displayName) == "string" and displayName ~= "" then
                TeamCommListener.mapNameToID[displayName] = mapData.id;
            end
        end
    end

    local LocaleManager = BuildEnv("LocaleManager");
    if LocaleManager and LocaleManager.GetLocaleRegistry then
        local localeRegistry = LocaleManager.GetLocaleRegistry();
        if localeRegistry then
            for _, mapData in ipairs(maps) do
                if mapData and mapData.mapID then
                    for _, localeData in pairs(localeRegistry) do
                        local localizedName = localeData and localeData.MapNames and localeData.MapNames[mapData.mapID];
                        if type(localizedName) == "string" and localizedName ~= "" and not TeamCommListener.mapNameToID[localizedName] then
                            TeamCommListener.mapNameToID[localizedName] = mapData.id;
                        end
                    end
                end
            end
        end
    end
end

local function EnsureMapNameCache()
    if not Data or not Data.GetAllMaps then
        return;
    end
    local maps = Data:GetAllMaps();
    if not maps then
        return;
    end
    local expansionID = (Data.GetCurrentExpansionID and Data:GetCurrentExpansionID()) or "default";
    if TeamCommListener.mapNameCacheMapsRef ~= maps
        or TeamCommListener.mapNameCacheCount ~= #maps
        or TeamCommListener.mapNameCacheExpansionID ~= expansionID
        or not TeamCommListener.mapNameToID then
        BuildMapNameCache();
    end
end

local function GetMapIdByName(mapName)
    local name = TrimString(mapName);
    if not name or name == "" then
        return nil;
    end
    EnsureMapNameCache();
    return TeamCommListener.mapNameToID and TeamCommListener.mapNameToID[name] or nil;
end

local function EnsurePlayerIdentityCache()
    if TeamCommListener.playerName and TeamCommListener.fullPlayerName then
        return;
    end
    local playerName = UnitName("player");
    local realmName = GetRealmName();
    TeamCommListener.playerName = playerName;
    if playerName and realmName and realmName ~= "" then
        TeamCommListener.fullPlayerName = playerName .. "-" .. realmName;
    else
        TeamCommListener.fullPlayerName = playerName;
    end
end

function TeamCommListener:ProcessTeamMessage(message, chatType, sender)
    if not message or type(message) ~= "string" then
        return false;
    end

    if not self.isInitialized then
        self:Initialize();
    end

    if not chatType or not TEAM_CHAT_TYPES[chatType] then
        return false;
    end

    local mapName = ParseTeamMessage(message);
    if not mapName then
        return false;
    end

    local mapId = GetMapIdByName(mapName);
    if not mapId then
        if IsDebugEnabled() and Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "忽略", string.format("消息地图不在当前版本配置中，已忽略：%s", mapName));
        end
        return false;
    end

    EnsurePlayerIdentityCache();
    if sender and (sender == self.playerName or sender == self.fullPlayerName) then
        if IsDebugEnabled() and Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format("跳过自己发送的消息：发送者=%s，地图=%s", sender, mapName));
        end
        return false;
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player");
    local mapData = Data:GetMap(mapId);
    local isOnMap = mapData and currentMapID == mapData.mapID;

    if IsDebugEnabled() and Logger and Logger.Debug then
        Logger:Debug("TeamCommListener", "处理", string.format("检测到团队空投消息：发送者=%s，地图=%s，聊天类型=%s",
            sender or "未知", mapName, chatType));
    end

    local currentTime = time();

    if not Data or not Data.SetLastRefresh then
        return false;
    end

    if not isOnMap then
        if HasRecentLocalConfirmedAirdrop(mapData, currentTime) then
            if IsDebugEnabled() and Logger and Logger.Debug then
                Logger:Debug("TeamCommListener", "处理", string.format(
                    "忽略晚到团队消息：地图=%s，本地已在%d秒保护窗内确认过空投，确认时间=%s",
                    mapName,
                    self.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW or 300,
                    UnifiedDataManager:FormatDateTime(mapData.currentAirdropTimestamp)
                ));
            end
            return true;
        end

        if UnifiedDataManager and UnifiedDataManager.GetValidTemporaryTime then
            local tempRecord = UnifiedDataManager:GetValidTemporaryTime(mapId);
            if tempRecord then
                local timeSinceLast = currentTime - tempRecord.timestamp;
                local isDuplicate = AirdropEventService and AirdropEventService.IsDuplicateTeamMessage
                    and AirdropEventService:IsDuplicateTeamMessage(tempRecord.timestamp, currentTime, 30)
                    or (timeSinceLast >= 0 and timeSinceLast <= 30 and currentTime > tempRecord.timestamp);
                if isDuplicate then
                    if IsDebugEnabled() and Logger and Logger.Debug then
                        Logger:Debug("TeamCommListener", "处理", string.format("跳过重复的团队消息（30秒内）：地图=%s，上次=%s，本次=%s，差值=%d秒",
                            mapName,
                            UnifiedDataManager:FormatDateTime(tempRecord.timestamp),
                            UnifiedDataManager:FormatDateTime(currentTime),
                            timeSinceLast));
                    end
                    return true;
                end
            end
        end

        local success = false;
        if UnifiedDataManager and UnifiedDataManager.SetTime then
            local source = (TimerManager and TimerManager.detectionSources and TimerManager.detectionSources.TEAM_MESSAGE) or "team_message";
            success = UnifiedDataManager:SetTime(mapId, currentTime, source);
            if success and IsDebugEnabled() and Logger and Logger.Debug then
                Logger:Debug("TeamCommListener", "处理", string.format("通过UnifiedDataManager设置临时时间成功：地图=%s", mapName));
            end
        else
            success = Data:SetLastRefresh(mapId, currentTime);
        end

        if not success then
            if Logger and Logger.Error then
                Logger:Error("TeamCommListener", "错误", string.format("更新刷新时间失败：地图=%s", mapName));
            end
            return false;
        end

        if TimerManager and TimerManager.UpdateUI then
            TimerManager:UpdateUI();
        end
    else
        if IsDebugEnabled() and Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format("在空投地图，跳过团队消息更新（由自己的检测处理）：地图=%s", mapName));
        end
    end

    return true;
end

function TeamCommListener:CheckHistoricalObjectGUID(mapId, objectGUID)
    if not mapId or not objectGUID then
        return false;
    end

    local mapData = Data:GetMap(mapId);
    local isSameObject = AirdropEventService and AirdropEventService.HasSameObjectGUID
        and AirdropEventService:HasSameObjectGUID(mapData and mapData.currentAirdropObjectGUID, objectGUID)
        or (mapData and mapData.currentAirdropObjectGUID == objectGUID);
    if isSameObject then
        if IsDebugEnabled() and Logger and Logger.Debug then
            Logger:Debug("TeamCommListener", "比对", string.format("重载后比对：相同 objectGUID，是同一事件，忽略：地图ID=%d，objectGUID=%s",
                mapId, objectGUID));
        end
        return true;
    end

    return false;
end

function TeamCommListener:Initialize()
    InitializeMessagePatterns();
    InitializeAutoReportPatterns();
    BuildMapNameCache();
    self.playerName = nil;
    self.fullPlayerName = nil;
    EnsurePlayerIdentityCache();

    self.isInitialized = true;

    if IsDebugEnabled() and Logger and Logger.Debug then
        Logger:Debug("TeamCommListener", "初始化", "团队消息读取器已初始化（被动）");
    end
end

function TeamCommListener:HandleChatEvent(event, message, sender)
    if not self.isInitialized then
        self:Initialize();
    end
    if Area and Area.IsActive and not Area:IsActive() then
        return;
    end
    if IsInInstance and IsInInstance() then
        return;
    end
    if not event or not message or type(message) ~= "string" then
        return;
    end

    local chatType = CHAT_EVENT_TO_TYPE[event];
    if not chatType then
        return;
    end
    self:ProcessTeamMessage(message, chatType, sender);
end

return TeamCommListener;
