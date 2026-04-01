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
local TeamCommParserRegistry = BuildEnv("TeamCommParserRegistry");
local TeamCommMapCache = BuildEnv("TeamCommMapCache");
local TeamCommMessageService = BuildEnv("TeamCommMessageService");

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

local function IsDebugEnabled()
    return Logger and Logger.debugEnabled == true;
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
    if TeamCommMessageService and TeamCommMessageService.Process then
        return TeamCommMessageService:Process(self, message, chatType, sender);
    end
    return false;
end

function TeamCommListener:Initialize()
    if TeamCommParserRegistry and TeamCommParserRegistry.Initialize then
        TeamCommParserRegistry:Initialize(self);
    end
    if TeamCommMapCache and TeamCommMapCache.Build then
        TeamCommMapCache:Build(self);
    end
    self.playerName = nil;
    self.fullPlayerName = nil;
    if TeamCommMapCache and TeamCommMapCache.EnsurePlayerIdentity then
        TeamCommMapCache:EnsurePlayerIdentity(self);
    end

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
