-- TeamCommMessageService.lua - 团队隐藏同步业务处理

local TeamCommMessageService = BuildEnv("TeamCommMessageService")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local AirdropEventService = BuildEnv("AirdropEventService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local TimerManager = BuildEnv("TimerManager")
local Data = BuildEnv("Data")
local Notification = BuildEnv("Notification")

local function RecordVisibleMessageSuppress(mapName, currentTime)
    if Notification and Notification.RecordReceivedSync then
        Notification:RecordReceivedSync(mapName, currentTime)
    end
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

local function ResolveSyncContext(listener, mapId, sender)
    local numericMapId = tonumber(mapId)
    if not numericMapId then
        return nil
    end

    local mapData = Data and Data.GetMap and Data:GetMap(numericMapId) or nil
    if not mapData then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "忽略", string.format("消息地图ID无效或未追踪，已忽略：mapId=%s", tostring(numericMapId)))
        end
        return nil
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(numericMapId)

    TeamCommMapCache:EnsurePlayerIdentity(listener)
    local isSelfSender = TeamCommMapCache and TeamCommMapCache.IsSelfSender
        and TeamCommMapCache:IsSelfSender(listener, sender)
        or (sender and (sender == listener.playerName or sender == listener.fullPlayerName))
    if isSelfSender then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format("跳过自己发送的同步消息：发送者=%s，地图=%s", sender, mapName))
        end
        return nil
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local persistentState = UnifiedDataManager and UnifiedDataManager.GetPersistentAirdropState
        and UnifiedDataManager:GetPersistentAirdropState(numericMapId)
        or nil
    return {
        mapId = numericMapId,
        mapData = mapData,
        mapName = mapName,
        currentMapID = currentMapID,
        persistentState = persistentState,
        isOnMap = mapData and currentMapID == mapData.mapID,
        currentTime = time(),
        sender = sender,
    }
end

function TeamCommMessageService:ProcessTemporarySync(listener, syncState, chatType, sender)
    local context = ResolveSyncContext(listener, syncState and syncState.mapId, sender)
    if not context then
        return false
    end

    local syncTimestamp = tonumber(syncState and syncState.timestamp)
    if not syncTimestamp then
        return false
    end

    if Logger and Logger.debugEnabled and Logger.Debug then
        Logger:Debug("TeamCommListener", "处理", string.format(
            "检测到隐藏临时同步：发送者=%s，地图=%s，聊天类型=%s，同步时间=%s",
            sender or "未知",
            context.mapName,
            chatType,
            UnifiedDataManager:FormatDateTime(syncTimestamp)
        ))
    end

    RecordVisibleMessageSuppress(context.mapName, context.currentTime)

    if context.isOnMap then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format("在空投地图，跳过隐藏临时同步（由自己的检测处理）：地图=%s", context.mapName))
        end
        return true
    end

    if self:HasRecentLocalConfirmedAirdrop(listener, context.persistentState, context.currentTime) then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format(
                "忽略晚到隐藏临时同步：地图=%s，本地已在%d秒保护窗内确认过空投，确认时间=%s",
                context.mapName,
                listener.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW or 300,
                UnifiedDataManager:FormatDateTime(context.persistentState.currentAirdropTimestamp)
            ))
        end
        return true
    end

    if context.persistentState
        and type(context.persistentState.currentAirdropTimestamp) == "number"
        and syncTimestamp <= context.persistentState.currentAirdropTimestamp then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format(
                "忽略旧的隐藏临时同步：地图=%s，同步时间=%s，本地确认时间=%s",
                context.mapName,
                UnifiedDataManager:FormatDateTime(syncTimestamp),
                UnifiedDataManager:FormatDateTime(context.persistentState.currentAirdropTimestamp)
            ))
        end
        return true
    end

    if UnifiedDataManager and UnifiedDataManager.GetValidTemporaryTime then
        local tempRecord = UnifiedDataManager:GetValidTemporaryTime(context.mapId)
        if tempRecord and type(tempRecord.timestamp) == "number" then
            local duplicateWindow = self:GetDuplicateMessageWindow(listener)
            local isDuplicate = math.abs(syncTimestamp - tempRecord.timestamp) <= duplicateWindow
            if isDuplicate then
                if Logger and Logger.debugEnabled and Logger.Debug then
                    Logger:Debug("TeamCommListener", "处理", string.format(
                        "跳过重复的隐藏临时同步（%d秒内）：地图=%s，上次=%s，本次=%s",
                        duplicateWindow,
                        context.mapName,
                        UnifiedDataManager:FormatDateTime(tempRecord.timestamp),
                        UnifiedDataManager:FormatDateTime(syncTimestamp)
                    ))
                end
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

    if TimerManager and TimerManager.UpdateUI then
        TimerManager:UpdateUI()
    end
    return true
end

function TeamCommMessageService:ProcessConfirmedSync(listener, syncState, chatType, sender)
    local context = ResolveSyncContext(listener, syncState and syncState.mapId, sender)
    if not context then
        return false
    end

    local syncTimestamp = tonumber(syncState and syncState.timestamp)
    if not syncTimestamp then
        return false
    end

    if Logger and Logger.debugEnabled and Logger.Debug then
        Logger:Debug("TeamCommListener", "处理", string.format(
            "检测到隐藏确认同步：发送者=%s，地图=%s，聊天类型=%s，确认时间=%s",
            sender or "未知",
            context.mapName,
            chatType,
            UnifiedDataManager:FormatDateTime(syncTimestamp)
        ))
    end

    RecordVisibleMessageSuppress(context.mapName, context.currentTime)

    if context.isOnMap then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format("在空投地图，跳过隐藏确认同步（由自己的检测处理）：地图=%s", context.mapName))
        end
        return true
    end

    if context.persistentState and type(context.persistentState.currentAirdropTimestamp) == "number" then
        local localTimestamp = context.persistentState.currentAirdropTimestamp
        local localGUID = context.persistentState.currentAirdropObjectGUID
        local incomingGUID = syncState and syncState.objectGUID or nil
        if syncTimestamp < localTimestamp or (syncTimestamp == localTimestamp and (incomingGUID == nil or incomingGUID == localGUID)) then
            if Logger and Logger.debugEnabled and Logger.Debug then
                Logger:Debug("TeamCommListener", "处理", string.format(
                    "忽略旧的隐藏确认同步：地图=%s，同步时间=%s，本地确认时间=%s",
                    context.mapName,
                    UnifiedDataManager:FormatDateTime(syncTimestamp),
                    UnifiedDataManager:FormatDateTime(localTimestamp)
                ))
            end
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

    if TimerManager and TimerManager.UpdateUI then
        TimerManager:UpdateUI()
    end
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
