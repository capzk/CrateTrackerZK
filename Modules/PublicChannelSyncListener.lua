-- PublicChannelSyncListener.lua - 备用相位缓存共享同步监听与发送
-- 注意：团队隐藏同步仍是唯一可靠同步来源。
-- 本模块只负责 best-effort 的运行时缓存补充信息，用于当前位面的临时显示回退。

local PublicChannelSyncListener = BuildEnv("PublicChannelSyncListener")

local HiddenSyncTransport = BuildEnv("HiddenSyncTransport")
local IconDetector = BuildEnv("IconDetector")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local PublicChannelSyncProtocol = BuildEnv("PublicChannelSyncProtocol")
local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")
local PublicChannelSyncStore = BuildEnv("PublicChannelSyncStore")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Data = BuildEnv("Data")

PublicChannelSyncListener.isInitialized = false
PublicChannelSyncListener.FEATURE_ENABLED = true
PublicChannelSyncListener.syncStateBuffer = PublicChannelSyncListener.syncStateBuffer or {}
PublicChannelSyncListener.channelContextBuffer = PublicChannelSyncListener.channelContextBuffer or {}
PublicChannelSyncListener.ADDON_PREFIX = PublicChannelSyncProtocol and PublicChannelSyncProtocol.ADDON_PREFIX or "CTKZK_PSYNC"

function PublicChannelSyncListener:IsFeatureEnabled()
    return self.FEATURE_ENABLED == true
end

function PublicChannelSyncListener:RegisterAddonPrefix()
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
    if listener:EnsureBroadcastChannelAvailable() ~= true then
        return false
    end

    local payload = PublicChannelSyncProtocol and PublicChannelSyncProtocol.BuildPayload and PublicChannelSyncProtocol:BuildPayload(syncState) or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    return PublicSyncChannelService and PublicSyncChannelService.SendPayload
        and PublicSyncChannelService:SendPayload(listener.ADDON_PREFIX, payload)
        or false
end

function PublicChannelSyncListener:CanSendSharedSync()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    return PublicSyncChannelService
        and PublicSyncChannelService.CanUsePublicChannel
        and PublicSyncChannelService:CanUsePublicChannel() == true
        or false
end

function PublicChannelSyncListener:CanReceiveSharedSync()
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not PublicSyncChannelService or not PublicSyncChannelService.CanUsePublicChannel then
        return false
    end
    return PublicSyncChannelService:CanUsePublicChannel() == true
end

function PublicChannelSyncListener:Initialize()
    if self:IsFeatureEnabled() ~= true then
        self.isInitialized = false
        return false
    end
    if TeamCommMapCache and TeamCommMapCache.EnsurePlayerIdentity then
        TeamCommMapCache:EnsurePlayerIdentity(self)
    end
    if PublicChannelSyncStore and PublicChannelSyncStore.Initialize then
        PublicChannelSyncStore:Initialize()
    end
    if PublicSyncChannelService and PublicSyncChannelService.Initialize then
        PublicSyncChannelService:Initialize()
    end
    self:RegisterAddonPrefix()
    if PublicSyncChannelService and PublicSyncChannelService.EnsureChannelJoined then
        PublicSyncChannelService:EnsureChannelJoined()
    end
    self.isInitialized = true
    return true
end

function PublicChannelSyncListener:EnsureBroadcastChannelAvailable(force)
    if self:IsFeatureEnabled() ~= true then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end
    self:RegisterAddonPrefix()
    if PublicSyncChannelService and PublicSyncChannelService.EnsureChannelJoined then
        return PublicSyncChannelService:EnsureChannelJoined(force == true)
    end
    return false
end

function PublicChannelSyncListener:SendSharedSync(syncState)
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

function PublicChannelSyncListener:HandleAddonEvent(event, prefix, payload, chatType, sender, ...)
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
    if not PublicSyncChannelService
        or not PublicSyncChannelService.MatchesChannelContext
        or PublicSyncChannelService:MatchesChannelContext(
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
    local syncState = PublicChannelSyncProtocol
        and PublicChannelSyncProtocol.ParsePayloadInto
        and PublicChannelSyncProtocol:ParsePayloadInto(prefix, payload, self.syncStateBuffer)
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
    if PublicChannelSyncStore and PublicChannelSyncStore.UpsertRecord then
        changed, record = PublicChannelSyncStore:UpsertRecord(
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

return PublicChannelSyncListener
