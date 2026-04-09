-- TeamSharedSyncListener.lua - 团队共享缓存同步监听与发送
-- 注意：团队隐藏同步仍是唯一可靠同步来源。
-- 本模块只负责 best-effort 的运行时缓存补充信息，用于当前位面的临时显示回退。

local TeamSharedSyncListener = BuildEnv("TeamSharedSyncListener")

local HiddenSyncTransport = BuildEnv("HiddenSyncTransport")
local IconDetector = BuildEnv("IconDetector")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local TeamSharedSyncProtocol = BuildEnv("TeamSharedSyncProtocol")
local TeamSharedSyncChannelService = BuildEnv("TeamSharedSyncChannelService")
local TeamSharedSyncStore = BuildEnv("TeamSharedSyncStore")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Data = BuildEnv("Data")

TeamSharedSyncListener.isInitialized = false
TeamSharedSyncListener.FEATURE_ENABLED = true
TeamSharedSyncListener.syncStateBuffer = TeamSharedSyncListener.syncStateBuffer or {}
TeamSharedSyncListener.channelContextBuffer = TeamSharedSyncListener.channelContextBuffer or {}
TeamSharedSyncListener.ADDON_PREFIX = TeamSharedSyncProtocol and TeamSharedSyncProtocol.ADDON_PREFIX or "CTKZK_PSYNC"

function TeamSharedSyncListener:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function TeamSharedSyncListener:RegisterAddonPrefix()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if self.addonPrefixRegistered == true then
        return true
    end

    return HiddenSyncTransport
        and HiddenSyncTransport.EnsureAddonPrefix
        and HiddenSyncTransport:EnsureAddonPrefix(self, self.ADDON_PREFIX)
        or false
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

    return TeamSharedSyncChannelService and TeamSharedSyncChannelService.SendPayload
        and TeamSharedSyncChannelService:SendPayload(listener.ADDON_PREFIX, payload)
        or false
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
        return false
    end
    if self:CanReceiveSharedSync() ~= true then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
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
        return false
    end

    if TeamCommMapCache and TeamCommMapCache.IsSelfSender and TeamCommMapCache:IsSelfSender(self, sender) then
        return false
    end

    self.syncStateBuffer = self.syncStateBuffer or {}
    local syncState = TeamSharedSyncProtocol
        and TeamSharedSyncProtocol.ParsePayloadInto
        and TeamSharedSyncProtocol:ParsePayloadInto(prefix, payload, self.syncStateBuffer)
        or nil
    if not syncState then
        return false
    end
    if IsSharedSyncPayloadConsistent(syncState) ~= true then
        return false
    end

    local mapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(syncState.mapID, syncState.expansionID) or nil
    if not mapData then
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

    return true
end

return TeamSharedSyncListener
