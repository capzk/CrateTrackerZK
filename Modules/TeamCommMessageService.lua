-- TeamCommMessageService.lua - 团队隐藏同步业务处理

local TeamCommMessageService = BuildEnv("TeamCommMessageService")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local AirdropEventService = BuildEnv("AirdropEventService")
local IconDetector = BuildEnv("IconDetector")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local TimerManager = BuildEnv("TimerManager")
local UIRefreshCoordinator = BuildEnv("UIRefreshCoordinator")
local Data = BuildEnv("Data")
local Notification = BuildEnv("Notification")

TeamCommMessageService.syncContextBuffer = TeamCommMessageService.syncContextBuffer or {
    persistentStateBuffer = {},
}

local function RecordVisibleMessageWindow(mapKey, mapName, currentTime, eventContext)
    if Notification and Notification.RecordReceivedSync then
        Notification:RecordReceivedSync(mapKey or mapName, currentTime, eventContext)
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

local function IsSameTrackedMapContext(currentMapID, mapData)
    if type(currentMapID) ~= "number" or type(mapData) ~= "table" or type(mapData.mapID) ~= "number" then
        return false
    end
    return currentMapID == mapData.mapID
end

local function HasSameObjectGUID(localGUID, incomingGUID)
    if AirdropEventService and AirdropEventService.HasSameObjectGUID then
        return AirdropEventService:HasSameObjectGUID(localGUID, incomingGUID)
    end
    return type(localGUID) == "string"
        and type(incomingGUID) == "string"
        and localGUID == incomingGUID
end

local function GetConfirmedTimestamp(state)
    if type(state) ~= "table" then
        return nil
    end
    return tonumber(state.currentAirdropTimestamp or state.lastRefresh)
end

local function ShouldPersistIncomingConfirmedState(persistentState, incomingTimestamp, incomingGUID)
    if type(persistentState) ~= "table" then
        return true
    end

    local localGUID = persistentState.currentAirdropObjectGUID
    if HasSameObjectGUID(localGUID, incomingGUID) then
        return false
    end

    local localTimestamp = GetConfirmedTimestamp(persistentState)
    if type(localTimestamp) == "number" and incomingTimestamp <= localTimestamp then
        return false
    end

    return true
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

local function ResolveSyncContext(listener, mapID, sender, outContext)
    local numericMapID = tonumber(mapID)
    if not numericMapID then
        return nil
    end
    if type(outContext) ~= "table" then
        outContext = {}
    end

    local mapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(numericMapID) or nil
    if not mapData then
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(numericMapID)

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
            and UnifiedDataManager:GetPersistentAirdropStateInto(mapData.id, outContext.persistentStateBuffer)
            or nil
    end
    outContext.mapId = mapData.id
    outContext.mapID = numericMapID
    outContext.mapData = mapData
    outContext.mapName = mapName
    outContext.currentMapID = currentMapID
    outContext.persistentState = persistentState
    outContext.isOnMap = isOnMap
    outContext.currentTime = Utils:GetCurrentTimestamp()
    outContext.sender = sender
    return outContext
end

function TeamCommMessageService:ProcessConfirmedSync(listener, syncState, _, sender)
    local context = ResolveSyncContext(listener, syncState and syncState.mapID, sender, AcquireSyncContextBuffer())
    if not context then
        return false
    end

    local syncTimestamp = tonumber(syncState and syncState.timestamp)
    local incomingGUID = syncState and syncState.objectGUID or nil
    if not syncTimestamp then
        return false
    end
    if type(incomingGUID) ~= "string" or incomingGUID == "" then
        return false
    end

    RecordVisibleMessageWindow(context.mapId, context.mapName, context.currentTime, {
        mapKey = context.mapId,
        eventTimestamp = syncTimestamp,
        objectGUID = incomingGUID,
    })

    if context.isOnMap then
        return true
    end

    -- 同地图确认状态采用单调更新规则：
    -- 1. 同 objectGUID 视为同一空投事件，忽略重复同步；
    -- 2. 不同 objectGUID 只有时间更晚时才允许覆盖。
    if not ShouldPersistIncomingConfirmedState(context.persistentState, syncTimestamp, incomingGUID) then
        return true
    end

    local phaseId = ExtractPhaseIDFromObjectGUID(incomingGUID)

    local success = UnifiedDataManager and UnifiedDataManager.PersistConfirmedAirdropState
        and UnifiedDataManager:PersistConfirmedAirdropState(context.mapId, {
            lastRefresh = syncTimestamp,
            currentAirdropTimestamp = syncTimestamp,
            currentAirdropObjectGUID = incomingGUID,
            lastRefreshPhase = phaseId,
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

    return self:ProcessConfirmedSync(listener, syncState, chatType, sender)
end

return TeamCommMessageService
