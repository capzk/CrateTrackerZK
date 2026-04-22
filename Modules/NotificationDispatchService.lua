-- NotificationDispatchService.lua - 通知分发与手动输出服务

local ADDON_NAME = "CrateTrackerZK"
local CrateTrackerZK = BuildEnv(ADDON_NAME)
local L = CrateTrackerZK.L
local NotificationDispatchService = BuildEnv("NotificationDispatchService")
local Area = BuildEnv("Area")
local Data = BuildEnv("Data")
local NotificationDecisionService = BuildEnv("NotificationDecisionService")
local NotificationOutputService = BuildEnv("NotificationOutputService")
local NotificationQueryService = BuildEnv("NotificationQueryService")
local TeamCommListener = BuildEnv("TeamCommListener")
local UnifiedDataManager = BuildEnv("UnifiedDataManager")
local Utils = BuildEnv("Utils")

local function BuildAutomaticNotificationRequest(mapName, detectionSource, eventContext)
    eventContext = type(eventContext) == "table" and eventContext or {}
    return {
        kind = "airdrop_auto",
        source = detectionSource,
        mapKey = eventContext.mapKey or mapName,
        mapId = eventContext.mapId or eventContext.mapID or eventContext.id,
        mapName = mapName,
        eventTimestamp = eventContext.eventTimestamp or eventContext.timestamp,
        objectGUID = eventContext.objectGUID,
        allowTeamChat = true,
        allowLocalFallback = true,
        allowSound = true,
        chatIntent = "automatic",
    }
end

local function ExecuteNotificationDecision(notification, message, decision)
    if NotificationOutputService and NotificationOutputService.ExecuteDecision then
        return NotificationOutputService:ExecuteDecision(notification, message, decision)
    end

    return {
        sentTeamChat = false,
        sentLocalFallback = false,
        sentText = false,
        playedSound = false,
    }
end

local function SendManualVisibleMessage(message, preferredChatType)
    local result = {
        sentTeamChat = false,
        sentLocalFallback = false,
        sentText = false,
        err = nil,
    }

    if preferredChatType then
        if NotificationOutputService and NotificationOutputService.SendManualMessage then
            local success, err = NotificationOutputService:SendManualMessage(message, preferredChatType)
            result.sentTeamChat = success == true
            result.sentText = result.sentTeamChat
            result.err = err
        end
        return result
    end

    if NotificationOutputService and NotificationOutputService.SendLocalMessage then
        result.sentLocalFallback = NotificationOutputService:SendLocalMessage(message) == true
        result.sentText = result.sentLocalFallback
    end

    return result
end

function NotificationDispatchService:SendAirdropSync(notification, syncState)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if TeamCommListener and TeamCommListener.CanEnableHiddenSync and TeamCommListener:CanEnableHiddenSync() ~= true then
        return false
    end

    local chatType = notification.GetTeamChatType and notification:GetTeamChatType() or nil
    if not chatType then
        return false
    end

    if TeamCommListener and TeamCommListener.SendConfirmedSync then
        return TeamCommListener:SendConfirmedSync(syncState, chatType)
    end
    return false
end

function NotificationDispatchService:NotifyAirdropDetected(notification, mapName, detectionSource, eventContext)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if not mapName then
        return
    end

    eventContext = eventContext or {}
    local mapNotificationKey = eventContext.mapKey or mapName
    local currentTime = Utils:GetCurrentTimestamp()
    if detectionSource == "npc_shout" and notification.RecordShout then
        notification:RecordShout(mapNotificationKey, currentTime)
    end

    local request = BuildAutomaticNotificationRequest(mapName, detectionSource, eventContext)
    local decision = NotificationDecisionService
        and NotificationDecisionService.DecideVisibleNotification
        and NotificationDecisionService:DecideVisibleNotification(notification, request, currentTime)
        or nil
    if not decision or decision.suppress == true then
        return
    end

    local message = NotificationQueryService and NotificationQueryService.BuildAirdropDetectedMessage
        and NotificationQueryService:BuildAirdropDetectedMessage(mapName)
        or string.format(L["AirdropDetected"], mapName)
    local outputResult = ExecuteNotificationDecision(notification, message, decision)
    if decision.trackDispatch == true
        and outputResult
        and outputResult.sentText == true
        and notification.CommitVisibleAutoDispatch then
        notification:CommitVisibleAutoDispatch(mapNotificationKey, eventContext, currentTime)
    end
