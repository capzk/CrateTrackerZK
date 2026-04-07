-- NotificationOutputService.lua - 通知输出适配

local NotificationOutputService = BuildEnv("NotificationOutputService")
local Logger = BuildEnv("Logger")
local TeamCommListener = BuildEnv("TeamCommListener")

local function NormalizeAddonCallResult(...)
    local secondary = select(2, ...)
    if secondary ~= nil then
        return secondary
    end
    return select(1, ...)
end

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
        return
    end
    self:PlayAirdropAlertSound(notification)
end

local function ResolveAddonDistribution(chatType)
    if chatType == "RAID_WARNING" then
        return "RAID"
    end
    if chatType == "RAID" or chatType == "PARTY" or chatType == "INSTANCE_CHAT" then
        return chatType
    end
    return nil
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

function NotificationOutputService:SendMessage(notification, message, chatType)
    local outboundChatType = self:GetAutomaticVisibleChatType(chatType)
    if chatType and notification and notification.teamNotificationEnabled and outboundChatType then
        local success, err = pcall(function()
            SendChatMessage(message, outboundChatType)
        end)
        if not success and Logger and Logger.Warn then
            Logger:Warn(
                "Notification",
                "通知",
                string.format("发送自动团队消息失败：类型=%s，错误=%s", outboundChatType, tostring(err))
            )
        end
        return success
    end

    Logger:Info("Notification", "通知", message)
    return false
end

function NotificationOutputService:SendManualMessage(message, chatType)
    local standardChatType = nil
    if chatType == "RAID_WARNING" then
        standardChatType = IsInRaid() and "RAID_WARNING" or nil
    else
        standardChatType = self:GetStandardVisibleChatType(chatType)
    end
    if chatType and standardChatType then
        local success, err = pcall(function()
            SendChatMessage(message, standardChatType)
        end)
        return success, err
    end
    return false, nil
end

function NotificationOutputService:SendAirdropSync(syncState, chatType)
    if TeamCommListener and TeamCommListener.SendConfirmedSync then
        return TeamCommListener:SendConfirmedSync(syncState, chatType)
    end
    return false
end

return NotificationOutputService
