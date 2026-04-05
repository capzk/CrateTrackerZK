-- PublicChannelSyncListener.lua - 公共频道相位共享同步监听与发送
-- 注意：团队隐藏同步仍是唯一可靠同步来源。
-- 本模块只负责 best-effort 的公共广播补充信息，用于当前位面的临时显示回退。

local PublicChannelSyncListener = BuildEnv("PublicChannelSyncListener")

local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local PublicChannelSyncProtocol = BuildEnv("PublicChannelSyncProtocol")
local PublicSyncChannelService = BuildEnv("PublicSyncChannelService")
local PublicChannelSyncStore = BuildEnv("PublicChannelSyncStore")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Data = BuildEnv("Data")
local CrateTrackerZK = BuildEnv("CrateTrackerZK")

PublicChannelSyncListener.isInitialized = false
PublicChannelSyncListener.syncStateBuffer = PublicChannelSyncListener.syncStateBuffer or {}
PublicChannelSyncListener.ADDON_PREFIX = PublicChannelSyncProtocol and PublicChannelSyncProtocol.ADDON_PREFIX or "CTKZK_PSYNC"

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
end

local function RegisterAddonPrefixInternal(prefix)
    if type(prefix) ~= "string" or prefix == "" then
        return false
    end

    if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
        local ok, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix)
        if ok and isRegistered == true then
            return true
        end
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok, result = pcall(function()
            return NormalizeAddonCallResult(C_ChatInfo.RegisterAddonMessagePrefix(prefix))
        end)
        if ok and (result == true or result == 0) then
            return true
        end
        if C_ChatInfo.IsAddonMessagePrefixRegistered then
            local verifyOk, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix)
            if verifyOk and isRegistered == true then
                return true
            end
        end
    elseif RegisterAddonMessagePrefix then
        local ok, result = pcall(function()
            return NormalizeAddonCallResult(RegisterAddonMessagePrefix(prefix))
        end)
        if ok and (result == true or result == 0) then
            return true
        end
        if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
            local verifyOk, isRegistered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, prefix)
            if verifyOk and isRegistered == true then
                return true
            end
        end
    end

    return false
end

function PublicChannelSyncListener:RegisterAddonPrefix()
    if self.addonPrefixRegistered == true then
        return true
    end

    self.addonPrefixRegistered = RegisterAddonPrefixInternal(self.ADDON_PREFIX) == true
    return self.addonPrefixRegistered == true
end

function PublicChannelSyncListener:CanSendPublicSync()
    if not PublicSyncChannelService or not PublicSyncChannelService.CanUsePublicChannel or PublicSyncChannelService:CanUsePublicChannel() ~= true then
        return false
    end
    if Area and Area.IsActive then
        return Area:IsActive() == true
    end
    return false
end

function PublicChannelSyncListener:CanReceivePublicSync()
    if not PublicSyncChannelService or not PublicSyncChannelService.CanUsePublicChannel then
        return false
    end
    return PublicSyncChannelService:CanUsePublicChannel() == true
end

function PublicChannelSyncListener:Initialize()
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
end

function PublicChannelSyncListener:EnsureBroadcastChannelAvailable(force)
    if not self.isInitialized then
        self:Initialize()
    end
    self:RegisterAddonPrefix()
    if PublicSyncChannelService and PublicSyncChannelService.EnsureChannelJoined then
        return PublicSyncChannelService:EnsureChannelJoined(force == true)
    end
    return false
end

function PublicChannelSyncListener:SendConfirmedSync(syncState)
    if self:CanSendPublicSync() ~= true then
        return false
    end
    if type(syncState) ~= "table" or type(syncState.phaseID) ~= "string" or syncState.phaseID == "" then
        return false
    end
    if self:EnsureBroadcastChannelAvailable() ~= true then
        return false
    end

    local payload = PublicChannelSyncProtocol and PublicChannelSyncProtocol.BuildPayload and PublicChannelSyncProtocol:BuildPayload(syncState) or nil
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    return PublicSyncChannelService and PublicSyncChannelService.SendPayload
        and PublicSyncChannelService:SendPayload(self.ADDON_PREFIX, payload)
        or false
end

local function ResolveCurrentChannelContext(...)
    return {
        target = select(1, ...),
        zoneChannelID = select(2, ...),
        localChannelID = select(3, ...),
        channelName = select(4, ...),
    }
end

function PublicChannelSyncListener:HandleAddonEvent(event, prefix, payload, chatType, sender, ...)
    if self:CanReceivePublicSync() ~= true then
        return false
    end
    if not self.isInitialized then
        self:Initialize()
    end

    local channelContext = ResolveCurrentChannelContext(...)
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

    self.syncStateBuffer = self.syncStateBuffer or {}
    local syncState = PublicChannelSyncProtocol
        and PublicChannelSyncProtocol.ParsePayloadInto
        and PublicChannelSyncProtocol:ParsePayloadInto(prefix, payload, self.syncStateBuffer)
        or nil
    if not syncState then
        return false
    end

    if TeamCommMapCache and TeamCommMapCache.IsSelfSender and TeamCommMapCache:IsSelfSender(self, sender) then
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
