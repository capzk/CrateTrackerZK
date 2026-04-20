-- UnifiedDataManagerExtensions.lua - 清理与格式化职责拆分

local UnifiedDataManager = BuildEnv("UnifiedDataManager");
local CrateTrackerZK = BuildEnv("CrateTrackerZK");
local TimeFormatter = BuildEnv("TimeFormatter");
local L = CrateTrackerZK and CrateTrackerZK.L or {};
local Data = BuildEnv("Data");
local StateBuckets = BuildEnv("StateBuckets");
local TeamSharedSyncStore = BuildEnv("TeamSharedSyncStore");
local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener");
local Notification = BuildEnv("Notification");
local PhaseTeamAlertCoordinator = BuildEnv("PhaseTeamAlertCoordinator");
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator");

local function IsTeamSharedSyncFeatureEnabled()
    return TeamSharedSyncListener
        and TeamSharedSyncListener.IsFeatureEnabled
        and TeamSharedSyncListener:IsFeatureEnabled() == true;
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
    if IsTeamSharedSyncFeatureEnabled()
        and TeamSharedSyncStore
        and TeamSharedSyncStore.ClearExpiredRecords then
        TeamSharedSyncStore:ClearExpiredRecords(Utils:GetCurrentTimestamp());
    end
end

local function GetSharedDisplayState(self, mapId)
    self.sharedDisplayStateByMap = self.sharedDisplayStateByMap or {};
    self.sharedDisplayStateByMap[mapId] = self.sharedDisplayStateByMap[mapId] or {};
    return self.sharedDisplayStateByMap[mapId];
end

function UnifiedDataManager:MarkSharedDisplayPhaseTransition(mapId, previousPhaseId, currentPhaseId, changedAt)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
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
    if IsTeamSharedSyncFeatureEnabled() ~= true then
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

function UnifiedDataManager:IsSharedDisplayActive(mapId)
    if type(mapId) ~= "number" or type(self.sharedDisplayStateByMap) ~= "table" then
        return false;
    end

    local state = self.sharedDisplayStateByMap[mapId];
    return type(state) == "table"
        and type(state.activeRecordKey) == "string"
        and state.activeRecordKey ~= "";
end

function UnifiedDataManager:GetSharedPhaseTimeRecordInto(mapId, phaseId, outRecord)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
        return nil;
    end
    if not self.isInitialized or type(phaseId) ~= "string" or phaseId == "" or type(outRecord) ~= "table" then
        return nil;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    if not mapData or type(mapData.expansionID) ~= "string" or type(mapData.mapID) ~= "number" then
        return nil;
    end

    if TeamSharedSyncStore and TeamSharedSyncStore.GetRecordInto then
        return TeamSharedSyncStore:GetRecordInto(
            mapData.expansionID,
            mapData.mapID,
            phaseId,
            outRecord,
            Utils:GetCurrentTimestamp()
        );
    end

    return nil;
end

function UnifiedDataManager:GetLatestSharedPhaseRecordForMapInto(mapId, outRecord)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
        return nil;
    end
    if not self.isInitialized or type(mapId) ~= "number" or type(outRecord) ~= "table" then
        return nil;
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil;
    if not mapData or type(mapData.expansionID) ~= "string" or type(mapData.mapID) ~= "number" then
        return nil;
    end

    if TeamSharedSyncStore and TeamSharedSyncStore.GetLatestRecordForMapInto then
        return TeamSharedSyncStore:GetLatestRecordForMapInto(
            mapData.expansionID,
            mapData.mapID,
            outRecord,
            Utils:GetCurrentTimestamp()
        );
    end

    return nil;
end

function UnifiedDataManager:ShouldSuppressPhaseTeamAlert(mapId, currentPhaseId, buffers)
    if not self.isInitialized then
        return false, nil;
    end
    if type(mapId) ~= "number" or type(currentPhaseId) ~= "string" or currentPhaseId == "" then
        return false, nil;
    end

    local persistentPhaseId = self.GetPersistentPhase and self:GetPersistentPhase(mapId) or nil;
    if type(persistentPhaseId) == "string" and persistentPhaseId ~= "" and persistentPhaseId == currentPhaseId then
        return true, "persistent_airdrop_phase_match";
    end

    local bufferState = type(buffers) == "table" and buffers or {};
    bufferState.sharedRecordBuffer = bufferState.sharedRecordBuffer or {};
    local latestSharedRecord = self.GetLatestSharedPhaseRecordForMapInto
        and self:GetLatestSharedPhaseRecordForMapInto(mapId, bufferState.sharedRecordBuffer)
        or nil;
    if latestSharedRecord
        and type(latestSharedRecord.phaseID) == "string"
        and latestSharedRecord.phaseID ~= ""
        and latestSharedRecord.phaseID == currentPhaseId then
        return true, "shared_airdrop_phase_match";
    end

    return false, nil;
