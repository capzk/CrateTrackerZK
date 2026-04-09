-- NotificationDecisionService.lua - 用户可见提醒决策服务

local NotificationDecisionService = BuildEnv("NotificationDecisionService")
local AirdropEventService = BuildEnv("AirdropEventService")
local NotificationDedupService = BuildEnv("NotificationDedupService")
local NotificationOutputService = BuildEnv("NotificationOutputService")

local function CreateDecision()
    return {
        suppress = false,
        reason = nil,
        playSound = false,
        sendTeamChat = false,
        sendLocalFallback = false,
        chatType = nil,
        trackDispatch = false,
    }
end

local function BuildEventContext(request)
    if type(request) ~= "table" then
        return {}
    end

    return {
        mapKey = request.mapKey,
        mapId = request.mapId,
        mapName = request.mapName,
        eventTimestamp = request.eventTimestamp,
        objectGUID = request.objectGUID,
    }
end

local function ResolveMapRef(request)
    if type(request) ~= "table" then
        return nil
    end
    if request.mapKey ~= nil then
        return request.mapKey
    end
    if request.mapId ~= nil then
        return request.mapId
    end
    return request.mapName
end

local function ResolveAutomaticChatType(notification, request)
    if type(request) ~= "table" or request.allowTeamChat ~= true then
        return nil
    end
    if type(notification) ~= "table" or notification.teamNotificationEnabled ~= true then
        return nil
    end
    if not NotificationOutputService or not NotificationOutputService.GetAutomaticVisibleChatType then
        return nil
    end

    local teamChatType = NotificationOutputService.GetTeamChatType
        and NotificationOutputService:GetTeamChatType()
        or nil
    return NotificationOutputService:GetAutomaticVisibleChatType(teamChatType)
end

local function ShouldSuppressMapIconByRecentShout(notification, request, currentTime)
    if type(request) ~= "table" or request.source ~= "map_icon" then
        return false
    end
    if not NotificationDedupService or not NotificationDedupService.IsRecentShout then
        return false
    end

    local mapRef = ResolveMapRef(request)
    local isRecentShout, lastShoutTime = NotificationDedupService:IsRecentShout(
        notification,
        mapRef,
        notification and notification.SHOUT_DEDUP_WINDOW or nil,
        currentTime
    )
    if isRecentShout ~= true then
        return false
    end

    if AirdropEventService and AirdropEventService.ShouldSuppressMapIconNotification then
        return AirdropEventService:ShouldSuppressMapIconNotification(
            lastShoutTime,
            currentTime,
            notification and notification.SHOUT_DEDUP_WINDOW or nil
        ) == true
    end

    return true
end

local function HasExpiredConfirmedSyncReceipt(notification, request, currentTime)
    if not NotificationDedupService or not NotificationDedupService.HasRecentReceivedSync then
        return false
    end

    local mapRef = ResolveMapRef(request)
    local eventContext = BuildEventContext(request)
    local hasRecentReceipt, lastReceiptTime = NotificationDedupService:HasRecentReceivedSync(
        notification,
        mapRef,
        notification and notification.RECEIVED_SYNC_VISIBLE_WINDOW or nil,
        currentTime,
        eventContext
    )
    return type(lastReceiptTime) == "number" and hasRecentReceipt ~= true
end

function NotificationDecisionService:DecideVisibleNotification(notification, request, currentTime)
    local decision = CreateDecision()
    if type(request) ~= "table" then
        decision.suppress = true
        decision.reason = "invalid_request"
        return decision
    end

    currentTime = currentTime or Utils:GetCurrentTimestamp()

    if request.kind == "shared_phase_sync_applied" then
        decision.playSound = request.allowSound == true
        decision.sendTeamChat = false
        decision.sendLocalFallback = request.allowLocalFallback == true
        decision.chatType = nil
        decision.trackDispatch = false
        return decision
    end

    if request.kind ~= "airdrop_auto" then
        decision.suppress = true
        decision.reason = "unsupported_kind"
        return decision
    end

    if ShouldSuppressMapIconByRecentShout(notification, request, currentTime) then
        decision.suppress = true
        decision.reason = "recent_shout"
        return decision
    end

    if HasExpiredConfirmedSyncReceipt(notification, request, currentTime) then
        decision.suppress = true
        decision.reason = "hidden_sync_window_expired"
        return decision
    end

    local mapRef = ResolveMapRef(request)
    local eventContext = BuildEventContext(request)
    if NotificationDedupService and NotificationDedupService.HasPlayerSentNotification then
        if NotificationDedupService:HasPlayerSentNotification(notification, mapRef, eventContext) then
            decision.suppress = true
            decision.reason = "player_already_sent"
            return decision
        end
    end

    if NotificationDedupService and NotificationDedupService.CanSendNotification then
        if NotificationDedupService:CanSendNotification(notification, mapRef, eventContext, currentTime) ~= true then
            decision.suppress = true
            decision.reason = "notification_window_expired"
            return decision
        end
    end

    decision.chatType = ResolveAutomaticChatType(notification, request)
    decision.sendTeamChat = decision.chatType ~= nil
    decision.sendLocalFallback = request.allowLocalFallback == true and decision.sendTeamChat ~= true
    decision.playSound = request.allowSound == true
    decision.trackDispatch = decision.sendTeamChat == true or decision.sendLocalFallback == true
    return decision
end

return NotificationDecisionService
