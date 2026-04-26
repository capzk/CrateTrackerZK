-- NotificationTeamMessageService.lua - 团队可见消息与共享提示服务

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)
local L = CrateTrackerZK.L
local NotificationTeamMessageService = BuildEnv("NotificationTeamMessageService")
local Data = BuildEnv("Data")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local NotificationQueryService = BuildEnv("NotificationQueryService")
local AirdropTrajectoryGeometryService = BuildEnv("AirdropTrajectoryGeometryService")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Utils = BuildEnv("Utils")

local function FormatCoordinatePercent(value)
    if AirdropTrajectoryGeometryService and AirdropTrajectoryGeometryService.FormatCoordinatePercent then
        return AirdropTrajectoryGeometryService:FormatCoordinatePercent(value)
    end
    return string.format("%.1f", (tonumber(value) or 0) * 100)
end

local function BuildWorldMapCoordinateLink(mapId, endX, endY)
    local uiMapID = tonumber(mapId)
    local coordinateX = tonumber(endX)
    local coordinateY = tonumber(endY)
    if not uiMapID or type(coordinateX) ~= "number" or type(coordinateY) ~= "number" then
        return nil
    end

    local encodedX = math.floor((coordinateX * 10000) + 0.5)
    local encodedY = math.floor((coordinateY * 10000) + 0.5)
    local displayText = type(MAP_PIN_HYPERLINK) == "string"
        and MAP_PIN_HYPERLINK ~= ""
        and MAP_PIN_HYPERLINK
        or "|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a 地图标记位置"
    return string.format("\124cffffff00\124Hworldmap:%d:%d:%d\124h[%s]\124h\124r", uiMapID, encodedX, encodedY, displayText)
end

local function BuildCandidateEntry(mapId, index, endX, endY)
    return {
        label = tostring(index or "?"),
        coordinateLink = BuildWorldMapCoordinateLink(mapId, endX, endY),
    }
end

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

function NotificationTeamMessageService:SendTrajectoryPredictionTeamMessage(notification, mapId, alertToken, objectGUID, endX, endY, eventTimestamp)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapId) ~= "number" or type(alertToken) ~= "string" or alertToken == "" then
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
    local mapKey = "trajectory:" .. tostring(mapId) .. ":" .. alertToken
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
    local coordinateLink = BuildWorldMapCoordinateLink(mapId, endX, endY)
    local message = NotificationQueryService and NotificationQueryService.BuildTrajectoryPredictionMessage
        and NotificationQueryService.BuildTrajectoryPredictionTeamMessage
        and NotificationQueryService:BuildTrajectoryPredictionTeamMessage(
            mapName,
            coordinateLink,
            FormatCoordinatePercent(endX),
            FormatCoordinatePercent(endY)
        )
        or string.format(
            "【%s】飞行轨迹匹配成功，预测落点坐标：%s",
            mapName,
            tostring(coordinateLink or "")
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

function NotificationTeamMessageService:SendTrajectoryPredictionCandidatesTeamMessage(notification, mapId, alertToken, objectGUID, candidates, eventTimestamp)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if type(mapId) ~= "number" or type(alertToken) ~= "string" or alertToken == "" then
        return false
    end
    if type(objectGUID) ~= "string" or objectGUID == "" then
        return false
    end
    if type(candidates) ~= "table" or #candidates ~= 2 then
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
    local mapKey = "trajectory_candidates:" .. tostring(mapId) .. ":" .. alertToken
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
    local candidateEntries = {
        BuildCandidateEntry(mapId, 1, candidates[1].endX, candidates[1].endY),
        BuildCandidateEntry(mapId, 2, candidates[2].endX, candidates[2].endY),
    }
    local message = NotificationQueryService
        and NotificationQueryService.BuildTrajectoryPredictionCandidatesMessage
        and NotificationQueryService:BuildTrajectoryPredictionCandidatesMessage(mapName, candidateEntries)
        or string.format(
            "【%s】当前轨迹存在多个可能落点，暂无法准确判断。 候选1：%s 候选2：%s",
            mapName,
            tostring(candidateEntries[1].coordinateLink or ""),
            tostring(candidateEntries[2].coordinateLink or "")
        )

    local sent = NotificationOutputService
        and NotificationOutputService.SendTeamMessage
        and NotificationOutputService:SendTeamMessage(message, visibleChatType, {
            logFailure = true,
            label = "发送轨迹候选团队消息失败",
        }) == true
        or false
    if sent == true and notification.CommitVisibleAutoDispatch then
        notification:CommitVisibleAutoDispatch(mapKey, eventContext, currentTime)
    end
    return sent == true
end

return NotificationTeamMessageService