end

function NotificationDispatchService:SendAutoTeamReport(notification)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if not notification:IsAutoTeamReportEnabled() then
        return false
    end
    if not notification:IsTeamNotificationEnabled() then
        return false
    end

    if Area then
        if Area.CanUseTrackedMapFeatures then
            if not Area:CanUseTrackedMapFeatures() then
                return false
            end
        elseif Area.IsActive and not Area:IsActive() then
            return false
        end
    end

    local mapData, remaining = notification:GetNearestAirdropInfo()
    if not mapData or remaining == nil then
        return false
    end

    local mapName = Data and Data.GetMapDisplayName and Data:GetMapDisplayName(mapData) or nil
    if not mapName or mapName == "" then
        return false
    end

    local message = NotificationQueryService and NotificationQueryService.BuildAutoTeamReportMessage
        and NotificationQueryService:BuildAutoTeamReportMessage(mapName, remaining)
        or string.format((L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!", mapName, UnifiedDataManager:FormatTime(remaining, true))
    local chatType = notification.GetTeamChatType and notification:GetTeamChatType() or nil
    if chatType then
        local visibleChatType = NotificationOutputService
            and NotificationOutputService.GetManualAirdropChatType
            and NotificationOutputService:GetManualAirdropChatType(notification, chatType)
        if visibleChatType then
            SendManualVisibleMessage(message, visibleChatType)
        end
    else
        SendManualVisibleMessage(message, nil)
    end
    return true
end

function NotificationDispatchService:NotifyMapRefresh(notification, mapData, isAirdropActive, clickButton)
    if not notification.isInitialized then
        notification:Initialize()
    end
    if not mapData then
        return
    end

    if isAirdropActive == nil then
        isAirdropActive = false
    end

    local message
    local systemMessage
    local displayName = Data:GetMapDisplayName(mapData)
    local remaining = nil

    if isAirdropActive then
        message = NotificationQueryService and NotificationQueryService.BuildAirdropDetectedMessage
            and NotificationQueryService:BuildAirdropDetectedMessage(displayName)
            or string.format(L["AirdropDetected"], displayName)
        systemMessage = message
    else
        remaining = UnifiedDataManager:GetRemainingTime(mapData.id)
        if not remaining then
            message = string.format(L["NoTimeRecord"], displayName)
            systemMessage = message
        else
            if clickButton == "RightButton" then
                message = NotificationQueryService and NotificationQueryService.BuildAutoTeamReportMessage
                    and NotificationQueryService:BuildAutoTeamReportMessage(displayName, remaining)
                    or string.format((L and L["AutoTeamReportMessage"]) or "Current [%s] War Supply Crate in: %s!!", displayName, UnifiedDataManager:FormatTime(remaining, true))
            else
                message = string.format(L["TimeRemaining"], displayName, UnifiedDataManager:FormatTime(remaining, true))
            end
            systemMessage = message
        end
    end

    local chatType = notification.GetTeamChatType and notification:GetTeamChatType() or nil
    if chatType then
        local visibleChatType = NotificationOutputService
            and NotificationOutputService.GetManualAirdropChatType
            and NotificationOutputService:GetManualAirdropChatType(notification, chatType)
        local outputResult = visibleChatType and SendManualVisibleMessage(message, visibleChatType) or nil
        if not outputResult or outputResult.sentText ~= true then
            SendManualVisibleMessage(systemMessage, nil)
        end
    else
        SendManualVisibleMessage(systemMessage, nil)
    end
end

return NotificationDispatchService
