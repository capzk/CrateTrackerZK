-- NotificationTeamMessageService.lua - 团队可见消息与共享提示服务

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)
local L = CrateTrackerZK.L
local NotificationTeamMessageService = BuildEnv("NotificationTeamMessageService")
local Data = BuildEnv("Data")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local NotificationQueryService = BuildEnv("NotificationQueryService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Utils = BuildEnv("Utils")

local function ResolveStandardVisibleChatType(notification)
    if type(notification) ~= "table"
        or not notification.IsTeamNotificationEnabled
        or notification:IsTeamNotificationEnabled() ~= true then
        return nil
    end

    local teamChatType = notification.GetTeamChatType and notification:GetTeamChatType() or nil
    if type(teamChatType) ~= "string" or teamChatType == "" then
        return nil
    end

    return NotificationOutputService
        and NotificationOutputService.GetStandardVisibleChatType
        and NotificationOutputService:GetStandardVisibleChatType(teamChatType)
        or nil
end

function NotificationTeamMessageService:NotifySharedPhaseSyncApplied(notification, mapId, sharedRecord)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" then
        return false
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId)
    local message = NotificationQueryService and NotificationQueryService.BuildSharedPhaseSyncAppliedMessage
        and NotificationQueryService:BuildSharedPhaseSyncAppliedMessage(mapName)
        or string.format((L and L["SharedPhaseSyncApplied"]) or "Acquired the latest shared airdrop info for the current phase in [%s].", mapName)

    return NotificationOutputService
        and NotificationOutputService.SendLocalMessage
        and NotificationOutputService:SendLocalMessage(message) == true
        or false
end

function NotificationTeamMessageService:SendSharedPhaseSyncAppliedTeamMessage(notification, mapId, sharedRecord)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapId) ~= "number" or type(sharedRecord) ~= "table" then
        return false
    end

    local visibleChatType = ResolveStandardVisibleChatType(notification)
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId)
    local message = NotificationQueryService and NotificationQueryService.BuildSharedPhaseSyncAppliedMessage
        and NotificationQueryService:BuildSharedPhaseSyncAppliedMessage(mapName)
        or string.format((L and L["SharedPhaseSyncApplied"]) or "Acquired the latest shared airdrop info for the current phase in [%s].", mapName)

    return NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType) == true
        or false
end

function NotificationTeamMessageService:SendTimeRemainingTeamMessage(notification, mapId)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapId) ~= "number" then
        return false
    end

    local visibleChatType = ResolveStandardVisibleChatType(notification)
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false
    end

    local mapData = Data and Data.GetMap and Data:GetMap(mapId) or nil
    if not mapData then
        return false
    end

    local remaining = UnifiedDataManager and UnifiedDataManager.GetRemainingTime and UnifiedDataManager:GetRemainingTime(mapId) or nil
    if type(remaining) ~= "number" then
        return false
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId)
    local message = NotificationQueryService and NotificationQueryService.BuildTimeRemainingMessage
        and NotificationQueryService:BuildTimeRemainingMessage(mapName, remaining)
        or string.format((L and L["TimeRemaining"]) or "[%s]War Supplies airdrop in: %s!!!", mapName, UnifiedDataManager:FormatTime(remaining, true))

    return NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType) == true
        or false
end

function NotificationTeamMessageService:NotifyPhaseTeamAlert(notification, mapName, previousPhaseID, currentPhaseID)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapName) ~= "string" or mapName == "" then
        return false
    end
    if currentPhaseID == nil then
        return false
    end
    if not notification:IsPhaseTeamAlertEnabled() or not notification:IsTeamNotificationEnabled() then
        return false
    end

    local teamChatType = notification:GetTeamChatType()
    if type(teamChatType) ~= "string" or teamChatType == "" then
        return false
    end

    local visibleChatType = NotificationOutputService
        and NotificationOutputService.GetStandardVisibleChatType
        and NotificationOutputService:GetStandardVisibleChatType(teamChatType)
        or nil
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false
    end

    local message = NotificationQueryService
        and NotificationQueryService.BuildPhaseTeamAlertMessage
        and NotificationQueryService:BuildPhaseTeamAlertMessage(mapName, previousPhaseID, currentPhaseID)
        or string.format(
            (L and L["PhaseTeamAlertMessage"]) or "Current %s phase changed: %s --> %s",
            mapName,
            tostring(previousPhaseID or ((L and L["UnknownPhaseValue"]) or "unknown")),
            tostring(currentPhaseID)
        )
    return NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType, {
            logFailure = true,
            label = "发送位面团队提醒失败",
        }) == true
        or false
end

function NotificationTeamMessageService:SendTrajectoryPredictionTeamMessage(notification, mapId, routeKey, objectGUID, endX, endY, eventTimestamp)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapId) ~= "number" or type(routeKey) ~= "string" or routeKey == "" then
        return false
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return false
    end
    if not notification:IsTeamNotificationEnabled() then
        return false
    end

    local visibleChatType = ResolveStandardVisibleChatType(notification)
    if type(visibleChatType) ~= "string" or visibleChatType == "" then
        return false
    end

    local currentTime = Utils:GetCurrentTimestamp()
    local mapKey = "trajectory:" .. tostring(mapId) .. ":" .. routeKey
    local eventContext = {
        mapKey = mapKey,
        eventTimestamp = tonumber(eventTimestamp) or currentTime,
        objectGUID = objectGUID,
    }

    if notification.HasPlayerSentNotification and notification:HasPlayerSentNotification(mapKey, eventContext) then
        return false
    end
    if notification.CanSendNotification and notification:CanSendNotification(mapKey, eventContext, currentTime) ~= true then
        return false
    end

    local mapData = Data and Data.GetMapByMapID and Data:GetMapByMapID(mapId) or nil
    if not mapData and Data and Data.GetMap then
        mapData = Data:GetMap(mapId)
    end
    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or tostring(mapId)
    local message = NotificationQueryService and NotificationQueryService.BuildTrajectoryPredictionMessage
        and NotificationQueryService:BuildTrajectoryPredictionMessage(
            mapName,
            math.floor(((tonumber(endX) or 0) * 100) + 0.5),
            math.floor(((tonumber(endY) or 0) * 100) + 0.5)
        )
        or string.format(
            (L and L["TrajectoryPredictionMatched"]) or "[%s] Matched airdrop trajectory, predicted drop coordinates: %d, %d",
            mapName,
            math.floor(((tonumber(endX) or 0) * 100) + 0.5),
            math.floor(((tonumber(endY) or 0) * 100) + 0.5)
        )

    local sent = NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType, {
            logFailure = true,
            label = "发送轨迹预测团队消息失败",
        }) == true
        or false
    if sent == true and notification.CommitVisibleAutoDispatch then
        notification:CommitVisibleAutoDispatch(mapKey, eventContext, currentTime)
    end
    return sent == true
end

return NotificationTeamMessageService
