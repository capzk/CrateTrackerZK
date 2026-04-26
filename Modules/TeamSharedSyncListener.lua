-- TeamSharedSyncListener.lua - 团队共享缓存同步监听与发送
-- 注意：团队隐藏同步仍是唯一可靠同步来源。
-- 本模块只负责 best-effort 的运行时缓存补充信息，用于当前位面的临时显示回退。

local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")

local HiddenSyncAuditService = BuildEnv("HiddenSyncAuditService")
local HiddenSyncTransport = BuildEnv("HiddenSyncTransport")
local IconDetector = BuildEnv("IconDetector")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local TeamSharedSyncProtocol = BuildEnv("TeamSharedSyncProtocol")
local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local TeamSharedSyncStore = BuildEnv("TeamSharedSyncStore")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Data = BuildEnv("Data")
local TeamSharedWarmupService = BuildEnv("TeamSharedWarmupService")
local AirdropTrajectorySyncService = BuildEnv("AirdropTrajectorySyncService")
local AirdropTrajectoryAlertCoordinator = BuildEnv("AirdropTrajectoryAlertCoordinator")

TeamSharedSyncListener.isInitialized = false
TeamSharedSyncListener.FEATURE_ENABLED = true
TeamSharedSyncListener.syncStateBuffer = TeamSharedSyncListener.syncStateBuffer or {}
TeamSharedSyncListener.channelContextBuffer = TeamSharedSyncListener.channelContextBuffer or {}
TeamSharedSyncListener.ADDON_PREFIX = TeamSharedSyncProtocol and TeamSharedSyncProtocol.ADDON_PREFIX or "CTKZK_PSYNC"
TeamSharedSyncListener.CONTROL_ADDON_PREFIX = TeamSharedSyncListener.ADDON_PREFIX
TeamSharedSyncListener.ROUTE_ADDON_PREFIX = TeamSharedSyncProtocol and TeamSharedSyncProtocol.ROUTE_ADDON_PREFIX or "CTKZK_PTRJ"

function TeamSharedSyncListener:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function TeamSharedSyncListener:GetAddonPrefixes()
    self.addonPrefixesBuffer = self.addonPrefixesBuffer or {}
    local prefixes = self.addonPrefixesBuffer
    prefixes[1] = self.CONTROL_ADDON_PREFIX
    prefixes[2] = self.ROUTE_ADDON_PREFIX
    for index = 3, #prefixes do
        prefixes[index] = nil
    end
    return prefixes
end

function TeamSharedSyncListener:RegisterAddonPrefix()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not HiddenSyncTransport or not HiddenSyncTransport.EnsureAddonPrefix then
        return false
    end

    local controlReady = HiddenSyncTransport:EnsureAddonPrefix(self, self.CONTROL_ADDON_PREFIX) == true
    local routeReady = HiddenSyncTransport:EnsureAddonPrefix(self, self.ROUTE_ADDON_PREFIX) == true
    self.addonPrefixRegistered = controlReady == true and routeReady == true
    return self.addonPrefixRegistered == true
end

local function ResolveAuditNoteForSend(sent, resultCode)
    if sent == true then
        return nil
    end
    return resultCode
end

local function SendSyncPayload(listener, syncState)
    if type(syncState) ~= "table" or type(syncState.phaseID) ~= "string" or syncState.phaseID == "" then
        return false
    end
    if listener:EnsureTeamSharedChannelAvailable() ~= true then
        return false
    end

    local payload = TeamSharedSyncProtocol and TeamSharedSyncProtocol.BuildPayload and TeamSharedSyncProtocol:BuildPayload(syncState) or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent, resultCode = false, nil
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload then
        sent, resultCode = TeamSharedSyncChannelService:SendPayload(listener.CONTROL_ADDON_PREFIX, payload)
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = listener.CONTROL_ADDON_PREFIX,
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = listener.CONTROL_ADDON_PREFIX,
            messageType = TeamSharedSyncProtocol and TeamSharedSyncProtocol.MESSAGE_TYPE or "PHASE_AIRDROP",
            expansionID = syncState.expansionID,
            mapID = syncState.mapID,
            phaseID = syncState.phaseID,
            objectGUID = syncState.objectGUID,
            payload = payload,
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
        })
    end
    return sent
