-- UnifiedDataManagerExtensions.lua - 清理与格式化职责拆分

local UnifiedDataManager = BuildEnv("UnifiedDataManager");
local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local TimeFormatter = BuildEnv("TimeFormatter");
local L = CrateTrackerZK and CrateTrackerZK.L or {};
local Data = BuildEnv("Data");
local Logger = BuildEnv("Logger");
local StateBuckets = BuildEnv("StateBuckets");

local function GetPhaseCacheStore()
    if StateBuckets and StateBuckets.GetPhaseCache then
        return StateBuckets:GetPhaseCache();
    end
    if Data and Data.GetPhaseCache then
        return Data:GetPhaseCache();
    end
    return {};
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

        if not timeData.temporaryTime then
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
        local expansionID = record and record.expansionID or nil;
        if not expansionID and PhaseStateStore and PhaseStateStore.ParseScopedKey then
            expansionID = select(1, PhaseStateStore:ParseScopedKey(scopedKey));
        end
        local mapData = Data and Data.GetMap and mapId and Data:GetMap(mapId) or nil;
        if mapData and record and record.phaseId and record.detectTime then
            if now - record.detectTime <= self.TEMPORARY_PHASE_EXPIRE then
                local phaseData = self:GetOrCreatePhaseData(mapId, true, expansionID);
                phaseData.phaseId = record.phaseId;
                phaseData.source = self.PhaseSource.PHASE_DETECTION;
                phaseData.detectTime = record.detectTime;
            end
        end
    end
end

function UnifiedDataManager:ClearExpiredTemporaryData()
    self:ClearExpiredTemporaryTimes();
    self:ClearExpiredTemporaryPhases();
end

function UnifiedDataManager:FormatTime(seconds, showOnlyMinutes)
    if TimeFormatter and TimeFormatter.FormatTime then
        return TimeFormatter:FormatTime(seconds, showOnlyMinutes, L);
    end
    return L["NoRecord"] or "--:--";
end

function UnifiedDataManager:FormatDateTime(timestamp)
    if TimeFormatter and TimeFormatter.FormatDateTime then
        return TimeFormatter:FormatDateTime(timestamp, L);
    end
    return L["NoRecord"] or "无";
end

function UnifiedDataManager:FormatTimeForDisplay(timestamp)
    if TimeFormatter and TimeFormatter.FormatTimeForDisplay then
        return TimeFormatter:FormatTimeForDisplay(timestamp);
    end
    return "--:--";
end

return UnifiedDataManager;
