-- UnifiedDataManagerExtensions.lua - 清理与格式化职责拆分

local UnifiedDataManager = BuildEnv("UnifiedDataManager");
local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local TimeFormatter = BuildEnv("TimeFormatter");
local L = CrateTrackerZK and CrateTrackerZK.L or {};
local Data = BuildEnv("Data");
local Logger = BuildEnv("Logger");
local StateBuckets = BuildEnv("StateBuckets");
local PublicChannelSyncStore = BuildEnv("PublicChannelSyncStore");
local PublicChannelSyncListener = BuildEnv("PublicChannelSyncListener");

local function IsPublicChannelSyncFeatureEnabled()
    return PublicChannelSyncListener
        and PublicChannelSyncListener.IsFeatureEnabled
        and PublicChannelSyncListener:IsFeatureEnabled() == true;
end

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

    local now = Utils:GetCurrentTimestamp();
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

end

function UnifiedDataManager:ClearExpiredTemporaryPhases()
    if not self.isInitialized then
        return;
    end

    local now = Utils:GetCurrentTimestamp();
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

end

function UnifiedDataManager:RestoreTemporaryPhaseCache()
    local phaseCache = GetPhaseCacheStore();
    if type(phaseCache) ~= "table" then
        return;
    end
    local now = Utils:GetCurrentTimestamp();
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
                mapData.currentPhaseID = record.phaseId;
            end
        end
    end
end

function UnifiedDataManager:ClearExpiredTemporaryData()
    self:ClearExpiredTemporaryTimes();
    self:ClearExpiredTemporaryPhases();
    if IsPublicChannelSyncFeatureEnabled()
        and PublicChannelSyncStore
        and PublicChannelSyncStore.ClearExpiredRecords then
        PublicChannelSyncStore:ClearExpiredRecords(Utils:GetCurrentTimestamp());
    end
end

local function GetSharedDisplayState(self, mapId)
    self.sharedDisplayStateByMap = self.sharedDisplayStateByMap or {};
    self.sharedDisplayStateByMap[mapId] = self.sharedDisplayStateByMap[mapId] or {};
    return self.sharedDisplayStateByMap[mapId];
end

function UnifiedDataManager:MarkSharedDisplayPhaseTransition(mapId, previousPhaseId, currentPhaseId, changedAt)
    if IsPublicChannelSyncFeatureEnabled() ~= true then
        return;
    end
    if type(mapId) ~= "number" then
        return;
    end

    local state = GetSharedDisplayState(self, mapId);
    state.phaseTransitionEligible = false;
    state.pendingPhaseId = nil;
    state.activeRecordKey = nil;

    if type(previousPhaseId) ~= "string" or previousPhaseId == "" then
        return;
    end
    if type(currentPhaseId) ~= "string" or currentPhaseId == "" then
        return;
    end
    if previousPhaseId == currentPhaseId then
        return;
    end

    state.phaseChangedAt = changedAt or Utils:GetCurrentTimestamp();
    state.phaseTransitionEligible = true;
    state.pendingPhaseId = currentPhaseId;
end

function UnifiedDataManager:CanUseSharedDisplayForPhase(mapId, phaseId)
    if IsPublicChannelSyncFeatureEnabled() ~= true then
        return false;
    end
    if type(mapId) ~= "number"
        or type(phaseId) ~= "string"
        or phaseId == ""
        or type(self.sharedDisplayStateByMap) ~= "table" then
        return false;
    end

    local state = self.sharedDisplayStateByMap[mapId];
    return type(state) == "table"
        and state.phaseTransitionEligible == true
        and state.pendingPhaseId == phaseId;
end

function UnifiedDataManager:ClearSharedDisplayPhaseGate(mapId)
    if type(mapId) ~= "number" or type(self.sharedDisplayStateByMap) ~= "table" then
        return;
    end

    local state = self.sharedDisplayStateByMap[mapId];
    if type(state) ~= "table" then
        return;
    end

    state.phaseTransitionEligible = false;
    state.pendingPhaseId = nil;
    state.activeRecordKey = nil;
end

function UnifiedDataManager:GetSharedPhaseTimeRecordInto(mapId, phaseId, outRecord)
    if IsPublicChannelSyncFeatureEnabled() ~= true then
        return nil;
    end
    if not self.isInitialized or type(phaseId) ~= "string" or phaseId == "" or type(outRecord) ~= "table" then
        return nil;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    if not mapData or type(mapData.expansionID) ~= "string" or type(mapData.mapID) ~= "number" then
        return nil;
    end

    if PublicChannelSyncStore and PublicChannelSyncStore.GetRecordInto then
        return PublicChannelSyncStore:GetRecordInto(
            mapData.expansionID,
            mapData.mapID,
            phaseId,
            outRecord,
            Utils:GetCurrentTimestamp()
        );
    end

    return nil;
end

function UnifiedDataManager:OnSharedDisplayActivated(mapId, phaseId, sharedRecord)
    if IsPublicChannelSyncFeatureEnabled() ~= true then
        return;
    end
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" or type(sharedRecord.recordKey) ~= "string" then
        return;
    end

    local state = GetSharedDisplayState(self, mapId);
    if state.activeRecordKey == sharedRecord.recordKey then
        return;
    end

    state.activeRecordKey = sharedRecord.recordKey;
    if state.lastNotifiedRecordKey == sharedRecord.recordKey then
        return;
    end

    state.lastNotifiedRecordKey = sharedRecord.recordKey;

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId);
    local message = string.format(
        (L and L["SharedPhaseSyncApplied"]) or "Acquired the latest shared airdrop info for the current phase in [%s].",
        mapName
    );
    if Logger and Logger.Info then
        Logger:Info("Notification", "通知", message);
    end
end

function UnifiedDataManager:OnSharedDisplayReleased(mapId)
    if IsPublicChannelSyncFeatureEnabled() ~= true then
        return;
    end
    if type(mapId) ~= "number" or type(self.sharedDisplayStateByMap) ~= "table" then
        return;
    end

    local state = self.sharedDisplayStateByMap[mapId];
    if type(state) ~= "table" then
        return;
    end

    state.activeRecordKey = nil;
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