end

local function SendTrajectoryPayload(listener, routeState)
    if type(routeState) ~= "table" or type(routeState.mapID) ~= "number" then
        return false
    end
    if listener:EnsureTeamSharedChannelAvailable() ~= true then
        return false
    end

    local payload = TeamSharedSyncProtocol
        and TeamSharedSyncProtocol.BuildTrajectoryPayload
        and TeamSharedSyncProtocol:BuildTrajectoryPayload(routeState)
        or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent, resultCode = false, nil
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload then
        sent, resultCode = TeamSharedSyncChannelService:SendPayload(listener.ROUTE_ADDON_PREFIX, payload)
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = listener.ROUTE_ADDON_PREFIX,
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = listener.ROUTE_ADDON_PREFIX,
            messageType = TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_MESSAGE_TYPE or "TRAJECTORY_ROUTE",
            mapID = routeState.mapID,
            routeKey = routeState.routeKey,
            routeFamilyKey = routeState.routeFamilyKey,
            landingKey = routeState.landingKey,
            alertToken = routeState.alertToken,
            sampleCount = routeState.sampleCount,
            observationCount = routeState.observationCount,
            verificationCount = routeState.verificationCount,
            verifiedPredictionCount = routeState.verifiedPredictionCount,
            confidenceScore = routeState.confidenceScore,
            payload = payload,
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
        })
    end
    return sent, resultCode
end

function TeamSharedSyncListener:CanSendSharedSync()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    return TeamSharedSyncChannelService
        and TeamSharedSyncChannelService.CanUseTeamChannel
        and TeamSharedSyncChannelService:CanUseTeamChannel() == true
        or false
end

function TeamSharedSyncListener:CanReceiveSharedSync()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not TeamSharedSyncChannelService or not TeamSharedSyncChannelService.CanUseTeamChannel then
        return false
    end
    return TeamSharedSyncChannelService:CanUseTeamChannel() == true
end

function TeamSharedSyncListener:Initialize()
    if self:IsFeatureEnabled() ~= true then
        self.isInitialized = false
        return false
    end
    if TeamCommMapCache and TeamCommMapCache.EnsurePlayerIdentity then
        TeamCommMapCache:EnsurePlayerIdentity(self)
    end
    if TeamSharedSyncStore and TeamSharedSyncStore.Initialize then
        TeamSharedSyncStore:Initialize()
    end
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.Initialize then
        TeamSharedSyncChannelService:Initialize()
    end
    self:RegisterAddonPrefix()
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.EnsureTeamChannelReady then
        TeamSharedSyncChannelService:EnsureTeamChannelReady()
    end
    self.isInitialized = true
    return true
end

function TeamSharedSyncListener:EnsureTeamSharedChannelAvailable(force)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end
    self:RegisterAddonPrefix()
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.EnsureTeamChannelReady then
        return TeamSharedSyncChannelService:EnsureTeamChannelReady(force == true)
    end
    return false
end

function TeamSharedSyncListener:SendSharedSync(syncState)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self:CanSendSharedSync() ~= true then
        return false
    end
    return SendSyncPayload(self, syncState)
end

function TeamSharedSyncListener:SendSyncRequest(requestState)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self:CanSendSharedSync() ~= true then
        return false
    end
    if self:EnsureTeamSharedChannelAvailable() ~= true then
        return false
    end

    local payload = TeamSharedSyncProtocol and TeamSharedSyncProtocol.BuildRequestPayload
        and TeamSharedSyncProtocol:BuildRequestPayload(requestState)
        or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent, resultCode = false, nil
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload then
        sent, resultCode = TeamSharedSyncChannelService:SendPayload(self.CONTROL_ADDON_PREFIX, payload)
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = self.CONTROL_ADDON_PREFIX,
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.CONTROL_ADDON_PREFIX,
            messageType = TeamSharedSyncProtocol and TeamSharedSyncProtocol.REQUEST_MESSAGE_TYPE or "SYNC_REQUEST",
            requestID = requestState and requestState.requestID or nil,
            payload = payload,
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
        })
    end
    return sent
