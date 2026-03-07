-- UnifiedDataManagerExtensions.lua - 清理与格式化职责拆分

local UnifiedDataManager = BuildEnv("UnifiedDataManager");
local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local L = CrateTrackerZK and CrateTrackerZK.L or {};
local ExpansionConfig = BuildEnv("ExpansionConfig");
local Data = BuildEnv("Data");
local Logger = BuildEnv("Logger");

local function GetCurrentExpansionID()
    if Data and Data.GetCurrentExpansionID then
        local id = Data:GetCurrentExpansionID();
        if id then
            return id;
        end
    end
    if ExpansionConfig and ExpansionConfig.GetCurrentExpansionID then
        local id = ExpansionConfig:GetCurrentExpansionID();
        if id then
            return id;
        end
    end
    return "default";
end

local function GetPhaseCacheStore()
    if Data and Data.GetPhaseCache then
        return Data:GetPhaseCache();
    end
    if type(CRATETRACKERZK_UI_DB) ~= "table" then
        CRATETRACKERZK_UI_DB = {};
    end
    if type(CRATETRACKERZK_UI_DB.expansionUIData) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData = {};
    end
    local expansionID = GetCurrentExpansionID();
    if type(CRATETRACKERZK_UI_DB.expansionUIData[expansionID]) ~= "table" then
        CRATETRACKERZK_UI_DB.expansionUIData[expansionID] = {};
    end
    local bucket = CRATETRACKERZK_UI_DB.expansionUIData[expansionID];
    if type(bucket.phaseCache) ~= "table" then
        bucket.phaseCache = {};
    end
    return bucket.phaseCache;
end

function UnifiedDataManager:ClearExpiredTemporaryTimes()
    if not self.isInitialized then
        return;
    end

    local now = time();
    local expiredCount = 0;

    for scopedKey, timeData in pairs(self.temporaryTimes) do
        if timeData.temporaryTime then
            if now - timeData.temporaryTime.setTime > self.TEMPORARY_TIME_EXPIRE then
                timeData.temporaryTime = nil;
                expiredCount = expiredCount + 1;
            end
        end

        if not timeData.temporaryTime and not timeData.persistentTime then
            self.temporaryTimes[scopedKey] = nil;
        end
    end

    if expiredCount > 0 then
        Logger:Debug("UnifiedDataManager", "清理", string.format("清理了%d个过期的临时时间数据", expiredCount));
    end
end

function UnifiedDataManager:ClearExpiredTemporaryPhases()
    if not self.isInitialized then
        return;
    end

    local now = time();
    local expiredCount = 0;
    local phaseCache = GetPhaseCacheStore();

    for scopedKey, phaseData in pairs(self.temporaryPhases) do
        if phaseData.phaseId and phaseData.detectTime then
            if now - phaseData.detectTime > self.TEMPORARY_PHASE_EXPIRE then
                phaseData.phaseId = nil;
                phaseData.source = nil;
                phaseData.detectTime = nil;
                expiredCount = expiredCount + 1;
                phaseCache[scopedKey] = nil;
            end
        end

        if not phaseData.phaseId then
            self.temporaryPhases[scopedKey] = nil;
        end
    end

    if expiredCount > 0 then
        Logger:Debug("UnifiedDataManager", "清理", string.format("清理了%d个过期的临时位面数据", expiredCount));
    end
end

function UnifiedDataManager:RestoreTemporaryPhaseCache()
    local phaseCache = GetPhaseCacheStore();
    if type(phaseCache) ~= "table" then
        return;
    end
    local now = time();
    for scopedKey, record in pairs(phaseCache) do
        local mapId = tonumber(record and record.mapId) or tonumber(tostring(scopedKey):match(":(%d+)$")) or tonumber(scopedKey);
        if mapId and record and record.phaseId and record.detectTime then
            if now - record.detectTime <= self.TEMPORARY_PHASE_EXPIRE then
                local phaseData = self:GetOrCreatePhaseData(mapId, true);
                phaseData.phaseId = record.phaseId;
                phaseData.source = self.PhaseSource.PHASE_DETECTION;
                phaseData.detectTime = record.detectTime;
                if Data and Data.GetMap then
                    local mapData = Data:GetMap(mapId);
                    if mapData then
                        mapData.currentPhaseID = record.phaseId;
                    end
                end
            end
        end
    end
end

function UnifiedDataManager:ClearExpiredTemporaryData()
    self:ClearExpiredTemporaryTimes();
    self:ClearExpiredTemporaryPhases();
end

function UnifiedDataManager:FormatTime(seconds, showOnlyMinutes)
    if not seconds then
        return L["NoRecord"] or "--:--";
    end
    if seconds < 0 then
        return L["NoRecord"] or "--:--";
    end
    if seconds == 0 then
        return "00:00";
    end

    local hours = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    local secs = seconds % 60;

    if showOnlyMinutes then
        local formatStr = L["MinuteSecond"] or "%d:%02d";
        return string.format(formatStr, minutes + hours * 60, secs);
    end
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs);
    end
    return string.format("%02d:%02d", minutes, secs);
end

function UnifiedDataManager:FormatDateTime(timestamp)
    if not timestamp then
        return L["NoRecord"] or "无";
    end
    return date("%H:%M:%S", timestamp);
end

function UnifiedDataManager:FormatTimeForDisplay(timestamp)
    if not timestamp then
        return "--:--";
    end
    local t = date("*t", timestamp);
    return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec);
end

return UnifiedDataManager;
