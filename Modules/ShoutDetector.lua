-- ShoutDetector.lua - NPC喊话检测模块（空投开始即时通知）

if not BuildEnv then
    BuildEnv = function(name)
        _G[name] = _G[name] or {};
        return _G[name];
    end
end

local ShoutDetector = BuildEnv("ShoutDetector");

local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK.L;

if not Localization then Localization = BuildEnv("Localization") end
if not MapTracker then MapTracker = BuildEnv("MapTracker") end
if not Notification then Notification = BuildEnv("Notification") end
if not Data then Data = BuildEnv("Data") end
if not Area then Area = BuildEnv("Area") end
if not Logger then Logger = BuildEnv("Logger") end

ShoutDetector.isInitialized = false;

local function SafeToString(value)
    local ok, result = pcall(tostring, value);
    if ok then
        return result;
    end
    return "<secret>";
end

local function GetTrackedMap()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil, nil;
    end
    local currentMapID = C_Map.GetBestMapForUnit("player");
    if not currentMapID or not MapTracker or not MapTracker.GetTargetMapData then
        return nil, currentMapID;
    end
    local targetMapData = MapTracker:GetTargetMapData(currentMapID);
    return targetMapData, currentMapID;
end

local function IsMapHidden(targetMapData)
    if not targetMapData or not CRATETRACKERZK_UI_DB or not CRATETRACKERZK_UI_DB.hiddenMaps then
        return false;
    end
    return CRATETRACKERZK_UI_DB.hiddenMaps[targetMapData.mapID] == true;
end

local function OnShoutDetected(message)
    -- 区域无效（副本/战场/隐藏地图）则跳过
    if Area and (Area.detectionPaused or Area.lastAreaValidState == false) then
        return;
    end

    local targetMapData, currentMapID = GetTrackedMap();
    if not targetMapData or not Data then
        return;
    end
    if IsMapHidden(targetMapData) then
        return;
    end

    local mapName = Data:GetMapDisplayName(targetMapData);
    if Notification and Notification.RecordShout then
        Notification:RecordShout(mapName);
    end
    -- 喊话触发视为新事件，清除通知去重，确保立即广播
    if Notification then
        Notification.firstNotificationTime = Notification.firstNotificationTime or {};
        Notification.playerSentNotification = Notification.playerSentNotification or {};
        Notification.firstNotificationTime[mapName] = nil;
        Notification.playerSentNotification[mapName] = nil;
    end
    Logger:Debug("ShoutDetector", "触发", string.format("喊话触发通知：地图=%s，消息=%s", mapName, SafeToString(message)));
    -- 立即发送通知（遵循现有开关/频道规则）
    if Notification and Notification.NotifyAirdropDetected then
        Notification:NotifyAirdropDetected(mapName, "npc_shout");
    end
end

local function normalizeQuote(str)
    return (str or ""):gsub("’", "'"):gsub("‘", "'"):gsub("＇", "'")
end

local function normalizePunct(str)
    -- 统一中英文常见标点为空格，便于模糊匹配
    return (str or "")
        :gsub("[%.,!%?:]", " ")
        :gsub("[，。？！：；]", " ")
end

local function normalizeForMatch(str)
    str = normalizeQuote(str or "")
    str = normalizePunct(str)
    str = str:lower()
    str = str:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return str
end

local function SafeNormalizeForMatch(value)
    local ok, result = pcall(normalizeForMatch, value);
    if ok then
        return result;
    end
    return nil;
end

local function MessageMatchesShout(message)
    if not message or type(message) ~= "string" then
        return false;
    end
    if not Localization or not Localization.GetAirdropShouts then
        return false;
    end
    local shouts = Localization:GetAirdropShouts();
    if not shouts or #shouts == 0 then
        return false;
    end
    local msg = SafeNormalizeForMatch(message);
    if not msg then
        return false;
    end
    for _, shout in ipairs(shouts) do
        if type(shout) == "string" then
            -- 先保留原文做前缀切分，再归一化
            local rawSuffix = shout:match("^[^:：]*[:：]%s*(.*)$");
            local targetFull = SafeNormalizeForMatch(shout);
            local targetSuffix = rawSuffix and SafeNormalizeForMatch(rawSuffix) or targetFull;
            if targetFull and targetFull ~= "" and msg:find(targetFull, 1, true) then
                Logger:Debug("ShoutDetector", "匹配", string.format("匹配到喊话（含前缀）：%s -> %s", SafeToString(message), shout));
                return true;
            elseif targetSuffix and targetSuffix ~= "" and msg:find(targetSuffix, 1, true) then
                Logger:Debug("ShoutDetector", "匹配", string.format("匹配到喊话（去前缀）：%s -> %s", SafeToString(message), shout));
                return true;
            end
        end
    end
    return false;
end

local function OnChatEvent(self, event, message)
    if Logger then
        Logger:Debug("ShoutDetector", "事件", string.format("收到聊天事件：%s，消息=%s", SafeToString(event), SafeToString(message)));
    end
    if not MessageMatchesShout(message) then
        if Logger then
            Logger:Debug("ShoutDetector", "未匹配", string.format("未匹配喊话：事件=%s，消息=%s", SafeToString(event), SafeToString(message)));
        end
        return;
    end
    OnShoutDetected(message);
end

function ShoutDetector:Initialize()
    if self.isInitialized then return end

    -- 如果当前语言没有配置喊话，直接跳过初始化
    local shouts = Localization and Localization.GetAirdropShouts and Localization:GetAirdropShouts();
    if not shouts or #shouts == 0 then
        Logger:Debug("ShoutDetector", "初始化", "未配置喊話內容，跳過初始化");
        return;
    end

    self.isInitialized = true;
    Logger:Debug("ShoutDetector", "初始化", "NPC喊話檢測已啟用（被动）");
end

function ShoutDetector:HandleChatEvent(event, message)
    if not self.isInitialized then
        return;
    end
    if Area and Area.IsActive and not Area:IsActive() then
        return;
    end
    if type(message) ~= "string" then
        return;
    end
    OnChatEvent(self, event, message);
end

return ShoutDetector;