end

function TeamSharedSyncListener:SendTrajectoryRoute(routeState)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self:CanSendSharedSync() ~= true then
        return false
    end
    return SendTrajectoryPayload(self, routeState)
end

function TeamSharedSyncListener:SendTrajectorySyncRequest(requestState)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self:CanSendSharedSync() ~= true then
        return false
    end
    if self:EnsureTeamSharedChannelAvailable() ~= true then
        return false
    end

    local payload = TeamSharedSyncProtocol
        and TeamSharedSyncProtocol.BuildTrajectoryRequestPayload
        and TeamSharedSyncProtocol:BuildTrajectoryRequestPayload(requestState)
        or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent, resultCode = false, nil
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload then
        sent, resultCode = TeamSharedSyncChannelService:SendPayload(self.CONTROL_ADDON_PREFIX, payload)
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = self.CONTROL_ADDON_PREFIX,
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.CONTROL_ADDON_PREFIX,
            messageType = TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_REQUEST_MESSAGE_TYPE or "TRAJECTORY_REQUEST",
            requestID = requestState and requestState.requestID or nil,
            payload = payload,
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
        })
    end
    return sent
end

function TeamSharedSyncListener:SendTrajectoryAlertClaim(syncState)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self:CanSendSharedSync() ~= true then
        return false
    end
    if self:EnsureTeamSharedChannelAvailable() ~= true then
        return false
    end

    local payload = TeamSharedSyncProtocol
        and TeamSharedSyncProtocol.BuildTrajectoryAlertPayload
        and TeamSharedSyncProtocol:BuildTrajectoryAlertPayload(syncState, TeamSharedSyncProtocol.TRAJECTORY_ALERT_CLAIM_MESSAGE_TYPE)
        or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent, resultCode = false, nil
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload then
        sent, resultCode = TeamSharedSyncChannelService:SendPayload(self.CONTROL_ADDON_PREFIX, payload)
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = self.CONTROL_ADDON_PREFIX,
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.CONTROL_ADDON_PREFIX,
            messageType = TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_ALERT_CLAIM_MESSAGE_TYPE or "TRAJECTORY_ALERT_CLAIM",
            mapID = syncState and syncState.mapID or nil,
            alertToken = syncState and syncState.alertToken or nil,
            objectGUID = syncState and syncState.objectGUID or nil,
            payload = payload,
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
        })
    end
    return sent
end

function TeamSharedSyncListener:SendTrajectoryAlertAck(syncState)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self:CanSendSharedSync() ~= true then
        return false
    end
    if self:EnsureTeamSharedChannelAvailable() ~= true then
        return false
    end

    local payload = TeamSharedSyncProtocol
        and TeamSharedSyncProtocol.BuildTrajectoryAlertPayload
        and TeamSharedSyncProtocol:BuildTrajectoryAlertPayload(syncState, TeamSharedSyncProtocol.TRAJECTORY_ALERT_ACK_MESSAGE_TYPE)
        or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local sent, resultCode = false, nil
    if TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload then
        sent, resultCode = TeamSharedSyncChannelService:SendPayload(self.CONTROL_ADDON_PREFIX, payload)
    end
    if HiddenSyncAuditService and HiddenSyncAuditService.Record then
        HiddenSyncAuditService:Record({
            protocol = self.CONTROL_ADDON_PREFIX,
            direction = "send",
            status = sent == true and "sent" or "failed",
            prefix = self.CONTROL_ADDON_PREFIX,
            messageType = TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_ALERT_ACK_MESSAGE_TYPE or "TRAJECTORY_ALERT_ACK",
            mapID = syncState and syncState.mapID or nil,
            alertToken = syncState and syncState.alertToken or nil,
            objectGUID = syncState and syncState.objectGUID or nil,
            payload = payload,
            resultCode = resultCode,
            note = ResolveAuditNoteForSend(sent, resultCode),
        })
    end
    return sent
end

local function ResolveCurrentChannelContext(outContext, ...)
    outContext = type(outContext) == "table" and outContext or {}
    outContext.target = select(1, ...)
    outContext.zoneChannelID = select(2, ...)
    outContext.localChannelID = select(3, ...)
    outContext.channelName = select(4, ...)
    return outContext
