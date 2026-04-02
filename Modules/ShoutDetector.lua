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
if not UnifiedDataManager then UnifiedDataManager = BuildEnv("UnifiedDataManager") end
if not TimerManager then TimerManager = BuildEnv("TimerManager") end
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")

ShoutDetector.isInitialized = false;
ShoutDetector.compiledShouts = ShoutDetector.compiledShouts or {};
ShoutDetector.compiledLocale = ShoutDetector.compiledLocale or nil;

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
    if not targetMapData then
        return false;
    end
    if Data and Data.IsMapHidden then
        return Data:IsMapHidden(targetMapData.expansionID, targetMapData.mapID);
    end
    return false;
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
    local currentTime = time();
    if Notification and Notification.RecordShout then
        Notification:RecordShout(mapName);
    end
    -- 喊话触发视为新事件，清除通知去重，确保立即广播
    if Notification and Notification.ResetMapNotificationState then
        Notification:ResetMapNotificationState(mapName);
    elseif Notification then
        Notification.firstNotificationTime = Notification.firstNotificationTime or {};
        Notification.playerSentNotification = Notification.playerSentNotification or {};
        Notification.firstNotificationTime[mapName] = nil;
        Notification.playerSentNotification[mapName] = nil;
    end
    -- 立即发送通知（遵循现有开关/频道规则）
    if Notification and Notification.NotifyAirdropDetected then
        Notification:NotifyAirdropDetected(mapName, "npc_shout");
    end

    -- 写入临时时间并刷新界面（用于即时显示）
    local syncWritten = false;
    if UnifiedDataManager and UnifiedDataManager.SetTime and UnifiedDataManager.TimeSource then
        syncWritten = UnifiedDataManager:SetTime(targetMapData.id, currentTime, UnifiedDataManager.TimeSource.TEAM_MESSAGE) == true;
    end
    if syncWritten and Notification and Notification.SendAirdropSync then
        Notification:SendAirdropSync({
            syncType = "TEMP",
            mapId = targetMapData.id,
            timestamp = currentTime,
        });
    end
    if UIRefreshCoordinator and UIRefreshCoordinator.RequestRowRefresh then
        UIRefreshCoordinator:RequestRowRefresh(targetMapData.id, {
            affectsSort = true,
            delay = 0.08,
        });
    elseif TimerManager and TimerManager.UpdateUI then
        TimerManager:UpdateUI();
    elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable();
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

local function BuildShoutMatchers()
    ShoutDetector.compiledShouts = {};
    ShoutDetector.compiledLocale = GetLocale and GetLocale() or nil;

    if not Localization or not Localization.GetAirdropShouts then
        return 0;
    end
    local shouts = Localization:GetAirdropShouts();
    if not shouts or #shouts == 0 then
        return 0;
    end

    for _, shout in ipairs(shouts) do
        if type(shout) == "string" and shout ~= "" then
            local rawSuffix = shout:match("^[^:：]*[:：]%s*(.*)$");
            local targetFull = SafeNormalizeForMatch(shout);
            local targetSuffix = rawSuffix and SafeNormalizeForMatch(rawSuffix) or targetFull;
            if (targetFull and targetFull ~= "") or (targetSuffix and targetSuffix ~= "") then
                table.insert(ShoutDetector.compiledShouts, {
                    original = shout,
                    full = targetFull,
                    suffix = targetSuffix
                });
            end
        end
    end

    return #ShoutDetector.compiledShouts;
end

local function MessageMatchesShout(message)
    if not message or type(message) ~= "string" then
        return false;
    end
    local currentLocale = GetLocale and GetLocale() or nil;
    if not ShoutDetector.compiledShouts or #ShoutDetector.compiledShouts == 0 or ShoutDetector.compiledLocale ~= currentLocale then
        if BuildShoutMatchers() == 0 then
            return false;
        end
    end

    local msg = SafeNormalizeForMatch(message);
    if not msg then
        return false;
    end

    for _, entry in ipairs(ShoutDetector.compiledShouts) do
        if entry.full and entry.full ~= "" and msg:find(entry.full, 1, true) then
            return true;
        end
        if entry.suffix and entry.suffix ~= "" and msg:find(entry.suffix, 1, true) then
            return true;
        end
    end

    return false;
end

local function OnChatEvent(self, event, message)
    if not MessageMatchesShout(message) then
        return;
    end
    OnShoutDetected(message);
end

function ShoutDetector:Initialize()
    if self.isInitialized then return end

    local compiledCount = BuildShoutMatchers();
    if compiledCount == 0 then
        return;
    end

    self.isInitialized = true;
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
