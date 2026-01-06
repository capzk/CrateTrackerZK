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
    Logger:Debug("ShoutDetector", "触发", string.format("喊话触发通知：地图=%s，消息=%s", mapName, message or ""));
    -- 立即发送通知（遵循现有开关/频道规则）
    if Notification and Notification.NotifyAirdropDetected then
        Notification:NotifyAirdropDetected(mapName, "npc_shout");
    end
end

local function normalizeQuote(str)
    return (str or ""):gsub("’", "'"):gsub("‘", "'")
end

local function normalizeForMatch(str)
    str = normalizeQuote(str or "")
    str = str:lower()
    -- 去掉常见标点与多余空格，提升匹配宽容度
    str = str:gsub("[%.,!%?]", " ")
    str = str:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return str
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
    local msg = normalizeForMatch(message);
    for _, shout in ipairs(shouts) do
        if type(shout) == "string" then
            local targetFull = normalizeForMatch(shout);
            local targetSuffix = targetFull;
            -- 去掉“X says/yells:”等前缀，兼容事件消息无说话人前缀的情况
            local colonPos = targetSuffix:find(":", 1, true);
            if colonPos then
                targetSuffix = targetSuffix:sub(colonPos + 1):gsub("^%s+", "");
            end
            if targetFull ~= "" and msg:find(targetFull, 1, true) then
                Logger:Debug("ShoutDetector", "匹配", string.format("匹配到喊话（含前缀）：%s -> %s", message, shout));
                return true;
            elseif targetSuffix ~= "" and msg:find(targetSuffix, 1, true) then
                Logger:Debug("ShoutDetector", "匹配", string.format("匹配到喊话（去前缀）：%s -> %s", message, shout));
                return true;
            end
        end
    end
    return false;
end

local function OnChatEvent(self, event, message)
    if Logger then
        Logger:Debug("ShoutDetector", "事件", string.format("收到聊天事件：%s，消息=%s", tostring(event), tostring(message)));
    end
    if not MessageMatchesShout(message) then
        if Logger then
            Logger:Debug("ShoutDetector", "未匹配", string.format("未匹配喊话：事件=%s，消息=%s", tostring(event), tostring(message)));
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

    self.eventFrame = CreateFrame("Frame");
    self.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY");
    self.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL");
    self.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE");
    self.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_PARTY");
    self.eventFrame:RegisterEvent("CHAT_MSG_MONSTER_WHISPER");
    self.eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE");
    self.eventFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER");
    self.eventFrame:SetScript("OnEvent", function(_, event, message)
        OnChatEvent(_, event, message);
    end);

    self.isInitialized = true;
    Logger:Debug("ShoutDetector", "初始化", "NPC喊話檢測已啟用");
end

return ShoutDetector;
