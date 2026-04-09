-- NotificationOutputService.lua - 通知输出适配

local NotificationOutputService = BuildEnv("NotificationOutputService")
local Logger = BuildEnv("Logger")

local function TryPlaySound(path)
    if not path or path == "" or not PlaySoundFile then
        return false
    end
    local ok, result = pcall(PlaySoundFile, path, "Master")
    if ok and result then
        return true
    end
    local ok2, result2 = pcall(PlaySoundFile, path)
    return ok2 and result2 == true
end

function NotificationOutputService:GetTeamChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

function NotificationOutputService:PlayAirdropAlertSound(notification)
    if not notification or not notification.IsSoundAlertEnabled or not notification:IsSoundAlertEnabled() then
        return false
    end
    local played = TryPlaySound(notification.airdropAlertSoundFile)
    if not played then
        Logger:Warn("Notification", "通知", string.format("空投提示音播放失败：%s", tostring(notification.airdropAlertSoundFile)))
    end
    return played
end

function NotificationOutputService:PlayDelayedAlertSound(notification)
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            self:PlayAirdropAlertSound(notification)
        end)
        return true
    end
    self:PlayAirdropAlertSound(notification)
    return true
end

local function TrySendChatMessage(message, chatType)
    if type(message) ~= "string" or message == "" then
        return false, "empty_message"
    end
    if type(chatType) ~= "string" or chatType == "" then
        return false, "invalid_chat_type"
    end

    local success, err = pcall(function()
        SendChatMessage(message, chatType)
    end)
    return success, err
end

local function ResolveAutomaticVisibleChatType(chatType)
    if chatType == "INSTANCE_CHAT" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        end
        return nil
    end
    if chatType == "RAID" or chatType == "RAID_WARNING" then
        if not IsInRaid() then
            return nil
        end
        local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        return hasPermission and "RAID_WARNING" or "RAID"
    end
    if chatType == "PARTY" then
        if IsInGroup() then
            return "PARTY"
        end
        return nil
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        local hasPermission = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        return hasPermission and "RAID_WARNING" or "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function NotificationOutputService:GetAutomaticVisibleChatType(chatType)
    return ResolveAutomaticVisibleChatType(chatType)
end

local function HasRaidWarningPermission()
    local isLeader = UnitIsGroupLeader and UnitIsGroupLeader("player") == true
    local isAssistant = UnitIsGroupAssistant and UnitIsGroupAssistant("player") == true
    return isLeader or isAssistant
end

local function ResolveStandardVisibleChatType(chatType)
    if chatType == "INSTANCE_CHAT" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        end
        return nil
    end
    if chatType == "RAID" or chatType == "RAID_WARNING" then
        if IsInRaid() then
            return "RAID"
        end
        return nil
    end
    if chatType == "PARTY" then
        if IsInGroup() then
            return "PARTY"
        end
        return nil
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function NotificationOutputService:GetStandardVisibleChatType(chatType)
    return ResolveStandardVisibleChatType(chatType)
end

function NotificationOutputService:GetManualAirdropChatType(notification, chatType)
    local standardChatType = self:GetStandardVisibleChatType(chatType)
    if standardChatType ~= "RAID" then
        return standardChatType
    end
    if not notification or not notification.IsLeaderModeEnabled or notification:IsLeaderModeEnabled() ~= true then
        return standardChatType
    end
    if not HasRaidWarningPermission() then
        return standardChatType
    end
    return "RAID_WARNING"
end

function NotificationOutputService:SendTeamMessage(message, chatType, options)
    local success, err = TrySendChatMessage(message, chatType)
    if success ~= true and options and options.logFailure == true and Logger and Logger.Warn then
        local label = options.label or "发送团队消息失败"
        Logger:Warn(
            "Notification",
            "通知",
            string.format("%s：类型=%s，错误=%s", label, tostring(chatType), tostring(err))
        )
    end
    return success, err
end

function NotificationOutputService:SendLocalMessage(message)
    Logger:Info("Notification", "通知", message)
    return true
end

function NotificationOutputService:ExecuteDecision(notification, message, decision)
    local result = {
        sentTeamChat = false,
        sentLocalFallback = false,
        sentText = false,
        playedSound = false,
    }
    if type(decision) ~= "table" or decision.suppress == true then
        return result
    end

    if decision.sendTeamChat == true then
        result.sentTeamChat = self:SendTeamMessage(message, decision.chatType, {
            logFailure = true,
            label = "发送自动团队消息失败",
        }) == true
    end
    if result.sentTeamChat ~= true and decision.sendLocalFallback == true then
        result.sentLocalFallback = self:SendLocalMessage(message) == true
    end

    result.sentText = result.sentTeamChat == true or result.sentLocalFallback == true

    if decision.playSound == true then
        result.playedSound = self:PlayDelayedAlertSound(notification) == true
    end

    return result
end

function NotificationOutputService:SendManualMessage(message, chatType)
    local standardChatType = nil
    if chatType == "RAID_WARNING" then
        standardChatType = IsInRaid() and "RAID_WARNING" or nil
    else
        standardChatType = self:GetStandardVisibleChatType(chatType)
    end
    if chatType and standardChatType then
        return self:SendTeamMessage(message, standardChatType)
    end
    return false, nil
end

return NotificationOutputService
