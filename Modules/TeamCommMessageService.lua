-- TeamCommMessageService.lua - 团队消息业务处理

local TeamCommMessageService = BuildEnv("TeamCommMessageService")
local TeamCommParserRegistry = BuildEnv("TeamCommParserRegistry")
local TeamCommMapCache = BuildEnv("TeamCommMapCache")
local AirdropEventService = BuildEnv("AirdropEventService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local TimerManager = BuildEnv("TimerManager")
local Data = BuildEnv("Data")

function TeamCommMessageService:HasRecentLocalConfirmedAirdrop(listener, mapData, currentTime)
    if type(mapData) ~= "table" then
        return false
    end
    if type(mapData.currentAirdropObjectGUID) ~= "string" or mapData.currentAirdropObjectGUID == "" then
        return false
    end
    if type(mapData.currentAirdropTimestamp) ~= "number" then
        return false
    end
    if type(currentTime) ~= "number" or currentTime < mapData.currentAirdropTimestamp then
        return false
    end
    local suppressWindow = listener.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW or 300
    if AirdropEventService and AirdropEventService.HasRecentTimestamp then
        return AirdropEventService:HasRecentTimestamp(mapData.currentAirdropTimestamp, currentTime, suppressWindow)
    end
    return (currentTime - mapData.currentAirdropTimestamp) <= suppressWindow
end

function TeamCommMessageService:Process(listener, message, chatType, sender)
    if not message or type(message) ~= "string" then
        return false
    end

    local mapName = TeamCommParserRegistry:ParseTeamMessage(listener, message)
    if not mapName then
        return false
    end

    local mapId = TeamCommMapCache:GetMapIdByName(listener, mapName)
    if not mapId then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "忽略", string.format("消息地图不在当前版本配置中，已忽略：%s", mapName))
        end
        return false
    end

    TeamCommMapCache:EnsurePlayerIdentity(listener)
    if sender and (sender == listener.playerName or sender == listener.fullPlayerName) then
        if Logger and Logger.debugEnabled and Logger.Debug then
            Logger:Debug("TeamCommListener", "处理", string.format("跳过自己发送的消息：发送者=%s，地图=%s", sender, mapName))
        end
        return false
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local mapData = Data:GetMap(mapId)
    local isOnMap = mapData and currentMapID == mapData.mapID
    local currentTime = time()

    if Logger and Logger.debugEnabled and Logger.Debug then
        Logger:Debug("TeamCommListener", "处理", string.format("检测到团队空投消息：发送者=%s，地图=%s，聊天类型=%s",
            sender or "未知", mapName, chatType))
    end

    if not isOnMap then
        if self:HasRecentLocalConfirmedAirdrop(listener, mapData, currentTime) then
            if Logger and Logger.debugEnabled and Logger.Debug then
                Logger:Debug("TeamCommListener", "处理", string.format(
                    "忽略晚到团队消息：地图=%s，本地已在%d秒保护窗内确认过空投，确认时间=%s",
                    mapName,
                    listener.LOCAL_CONFIRMED_MESSAGE_SUPPRESS_WINDOW or 300,
                    UnifiedDataManager:FormatDateTime(mapData.currentAirdropTimestamp)
                ))
            end
            return true
        end

        if UnifiedDataManager and UnifiedDataManager.GetValidTemporaryTime then
            local tempRecord = UnifiedDataManager:GetValidTemporaryTime(mapId)
            if tempRecord then
                local timeSinceLast = currentTime - tempRecord.timestamp
                local isDuplicate = AirdropEventService and AirdropEventService.IsDuplicateTeamMessage
                    and AirdropEventService:IsDuplicateTeamMessage(tempRecord.timestamp, currentTime, 30)
                    or (timeSinceLast >= 0 and timeSinceLast <= 30 and currentTime > tempRecord.timestamp)
                if isDuplicate then
                    if Logger and Logger.debugEnabled and Logger.Debug then
                        Logger:Debug("TeamCommListener", "处理", string.format("跳过重复的团队消息（30秒内）：地图=%s，上次=%s，本次=%s，差值=%d秒",
                            mapName,
                            UnifiedDataManager:FormatDateTime(tempRecord.timestamp),
                            UnifiedDataManager:FormatDateTime(currentTime),
                            timeSinceLast))
                    end
                    return true
                end
            end
        end

        local success = false
        if UnifiedDataManager and UnifiedDataManager.SetTime then
            local source = (TimerManager and TimerManager.detectionSources and TimerManager.detectionSources.TEAM_MESSAGE) or "team_message"
            success = UnifiedDataManager:SetTime(mapId, currentTime, source)
        elseif Data and Data.SetLastRefresh then
            success = Data:SetLastRefresh(mapId, currentTime)
        end

        if not success then
            if Logger and Logger.Error then
                Logger:Error("TeamCommListener", "错误", string.format("更新刷新时间失败：地图=%s", mapName))
            end
            return false
        end

        if TimerManager and TimerManager.UpdateUI then
            TimerManager:UpdateUI()
        end
    elseif Logger and Logger.debugEnabled and Logger.Debug then
        Logger:Debug("TeamCommListener", "处理", string.format("在空投地图，跳过团队消息更新（由自己的检测处理）：地图=%s", mapName))
    end

    return true
end

return TeamCommMessageService
