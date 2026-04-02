-- TeamCommMessageService.lua - 团队隐藏同步业务处理

local TeamCommMessageService = BuildEnv("TeamCommMessageService")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local AirdropEventService = BuildEnv("AirdropEventService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local TimerManager = BuildEnv("TimerManager")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local Data = BuildEnv("Data")
local Notification = BuildEnv("Notification")

TeamCommMessageService.syncContextBuffer = TeamCommMessageService.syncContextBuffer or {
    persistentStateBuffer = {},
}

local function RecordVisibleMessageSuppress(mapName, currentTime)
    if Notification and Notification.RecordReceivedSync then
        Notification:RecordReceivedSync(mapName, currentTime)
    end
end

local function RequestSyncUIRefresh(mapId)
    if UIRefreshCoordinator and UIRefreshCoordinator.RequestSyncRefresh then
        return UIRefreshCoordinator:RequestSyncRefresh(mapId)
    end
    if TimerManager and TimerManager.UpdateUI then
        TimerManager:UpdateUI()
        return true
    end
    return false
end

local function AcquireSyncContextBuffer()
    local buffer = TeamCommMessageService.syncContextBuffer or {}
    TeamCommMessageService.syncContextBuffer = buffer
    buffer.persistentStateBuffer = buffer.persistentStateBuffer or {}
    return buffer
end

function TeamCommMessageService:HasRecentLocalConfirmedAirdrop(listener, mapData, currentTime)
    local persistentState = mapData;
    if type(persistentState) ~= "table" then
        return false
    end
    if type(persistentState.currentAirdropObjectGUID) ~= "string" or persistentState.currentAirdropObjectGUID == "" then
        return false
    end
    if type(persistentState.currentAirdropTimestamp) ~= "number" then
        return false
    end
    if type(currentTime) ~= "number" or currentTime < persistentState.currentAirdropTimestamp then
        return false
    end
    local suppressWindow = listener.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW or 300
    if AirdropEventService and AirdropEventService.HasRecentTimestamp then
        return AirdropEventService:HasRecentTimestamp(persistentState.currentAirdropTimestamp, currentTime, suppressWindow)
    end
    return (currentTime - persistentState.currentAirdropTimestamp) <= suppressWindow
end

function TeamCommMessageService:GetDuplicateMessageWindow(listener)
    if type(listener) == "table" and type(listener.DUPLICATE_MESSAGE_SUPPRESS_WINDOW) == "number" then
        return listener.DUPLICATE_MESSAGE_SUPPRESS_WINDOW
    end
    return 15
end

local function IsSameTrackedMapContext(currentMapID, mapData)
    if type(currentMapID) ~= "number" or type(mapData) ~= "table" or type(mapData.mapID) ~= "number" then
        return false
    end

    local inspectMapID = currentMapID
    local visited = {}
    while type(inspectMapID) == "number" and not visited[inspectMapID] do
        if inspectMapID == mapData.mapID then
            return true
        end
        visited[inspectMapID] = true

        if not C_Map or not C_Map.GetMapInfo then
            break
        end

        local mapInfo = C_Map.GetMapInfo(inspectMapID)
        inspectMapID = mapInfo and mapInfo.parentMapID or nil
    end

    return false
end

local function HasSameObjectGUID(localGUID, incomingGUID)
    if AirdropEventService and AirdropEventService.HasSameObjectGUID then
        return AirdropEventService:HasSameObjectGUID(localGUID, incomingGUID)
    end
    return type(localGUID) == "string"
        and type(incomingGUID) == "string"
        and localGUID == incomingGUID
end

local function ResolveSyncContext(listener, mapId, sender, outContext)
    local numericMapId = tonumber(mapId)
    if not numericMapId then
        return nil
    end
    if type(outContext) ~= "table" then
        outContext = {}
    end

    local mapData = Data and Data.GetMap and Data:GetMap(numericMapId) or nil
    if not mapData then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(numericMapId)

    TeamCommMapCache:EnsurePlayerIdentity(listener)
    local isSelfSender = TeamCommMapCache and TeamCommMapCache.IsSelfSender
        and TeamCommMapCache:IsSelfSender(listener, sender)
        or (sender and (sender == listener.playerName or sender == listener.fullPlayerName))
    if isSelfSender then
        return nil
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local isOnMap = IsSameTrackedMapContext(currentMapID, mapData)
    local persistentState = nil
    if not isOnMap then
        persistentState = UnifiedDataManager and UnifiedDataManager.GetPersistentAirdropStateInto
            and UnifiedDataManager:GetPersistentAirdropStateInto(numericMapId, outContext.persistentStateBuffer)
            or nil
    end
    outContext.mapId = numericMapId
    outContext.mapData = mapData
    outContext.mapName = mapName
    outContext.currentMapID = currentMapID
    outContext.persistentState = persistentState
    outContext.isOnMap = isOnMap
    outContext.currentTime = time()
    outContext.sender = sender
    return outContext
end

function TeamCommMessageService:ProcessTemporarySync(listener, syncState, _, sender)
    local context = ResolveSyncContext(listener, syncState and syncState.mapId, sender, AcquireSyncContextBuffer())
    if not context then
        return false
    end

    local syncTimestamp = tonumber(syncState and syncState.timestamp)
    if not syncTimestamp then
        return false
    end

    RecordVisibleMessageSuppress(context.mapName, context.currentTime)

    if context.isOnMap then
        return true
    end

    if self:HasRecentLocalConfirmedAirdrop(listener, context.persistentState, context.currentTime) then
        return true
    end

    if context.persistentState
        and type(context.persistentState.currentAirdropTimestamp) == "number"
        and syncTimestamp <= context.persistentState.currentAirdropTimestamp then
        return true
    end

    if UnifiedDataManager and UnifiedDataManager.GetValidTemporaryTime then
        local tempRecord = UnifiedDataManager:GetValidTemporaryTime(context.mapId)
        if tempRecord and type(tempRecord.timestamp) == "number" then
            local duplicateWindow = self:GetDuplicateMessageWindow(listener)
            local isDuplicate = math.abs(syncTimestamp - tempRecord.timestamp) <= duplicateWindow
            if isDuplicate then
                return true
            end
        end
    end

    local success = false
    if UnifiedDataManager and UnifiedDataManager.SetTime then
        local source = (TimerManager and TimerManager.detectionSources and TimerManager.detectionSources.TEAM_MESSAGE) or "team_message"
        success = UnifiedDataManager:SetTime(context.mapId, syncTimestamp, source)
    end

    if not success then
        if Logger and Logger.Error then
            Logger:Error("TeamCommListener", "错误", string.format("更新隐藏临时时间失败：地图=%s", context.mapName))
        end
        return false
    end

    RequestSyncUIRefresh(context.mapId)
    return true
end

function TeamCommMessageService:ProcessConfirmedSync(listener, syncState, _, sender)
    local context = ResolveSyncContext(listener, syncState and syncState.mapId, sender, AcquireSyncContextBuffer())
    if not context then
        return false
    end

    local syncTimestamp = tonumber(syncState and syncState.timestamp)
    if not syncTimestamp then
        return false
    end

    RecordVisibleMessageSuppress(context.mapName, context.currentTime)

    if context.isOnMap then
        return true
    end

    if self:HasRecentLocalConfirmedAirdrop(listener, context.persistentState, context.currentTime) then
        return true
    end

    if context.persistentState and type(context.persistentState.currentAirdropTimestamp) == "number" then
        local localTimestamp = context.persistentState.currentAirdropTimestamp
        local localGUID = context.persistentState.currentAirdropObjectGUID
        local incomingGUID = syncState and syncState.objectGUID or nil

        if syncTimestamp < localTimestamp then
            return true
        end

        -- 同一事件的确认时间必须保留最早值，不能被后到队友继续往后推。
        if HasSameObjectGUID(localGUID, incomingGUID) and syncTimestamp >= localTimestamp then
            return true
        end

        -- 无 GUID 的较弱确认结果，不允许覆盖已有的本地确认状态。
        if type(localGUID) == "string" and localGUID ~= "" and incomingGUID == nil and syncTimestamp >= localTimestamp then
            return true
        end

        if syncTimestamp == localTimestamp and (incomingGUID == nil or incomingGUID == localGUID) then
            return true
        end
    end

    local success = UnifiedDataManager and UnifiedDataManager.PersistConfirmedAirdropState
        and UnifiedDataManager:PersistConfirmedAirdropState(context.mapId, {
            lastRefresh = syncTimestamp,
            currentAirdropTimestamp = syncTimestamp,
            currentAirdropObjectGUID = syncState and syncState.objectGUID or nil,
            lastRefreshPhase = syncState and syncState.phaseId or nil,
            source = UnifiedDataManager.TimeSource.TEAM_MESSAGE,
        })

    if not success then
        if Logger and Logger.Error then
            Logger:Error("TeamCommListener", "错误", string.format("更新隐藏确认时间失败：地图=%s", context.mapName))
        end
        return false
    end

    RequestSyncUIRefresh(context.mapId)
    return true
end

function TeamCommMessageService:ProcessSync(listener, syncState, chatType, sender)
    if type(syncState) ~= "table" then
        return false
    end

    if syncState.syncType == "TEMP" then
        return self:ProcessTemporarySync(listener, syncState, chatType, sender)
    end
    if syncState.syncType == "CONFIRMED" then
        return self:ProcessConfirmedSync(listener, syncState, chatType, sender)
    end
    return false
end

return TeamCommMessageService