end

local function ExtractPhaseIDFromObjectGUID(objectGUID)
    if IconDetector and IconDetector.ExtractPhaseID then
        return IconDetector.ExtractPhaseID(objectGUID)
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return nil
    end

    local _, _, serverID, _, zoneUID = strsplit("-", objectGUID)
    if serverID and zoneUID then
        return serverID .. "-" .. zoneUID
    end

    return nil
end

local function IsSharedSyncPayloadConsistent(syncState)
    if type(syncState) ~= "table" then
        return false
    end
    if type(syncState.phaseID) ~= "string" or syncState.phaseID == "" then
        return false
    end
    if type(syncState.objectGUID) ~= "string" or syncState.objectGUID == "" then
        return false
    end

    local resolvedPhaseID = ExtractPhaseIDFromObjectGUID(syncState.objectGUID)
    return type(resolvedPhaseID) == "string"
        and resolvedPhaseID ~= ""
        and resolvedPhaseID == syncState.phaseID
end

function TeamSharedSyncListener:HandleAddonEvent(event, prefix, payload, chatType, sender, ...)
    if self:IsFeatureEnabled() ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = prefix or self.CONTROL_ADDON_PREFIX,
                direction = "recv",
                status = "blocked",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "feature_disabled",
            })
        end
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    else
        self:RegisterAddonPrefix()
        if TeamSharedSyncChannelService and TeamSharedSyncChannelService.EnsureTeamChannelReady then
            TeamSharedSyncChannelService:EnsureTeamChannelReady()
        end
    end
    if self:CanReceiveSharedSync() ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = prefix or self.CONTROL_ADDON_PREFIX,
                direction = "recv",
                status = "blocked",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "receive_gate_closed",
            })
        end
        return false
    end

    self.channelContextBuffer = self.channelContextBuffer or {}
    local channelContext = ResolveCurrentChannelContext(self.channelContextBuffer, ...)
    if not TeamSharedSyncChannelService
        or not TeamSharedSyncChannelService.MatchesTeamChannelContext
        or TeamSharedSyncChannelService:MatchesTeamChannelContext(
            chatType,
            channelContext.target,
            channelContext.zoneChannelID,
            channelContext.localChannelID,
            channelContext.channelName
        ) ~= true then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = prefix or self.CONTROL_ADDON_PREFIX,
                direction = "recv",
                status = "ignored",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "channel_mismatch",
            })
        end
        return false
    end

    if TeamCommMapCache and TeamCommMapCache.IsSelfSender and TeamCommMapCache:IsSelfSender(self, sender) then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = prefix or self.CONTROL_ADDON_PREFIX,
                direction = "recv",
                status = "ignored",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "self_sender",
            })
        end
        return false
    end

    self.syncStateBuffer = self.syncStateBuffer or {}
    local syncState = TeamSharedSyncProtocol
        and TeamSharedSyncProtocol.ParsePayloadInto
        and TeamSharedSyncProtocol:ParsePayloadInto(prefix, payload, self.syncStateBuffer)
        or nil
    if not syncState then
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = prefix or self.CONTROL_ADDON_PREFIX,
                direction = "recv",
                status = "ignored",
                prefix = prefix,
                chatType = chatType,
                sender = sender,
                payload = payload,
                note = "parse_failed",
            })
        end
        return false
    end
    local function RecordProcessed(status, note)
        if HiddenSyncAuditService and HiddenSyncAuditService.Record then
            HiddenSyncAuditService:Record({
                protocol = prefix or self.CONTROL_ADDON_PREFIX,
                direction = "recv",
                status = status,
                prefix = prefix,
                messageType = syncState.messageType,
                chatType = chatType,
                sender = sender,
                requestID = syncState.requestID,
                expansionID = syncState.expansionID,
                mapID = syncState.mapID,
                phaseID = syncState.phaseID,
                routeKey = syncState.routeKey,
                routeFamilyKey = syncState.routeFamilyKey,
                landingKey = syncState.landingKey,
                alertToken = syncState.alertToken,
                objectGUID = syncState.objectGUID,
                sampleCount = syncState.sampleCount,
                observationCount = syncState.observationCount,
                verificationCount = syncState.verificationCount,
                verifiedPredictionCount = syncState.verifiedPredictionCount,
                confidenceScore = syncState.confidenceScore,
                payload = payload,
                note = note,
            })
        end
    end
    if syncState.messageType == (TeamSharedSyncProtocol and TeamSharedSyncProtocol.REQUEST_MESSAGE_TYPE or "SYNC_REQUEST") then
        local handled = TeamSharedWarmupService
            and TeamSharedWarmupService.HandleSyncRequest
            and TeamSharedWarmupService:HandleSyncRequest(syncState, sender)
            or false
        RecordProcessed(handled == true and "processed" or "ignored", "sync_request")
        return handled
    end
    if syncState.messageType == (TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_REQUEST_MESSAGE_TYPE or "TRAJECTORY_REQUEST") then
        local handled = AirdropTrajectorySyncService
            and AirdropTrajectorySyncService.HandleSyncRequest
            and AirdropTrajectorySyncService:HandleSyncRequest(syncState, sender)
            or false
        RecordProcessed(handled == true and "processed" or "ignored", "trajectory_request")
        return handled
    end
    if syncState.messageType == (TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_MESSAGE_TYPE or "TRAJECTORY_ROUTE") then
        local handled = AirdropTrajectorySyncService
            and AirdropTrajectorySyncService.HandleTrajectoryRoute
            and AirdropTrajectorySyncService:HandleTrajectoryRoute(syncState, sender)
            or false
        RecordProcessed(handled == true and "processed" or "ignored", "trajectory_route")
        return handled
    end
    if syncState.messageType == (TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_ALERT_CLAIM_MESSAGE_TYPE or "TRAJECTORY_ALERT_CLAIM")
        or syncState.messageType == (TeamSharedSyncProtocol and TeamSharedSyncProtocol.TRAJECTORY_ALERT_ACK_MESSAGE_TYPE or "TRAJECTORY_ALERT_ACK") then
        local handled = AirdropTrajectoryAlertCoordinator
            and AirdropTrajectoryAlertCoordinator.HandleRemoteCoordination
            and AirdropTrajectoryAlertCoordinator:HandleRemoteCoordination(syncState, sender)
            or false
        RecordProcessed(handled == true and "processed" or "ignored", "trajectory_alert")
        return handled
    end
    if IsSharedSyncPayloadConsistent(syncState) ~= true then
        RecordProcessed("ignored", "payload_inconsistent")
        return false
    end

    local mapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(syncState.mapID, syncState.expansionID) or nil
    if not mapData then
        RecordProcessed("ignored", "tracked_map_not_found")
        return false
    end

    local currentTime = Utils:GetCurrentTimestamp()
    local changed, record = false, nil
    if TeamSharedSyncStore and TeamSharedSyncStore.UpsertRecord then
        changed, record = TeamSharedSyncStore:UpsertRecord(
            syncState.expansionID,
            syncState.mapID,
            syncState.phaseID,
            syncState.timestamp,
            syncState.objectGUID,
            sender,
            currentTime
        )
    end
    if changed ~= true or type(record) ~= "table" then
        RecordProcessed("ignored", "store_not_changed")
        return false
    end

    if UnifiedDataManager and UnifiedDataManager.RefreshSharedDisplayActivation then
        UnifiedDataManager:RefreshSharedDisplayActivation(mapData.id, currentTime)
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    local currentPhaseID = UnifiedDataManager and UnifiedDataManager.GetCurrentPhase and UnifiedDataManager:GetCurrentPhase(mapData.id) or nil
    if currentMapID == mapData.mapID and currentPhaseID == syncState.phaseID then
        if UIRefreshCoordinator and UIRefreshCoordinator.RequestRowRefresh then
            UIRefreshCoordinator:RequestRowRefresh(mapData.id, {
                affectsSort = true,
                delay = 0.08,
            })
        elseif UIRefreshCoordinator and UIRefreshCoordinator.RefreshMainTable then
            UIRefreshCoordinator:RefreshMainTable()
        end
    end

    RecordProcessed("processed", "phase_airdrop")
    return true
end

return TeamSharedSyncListener
