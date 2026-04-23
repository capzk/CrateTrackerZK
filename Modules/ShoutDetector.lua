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
local AirdropTrajectoryService = BuildEnv("AirdropTrajectoryService")
local IconDetector = BuildEnv("IconDetector")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")

ShoutDetector.isInitialized = false;
ShoutDetector.compiledShouts = ShoutDetector.compiledShouts or {};
ShoutDetector.compiledLocale = ShoutDetector.compiledLocale or nil;
ShoutDetector.trajectoryShoutRetryTimers = ShoutDetector.trajectoryShoutRetryTimers or {};

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

local function CaptureTrajectoryShoutIcon(currentMapID, targetMapData)
    if not IconDetector
        or not IconDetector.DetectIconInto
        or type(targetMapData) ~= "table" then
        return nil;
    end

    ShoutDetector.trajectoryShoutIconBuffer = ShoutDetector.trajectoryShoutIconBuffer or {};
    local iconResult = IconDetector:DetectIconInto(currentMapID, targetMapData.mapID, ShoutDetector.trajectoryShoutIconBuffer);
    if type(iconResult) ~= "table" or iconResult.detected ~= true then
        return nil;
    end
    return iconResult;
end

local function CancelTrajectoryShoutRetry(mapRuntimeId)
    if type(mapRuntimeId) ~= "number" then
        return false;
    end

    local timer = ShoutDetector.trajectoryShoutRetryTimers and ShoutDetector.trajectoryShoutRetryTimers[mapRuntimeId] or nil;
    if timer and timer.Cancel then
        timer:Cancel();
    end
    if ShoutDetector.trajectoryShoutRetryTimers then
        ShoutDetector.trajectoryShoutRetryTimers[mapRuntimeId] = nil;
    end
    return true;
end

local function ScheduleTrajectoryShoutRetry(targetMapData)
    if type(targetMapData) ~= "table" or type(targetMapData.id) ~= "number" then
        return false;
    end
    if not C_Timer or not C_Timer.NewTimer then
        return false;
    end

    CancelTrajectoryShoutRetry(targetMapData.id);
    ShoutDetector.trajectoryShoutRetryTimers[targetMapData.id] = C_Timer.NewTimer(1.0, function()
        CancelTrajectoryShoutRetry(targetMapData.id);

        local retryTargetMapData, retryCurrentMapID = GetTrackedMap();
        if not retryTargetMapData
            or type(retryTargetMapData.id) ~= "number"
            or retryTargetMapData.id ~= targetMapData.id
            or IsMapHidden(retryTargetMapData) then
            return;
        end

        local retryIconResult = CaptureTrajectoryShoutIcon(retryCurrentMapID, retryTargetMapData);
        if retryIconResult
            and AirdropTrajectoryService
            and AirdropTrajectoryService.HandleAirdropShout then
            AirdropTrajectoryService:HandleAirdropShout(retryTargetMapData, Utils:GetCurrentTimestamp(), retryIconResult);
        end
    end);
    return true;
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
    local currentTime = Utils:GetCurrentTimestamp();
    if TimerManager and TimerManager.HandleMapContextChanged then
        local _, refreshedTargetMapData = TimerManager:HandleMapContextChanged(currentMapID, targetMapData, currentTime);
        targetMapData = refreshedTargetMapData or targetMapData;
    end
    if TimerManager and TimerManager.IsMapSwitchGuardActiveFor and TimerManager:IsMapSwitchGuardActiveFor(targetMapData, currentTime) then
        return;
    end
    if IsMapHidden(targetMapData) then
        return;
    end

    local mapName = Data:GetMapDisplayName(targetMapData);
    local mapNotificationKey = targetMapData.id;
    if Notification and Notification.RecordShout then
        Notification:RecordShout(mapNotificationKey);
    end
    -- 喊话触发视为新事件，清除通知去重，确保立即广播
    if Notification and Notification.ResetMapNotificationState then
        Notification:ResetMapNotificationState(mapNotificationKey);
    end
    -- 立即发送通知（遵循现有开关/频道规则）
    if Notification and Notification.NotifyAirdropDetected then
        Notification:NotifyAirdropDetected(mapName, "npc_shout", {
            mapKey = mapNotificationKey,
            eventTimestamp = currentTime,
        });
    end

    -- 写入临时时间并刷新界面（用于即时显示）
    if UnifiedDataManager and UnifiedDataManager.SetTime and UnifiedDataManager.TimeSource then
        local currentPhaseId = UnifiedDataManager.GetCurrentPhase and UnifiedDataManager:GetCurrentPhase(targetMapData.id) or nil;
        UnifiedDataManager:SetTime(targetMapData.id, currentTime, UnifiedDataManager.TimeSource.TEAM_MESSAGE, currentPhaseId);
    end
    local shoutIconResult = CaptureTrajectoryShoutIcon(currentMapID, targetMapData);
    if AirdropTrajectoryService and AirdropTrajectoryService.HandleAirdropShout then
        AirdropTrajectoryService:HandleAirdropShout(targetMapData, currentTime, shoutIconResult);
    end
    if shoutIconResult then
        CancelTrajectoryShoutRetry(targetMapData.id);
    else
        ScheduleTrajectoryShoutRetry(targetMapData);
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