end

function UnifiedDataManager:NotifySharedDisplayApplied(mapId, sharedRecord)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
        return false;
    end
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" or type(sharedRecord.recordKey) ~= "string" then
        return false;
    end

    local state = GetSharedDisplayState(self, mapId);
    local isFirstNotifyForRecord = state.lastNotifiedRecordKey ~= sharedRecord.recordKey;
    if isFirstNotifyForRecord then
        state.lastNotifiedRecordKey = sharedRecord.recordKey;
    end

    if PhaseTeamAlertCoordinator and PhaseTeamAlertCoordinator.HandleSharedDisplayActivated then
        PhaseTeamAlertCoordinator:HandleSharedDisplayActivated(mapId, sharedRecord);
    end
    if isFirstNotifyForRecord and Notification and Notification.NotifySharedPhaseSyncApplied then
        Notification:NotifySharedPhaseSyncApplied(mapId, sharedRecord);
    end
    if UIRefreshCoordinator and UIRefreshCoordinator.RequestRowRefresh then
        UIRefreshCoordinator:RequestRowRefresh(mapId, {
            affectsSort = true,
            force = true,
            delay = 0,
        });
    elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
        UIRefreshCoordinator:RefreshMainTable(true);
    end
    return isFirstNotifyForRecord == true;
end

function UnifiedDataManager:OnSharedDisplayActivated(mapId, phaseId, sharedRecord)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
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
    if self.SetTemporaryTime
        and type(sharedRecord.timestamp) == "number" then
        self:SetTemporaryTime(
            mapId,
            sharedRecord.timestamp,
            self.TimeSource.PUBLIC_CHANNEL_SYNC,
            type(phaseId) == "string" and phaseId ~= "" and phaseId or sharedRecord.phaseID
        );
    end
    self:NotifySharedDisplayApplied(mapId, sharedRecord);
end

function UnifiedDataManager:OnSharedDisplayReleased(mapId)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
        return;
    end
    if type(mapId) ~= "number" or type(self.sharedDisplayStateByMap) ~= "table" then
        return;
    end

    local state = self.sharedDisplayStateByMap[mapId];
    if type(state) ~= "table" then
        return;
    end

    local previousActiveRecordKey = state.activeRecordKey;
    state.activeRecordKey = nil;
    if type(previousActiveRecordKey) == "string" and previousActiveRecordKey ~= "" then
        if UIRefreshCoordinator and UIRefreshCoordinator.RequestRowRefresh then
            UIRefreshCoordinator:RequestRowRefresh(mapId, {
                affectsSort = true,
                force = true,
                delay = 0,
            });
        elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
            UIRefreshCoordinator:RefreshMainTable(true);
        end
    end
end

function UnifiedDataManager:RefreshSharedDisplayActivation(mapId, currentTime)
    if IsTeamSharedSyncFeatureEnabled() ~= true then
        return false;
    end
    if not self.isInitialized or type(mapId) ~= "number" then
        return false;
    end

    local sharedState = GetSharedDisplayState(self, mapId);
    local previousActiveRecordKey = type(sharedState) == "table" and sharedState.activeRecordKey or nil;

    self.sharedDisplayActivationProbeByMap = self.sharedDisplayActivationProbeByMap or {};
    local probe = self.sharedDisplayActivationProbeByMap[mapId] or {};
    self.sharedDisplayActivationProbeByMap[mapId] = probe;
    probe.displayTimeBuffer = probe.displayTimeBuffer or {};
    probe.persistentRecordBuffer = probe.persistentRecordBuffer or {};

    local displayTime = self:GetDisplayTimeInto(
        mapId,
        currentTime or Utils:GetCurrentTimestamp(),
        probe.displayTimeBuffer,
        probe.persistentRecordBuffer
    );
    local currentActiveRecordKey = type(sharedState) == "table" and sharedState.activeRecordKey or nil;
    return type(displayTime) == "table"
        and displayTime.source == self.TimeSource.PUBLIC_CHANNEL_SYNC
        and currentActiveRecordKey ~= previousActiveRecordKey;
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
